#!/usr/bin/env python3
"""Builds the food database bundled with Dietapp from USDA FoodData Central.

FoodData Central is in the public domain (CC0). This keeps its generic foods:
Survey (FNDDS), Foundation and SR Legacy, the same data types the app searched
through the USDA API, with their nutrients per 100 g and household portions.

    python3 Tools/build_food_database.py

Downloads the datasets once into Tools/.cache (git-ignored) and writes
Packages/Sources/NutritionKit/Resources/foods.sqlite. Uses only the standard library.

Spanish names come from two hand-written tables: Tools/spanish_food_names.tsv for the
foods searches find most often, and Tools/spanish_portion_names.tsv for common portions.
"""

import csv
import io
import os
import re
import sqlite3
import sys
import urllib.request
import zipfile
from datetime import date

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, "Tools", ".cache")
OUTPUT = os.path.join(ROOT, "Packages", "Sources", "NutritionKit", "Resources", "foods.sqlite")
SPANISH_FOOD_NAMES = os.path.join(ROOT, "Tools", "spanish_food_names.tsv")
SPANISH_PORTION_NAMES = os.path.join(ROOT, "Tools", "spanish_portion_names.tsv")
USER_AGENT = "Dietapp-build/1.0 (https://github.com/luisescamilla13/Dietapp)"

# The data type as stored in the CSVs, and the zip it ships in.
DATASETS = [
    ("survey_fndds_food", "survey_food_csv_2024-10-31"),
    ("foundation_food", "foundation_food_csv_2026-04-30"),
    ("sr_legacy_food", "sr_legacy_food_csv_2018-04"),
]

# Survey (FNDDS) files identify nutrients by their legacy number, the others by id.
NUTRIENTS = {
    "survey_fndds_food": {"208": "calories", "203": "protein", "205": "carbohydrates", "204": "fat", "291": "fiber"},
    "default": {
        "1008": "calories",
        # Foundation foods often report energy only with Atwater factors.
        "2048": "calories_atwater_specific",
        "2047": "calories_atwater_general",
        "1003": "protein",
        "1005": "carbohydrates",
        "1004": "fat",
        "1079": "fiber",
    },
}

UNDETERMINED_UNIT = "9999"

NOT_SPECIFIED = re.compile(r",? NS as to [^,]*")

# Survey (FNDDS) names read like what people eat ("Apple, raw"), so they rank first.
DATA_TYPE_PRIORITY = {"survey_fndds_food": 0.0, "foundation_food": 0.3, "sr_legacy_food": 0.6}


def main():
    foods, portions = [], []
    for data_type, dataset in DATASETS:
        tables = load(dataset)
        dataset_foods = read_foods(tables, data_type)
        foods += dataset_foods
        portions += read_portions(tables, data_type, {food[0] for food in dataset_foods})
        print(f"{dataset}: {len(dataset_foods)} foods")
    foods, portions = add_spanish_names(foods, portions)
    write(foods, portions)
    size = os.path.getsize(OUTPUT) / 1_000_000
    print(f"Wrote {len(foods)} foods and {len(portions)} portions to {os.path.relpath(OUTPUT, ROOT)} ({size:.1f} MB)")


def load(dataset):
    """Returns the CSV files of a dataset as lists of dicts, downloading it if needed."""
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, f"{dataset}.zip")
    if not os.path.exists(path):
        url = f"https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_{dataset}.zip"
        print(f"Downloading {url}")
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request) as response, open(path + ".part", "wb") as file:
            file.write(response.read())
        os.rename(path + ".part", path)

    tables = {}
    with zipfile.ZipFile(path) as archive:
        for name in archive.namelist():
            table = os.path.basename(name).removesuffix(".csv")
            if table in ("food", "food_nutrient", "food_portion", "measure_unit"):
                with archive.open(name) as file:
                    tables[table] = list(csv.DictReader(io.TextIOWrapper(file, encoding="utf-8")))
    return tables


def read_foods(tables, data_type):
    nutrient_names = NUTRIENTS.get(data_type, NUTRIENTS["default"])
    ids = {row["fdc_id"] for row in tables["food"] if row["data_type"] == data_type}
    values = {}
    for row in tables["food_nutrient"]:
        name = nutrient_names.get(row["nutrient_id"])
        if name and row["fdc_id"] in ids and row["amount"]:
            values.setdefault(row["fdc_id"], {})[name] = float(row["amount"])

    foods = []
    for row in tables["food"]:
        if row["fdc_id"] not in ids:
            continue
        nutrients = values.get(row["fdc_id"], {})
        calories = nutrients.get("calories", nutrients.get("calories_atwater_specific", nutrients.get("calories_atwater_general")))
        if calories is None:
            continue  # Can't log a food without its energy.
        name = row["description"].strip()
        foods.append((
            int(row["fdc_id"]),
            name,
            data_type,
            priority(name, data_type),
            calories,
            nutrients.get("protein", 0.0),
            nutrients.get("carbohydrates", 0.0),
            nutrients.get("fat", 0.0),
            nutrients.get("fiber", 0.0),
        ))
    return foods


def priority(name, data_type):
    """A static ranking penalty, lower is better. Search adds it to the text match score."""
    penalty = DATA_TYPE_PRIORITY[data_type]
    head = name.split(",")[0]
    if len(head) > 2 and re.fullmatch(r"[A-Z0-9 '&.\-\"]+", head):
        penalty += 3  # A restaurant or brand: "DENNY'S, french fries".
    if "abyfood" in name:
        penalty += 2
    if re.search(r"\b(meatless|imitation)\b", name):
        penalty += 1.5  # "Chicken, meatless" is not what "chicken" means.
    # "Not further specified" and "NS as to cooking method" mark the generic version.
    # The "NS as to" parts don't count toward length, since they make names longer, not more specific.
    generic = NOT_SPECIFIED.sub("", name)
    if generic != name or re.search(r"\bNFS\b", name):
        penalty -= 0.6
    if re.search(r"\braw\b", name):
        penalty -= 0.3
    if re.search(r"\b(dried|dehydrated|powder|powdered|freeze-dried|dry mix)\b", name):
        penalty += 0.5  # "Egg, whole, dried" is an ingredient, not what people eat.
    return penalty + 0.03 * len(generic)  # Shorter names are more general.


def read_portions(tables, data_type, food_ids):
    units = {row["id"]: row["name"] for row in tables.get("measure_unit", [])}
    portions = []
    for row in tables["food_portion"]:
        if not row["fdc_id"]:
            continue
        food_id = int(row["fdc_id"])
        grams = float(row["gram_weight"] or 0)
        name = portion_name(row, data_type, units)
        if food_id in food_ids and grams > 0 and name:
            position = int(row["seq_num"] or row["id"])
            portions.append((food_id, position, name, grams))
    return portions


def portion_name(row, data_type, units):
    """Matches the names the USDA API shows: "1 small/regular", "1 cup, chopped"."""
    description = row["portion_description"].strip()
    modifier = row["modifier"].strip()
    if data_type == "survey_fndds_food":
        return description  # The modifier is a numeric code here.
    amount = format_amount(row["amount"])
    unit = units.get(row["measure_unit_id"]) if row["measure_unit_id"] != UNDETERMINED_UNIT else None
    words = ", ".join(part for part in (unit, modifier or description) if part)
    return f"{amount} {words}".strip() if words else ""


def format_amount(text):
    if not text:
        return ""
    value = float(text)
    return str(int(value)) if value.is_integer() else f"{value:g}"


def add_spanish_names(foods, portions):
    """Appends each food's and portion's Spanish name, or None, to its row."""
    food_names = {int(fdc_id): (name, spanish) for fdc_id, name, spanish in read_table(SPANISH_FOOD_NAMES)}
    portion_names = dict(read_table(SPANISH_PORTION_NAMES))
    names = {food[0]: food[1] for food in foods}
    for fdc_id, (name, _) in food_names.items():
        # The English name guards against translating a food USDA renamed or replaced.
        if names.get(fdc_id) != name:
            sys.exit(f"spanish_food_names.tsv: {fdc_id} is {names.get(fdc_id)!r}, not {name!r}")
    foods = [food + (food_names.get(food[0], (None, None))[1],) for food in foods]
    portions = [portion + (portion_names.get(portion[2]),) for portion in portions]
    print(f"Spanish names: {len(food_names)} foods, {sum(p[-1] is not None for p in portions)} portions")
    return foods, portions


def read_table(path):
    """The rows of a tab-separated file, without its header."""
    with open(path, encoding="utf-8") as file:
        return list(csv.reader(file, delimiter="\t"))[1:]


def write(foods, portions):
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    if os.path.exists(OUTPUT):
        os.remove(OUTPUT)
    db = sqlite3.connect(OUTPUT)
    db.executescript("""
        CREATE TABLE foods (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            data_type TEXT NOT NULL,
            priority REAL NOT NULL,
            calories REAL NOT NULL,
            protein REAL NOT NULL,
            carbohydrates REAL NOT NULL,
            fat REAL NOT NULL,
            fiber REAL NOT NULL,
            name_es TEXT
        );
        CREATE TABLE portions (
            food_id INTEGER NOT NULL REFERENCES foods(id),
            position INTEGER NOT NULL,
            name TEXT NOT NULL,
            grams REAL NOT NULL,
            name_es TEXT
        );
        CREATE INDEX portions_by_food ON portions(food_id, position);
        -- Full-text index over the names. remove_diacritics lets "creme" find "crème".
        CREATE VIRTUAL TABLE foods_search USING fts5(
            name, content='foods', content_rowid='id', tokenize='unicode61 remove_diacritics 2'
        );
        CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
    """)
    db.executemany("INSERT INTO foods VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", foods)
    db.executemany("INSERT INTO portions VALUES (?, ?, ?, ?, ?)", portions)
    db.execute("INSERT INTO foods_search(foods_search) VALUES ('rebuild')")
    db.executemany("INSERT INTO metadata VALUES (?, ?)", [
        ("source", "USDA FoodData Central (public domain, CC0)"),
        ("datasets", ", ".join(dataset for _, dataset in DATASETS)),
        ("built", date.today().isoformat()),
    ])
    db.commit()
    db.execute("VACUUM")
    db.close()


if __name__ == "__main__":
    sys.exit(main())

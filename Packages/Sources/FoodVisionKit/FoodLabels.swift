/// The labels of Vision's image classifier that name a food or drink you could log.
///
/// The classifier knows about 1,300 labels. Most aren't food ("dog", "car"), and some
/// food labels are too broad to look up ("food", "fruit", "dessert") or are usually
/// a garnish ("cilantro"), so only these become suggestions.
enum FoodLabels {
    /// The USDA search term for a label, or `nil` when it isn't a loggable food.
    static func searchTerm(for label: String) -> String? {
        guard foods.contains(label) else { return nil }
        return searchTerms[label] ?? label.replacing("_", with: " ")
    }

    /// Search terms for labels whose name isn't what USDA calls the food.
    private static let searchTerms = [
        "bell_pepper": "sweet pepper",
        "birthday_cake": "cake",
        "cake_regular": "cake",
        "chocolate_chip": "chocolate chip cookie",
        "donut": "doughnut",
        "fries": "french fries",
        "hotdog": "hot dog",
        "mandarine": "mandarin orange",
        "oranges": "orange",
        "pepper_veggie": "sweet pepper",
        "shellfish_prepared": "shellfish",
        "soda": "soft drink",
        "springroll": "spring roll",
        "sugar_cube": "sugar",
        "tapioca_pearls": "tapioca",
        "tea_drink": "tea",
        "tortilla": "corn tortilla",
        "wedding_cake": "cake",
    ]

    static let foods: Set<String> = [
        // Fruit
        "apple", "apricot", "avocado", "banana", "blackberry", "blueberry", "cantaloupe",
        "cherry", "coconut", "cranberry", "durian", "fig", "grape", "grapefruit", "guava",
        "honeydew", "kiwi", "lemon", "lime", "lychee", "mandarine", "mango", "mangosteen",
        "melon", "nectarine", "oranges", "papaya", "passionfruit", "peach", "pear",
        "persimmon", "pineapple", "plum", "pomegranate", "rambutan", "raspberry",
        "starfruit", "strawberry", "watermelon",
        // Vegetables
        "artichoke", "arugula", "asparagus", "bean", "beet", "bell_pepper", "broccoli",
        "carrot", "cauliflower", "celery", "corn", "cucumber", "daikon", "edamame",
        "eggplant", "garlic", "green_beans", "habanero", "jalapeno", "kohlrabi", "leek",
        "lettuce", "mushroom", "onion", "pea", "pepper_veggie", "pickle", "potato",
        "pumpkin", "radish", "rhubarb", "spinach", "taro", "tomato", "zucchini",
        // Nuts and seeds
        "almond", "cashew", "chestnut", "macadamia", "peanut", "pecan", "pistachio",
        "sesame", "sunflower_seeds",
        // Meat, fish and eggs
        "anchovy", "bacon", "beef", "clam", "crab", "egg", "fried_chicken", "fried_egg",
        "grilled_chicken", "ham", "lobster", "mackerel", "meatball", "mussel", "omelet",
        "oyster", "pepperoni", "roe", "salami", "salmon", "sardine", "sausage", "scallop",
        "scrambled_eggs", "seabass", "shellfish_prepared", "snapper", "spareribs", "steak",
        "swordfish", "trout", "tuna", "yolk",
        // Bread, grains and pasta
        "bagel", "biscuit", "bread", "cereal", "croissant", "matzo", "muffin", "naan",
        "oatmeal", "pancake", "pasta", "pita", "quinoa", "rice", "scone", "spaghetti",
        "tortilla", "waffle", "white_bread",
        // Dishes
        "antipasti", "biryani", "bruschetta", "burrito", "caprese", "casserole", "coleslaw",
        "crepe", "curry", "dumpling", "falafel", "fondue", "fries", "guacamole", "gyoza",
        "hamburger", "hotdog", "hummus", "kebab", "nachos", "paella", "pierogi", "pizza",
        "quesadilla", "ramen", "risotto", "salad", "samosa", "sandwich", "satay",
        "sauerkraut", "shawarma", "souffle", "soup", "souvlaki", "springroll", "stir_fry",
        "sushi", "tabbouleh", "taco", "tapas", "tempura", "teriyaki", "wonton",
        // Dairy and spreads
        "butter", "cheese", "honey", "jelly", "mustard", "wasabi", "yogurt",
        // Sweets
        "baklava", "biscotti", "birthday_cake", "brownie", "cake", "cake_regular", "candy",
        "candy_cane", "caramel", "cheesecake", "chocolate", "chocolate_chip", "cookie",
        "cupcake", "donut", "flan", "fruitcake", "gingerbread", "ice_cream", "jello",
        "lollipop", "marshmallow", "pastry", "pie", "popcorn", "popsicle", "pretzel",
        "pudding", "strudel", "sugar_cube", "taffy", "tiramisu", "wedding_cake",
        // Drinks
        "beer", "bubble_tea", "cocktail", "coffee", "juice", "liquor", "margarita",
        "martini", "milkshake", "mojito", "red_wine", "sangria", "smoothie", "soda",
        "sparkling_wine", "tapioca_pearls", "tea_drink", "tequila", "white_wine", "wine",
    ]
}

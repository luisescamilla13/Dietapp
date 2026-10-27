import Foundation
import SQLite3

public enum LocalFoodDatabaseError: Error, Equatable {
    case cannotOpen
    case queryFailed(String)
}

/// Searches the food database bundled with the app, built from USDA FoodData Central by
/// `Tools/build_food_database.py`. Works offline and needs no API key.
///
/// An actor, because a SQLite connection must not be used from two threads at once.
public actor LocalFoodDatabase: NutritionSearching {
    private let db: OpaquePointer
    private let resultLimit: Int

    /// The database bundled with `NutritionKit`.
    public static var bundledURL: URL {
        Bundle.module.url(forResource: "foods", withExtension: "sqlite")!
    }

    public init(url: URL = LocalFoodDatabase.bundledURL, resultLimit: Int = 25) throws {
        var db: OpaquePointer?
        // Read-only and immutable: the file ships in the bundle, so SQLite can skip locking.
        let uri = "file:\(url.path(percentEncoded: true))?immutable=1"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK, let db else {
            sqlite3_close(db)
            throw LocalFoodDatabaseError.cannotOpen
        }
        self.db = db
        self.resultLimit = resultLimit
    }

    // Isolated, so closing can't race a query still running on the actor.
    isolated deinit {
        sqlite3_close(db)
    }

    public func searchFoods(matching query: String) async throws -> [Food] {
        var query = SearchQuery(query)
        guard !query.isEmpty else { return [] }

        var candidates = try candidates(matching: query)
        // A word the database doesn't know, as in "chilaquiles verdes", rules out every
        // food. Names start with the food itself, so drop words from the end.
        while candidates.isEmpty, query.terms.count > 1 {
            query.terms.removeLast()
            candidates = try self.candidates(matching: query)
        }
        let ranked = SearchRanking.rank(candidates, for: query).prefix(resultLimit)
        let foods = try foods(withIDs: ranked.map(\.id))
        return ranked.compactMap { foods[$0.id] }
    }

    /// Foods whose names match every term of the query, by text score and priority.
    private func candidates(matching query: SearchQuery) throws -> [SearchRanking.Candidate] {
        let sql = """
            SELECT foods.id, foods.name, bm25(foods_search), foods.priority
            FROM foods_search JOIN foods ON foods.id = foods_search.rowid
            WHERE foods_search MATCH ?
            ORDER BY \(Self.textScoreWeight) * bm25(foods_search) + foods.priority
            LIMIT 60
            """
        var best: [Int64: SearchRanking.Candidate] = [:]
        for expression in query.matchExpressions {
            let matches = try rows(sql, bindings: [expression]) { statement in
                (id: sqlite3_column_int64(statement, 0), name: text(statement, 1), textScore: sqlite3_column_double(statement, 2), priority: sqlite3_column_double(statement, 3))
            }
            // Text scores are relative to the best match of the same expression, so
            // Spanish and English matches compete on priority and ranking alone.
            let bestTextScore = matches.map(\.textScore).min() ?? 0
            for match in matches {
                let candidate = SearchRanking.Candidate(id: match.id, name: match.name, baseScore: Self.textScoreWeight * (match.textScore - bestTextScore) + match.priority)
                if best[match.id].map({ candidate.baseScore < $0.baseScore }) ?? true {
                    best[match.id] = candidate
                }
            }
        }
        return Array(best.values)
    }

    private func foods(withIDs ids: [Int64]) throws -> [Int64: Food] {
        guard !ids.isEmpty else { return [:] }
        let list = ids.map(String.init).joined(separator: ",")
        var portions: [Int64: [Portion]] = [:]
        for (id, portion) in try rows("SELECT food_id, name, grams FROM portions WHERE food_id IN (\(list)) ORDER BY food_id, position", read: { statement in
            (sqlite3_column_int64(statement, 0), Portion(name: text(statement, 1), grams: sqlite3_column_double(statement, 2)))
        }) {
            portions[id, default: []].append(portion)
        }

        let foods = try rows("SELECT id, name, calories, protein, carbohydrates, fat, fiber FROM foods WHERE id IN (\(list))") { statement in
            let id = sqlite3_column_int64(statement, 0)
            return Food(
                source: .usda,
                sourceID: String(id),
                name: text(statement, 1),
                nutrientsPer100g: Nutrients(
                    calories: sqlite3_column_double(statement, 2),
                    protein: sqlite3_column_double(statement, 3),
                    carbohydrates: sqlite3_column_double(statement, 4),
                    fat: sqlite3_column_double(statement, 5),
                    fiber: sqlite3_column_double(statement, 6)
                ),
                portions: portions[id] ?? []
            )
        }
        return Dictionary(uniqueKeysWithValues: foods.map { (Int64($0.sourceID)!, $0) })
    }

    private func rows<Row>(_ sql: String, bindings: [String] = [], read: (OpaquePointer) -> Row) throws -> [Row] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw LocalFoodDatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }
        for (index, value) in bindings.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), value, -1, Self.transient)
        }
        var rows: [Row] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW: rows.append(read(statement))
            case SQLITE_DONE: return rows
            default: throw LocalFoodDatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    /// How much bm25 counts next to a food's priority. Every candidate contains every
    /// term, so bm25 mostly measures how short the name is, which favors specific dishes
    /// like "Egg, creamed" over generic foods like "Egg, whole, raw".
    static let textScoreWeight = 0.3

    /// Tells SQLite to copy bound strings, since Swift's bridged C strings are temporary.
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}

private func text(_ statement: OpaquePointer, _ column: Int32) -> String {
    sqlite3_column_text(statement, column).map { String(cString: $0) } ?? ""
}

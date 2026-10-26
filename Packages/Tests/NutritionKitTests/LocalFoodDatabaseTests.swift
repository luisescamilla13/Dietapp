import Foundation
import Testing
@testable import NutritionKit

struct SearchRankingTests {
    @Test func searchTermsSkipStopWordsPluralsAndAccents() {
        #expect(SearchRanking.terms(in: "Coffee with Milk") == ["coffee", "milk"])
        #expect(SearchRanking.terms(in: "scrambled eggs") == ["scrambled", "egg"])
        #expect(SearchRanking.terms(in: "tomatoes, peaches") == ["tomato", "peach"])
        #expect(SearchRanking.terms(in: "crème brûlée") == ["creme", "brulee"])
        #expect(SearchRanking.terms(in: "glass") == ["glass"])
        #expect(SearchRanking.terms(in: "  \"*  ") == [])
    }

    @Test func prefersTheFoodItselfOverDishesThatMentionIt() {
        let ranked = SearchRanking.rank([
            candidate("Eggnog", 0),
            candidate("Egg burrito", 0),
            candidate("Pie, apple", 0),
            candidate("Egg, whole, raw", 0.5),
        ], for: ["egg"])

        #expect(ranked.map(\.name) == ["Egg, whole, raw", "Egg burrito", "Eggnog", "Pie, apple"])
    }

    @Test func keepsTheBestOfRepeatedNames() {
        let ranked = SearchRanking.rank([candidate("Strawberries, raw", 1, id: 1), candidate("Strawberries, raw", 0, id: 2)], for: ["strawberry"])

        #expect(ranked.map(\.id) == [2])
    }

    private func candidate(_ name: String, _ score: Double, id: Int64 = 0) -> SearchRanking.Candidate {
        SearchRanking.Candidate(id: id, name: name, baseScore: score)
    }
}

/// Searches the real bundled database.
struct LocalFoodDatabaseTests {
    let database: LocalFoodDatabase

    init() throws {
        database = try LocalFoodDatabase()
    }

    @Test(arguments: [
        ("apple", "Apple, raw"),
        ("taco", "Taco, NFS"),
        ("banana", "Banana, raw"),
        ("milk", "Milk, NFS"),
        ("cola soft drink", "Soft drink, cola"),
        ("scrambled eggs", "Egg, whole, cooked, scrambled"),
        ("french fries", "Potato, french fries, NFS"),
        ("corn tortilla", "Tortilla, corn"),
        ("chilaquiles", "Chilaquiles"),
    ])
    func findsTheCommonFoodFirst(query: String, expected: String) async throws {
        let foods = try await database.searchFoods(matching: query)

        #expect(foods.first?.name == expected, "\(foods.prefix(5).map(\.name))")
    }

    @Test func returnsTheSameFoodsAsTheUSDAAPI() async throws {
        let taco = try #require(try await database.searchFoods(matching: "taco").first)

        // Same FDC ID as the API, so a food logged from either source is the same food.
        #expect(taco.id == "usda:2708514")
        #expect(taco.nutrientsPer100g.calories == 246)
        #expect(taco.nutrientsPer100g.protein == 15.31)
        #expect(taco.portions.map(\.name) == ["1 miniature", "1 small/regular", "1 large", "1 cup", "Quantity not specified"])
    }

    @Test func namesPortionsOfEveryDataset() async throws {
        let apple = try #require(try await database.searchFoods(matching: "apples raw with skin").first { $0.sourceID == "171688" })

        #expect(apple.portions.first == Portion(name: "1 cup, quartered or chopped", grams: 125))
    }

    @Test func pushesRestaurantItemsDown() async throws {
        let fries = try await database.searchFoods(matching: "french fries").prefix(3)

        #expect(!fries.contains { $0.name.hasPrefix("DENNY'S") || $0.name.hasPrefix("McDONALD'S") })
    }

    @Test func treatsSearchSyntaxAsText() async throws {
        // Quotes, operators and parentheses would be FTS5 syntax if they reached SQLite.
        #expect(try await database.searchFoods(matching: "apple\" * (").first?.name == "Apple, raw")
        #expect(try await database.searchFoods(matching: "NOT AND NEAR(").isEmpty)
        #expect(try await database.searchFoods(matching: "   ").isEmpty)
        #expect(try await database.searchFoods(matching: "zzzqqq").isEmpty)
    }

    @Test func limitsTheResults() async throws {
        #expect(try await database.searchFoods(matching: "chicken").count == 25)
    }
}

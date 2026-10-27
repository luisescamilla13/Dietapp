import Foundation
import Testing
@testable import NutritionKit

struct SearchQueryTests {
    @Test func skipsStopWordsPluralsAndAccents() {
        #expect(words(of: "Coffee with Milk") == [["coffee"], ["milk"]])
        #expect(words(of: "scrambled eggs") == [["scrambled"], ["egg"]])
        #expect(words(of: "tomatoes, peaches") == [["tomato"], ["peach"]])
        #expect(words(of: "crème brûlée") == [["creme"], ["brulee"]])
        #expect(words(of: "glass") == [["glass"]])
        #expect(SearchQuery("  \"*  ").isEmpty)
    }

    @Test func translatesSpanishWords() {
        #expect(SearchQuery("pollo").terms == [.init(original: ["pollo"], english: ["chicken"])])
        #expect(SearchQuery("Frijoles").terms == [.init(original: ["frijole"], english: ["bean"])])
        #expect(SearchQuery("limones").terms == [.init(original: ["limone"], english: ["lime"])])
        #expect(SearchQuery("camote").terms == [.init(original: ["camote"], english: ["sweet", "potato"])])
    }

    @Test func completesTheLastSpanishWord() {
        #expect(SearchQuery("huev").terms == [.init(original: ["huev"], english: ["egg"])])
        #expect(SearchQuery("tacos de poll").terms.last == .init(original: ["poll"], english: ["chicken"]))
        // Too short, ambiguous, or not the last word.
        #expect(SearchQuery("hue").terms == [.init(original: ["hue"], english: nil)])
        #expect(SearchQuery("chic").terms == [.init(original: ["chic"], english: nil)])
        #expect(SearchQuery("huev rancheros").terms.first == .init(original: ["huev"], english: nil))
    }

    @Test func translatesPhrasesAsAWhole() {
        #expect(SearchQuery("tacos al pastor").terms == [.init(original: ["taco", "pastor"], english: ["taco", "corn", "tortilla", "pork"])])
        #expect(SearchQuery("papas a la francesa").terms == [.init(original: ["papa", "francesa"], english: ["french", "frie"])])
        #expect(SearchQuery("pollo frito").terms.count == 2)
    }

    @Test func searchesTheOriginalAndTheTranslation() {
        #expect(SearchQuery("egg").matchExpressions == [#""egg"*"#])
        #expect(SearchQuery("pan integral").matchExpressions == [#""pan"* "integral"*"#, #""bread"* "whole"* "wheat"*"#])
        #expect(SearchQuery("pollo grilled").matchExpressions == [#""pollo"* "grilled"*"#, #""chicken"* "grilled"*"#])
    }

    private func words(of text: String) -> [[String]] {
        SearchQuery(text).terms.map(\.original)
    }
}

struct SearchRankingTests {
    @Test func prefersTheFoodItselfOverDishesThatMentionIt() {
        let ranked = SearchRanking.rank([
            candidate("Eggnog", 0),
            candidate("Egg burrito", 0),
            candidate("Pie, apple", 0),
            candidate("Egg, whole, raw", 0.5),
        ], for: SearchQuery("egg"))

        #expect(ranked.map(\.name) == ["Egg, whole, raw", "Egg burrito", "Eggnog", "Pie, apple"])
    }

    @Test func keepsTheBestOfRepeatedNames() {
        let ranked = SearchRanking.rank([candidate("Strawberries, raw", 1, id: 1), candidate("Strawberries, raw", 0, id: 2)], for: SearchQuery("strawberry"))

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
        // Generic words find the generic food, not the shortest name.
        ("egg", "Egg, whole, raw"),
        ("chicken", "Chicken, NS as to part and cooking method, NS as to skin eaten"),
        ("coffee", "Coffee, NS as to type"),
        ("bread", "Bread, NS as to major flour"),
        ("salmon", "Fish, salmon, NFS"),
        ("soda", "Soft drink, NFS"),
    ])
    func findsTheCommonFoodFirst(query: String, expected: String) async throws {
        let foods = try await database.searchFoods(matching: query)

        #expect(foods.first?.name == expected, "\(foods.prefix(5).map(\.name))")
    }

    @Test(arguments: [
        ("manzana", "Apple, raw"),
        ("plátanos", "Banana, raw"),
        ("leche", "Milk, NFS"),
        ("huevos revueltos", "Egg, whole, cooked, scrambled"),
        ("café con leche", "Coffee, cafe con leche"),
        ("frijoles", "Beans, NFS"),
        ("frijoles refritos", "Refried beans"),
        ("tacos al pastor", "Taco, corn tortilla, pork, cheese"),
        ("tortilla de harina", "Tortilla, flour"),
        ("papas fritas", "Potato, french fries, NFS"),
        ("pechuga de pollo", "Chicken breast, NS as to cooking method, skin eaten"),
        ("caldo de pollo", "Soup, chicken"),
        ("arroz con leche", "Pudding, rice"),
        ("jugo de naranja", "Orange juice, 100%, NFS"),
        ("refresco", "Soft drink, NFS"),
        ("elote", "Corn, raw"),
        ("aguacate", "Avocado, raw"),
        ("queso fresco", "Queso Fresco"),
        ("pan dulce", "Pan dulce, NFS"),
        ("enchiladas de pollo", "Enchilada, chicken"),
        ("fresas", "Strawberries, raw"),
        ("huev", "Egg, whole, raw"),
        ("café", "Coffee, NS as to type"),
        ("frijoles negros", "Black beans, NFS"),
        ("aceite de oliva", "Olive oil"),
    ])
    func findsTheCommonFoodInSpanish(query: String, expected: String) async throws {
        let foods = try await database.searchFoods(matching: query)

        #expect(foods.first?.name == expected, "\(foods.prefix(5).map(\.name))")
    }

    @Test func ignoresWordsThatMatchNothingAtTheEnd() async throws {
        #expect(try await database.searchFoods(matching: "chilaquiles verdes").first?.name == "Chilaquiles")
    }

    @Test func keepsFoodDataCentralIDs() async throws {
        let taco = try #require(try await database.searchFoods(matching: "taco").first)

        // Same FDC ID as FoodData Central, so foods logged earlier through the USDA API still match.
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
        #expect(try await database.searchFoods(matching: "zzzqqq NOT AND NEAR(").isEmpty)
        #expect(try await database.searchFoods(matching: "   ").isEmpty)
        #expect(try await database.searchFoods(matching: "zzzqqq").isEmpty)
    }

    @Test func limitsTheResults() async throws {
        #expect(try await database.searchFoods(matching: "chicken").count == 25)
    }
}

import FoodParsingKit
import Foundation
import NutritionKit
import Testing
@testable import Dietapp

struct MealMatcherTests {
    let cola = Food.samples.first { $0.name == "Soft drink, cola" }!

    @Test func prefersAPortionMatchingTheUnit() {
        let item = ParsedFoodItem(name: "dos cocas", quantity: 2, unit: "can", searchTerm: "cola", estimatedGrams: 700)

        #expect(MealMatcher.defaultGrams(for: item, food: cola) == 744)
    }

    @Test func usesTheRegularSizeForCountedPieces() {
        let taco = Food(
            source: .usda, sourceID: "1", name: "Taco, corn tortilla, pork",
            nutrientsPer100g: .zero,
            portions: [Portion(name: "1 large", grams: 160), Portion(name: "1 small/regular", grams: 105)]
        )
        let item = ParsedFoodItem(name: "dos tacos", quantity: 2, unit: "piece", searchTerm: "pork taco", estimatedGrams: 300)

        #expect(MealMatcher.defaultGrams(for: item, food: taco) == 210)
    }

    @Test func fallsBackToTheModelsEstimate() {
        let item = ParsedFoodItem(name: "un vaso de coca", quantity: 1, unit: "glass", searchTerm: "cola", estimatedGrams: 250)

        #expect(MealMatcher.defaultGrams(for: item, food: cola) == 250)
    }

    @Test func thenTheTypicalServingThenOneHundredGrams() {
        var food = cola
        food.portions = [Portion(name: "Quantity not specified", grams: 300)]
        let item = ParsedFoodItem(name: "coca", quantity: 2, unit: "glass", searchTerm: "cola")

        #expect(MealMatcher.defaultGrams(for: item, food: food) == 600)

        food.portions = []
        #expect(MealMatcher.defaultGrams(for: item, food: food) == 200)
    }

    @Test func keepsTheOrderAndSurvivesAFailedLookup() async {
        let items = [
            ParsedFoodItem(name: "una manzana", quantity: 1, unit: "piece", searchTerm: "apple", estimatedGrams: 180),
            ParsedFoodItem(name: "algo raro", quantity: 1, unit: "piece", searchTerm: "fails", estimatedGrams: 50),
            ParsedFoodItem(name: "un taco", quantity: 1, unit: "piece", searchTerm: "taco", estimatedGrams: 90),
        ]

        let review = await MealMatcher.match(items, using: SearchFailing(query: "fails"))

        #expect(review.map(\.parsed.name) == ["una manzana", "algo raro", "un taco"])
        #expect(review.map(\.selectedFood?.name) == ["Apple, raw", nil, "Taco, NFS"])
        #expect(review.map(\.isIncluded) == [true, false, true])
    }
}

@MainActor
struct DescribeMealModelTests {
    @Test func parsesMatchesAndPreselectsAmounts() async {
        let model = DescribeMealModel(parser: StubFoodParser(), search: StubNutritionSearch())

        await model.analyze("dos tacos al pastor y una coca")

        #expect(model.phase == .review)
        #expect(model.includedItems.map(\.selectedFood?.name) == ["Taco, NFS", "Soft drink, cola"])
        // No "piece" portion for tacos, so the model's estimate; a "can" portion for the cola.
        #expect(model.includedItems.map(\.grams) == [180, 372])
    }

    @Test func explainsWhenAppleIntelligenceIsOff() async {
        let model = DescribeMealModel(parser: StubFoodParser(availability: .appleIntelligenceNotEnabled), search: StubNutritionSearch())

        await model.analyze("dos tacos")

        #expect(model.phase == .failed(DescribeMealModel.message(for: .appleIntelligenceNotEnabled)!))
    }

    @Test func failsWhenNoFoodIsFound() async {
        let model = DescribeMealModel(parser: StubFoodParser(items: []), search: StubNutritionSearch())

        await model.analyze("hola")

        guard case .failed = model.phase else {
            Issue.record("Expected a failure, got \(model.phase)")
            return
        }
        #expect(model.reviewItems.isEmpty)
    }

    @Test func ignoresABlankDescription() async {
        let model = DescribeMealModel(parser: StubFoodParser(), search: StubNutritionSearch())

        await model.analyze("   ")

        #expect(model.phase == .idle)
    }
}

/// Searches the sample foods but throws for one query.
private struct SearchFailing: NutritionSearching {
    let query: String

    func searchFoods(matching query: String) async throws -> [Food] {
        if query == self.query { throw URLError(.notConnectedToInternet) }
        return try await StubNutritionSearch().searchFoods(matching: query)
    }
}

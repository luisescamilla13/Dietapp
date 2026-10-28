import Foundation
import NutritionKit
import Testing
@testable import Dietapp

@MainActor
struct FoodSearchModelTests {
    @Test func findsMatchingFoods() async {
        let model = FoodSearchModel(search: StubNutritionSearch(), debounce: .zero)

        await model.search(for: "apple")

        #expect(model.state == .results([Food.samples[0]]))
    }

    @Test func reportsWhenNothingMatches() async {
        let model = FoodSearchModel(search: StubNutritionSearch(), debounce: .zero)

        await model.search(for: "pizza")

        #expect(model.state == .noResults)
    }

    @Test func blankQueryGoesBackToIdle() async {
        let model = FoodSearchModel(search: StubNutritionSearch(), debounce: .zero)
        await model.search(for: "apple")

        await model.search(for: "  ")

        #expect(model.state == .idle)
    }

    @Test func showsAMessageWhenSearchFails() async {
        let model = FoodSearchModel(search: FailingSearch(error: LocalFoodDatabaseError.queryFailed("disk I/O error")), debounce: .zero)

        await model.search(for: "apple")

        guard case .failed(let message) = model.state else {
            Issue.record("Expected a failure, got \(model.state)")
            return
        }
        #expect(message == String(localized: "Search failed. Try again."))
    }

    @Test func cancelledSearchKeepsThePreviousState() async {
        let model = FoodSearchModel(search: StubNutritionSearch(), debounce: .seconds(10))

        let task = Task { await model.search(for: "apple") }
        task.cancel()
        await task.value

        #expect(model.state == .idle)
    }
}

private struct FailingSearch: NutritionSearching {
    let error: LocalFoodDatabaseError

    func searchFoods(matching query: String) async throws -> [Food] {
        throw error
    }
}

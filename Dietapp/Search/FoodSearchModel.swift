import Foundation
import NutritionKit
import Observation

@Observable
final class FoodSearchModel {
    enum State: Equatable {
        case idle
        case loading
        case results([Food])
        case noResults
        case failed(String)
    }

    private(set) var state = State.idle

    @ObservationIgnored private let search: any NutritionSearching
    @ObservationIgnored private let debounce: Duration

    init(search: any NutritionSearching, debounce: Duration = .milliseconds(350)) {
        self.search = search
        self.debounce = debounce
    }

    /// Meant to be called from `.task(id: query)`: SwiftUI cancels the previous call
    /// when the query changes, so the sleep doubles as the debounce and stale
    /// responses never overwrite newer ones.
    func search(for query: String) async {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            state = .idle
            return
        }

        do {
            try await Task.sleep(for: debounce)
            state = .loading
            let foods = try await search.searchFoods(matching: query)
            try Task.checkCancellation()
            state = foods.isEmpty ? .noResults : .results(foods)
        } catch is CancellationError {
            // A newer query replaced this one.
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: any Error) -> String {
        switch error {
        case USDAClientError.invalidAPIKey:
            String(localized: "The USDA API key is invalid. Check Config/Secrets.xcconfig.")
        case USDAClientError.rateLimited:
            String(localized: "Too many searches for now. Try again in a few minutes.")
        case let error as URLError where error.code == .notConnectedToInternet:
            String(localized: "You're offline. Connect to the internet to search foods.")
        default:
            String(localized: "Search failed. Try again.")
        }
    }
}

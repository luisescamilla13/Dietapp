import FoodParsingKit
import Foundation
import NutritionKit
import Observation

@Observable
final class DescribeMealModel {
    enum Phase: Equatable {
        case idle
        /// The model is reading the description; `parsedItems` fills in as it streams.
        case parsing
        case matching
        case review
        case failed(String)
    }

    private(set) var phase = Phase.idle
    private(set) var parsedItems: [ParsedFoodItem] = []
    var reviewItems: [ReviewItem] = []

    @ObservationIgnored private let parser: any FoodParsing
    @ObservationIgnored private let search: any NutritionSearching

    init(parser: any FoodParsing, search: any NutritionSearching) {
        self.parser = parser
        self.search = search
    }

    var availability: FoodParsingAvailability { parser.availability }

    var includedItems: [ReviewItem] { reviewItems.filter { $0.isIncluded && $0.selectedFood != nil } }

    func analyze(_ description: String) async {
        let description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else { return }

        parsedItems = []
        reviewItems = []
        phase = .parsing
        do {
            for try await items in parser.parse(description) {
                parsedItems = items
            }
            try Task.checkCancellation()
            guard !parsedItems.isEmpty else {
                phase = .failed(String(localized: "Couldn't find any food in that description. Try naming each food, like \"two eggs and a coffee\"."))
                return
            }
            phase = .matching
            reviewItems = await MealMatcher.match(parsedItems, using: search)
            try Task.checkCancellation()
            phase = .review
        } catch is CancellationError {
            phase = .idle
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    func startOver() {
        phase = .idle
        parsedItems = []
        reviewItems = []
    }

    static func message(for availability: FoodParsingAvailability) -> String? {
        switch availability {
        case .available: nil
        case .deviceNotEligible: String(localized: "Describing meals needs a device that supports Apple Intelligence.")
        case .appleIntelligenceNotEnabled: String(localized: "Turn on Apple Intelligence in Settings to describe meals.")
        case .modelNotReady: String(localized: "Apple Intelligence is still getting ready. Try again in a few minutes.")
        case .unavailable: String(localized: "Describing meals isn't available right now.")
        }
    }

    private static func message(for error: any Error) -> String {
        switch error {
        case FoodParsingError.unavailable(let availability):
            message(for: availability) ?? String(localized: "Describing meals isn't available right now.")
        case FoodParsingError.unsupportedLanguage:
            String(localized: "That language isn't supported yet. Try English or Spanish.")
        case FoodParsingError.refused:
            String(localized: "Couldn't read that description. Try describing only the foods.")
        default:
            String(localized: "Something went wrong. Try again.")
        }
    }
}

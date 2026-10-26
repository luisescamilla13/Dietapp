import FoodVisionKit
import Foundation
import Observation

/// Recognizes the foods in a photo so the user can search for one of them.
@Observable
final class PhotoSuggestionsModel {
    enum State: Equatable {
        case idle
        case recognizing
        case suggestions([FoodSuggestion])
        case noFood
        case failed(String)
    }

    private(set) var state = State.idle

    @ObservationIgnored private let recognizer: any FoodRecognizing

    init(recognizer: any FoodRecognizing) {
        self.recognizer = recognizer
    }

    func recognize(_ imageData: Data) async {
        state = .recognizing
        do {
            let suggestions = try await recognizer.suggestions(for: imageData)
            try Task.checkCancellation()
            state = suggestions.isEmpty ? .noFood : .suggestions(suggestions)
        } catch is CancellationError {
            // A newer photo replaced this one.
        } catch FoodRecognitionError.unreadableImage {
            state = .failed(String(localized: "Couldn't open that photo. Try another one."))
        } catch {
            state = .failed(String(localized: "Couldn't look at that photo. Try again."))
        }
    }

    func clear() {
        state = .idle
    }
}

extension FoodSuggestion {
    /// The search term in sentence case: "French fries".
    var displayName: String {
        searchTerm.prefix(1).uppercased() + searchTerm.dropFirst()
    }
}

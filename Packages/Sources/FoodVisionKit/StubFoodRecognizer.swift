import Foundation

/// Returns fixed suggestions, for previews, UI tests and the simulator.
public struct StubFoodRecognizer: FoodRecognizing {
    public var result: [FoodSuggestion]

    public init(result: [FoodSuggestion] = StubFoodRecognizer.sampleSuggestions) {
        self.result = result
    }

    public func suggestions(for imageData: Data) async throws -> [FoodSuggestion] {
        result
    }

    public static let sampleSuggestions = [
        FoodSuggestion(label: "taco", searchTerm: "taco", confidence: 0.87),
        FoodSuggestion(label: "tortilla", searchTerm: "corn tortilla", confidence: 0.79),
    ]
}

import Foundation

/// Returns fixed suggestions, for previews, UI tests and the simulator.
public struct StubFoodRecognizer: FoodRecognizing {
    public var result: [FoodSuggestion]
    public var error: FoodRecognitionError?

    public init(result: [FoodSuggestion] = StubFoodRecognizer.sampleSuggestions, error: FoodRecognitionError? = nil) {
        self.result = result
        self.error = error
    }

    public func suggestions(for imageData: Data) async throws -> [FoodSuggestion] {
        if let error { throw error }
        return result
    }

    public static let sampleSuggestions = [
        FoodSuggestion(label: "taco", searchTerm: "taco", confidence: 0.87),
        FoodSuggestion(label: "tortilla", searchTerm: "corn tortilla", confidence: 0.79),
    ]
}

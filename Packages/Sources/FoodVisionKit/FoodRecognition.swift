import Foundation

/// A food the photo may show. The user confirms it before anything is logged.
public struct FoodSuggestion: Identifiable, Hashable, Sendable {
    /// The classifier's label, such as "fried_egg".
    public var label: String
    /// What to look up in the nutrition database, such as "fried egg".
    public var searchTerm: String
    /// From 0 to 1.
    public var confidence: Double

    public var id: String { label }

    public init(label: String, searchTerm: String, confidence: Double) {
        self.label = label
        self.searchTerm = searchTerm
        self.confidence = confidence
    }
}

public enum FoodRecognitionError: Error, Equatable {
    case unreadableImage
    case failed
}

/// Suggests foods from a photo.
public protocol FoodRecognizing: Sendable {
    /// The likeliest foods first. Empty when the photo shows no food it knows.
    func suggestions(for imageData: Data) async throws -> [FoodSuggestion]
}

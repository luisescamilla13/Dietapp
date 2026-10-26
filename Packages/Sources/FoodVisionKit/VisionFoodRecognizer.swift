import Foundation
import ImageIO
import Vision

/// Classifies photos on the device with Vision's built-in image classifier.
public struct VisionFoodRecognizer: FoodRecognizing {
    public init() {}

    public func suggestions(for imageData: Data) async throws -> [FoodSuggestion] {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil), CGImageSourceGetType(source) != nil else {
            throw FoodRecognitionError.unreadableImage
        }
        let observations: [ClassificationObservation]
        do {
            observations = try await ClassifyImageRequest().perform(on: imageData)
        } catch {
            throw FoodRecognitionError.failed
        }
        return Self.suggestions(from: observations.map { ($0.identifier, Double($0.confidence)) })
    }

    /// Labels under this confidence are mostly noise, like "strawberry" on a pizza.
    static let minimumConfidence = 0.15
    static let maximumSuggestions = 5

    /// Keeps the specific foods among the classifier's labels, likeliest first.
    static func suggestions(from observations: [(label: String, confidence: Double)]) -> [FoodSuggestion] {
        var suggestions: [FoodSuggestion] = []
        for (label, confidence) in observations.sorted(by: { $0.confidence > $1.confidence }) {
            guard confidence >= minimumConfidence, let searchTerm = FoodLabels.searchTerm(for: label) else { continue }
            // Labels like "cake" and "birthday_cake" look up the same food.
            guard !suggestions.contains(where: { $0.searchTerm == searchTerm }) else { continue }
            suggestions.append(FoodSuggestion(label: label, searchTerm: searchTerm, confidence: confidence))
            if suggestions.count == maximumSuggestions { break }
        }
        return suggestions
    }
}

import Foundation
import Testing
import Vision
@testable import FoodVisionKit

struct FoodLabelsTests {
    @Test func everyFoodIsALabelTheClassifierKnows() {
        let known = Set(ClassifyImageRequest().supportedIdentifiers)

        // A typo in the list would silently drop a food.
        #expect(FoodLabels.foods.subtracting(known).isEmpty)
    }

    @Test func mapsLabelsToSearchTerms() {
        #expect(FoodLabels.searchTerm(for: "pizza") == "pizza")
        #expect(FoodLabels.searchTerm(for: "fried_egg") == "fried egg")
        #expect(FoodLabels.searchTerm(for: "fries") == "french fries")
        #expect(FoodLabels.searchTerm(for: "dog") == nil)
        #expect(FoodLabels.searchTerm(for: "food") == nil)
        #expect(FoodLabels.searchTerm(for: "cilantro") == nil)
    }
}

struct SuggestionRankingTests {
    @Test func keepsConfidentFoodsLikeliestFirst() {
        let suggestions = VisionFoodRecognizer.suggestions(from: [
            ("food", 0.93), ("tortilla", 0.79), ("taco", 0.87), ("plate", 0.25), ("strawberry", 0.14),
        ])

        #expect(suggestions.map(\.label) == ["taco", "tortilla"])
        #expect(suggestions.map(\.searchTerm) == ["taco", "corn tortilla"])
    }

    @Test func dropsLabelsThatLookUpTheSameFood() {
        let suggestions = VisionFoodRecognizer.suggestions(from: [("birthday_cake", 0.6), ("cake", 0.5)])

        #expect(suggestions.map(\.label) == ["birthday_cake"])
    }

    @Test func suggestsAtMostFive() {
        let observations = ["apple", "banana", "cherry", "grape", "kiwi", "lemon"].map { ($0, 0.5) }

        #expect(VisionFoodRecognizer.suggestions(from: observations).count == 5)
    }
}

/// Classifies real photos with Vision, which runs on the Mac too.
struct VisionFoodRecognizerTests {
    let recognizer = VisionFoodRecognizer()

    @Test(arguments: [
        ("pizza", "pizza"),
        ("tacos", "taco"),
        ("sushi", "sushi"),
        ("hamburger", "hamburger"),
        ("salad", "salad"),
    ])
    func suggestsTheFoodInThePhoto(photo: String, label: String) async throws {
        let suggestions = try await recognizer.suggestions(for: fixture(photo))

        #expect(suggestions.prefix(3).contains { $0.label == label }, "\(suggestions.map(\.label))")
    }

    @Test func suggestsNothingForAPhotoWithoutFood() async throws {
        let suggestions = try await recognizer.suggestions(for: fixture("dog"))

        #expect(suggestions.isEmpty, "\(suggestions.map(\.label))")
    }

    @Test func rejectsDataThatIsNotAnImage() async {
        await #expect(throws: FoodRecognitionError.unreadableImage) {
            try await recognizer.suggestions(for: Data("not an image".utf8))
        }
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "jpg", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}

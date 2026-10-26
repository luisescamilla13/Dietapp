import FoodVisionKit
import Foundation
import Testing
@testable import Dietapp

@MainActor
struct PhotoSuggestionsModelTests {
    @Test func listsTheSuggestions() async {
        let model = PhotoSuggestionsModel(recognizer: StubFoodRecognizer())

        await model.recognize(Data())

        #expect(model.state == .suggestions(StubFoodRecognizer.sampleSuggestions))
    }

    @Test func saysWhenThereIsNoFood() async {
        let model = PhotoSuggestionsModel(recognizer: StubFoodRecognizer(result: []))

        await model.recognize(Data())

        #expect(model.state == .noFood)
    }

    @Test func explainsAnUnreadablePhoto() async {
        let model = PhotoSuggestionsModel(recognizer: VisionFoodRecognizer())

        await model.recognize(Data("not an image".utf8))

        guard case .failed = model.state else {
            Issue.record("Expected a failure, got \(model.state)")
            return
        }
    }

    @Test func explainsWhenRecognitionIsUnavailable() async {
        let model = PhotoSuggestionsModel(recognizer: StubFoodRecognizer(error: .unavailable))

        await model.recognize(Data())

        guard case .failed(let message) = model.state else {
            Issue.record("Expected a failure, got \(model.state)")
            return
        }
        #expect(message.contains("real device"))
    }

    @Test func showsSearchTermsInSentenceCase() {
        let fries = FoodSuggestion(label: "fries", searchTerm: "french fries", confidence: 0.5)

        #expect(fries.displayName == "French fries")
    }
}

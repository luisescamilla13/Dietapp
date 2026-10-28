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
        // Compared in the language the tests run in, which follows the simulator's.
        #expect(message == String(localized: "Photo suggestions need a real device. The simulator can't run Vision's classifier."))
    }

    @Test func showsSearchTermsInSentenceCase() {
        let fries = FoodSuggestion(label: "fries", searchTerm: "french fries", confidence: 0.5)

        #expect(fries.displayName == "French fries")
    }
}

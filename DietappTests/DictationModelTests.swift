import Foundation
import DictationKit
import Testing
@testable import Dietapp

@MainActor
struct DictationModelTests {
    @Test func addsWhatItHearsAfterTheTypedText() async {
        let model = DictationModel(dictation: StubDictation(phrase: "y una coca"))
        var updates: [String] = []

        await model.listen(in: .spanish, after: "dos tacos ") { updates.append($0) }

        #expect(updates == ["dos tacos y", "dos tacos y una", "dos tacos y una coca"])
        #expect(model.state == .idle)
    }

    @Test func explainsADeniedMicrophone() async {
        let model = DictationModel(dictation: StubDictation(error: .microphoneDenied))

        await model.listen(in: .spanish, after: "") { _ in }

        guard case .failed(let message) = model.state else {
            Issue.record("Expected a failure, got \(model.state)")
            return
        }
        #expect(message == String(localized: "Allow microphone access in Settings to dictate."))
    }
}

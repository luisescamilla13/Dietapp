import Foundation
import Testing
@testable import DictationKit

struct DictationLanguageTests {
    @Test func startsInThePhonesLanguage() {
        #expect(DictationLanguage(matching: Locale(identifier: "es-MX")) == .spanish)
        #expect(DictationLanguage(matching: Locale(identifier: "en-GB")) == .english)
        #expect(DictationLanguage(matching: Locale(identifier: "fr-FR")) == .english)
    }

    @Test func keepsTheRegionOfTheSameLanguage() {
        #expect(DictationLanguage.spanish.locale(preferring: Locale(identifier: "es-AR")).identifier == "es-AR")
        #expect(DictationLanguage.spanish.locale(preferring: Locale(identifier: "en-US")).identifier == "es-MX")
        #expect(DictationLanguage.english.locale(preferring: Locale(identifier: "es-MX")).identifier == "en-US")
    }
}

struct TranscriptTests {
    @Test func replacesThePhraseInProgressUntilItIsFinal() {
        var transcript = Transcript()

        transcript.add("dos ta", isFinal: false)
        #expect(transcript.text == "dos ta")
        transcript.add("dos tacos", isFinal: true)
        transcript.add("y una", isFinal: false)
        #expect(transcript.text == "dos tacos y una")
        transcript.add(" y una coca ", isFinal: true)
        #expect(transcript.text == "dos tacos y una coca")
    }
}

struct StubDictationTests {
    @Test func typesThePhraseWordByWord() async throws {
        var events: [DictationEvent] = []
        for try await event in StubDictation(phrase: "un taco").dictate(in: .spanish) {
            events.append(event)
        }

        #expect(events == [.listening, .transcript("un"), .transcript("un taco")])
    }

    @Test func throwsItsError() async {
        await #expect(throws: DictationError.microphoneDenied) {
            for try await _ in StubDictation(error: .microphoneDenied).dictate(in: .spanish) {}
        }
    }
}

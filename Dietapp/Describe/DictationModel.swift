import DictationKit
import Foundation
import Observation

/// Fills the meal description with what the user says.
@Observable
final class DictationModel {
    enum State: Equatable {
        case idle
        case downloadingLanguage
        case listening
        case failed(String)
    }

    private(set) var state = State.idle

    @ObservationIgnored private let dictation: any Dictating

    init(dictation: any Dictating) {
        self.dictation = dictation
    }

    /// Listens until the calling task is cancelled, calling `update` with `text` followed by
    /// everything heard so far, so dictating adds to what the user already typed.
    func listen(in language: DictationLanguage, after text: String, update: (String) -> Void) async {
        let typed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        state = .idle
        do {
            for try await event in dictation.dictate(in: language) {
                switch event {
                case .downloadingLanguage:
                    state = .downloadingLanguage
                case .listening:
                    state = .listening
                case .transcript(let heard):
                    update(typed.isEmpty ? heard : "\(typed) \(heard)")
                }
            }
            state = .idle
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: any Error) -> String {
        switch error {
        case DictationError.microphoneDenied:
            String(localized: "Allow microphone access in Settings to dictate.")
        case DictationError.unsupportedLanguage:
            String(localized: "Dictation isn't available in that language on this device.")
        case DictationError.unavailable:
            String(localized: "Dictation isn't available on this device. Type your meal instead.")
        default:
            String(localized: "Couldn't hear that. Try again.")
        }
    }
}

extension DictationLanguage {
    /// Each language in its own words, the way language pickers usually show them.
    var name: String {
        switch self {
        case .english: "English"
        case .spanish: "Español"
        }
    }
}

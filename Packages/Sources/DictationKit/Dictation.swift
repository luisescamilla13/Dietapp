import Foundation

/// A language the user can dictate in. Speech models are per language, so the user
/// picks one instead of the app guessing from the phone's settings.
public enum DictationLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case spanish = "es"

    public var id: Self { self }

    /// The language of `locale` when it's one of ours, else English.
    public init(matching locale: Locale) {
        self = Self(rawValue: locale.language.languageCode?.identifier ?? "") ?? .english
    }

    /// A locale for this language. It keeps the user's region when they already speak
    /// this language, so a Mexican phone dictates in es-MX rather than es-ES.
    public func locale(preferring current: Locale = .current) -> Locale {
        if current.language.languageCode?.identifier == rawValue { return current }
        return Locale(identifier: self == .spanish ? "es-MX" : "en-US")
    }
}

public enum DictationEvent: Sendable, Equatable {
    /// The speech model for the language is downloading. Happens once per language.
    case downloadingLanguage
    /// The microphone is on.
    case listening
    /// Everything heard so far. The last words may still change as more audio arrives.
    case transcript(String)
}

public enum DictationError: Error, Equatable {
    case microphoneDenied
    case unsupportedLanguage
    /// No microphone, or speech recognition isn't available on this device.
    case unavailable
    case failed
}

/// Turns speech into text.
public protocol Dictating: Sendable {
    /// Listens until the task reading the stream is cancelled. The stream can also end
    /// on its own, or with a `DictationError`.
    func dictate(in language: DictationLanguage) -> AsyncThrowingStream<DictationEvent, any Error>
}

/// Joins finished phrases with the phrase still being recognized.
struct Transcript {
    private var finished = ""
    private var inProgress = ""

    var text: String {
        [finished, inProgress].filter { !$0.isEmpty }.joined(separator: " ")
    }

    mutating func add(_ phrase: String, isFinal: Bool) {
        let phrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        if isFinal {
            finished = [finished, phrase].filter { !$0.isEmpty }.joined(separator: " ")
            inProgress = ""
        } else {
            inProgress = phrase
        }
    }
}

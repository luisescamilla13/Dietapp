/// Types out a fixed phrase word by word, for previews, UI tests and the simulator.
public struct StubDictation: Dictating {
    public var phrase: String
    public var error: DictationError?

    public init(phrase: String = "dos tacos al pastor y una coca", error: DictationError? = nil) {
        self.phrase = phrase
        self.error = error
    }

    public func dictate(in language: DictationLanguage) -> AsyncThrowingStream<DictationEvent, any Error> {
        let phrase = phrase
        let error = error
        return AsyncThrowingStream { continuation in
            if let error {
                continuation.finish(throwing: error)
                return
            }
            continuation.yield(.listening)
            let words = phrase.split(separator: " ")
            for count in words.indices {
                continuation.yield(.transcript(words[...count].joined(separator: " ")))
            }
            continuation.finish()
        }
    }
}

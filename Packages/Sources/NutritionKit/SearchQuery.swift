import Foundation

/// A food search split into terms that must all match. Spanish words and phrases are
/// also searched in English, so "pollo" finds "Chicken, ..." and still finds foods with
/// Spanish names, such as "Soup, sopa or caldo de pollo".
struct SearchQuery: Equatable {
    /// A word or phrase of the query. A food matches it when its name has all of the
    /// words, as word prefixes, of either the original or the English translation.
    struct Term: Equatable {
        var original: [String]
        var english: [String]?
    }

    var terms: [Term]

    private static let stopWords: Set<String> = [
        "a", "an", "and", "in", "of", "on", "or", "the", "with",
        "al", "con", "de", "del", "el", "en", "la", "las", "los", "un", "una", "unas", "unos", "y",
    ]

    init(_ text: String) {
        let raw = Self.words(in: text)
        let normalized = raw.map(Self.singular)
        terms = []
        var index = 0
        while index < raw.count {
            if let (length, english) = Self.phrase(at: index, in: normalized) {
                let original = (index..<index + length).filter { !Self.stopWords.contains(raw[$0]) }.map { normalized[$0] }
                terms.append(Term(original: original, english: english))
                index += length
                continue
            }
            if !Self.stopWords.contains(raw[index]) {
                let word = normalized[index]
                terms.append(Term(original: [word], english: Self.translation(of: word)))
            }
            index += 1
        }
        // Search runs while the user types, so the last word may be unfinished.
        if let last = raw.last, terms.last?.original == [Self.singular(last)], terms.last?.english == nil {
            terms[terms.count - 1].english = Self.completion(of: last)
        }
    }

    var isEmpty: Bool { terms.isEmpty }

    /// Every word in either language, which ranking looks for in food names.
    var words: Set<String> {
        Set(terms.flatMap { $0.original + ($0.english ?? []) })
    }

    /// FTS5 `MATCH` expressions: the query as typed and, if any of it translates, in
    /// English. They are searched apart because text scores aren't comparable across
    /// words: rare ones like "leche" score far higher than "milk".
    ///
    /// Words are quoted, so FTS5 syntax typed in the query ("AND", "*") is just text.
    var matchExpressions: [String] {
        let original = Self.expression(terms.map(\.original))
        let english = Self.expression(terms.map { $0.english ?? $0.original })
        return original == english ? [original] : [original, english]
    }

    private static func expression(_ terms: [[String]]) -> String {
        terms.joined().map { "\"\($0)\"*" }.joined(separator: " ")
    }

    // MARK: - Spanish

    private static let phrases: [[String]: [String]] = Dictionary(
        uniqueKeysWithValues: SpanishFoodWords.phrases.map { (words(in: $0).map(singular), terms(in: $1)) }
    )
    private static let longestPhrase = phrases.keys.map(\.count).max() ?? 0

    private static let translations: [String: [String]] = Dictionary(
        uniqueKeysWithValues: SpanishFoodWords.words.map { (singular(words(in: $0)[0]), terms(in: $1)) }
    )

    /// The longest Spanish phrase starting at `index`, as its length and its English words.
    private static func phrase(at index: Int, in words: [String]) -> (Int, [String])? {
        for length in stride(from: min(longestPhrase, words.count - index), through: 2, by: -1) {
            if let english = phrases[Array(words[index..<index + length])] {
                return (length, english)
            }
        }
        return nil
    }

    /// The English words for a Spanish word. Spanish plurals often add "es", which
    /// `singular` only cuts to "e": "frijoles" → "frijole" → "frijol".
    private static func translation(of word: String) -> [String]? {
        translations[word] ?? (word.hasSuffix("e") ? translations[String(word.dropLast())] : nil)
    }

    private static let completions: [(spanish: String, english: [String])] = SpanishFoodWords.words.map {
        (words(in: $0)[0], terms(in: $1))
    }

    /// The English words for the one Spanish word that starts with `prefix`: "huev" →
    /// "egg". Short or ambiguous prefixes get none, so "chic" (chícharo or chicharrón)
    /// doesn't crowd out the "chicken" someone is typing.
    private static func completion(of prefix: String) -> [String]? {
        guard prefix.count >= 4 else { return nil }
        let matches = completions.filter { $0.spanish.hasPrefix(prefix) }
        return matches.count == 1 ? matches[0].english : nil
    }

    // MARK: - Normalizing

    /// The words of English text, without stop words.
    private static func terms(in text: String) -> [String] {
        words(in: text).filter { !stopWords.contains($0) }.map(singular)
    }

    /// Lowercased words without accents: "Café con leche" → ["cafe", "con", "leche"].
    static func words(in text: some StringProtocol) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// A rough English singular, good enough for prefix search: "tomatoes" → "tomato".
    static func singular(_ word: String) -> String {
        if word.count > 4, word.hasSuffix("es") {
            let stem = word.dropLast(2)
            if stem.hasSuffix("ch") || stem.hasSuffix("sh") || "osxz".contains(stem.last!) {
                return String(stem)
            }
        }
        if word.count > 3, word.hasSuffix("s"), !word.hasSuffix("ss") {
            return String(word.dropLast())
        }
        return word
    }
}

import Foundation

/// Orders full-text search candidates the way people expect: "egg" finds "Egg, whole,
/// raw" before "Eggnog", and "apple" finds "Apple, raw" before "Pie, apple".
enum SearchRanking {
    struct Candidate: Equatable {
        var id: Int64
        var name: String
        /// SQLite's bm25 text score plus the food's static priority. Lower is better.
        var baseScore: Double
    }

    private static let stopWords: Set<String> = ["a", "an", "and", "in", "of", "on", "or", "the", "with"]

    /// The words to search for, lowercased, without accents, stop words or plurals.
    static func terms(in query: String) -> [String] {
        words(in: query).filter { !stopWords.contains($0) }.map(singular)
    }

    /// Best first, without repeated names: several datasets have "Strawberries, raw".
    static func rank(_ candidates: [Candidate], for terms: [String]) -> [Candidate] {
        let terms = Set(terms)
        let scored = candidates.map { candidate in (candidate, score(candidate, for: terms)) }
        var seen: Set<String> = []
        return scored
            .sorted { $0.1 < $1.1 }
            .map(\.0)
            .filter { seen.insert($0.name.lowercased()).inserted }
    }

    private static func score(_ candidate: Candidate, for terms: Set<String>) -> Double {
        let nameWords = words(in: candidate.name).map(singular)
        var score = candidate.baseScore
        // Names start with the food itself: "Rice, white", not "Beans and white rice".
        if let first = nameWords.first, terms.contains(first) {
            score -= 2
        }
        // Whole words beat prefix matches: "egg" over "eggnog".
        score -= Double(terms.filter(nameWords.contains).count)
        // The part before the first comma is just the searched food: "Egg, whole" over "Egg burrito".
        let head = words(in: candidate.name.prefix { $0 != "," }).map(singular)
        if !head.isEmpty, Set(head).isSubset(of: terms) {
            score -= 1.5
        }
        return score
    }

    private static func words(in text: some StringProtocol) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// A rough English singular, good enough for prefix search: "tomatoes" → "tomato".
    private static func singular(_ word: String) -> String {
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

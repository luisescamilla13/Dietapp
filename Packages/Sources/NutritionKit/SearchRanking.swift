import Foundation

/// Orders full-text search candidates the way people expect: "egg" finds "Egg, whole,
/// raw" before "Eggnog", and "apple" finds "Apple, raw" before "Pie, apple".
///
/// Terms are every word of the query in both languages, so "manzana" ranks by "apple" too.
enum SearchRanking {
    struct Candidate: Equatable {
        var id: Int64
        var name: String
        /// SQLite's bm25 text score plus the food's static priority. Lower is better.
        var baseScore: Double
    }

    /// Best first, without repeated names: several datasets have "Strawberries, raw".
    static func rank(_ candidates: [Candidate], for terms: Set<String>) -> [Candidate] {
        let scored = candidates.map { candidate in (candidate, score(candidate, for: terms)) }
        var seen: Set<String> = []
        return scored
            .sorted { $0.1 < $1.1 }
            .map(\.0)
            .filter { seen.insert($0.name.lowercased()).inserted }
    }

    private static func score(_ candidate: Candidate, for terms: Set<String>) -> Double {
        let nameWords = SearchQuery.words(in: candidate.name).map(SearchQuery.singular)
        var score = candidate.baseScore
        // Names start with the food itself: "Rice, white", not "Beans and white rice".
        if let first = nameWords.first, terms.contains(first) {
            score -= 2
        }
        // Whole words beat prefix matches: "egg" over "eggnog".
        score -= Double(terms.filter(nameWords.contains).count)
        // The part before the first comma is just the searched food: "Egg, whole" over "Egg burrito".
        let head = SearchQuery.words(in: candidate.name.prefix { $0 != "," }).map(SearchQuery.singular)
        if !head.isEmpty, Set(head).isSubset(of: terms) {
            score -= 1.5
        }
        return score
    }
}

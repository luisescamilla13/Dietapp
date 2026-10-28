import Foundation

/// Orders full-text search candidates the way people expect: "egg" finds "Egg, whole,
/// raw" before "Eggnog", and "apple" finds "Apple, raw" before "Pie, apple".
///
/// A Spanish term ranks by its English translation too, so "manzana" ranks like "apple".
enum SearchRanking {
    struct Candidate: Equatable {
        var id: Int64
        var name: String
        var spanishName: String? = nil
        /// SQLite's bm25 text score plus the food's static priority. Lower is better.
        var baseScore: Double
    }

    /// Categories that FoodData Central puts before the food: "Fish, salmon, raw" is
    /// salmon. Dishes like "Pie, apple" aren't here, since they aren't the fruit.
    private static let categories: Set<String> = ["crustacean", "fish", "mollusk", "nut", "pepper", "seed", "spice"]

    /// Best first, without repeated names: several datasets have "Strawberries, raw", and
    /// "Pomegranate, raw" and "Pomegranates, raw" are both "Granada, cruda".
    static func rank(_ candidates: [Candidate], for query: SearchQuery) -> [Candidate] {
        let scored = candidates.map { candidate in (candidate, score(candidate, for: query)) }
        var seen: Set<String> = []
        return scored
            .sorted { $0.1 < $1.1 }
            .map(\.0)
            .filter { candidate in
                let names = [candidate.name, candidate.spanishName].compactMap { $0?.lowercased() }
                guard seen.isDisjoint(with: names) else { return false }
                seen.formUnion(names)
                return true
            }
    }

    private static func score(_ candidate: Candidate, for query: SearchQuery) -> Double {
        let words = query.words
        let nameWords = Set(SearchQuery.words(in: candidate.name).map(SearchQuery.singular))
        var segments = candidate.name.split(separator: ",").map { SearchQuery.words(in: $0).map(SearchQuery.singular) }
        if segments.count > 1, segments[0].count == 1, categories.contains(segments[0][0]) {
            segments.removeFirst()
        }
        let head = segments.first ?? []
        var score = candidate.baseScore
        // Names start with the food itself: "Rice, white", not "Beans and white rice".
        if let first = head.first, words.contains(first) {
            score -= 2
        }
        // Whole words beat prefix matches: "egg" over "eggnog". Per term, so "café"
        // doesn't favor names that have both "cafe" and "coffee".
        score -= Double(query.terms.filter { term in
            Set(term.original).isSubset(of: nameWords) || term.english.map { Set($0).isSubset(of: nameWords) } == true
        }.count)
        // The part before the first comma is just the searched food: "Egg, whole" over "Egg burrito".
        if !head.isEmpty, Set(head).isSubset(of: words) {
            score -= 1.5
        }
        return score
    }
}

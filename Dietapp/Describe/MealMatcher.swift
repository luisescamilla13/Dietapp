import FoodParsingKit
import Foundation
import NutritionKit

/// A parsed item with the foods it may be, ready for the user to confirm.
nonisolated struct ReviewItem: Identifiable, Equatable {
    let id = UUID()
    let parsed: ParsedFoodItem
    /// Nutrition database matches, best first. Empty when nothing matched.
    let candidates: [Food]
    var selectedFoodID: Food.ID?
    var grams: Double
    var isIncluded: Bool

    var selectedFood: Food? { candidates.first { $0.id == selectedFoodID } }
}

/// Looks up every parsed item in the nutrition database at the same time.
nonisolated enum MealMatcher {
    static let candidateLimit = 5

    /// Results keep the order of `items`. A failed lookup gives an item with no
    /// candidates instead of failing the whole meal.
    static func match(_ items: [ParsedFoodItem], using search: any NutritionSearching) async -> [ReviewItem] {
        let candidates = await withTaskGroup(of: (Int, [Food]).self) { group in
            for (index, item) in items.enumerated() {
                group.addTask {
                    let foods = (try? await search.searchFoods(matching: item.searchTerm)) ?? []
                    return (index, Array(foods.prefix(candidateLimit)))
                }
            }
            var byIndex: [Int: [Food]] = [:]
            for await (index, foods) in group {
                byIndex[index] = foods
            }
            return byIndex
        }

        return items.enumerated().map { index, item in
            let foods = candidates[index] ?? []
            let best = foods.first
            return ReviewItem(
                parsed: item,
                candidates: foods,
                selectedFoodID: best?.id,
                grams: best.map { defaultGrams(for: item, food: $0) } ?? item.estimatedGrams ?? 100,
                isIncluded: best != nil
            )
        }
    }

    /// The amount to preselect, from most to least reliable: a database portion that
    /// matches the item's unit ("1 can"), the database's regular size for a counted piece
    /// ("1 small/regular" taco), the model's estimate, the database's typical serving,
    /// or 100 g per unit.
    static func defaultGrams(for item: ParsedFoodItem, food: Food) -> Double {
        let unit = item.unit.lowercased()
        if let portion = food.portions.first(where: { words(in: $0.name).contains(unit) }) {
            return portion.grams * item.quantity
        }
        if unit == "piece", let portion = food.portions.first(where: { !words(in: $0.name).isDisjoint(with: regularSizes) }) {
            return portion.grams * item.quantity
        }
        if let estimate = item.estimatedGrams {
            return estimate
        }
        if let typical = food.portions.first(where: { $0.name == "Quantity not specified" }) {
            return typical.grams * item.quantity
        }
        return 100 * item.quantity
    }

    private static let regularSizes: Set<String> = ["regular", "medium"]

    private static func words(in text: String) -> Set<String> {
        Set(text.lowercased().components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty })
    }
}

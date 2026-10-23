import Foundation
import NutritionKit

/// Daily targets the user sets for energy and macronutrients.
public struct NutritionGoals: Sendable, Hashable, Codable {
    public var calories: Double
    public var protein: Double
    public var carbohydrates: Double
    public var fat: Double

    public init(calories: Double, protein: Double, carbohydrates: Double, fat: Double) {
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
    }

    /// A common 2,000 kcal starting point: 25% protein, 50% carbohydrates, 25% fat.
    public static let `default` = NutritionGoals(calories: 2000, protein: 125, carbohydrates: 250, fat: 56)
}

/// Persists the goals in `UserDefaults`. Not `Sendable`, because `UserDefaults` isn't:
/// create one where it is used instead of sharing it across actors.
public struct GoalsStore {
    private let defaults: UserDefaults
    private let key = "nutritionGoals"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var goals: NutritionGoals {
        get {
            defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(NutritionGoals.self, from: $0) } ?? .default
        }
        nonmutating set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: key)
        }
    }
}

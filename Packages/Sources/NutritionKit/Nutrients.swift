/// Macronutrients and energy for a given amount of food.
public struct Nutrients: Sendable, Hashable, Codable {
    public var calories: Double
    public var protein: Double
    public var carbohydrates: Double
    public var fat: Double
    public var fiber: Double

    public init(calories: Double, protein: Double, carbohydrates: Double, fat: Double, fiber: Double) {
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.fiber = fiber
    }

    public static let zero = Nutrients(calories: 0, protein: 0, carbohydrates: 0, fat: 0, fiber: 0)

    public static func + (lhs: Nutrients, rhs: Nutrients) -> Nutrients {
        Nutrients(
            calories: lhs.calories + rhs.calories,
            protein: lhs.protein + rhs.protein,
            carbohydrates: lhs.carbohydrates + rhs.carbohydrates,
            fat: lhs.fat + rhs.fat,
            fiber: lhs.fiber + rhs.fiber
        )
    }
}

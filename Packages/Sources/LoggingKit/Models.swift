import Foundation
import NutritionKit
import SwiftData

/// The foods logged for one meal type on one day.
@Model
public final class Meal {
    #Unique<Meal>([\.day, \.typeRawValue])

    /// Start of the day in the calendar used when logging.
    public private(set) var day: Date
    // Stored as a string because SwiftData predicates can't filter on enums.
    private(set) var typeRawValue: String

    @Relationship(deleteRule: .cascade, inverse: \FoodEntry.meal)
    public internal(set) var entries: [FoodEntry] = []

    public var type: MealType { MealType(rawValue: typeRawValue) ?? .snack }

    public var nutrients: Nutrients { entries.reduce(.zero) { $0 + $1.nutrients } }

    init(day: Date, type: MealType) {
        self.day = day
        self.typeRawValue = type.rawValue
    }
}

/// One food in a meal.
@Model
public final class FoodEntry {
    public private(set) var foodID: String
    /// The name shown when the food was logged, in the app's language at the time.
    public private(set) var foodName: String
    public var grams: Double
    /// The household measure chosen when logging, such as "1 medium".
    public var portionName: String?
    public private(set) var loggedAt: Date
    /// Copied from the food when it was logged, so history doesn't change
    /// if the nutrition database later updates the food.
    public private(set) var nutrientsPer100g: Nutrients

    public private(set) var meal: Meal?

    public var nutrients: Nutrients { nutrientsPer100g.scaled(by: grams / 100) }

    init(food: Food, name: String, grams: Double, portionName: String?, loggedAt: Date) {
        self.foodID = food.id
        self.foodName = name
        self.grams = grams
        self.portionName = portionName
        self.loggedAt = loggedAt
        self.nutrientsPer100g = food.nutrientsPer100g
    }
}

public enum LoggingSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)
    public static var models: [any PersistentModel.Type] { [Meal.self, FoodEntry.self] }
}

/// Add a new schema version and a migration stage here whenever the models change.
public enum LoggingMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [LoggingSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

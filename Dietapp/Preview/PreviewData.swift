import Foundation
import LoggingKit
import NutritionKit
import SwiftData

/// Offline search over a few sample foods, for previews and tests.
nonisolated struct StubNutritionSearch: NutritionSearching {
    var foods: [Food] = Food.samples

    func searchFoods(matching query: String) async throws -> [Food] {
        foods.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}

extension Food {
    nonisolated static let samples: [Food] = [
        Food(
            source: .usda, sourceID: "2709215", name: "Apple, raw",
            nutrientsPer100g: Nutrients(calories: 61, protein: 0.17, carbohydrates: 14.8, fat: 0.15, fiber: 2.1),
            portions: [Portion(name: "1 small", grams: 165), Portion(name: "1 medium", grams: 200)]
        ),
        Food(
            source: .usda, sourceID: "2705964", name: "Egg, whole, fried",
            nutrientsPer100g: Nutrients(calories: 196, protein: 13.6, carbohydrates: 0.8, fat: 15.3, fiber: 0),
            portions: [Portion(name: "1 large", grams: 46)]
        ),
        Food(
            source: .usda, sourceID: "2708514", name: "Taco, NFS",
            nutrientsPer100g: Nutrients(calories: 246, protein: 15.3, carbohydrates: 15.6, fat: 13.6, fiber: 2.2),
            portions: [Portion(name: "1 taco", grams: 78)]
        ),
    ]
}

extension ModelContainer {
    /// An in-memory store with a few entries logged today and on earlier days.
    @MainActor
    static func preview(withSampleData: Bool = true) -> ModelContainer {
        let container = try! FoodLog.makeContainer(inMemory: true)
        guard withSampleData else { return container }

        let log = FoodLog(context: container.mainContext)
        let calendar = Calendar.current
        for daysAgo in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: .now)!
            _ = try? log.log(Food.samples[1], grams: 92, portionName: "1 large", to: .breakfast, at: date)
            _ = try? log.log(Food.samples[2], grams: 78.0 * Double(1 + daysAgo % 3), to: .lunch, at: date)
            if daysAgo % 2 == 0 {
                _ = try? log.log(Food.samples[0], grams: 200, portionName: "1 medium", to: .snack, at: date)
            }
        }
        return container
    }
}

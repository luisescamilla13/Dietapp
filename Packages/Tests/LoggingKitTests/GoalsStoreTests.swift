import Foundation
import Testing
import LoggingKit

struct GoalsStoreTests {
    // A unique suite per test keeps tests independent from each other and from the real app.
    let defaults = UserDefaults(suiteName: "GoalsStoreTests-\(UUID().uuidString)")!

    @Test func defaultsToTheStandardGoals() {
        #expect(GoalsStore(defaults: defaults).goals == .default)
    }

    @Test func savedGoalsPersistAcrossStores() {
        let goals = NutritionGoals(calories: 1800, protein: 140, carbohydrates: 180, fat: 60)

        GoalsStore(defaults: defaults).goals = goals

        #expect(GoalsStore(defaults: defaults).goals == goals)
    }
}

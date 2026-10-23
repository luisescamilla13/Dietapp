import Foundation
import NutritionKit
import SwiftData
import Testing
@testable import LoggingKit

@MainActor
struct FoodLogTests {
    let log: FoodLog
    let calendar: Calendar

    init() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        self.calendar = calendar
        log = FoodLog(context: ModelContext(try FoodLog.makeContainer(inMemory: true)), calendar: calendar)
    }

    @Test func loggingAFoodAddsItToThatDaysMeal() throws {
        try log.log(.apple, grams: 200, portionName: "1 medium", to: .snack, at: date("2026-10-23 16:00"))

        let meals = try log.meals(on: date("2026-10-23 09:00"))
        #expect(meals.map(\.type) == [.snack])
        let entry = try #require(meals.first?.entries.first)
        #expect(entry.foodName == "Apple, raw")
        #expect(entry.portionName == "1 medium")
        #expect(entry.nutrients == Nutrients(calories: 120, protein: 0.5, carbohydrates: 28, fat: 0.5, fiber: 4))
    }

    @Test func foodsInTheSameMealAndDayShareOneMeal() throws {
        try log.log(.apple, grams: 100, to: .breakfast, at: date("2026-10-23 08:00"))
        try log.log(.rice, grams: 100, to: .breakfast, at: date("2026-10-23 08:30"))

        let meals = try log.context.fetch(FetchDescriptor<Meal>())
        #expect(meals.count == 1)
        #expect(meals.first?.entries.count == 2)
    }

    @Test func mealsAreOrderedThroughTheDay() throws {
        try log.log(.rice, grams: 100, to: .dinner, at: date("2026-10-23 20:00"))
        try log.log(.apple, grams: 100, to: .breakfast, at: date("2026-10-23 08:00"))

        #expect(try log.meals(on: date("2026-10-23 12:00")).map(\.type) == [.breakfast, .dinner])
    }

    @Test func totalsOnlyCountThatDay() throws {
        try log.log(.apple, grams: 100, to: .breakfast, at: date("2026-10-23 08:00"))
        try log.log(.rice, grams: 200, to: .lunch, at: date("2026-10-23 14:00"))
        try log.log(.rice, grams: 500, to: .lunch, at: date("2026-10-24 14:00"))

        #expect(try log.totals(on: date("2026-10-23 12:00")).calories == 60 + 260)
    }

    @Test func changingGramsRescalesTheEntryNutrients() throws {
        let entry = try log.log(.apple, grams: 100, to: .snack, at: date("2026-10-23 16:00"))

        entry.grams = 150

        #expect(entry.nutrients.calories == 90)
    }

    @Test func deletingAnEntryRemovesItFromTheTotals() throws {
        let entry = try log.log(.apple, grams: 100, to: .snack, at: date("2026-10-23 16:00"))
        try log.log(.rice, grams: 100, to: .snack, at: date("2026-10-23 16:00"))

        try log.delete(entry)

        #expect(try log.totals(on: date("2026-10-23 12:00")).calories == 130)
    }

    @Test func dailyTotalsIncludeDaysWithNothingLogged() throws {
        try log.log(.apple, grams: 100, to: .snack, at: date("2026-10-21 16:00"))
        try log.log(.rice, grams: 100, to: .lunch, at: date("2026-10-23 14:00"))

        let totals = try log.dailyTotals(from: date("2026-10-21 00:00"), through: date("2026-10-23 23:00"))

        #expect(totals.map(\.day) == [date("2026-10-21 00:00"), date("2026-10-22 00:00"), date("2026-10-23 00:00")])
        #expect(totals.map(\.nutrients.calories) == [60, 0, 130])
    }

    private func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: string)!
    }
}

private extension Food {
    static let apple = Food(
        source: .usda,
        sourceID: "2709215",
        name: "Apple, raw",
        nutrientsPer100g: Nutrients(calories: 60, protein: 0.25, carbohydrates: 14, fat: 0.25, fiber: 2)
    )
    static let rice = Food(
        source: .usda,
        sourceID: "2512381",
        name: "Rice, white, cooked",
        nutrientsPer100g: Nutrients(calories: 130, protein: 2.5, carbohydrates: 28, fat: 0.25, fiber: 0.5)
    )
}

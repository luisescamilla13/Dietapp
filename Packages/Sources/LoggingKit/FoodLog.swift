import Foundation
import NutritionKit
import SwiftData

/// Total nutrients for one day, used by the history chart.
public struct DayTotal: Sendable, Hashable {
    public var day: Date
    public var nutrients: Nutrients

    /// One total per day from `start` through `end`, including days with nothing logged.
    /// Pure, so views can build it from `@Query` results and stay live.
    public static func totals(for meals: [Meal], from start: Date, through end: Date, calendar: Calendar) -> [DayTotal] {
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        let byDay = Dictionary(grouping: meals, by: \.day).mapValues { $0.reduce(.zero) { $0 + $1.nutrients } }

        var totals: [DayTotal] = []
        var day = first
        while day <= last {
            totals.append(DayTotal(day: day, nutrients: byDay[day] ?? .zero))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return totals
    }
}

/// Reads and writes the food log. Main-actor bound because it shares the
/// SwiftUI view context.
@MainActor
public final class FoodLog {
    public let context: ModelContext
    private let calendar: Calendar

    public init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: LoggingSchemaV1.self),
            migrationPlan: LoggingMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }

    @discardableResult
    public func log(_ food: Food, grams: Double, portionName: String? = nil, to type: MealType, at date: Date = .now) throws -> FoodEntry {
        let meal = try meal(type, on: date) ?? {
            let meal = Meal(day: calendar.startOfDay(for: date), type: type)
            context.insert(meal)
            return meal
        }()
        let entry = FoodEntry(food: food, grams: grams, portionName: portionName, loggedAt: date)
        context.insert(entry)
        meal.entries.append(entry)
        try context.save()
        return entry
    }

    /// The time to stamp on a food logged to `day`: `now` for today, or the current
    /// time of day on an earlier day, so entries keep a sensible order within it.
    public func loggingDate(for day: Date, now: Date = .now) -> Date {
        if calendar.isDate(day, inSameDayAs: now) { return now }
        let time = calendar.dateComponents([.hour, .minute, .second], from: now)
        return calendar.date(
            bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: time.second ?? 0,
            of: calendar.startOfDay(for: day)
        ) ?? calendar.startOfDay(for: day)
    }

    public func delete(_ entry: FoodEntry) throws {
        context.delete(entry)
        try context.save()
    }

    /// The day's meals that have at least one entry, in breakfast-to-snack order.
    public func meals(on date: Date) throws -> [Meal] {
        let day = calendar.startOfDay(for: date)
        let meals = try context.fetch(FetchDescriptor<Meal>(predicate: #Predicate { $0.day == day }))
        return meals
            .filter { !$0.entries.isEmpty }
            .sorted { MealType.allCases.firstIndex(of: $0.type)! < MealType.allCases.firstIndex(of: $1.type)! }
    }

    public func totals(on date: Date) throws -> Nutrients {
        try meals(on: date).reduce(.zero) { $0 + $1.nutrients }
    }

    public func dailyTotals(from start: Date, through end: Date) throws -> [DayTotal] {
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        let meals = try context.fetch(FetchDescriptor<Meal>(predicate: #Predicate { $0.day >= first && $0.day <= last }))
        return DayTotal.totals(for: meals, from: first, through: last, calendar: calendar)
    }

    private func meal(_ type: MealType, on date: Date) throws -> Meal? {
        let day = calendar.startOfDay(for: date)
        let rawValue = type.rawValue
        var descriptor = FetchDescriptor<Meal>(predicate: #Predicate { $0.day == day && $0.typeRawValue == rawValue })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

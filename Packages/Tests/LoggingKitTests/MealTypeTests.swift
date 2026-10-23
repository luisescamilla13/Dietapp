import Foundation
import Testing
import LoggingKit

struct MealTypeTests {
    @Test func mealsAreOrderedThroughTheDay() {
        #expect(MealType.allCases == [.breakfast, .lunch, .dinner, .snack])
    }

    @Test func rawValuesAreStableForPersistence() {
        #expect(MealType.allCases.map(\.rawValue) == ["breakfast", "lunch", "dinner", "snack"])
    }

    @Test(arguments: [
        (4, MealType.snack),
        (5, .breakfast), (10, .breakfast),
        (11, .snack),
        (12, .lunch), (16, .lunch),
        (17, .snack),
        (18, .dinner), (22, .dinner),
        (23, .snack), (0, .snack),
    ])
    func suggestsTheMealForTheHour(hour: Int, expected: MealType) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: hour, minute: 30))!

        #expect(MealType.suggested(at: date, calendar: calendar) == expected)
    }
}

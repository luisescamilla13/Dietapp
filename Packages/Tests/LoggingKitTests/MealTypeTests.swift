import Testing
import LoggingKit

struct MealTypeTests {
    @Test func mealsAreOrderedThroughTheDay() {
        #expect(MealType.allCases == [.breakfast, .lunch, .dinner, .snack])
    }

    @Test func rawValuesAreStableForPersistence() {
        #expect(MealType.allCases.map(\.rawValue) == ["breakfast", "lunch", "dinner", "snack"])
    }
}

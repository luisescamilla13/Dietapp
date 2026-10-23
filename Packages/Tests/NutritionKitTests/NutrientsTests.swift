import Testing
import NutritionKit

struct NutrientsTests {
    @Test func additionSumsEveryField() {
        let egg = Nutrients(calories: 72, protein: 6.5, carbohydrates: 0.5, fat: 4.75, fiber: 0)
        let toast = Nutrients(calories: 80, protein: 3, carbohydrates: 14, fat: 1, fiber: 2)

        #expect(egg + toast == Nutrients(calories: 152, protein: 9.5, carbohydrates: 14.5, fat: 5.75, fiber: 2))
    }

    @Test func zeroIsTheIdentity() {
        let egg = Nutrients(calories: 72, protein: 6.5, carbohydrates: 0.5, fat: 4.75, fiber: 0)

        #expect(egg + .zero == egg)
    }
}

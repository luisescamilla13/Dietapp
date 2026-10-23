import Testing
import NutritionKit

struct NutrientsTests {
    @Test func additionSumsEveryField() {
        let egg = Nutrients(calories: 72, protein: 6.5, carbohydrates: 0.5, fat: 4.75, fiber: 0)
        let toast = Nutrients(calories: 80, protein: 3, carbohydrates: 14, fat: 1, fiber: 2)

        #expect(egg + toast == Nutrients(calories: 152, protein: 9.5, carbohydrates: 14.5, fat: 5.75, fiber: 2))
    }

    @Test func foodNutrientsScaleFromPer100Grams() {
        let rice = Food(
            source: .usda,
            sourceID: "1",
            name: "Rice, cooked",
            nutrientsPer100g: Nutrients(calories: 130, protein: 2.5, carbohydrates: 28, fat: 0.25, fiber: 0.5)
        )

        #expect(rice.nutrients(forGrams: 200) == Nutrients(calories: 260, protein: 5, carbohydrates: 56, fat: 0.5, fiber: 1))
    }

    @Test func zeroIsTheIdentity() {
        let egg = Nutrients(calories: 72, protein: 6.5, carbohydrates: 0.5, fat: 4.75, fiber: 0)

        #expect(egg + .zero == egg)
    }
}

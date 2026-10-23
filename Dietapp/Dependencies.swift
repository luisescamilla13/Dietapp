import FoodParsingKit
import NutritionKit
import SwiftUI

extension EnvironmentValues {
    /// Injected by `DietappApp`; previews and tests pass a stub instead.
    @Entry var nutritionSearch: any NutritionSearching = StubNutritionSearch()
    @Entry var foodParser: any FoodParsing = StubFoodParser()
}

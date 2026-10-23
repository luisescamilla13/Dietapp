import Testing
import FoodVisionKit

struct FoodVisionKitTests {
    @Test func moduleIsLinked() {
        #expect(FoodVisionKit.moduleName == "FoodVisionKit")
    }
}

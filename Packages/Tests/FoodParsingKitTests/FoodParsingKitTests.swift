import Testing
import FoodParsingKit

struct FoodParsingKitTests {
    @Test func moduleIsLinked() {
        #expect(FoodParsingKit.moduleName == "FoodParsingKit")
    }
}

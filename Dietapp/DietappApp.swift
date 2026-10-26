import DictationKit
import FoodParsingKit
import FoodVisionKit
import LoggingKit
import NutritionKit
import SwiftData
import SwiftUI

@main
struct DietappApp: App {
    private let container: ModelContainer
    private let nutritionSearch: any NutritionSearching
    private let foodParser: any FoodParsing
    private let dictation: any Dictating
    private let foodRecognizer: any FoodRecognizing
    @State private var goals = GoalsSettings()

    init() {
        // Launch arguments let UI tests and the agent harness run without touching
        // real data or the network.
        let arguments = ProcessInfo.processInfo.arguments
        do {
            // The bundled database works offline, unlike the USDA API it replaces.
            nutritionSearch = arguments.contains("-stub-search")
                ? StubNutritionSearch()
                : try LocalFoodDatabase()
        } catch {
            fatalError("Could not open the bundled food database: \(error)")
        }
        foodParser = arguments.contains("-stub-parser")
            ? StubFoodParser()
            : FoundationModelsFoodParser()
        dictation = arguments.contains("-stub-dictation")
            ? StubDictation()
            : SpeechAnalyzerDictation()
        foodRecognizer = arguments.contains("-stub-recognizer")
            ? StubFoodRecognizer()
            : VisionFoodRecognizer()
        do {
            container = try FoodLog.makeContainer(inMemory: arguments.contains("-in-memory-store"))
        } catch {
            fatalError("Could not open the food log store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.nutritionSearch, nutritionSearch)
                .environment(\.foodParser, foodParser)
                .environment(\.dictation, dictation)
                .environment(\.foodRecognizer, foodRecognizer)
                .environment(goals)
        }
        .modelContainer(container)
    }
}

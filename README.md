# Dietapp

[![CI](https://github.com/luisescamilla13/Dietapp/actions/workflows/ci.yml/badge.svg)](https://github.com/luisescamilla13/Dietapp/actions/workflows/ci.yml)

A free, open-source iOS food logging app that uses Apple's **on-device** AI. Describe a meal by text or voice ("two scrambled eggs and a coffee with milk"), scan a barcode, or snap a photo of your plate, and Dietapp turns it into a meal entry with its nutrients. No account, no server, and your data never leaves your phone. Food search runs on a database bundled with the app, so it works offline.

> **Status:** early development. The project foundation is in place, and features land phase by phase (see [Roadmap](#roadmap)).

## Tech stack

| Area | Choice |
|---|---|
| UI | SwiftUI, Observation (`@Observable`), NavigationStack |
| Concurrency | Swift 6 language mode with strict concurrency, async/await, actors, `AsyncStream` |
| Persistence | SwiftData |
| Charts | Swift Charts |
| Text AI | Apple Foundation Models (on-device) with guided generation |
| Image AI | Vision, optionally a Core ML Food-101 model |
| Voice | `SpeechAnalyzer` |
| Barcodes | VisionKit `DataScannerViewController` |
| Nutrition data | USDA FoodData Central, bundled as SQLite with full-text search (FTS5) |
| Tests | Swift Testing, XCUITest, Maestro |
| CI | GitHub Actions |

## Architecture

The app target is a thin SwiftUI layer. The logic lives in a local Swift package (`Packages/`) split into modules, and each module only sees the modules it declares as dependencies:

| Module | Responsibility |
|---|---|
| `NutritionKit` | Domain models (`Food`, `Nutrients`), and the bundled food database |
| `LoggingKit` | Meals and daily totals with SwiftData. Depends on `NutritionKit` |
| `FoodParsingKit` | Natural language → structured food items with Foundation Models |
| `FoodVisionKit` | Photo → food suggestions with Vision's on-device image classifier |
| `DictationKit` | Speech → text on device with `SpeechAnalyzer`, in English or Spanish |

Each module exposes protocols with mock implementations, which the tests and SwiftUI previews use. The packages also build for macOS, so their tests run with `swift test` in seconds, without a simulator.

## Requirements

- Xcode 27 or later
- iOS 26 or later (Foundation Models features require an Apple Intelligence–capable device with Apple Intelligence turned on. Without it, the app falls back to manual search.)

## Getting started

```sh
git clone https://github.com/luisescamilla13/Dietapp.git
cd Dietapp
open Dietapp.xcodeproj
```

The app needs no API key: foods come from the bundled database.

### Food database

`Packages/Sources/NutritionKit/Resources/foods.sqlite` holds about 13,600 generic foods from [USDA FoodData Central](https://fdc.nal.usda.gov) (public domain): the Survey (FNDDS), Foundation and SR Legacy datasets, with nutrients per 100 g and household portions. Food IDs are FoodData Central's, so `usda:2708514` is "Taco, NFS" on [fdc.nal.usda.gov](https://fdc.nal.usda.gov/food-details/2708514/nutrients). To rebuild it, for example after a new USDA release:

```sh
python3 Tools/build_food_database.py   # standard library only; caches downloads in Tools/.cache
```

Search uses SQLite's FTS5 for candidates, then ranks them in Swift (`SearchRanking`), so "egg" finds "Egg, whole, raw" before "Eggnog". It works in English and Spanish: `SearchQuery` also searches the English translation of Spanish words and phrases (`SpanishFoodWords`), so "pollo" finds chicken, "frijoles refritos" finds refried beans, and foods FoodData Central already names in Spanish, like "Soup, sopa or caldo de pollo", still match.

Running the tests:

```sh
# Package tests on macOS, offline. The language model and speech tests run only where
# Apple Intelligence and the speech models are installed.
cd Packages && swift test

# App tests on the simulator
xcodebuild test -project Dietapp.xcodeproj -scheme Dietapp \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:DietappTests

# End-to-end UI test: search, log a food, check Today and History
xcodebuild test -project Dietapp.xcodeproj -scheme Dietapp \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:DietappUITests \
  -parallel-testing-enabled NO
```

The UI tests launch the app with `-in-memory-store`, `-stub-search`, `-stub-parser`, `-stub-dictation` and `-stub-recognizer`, so they never touch your data, the network, the language model or the microphone. The photo flow has no UI test: the system photo picker runs in its own process, out of reach of UI tests.

```sh
# Opt-in: describe a meal with the real on-device model and the bundled food database
# (needs Apple Intelligence turned on on the Mac running the simulator)
TEST_RUNNER_LIVE_UI_TESTS=1 xcodebuild test -project Dietapp.xcodeproj -scheme Dietapp \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -only-testing:DietappUITests/DietappUITests/testLiveDescribeMeal -parallel-testing-enabled NO
```

## Roadmap

- [x] **Phase 0:** project foundation, modules, CI
- [x] **Phase 1:** food logging MVP: USDA search, meals, daily totals, history charts
- [ ] **Phase 2:** barcode scanning with Open Food Facts
- [x] **Phase 3:** text and voice logging with on-device Foundation Models
- [x] **Phase 4:** food suggestions from a photo
- [ ] **Phase 5:** quality: test coverage, accessibility, Spanish and English localization
- [ ] **Phase 6:** open-source verification harness that lets AI coding agents drive the app

## License

[MIT](LICENSE)

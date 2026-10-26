# Dietapp

[![CI](https://github.com/luisescamilla13/Dietapp/actions/workflows/ci.yml/badge.svg)](https://github.com/luisescamilla13/Dietapp/actions/workflows/ci.yml)

A free, open-source iOS food logging app that uses Apple's **on-device** AI. Describe a meal by text or voice ("two scrambled eggs and a coffee with milk"), scan a barcode, or snap a photo of your plate, and Dietapp turns it into a meal entry with its nutrients. No account, no server, and your data never leaves your phone (except for nutrition lookups to USDA and Open Food Facts).

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
| Nutrition data | USDA FoodData Central, Open Food Facts |
| Tests | Swift Testing, XCUITest, Maestro |
| CI | GitHub Actions |

## Architecture

The app target is a thin SwiftUI layer. The logic lives in a local Swift package (`Packages/`) split into modules, and each module only sees the modules it declares as dependencies:

| Module | Responsibility |
|---|---|
| `NutritionKit` | Domain models (`Food`, `Nutrients`) and the USDA / Open Food Facts clients |
| `LoggingKit` | Meals and daily totals with SwiftData. Depends on `NutritionKit` |
| `FoodParsingKit` | Natural language → structured food items with Foundation Models |
| `FoodVisionKit` | Photo → food suggestions with Vision / Core ML |
| `DictationKit` | Speech → text on device with `SpeechAnalyzer`, in English or Spanish |

Each module exposes protocols with mock implementations, which the tests and SwiftUI previews use. The packages also build for macOS, so their tests run with `swift test` in seconds, without a simulator.

## Requirements

- Xcode 27 or later
- iOS 26 or later (Foundation Models features require an Apple Intelligence–capable device with Apple Intelligence turned on. Without it, the app falls back to manual search and barcodes.)

## Getting started

```sh
git clone https://github.com/luisescamilla13/Dietapp.git
cd Dietapp
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # optional: add your USDA API key
open Dietapp.xcodeproj
```

You can get a free USDA API key at [fdc.nal.usda.gov](https://fdc.nal.usda.gov/api-key-signup). Without one, the app uses USDA's rate-limited `DEMO_KEY`. Note that the key ends up inside the app binary: keeping it out of the repo prevents leaks through git, but it does not make the key secret.

Running the tests:

```sh
# Package tests on macOS (offline, using recorded USDA responses). The language model
# and speech tests run only where Apple Intelligence and the speech models are installed.
cd Packages && swift test

# Also run the tests that call the real USDA API
USDA_API_KEY=your_key swift test

# App tests on the simulator
xcodebuild test -project Dietapp.xcodeproj -scheme Dietapp \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:DietappTests

# End-to-end UI test: search, log a food, check Today and History
xcodebuild test -project Dietapp.xcodeproj -scheme Dietapp \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:DietappUITests \
  -parallel-testing-enabled NO
```

The UI tests launch the app with `-in-memory-store`, `-stub-search`, `-stub-parser` and `-stub-dictation`, so they never touch your data, the network, the language model or the microphone.

```sh
# Opt-in: describe a meal with the real on-device model and the real USDA API
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
- [ ] **Phase 4:** food suggestions from a photo
- [ ] **Phase 5:** quality: test coverage, accessibility, Spanish and English localization
- [ ] **Phase 6:** open-source verification harness that lets AI coding agents drive the app

## License

[MIT](LICENSE)

import XCTest

final class DietappUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The Phase 1 goal: search "apple", log it, and see today's totals and the history update.
    @MainActor
    func testLoggingAFoodUpdatesTodayAndHistory() throws {
        let app = launchApp()
        attachScreenshot(of: app, named: "1-today-empty")

        logSmallApple(in: app)

        // 1 small apple = 165 g × 61 kcal / 100 g ≈ 101 kcal.
        XCTAssertTrue(app.staticTexts["101 kcal"].exists)
        attachScreenshot(of: app, named: "4-today-logged")

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Days logged, 1 of 7"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "5-history")
    }

    @MainActor
    func testSwipeDeletesAFood() throws {
        let app = launchApp()
        logSmallApple(in: app)

        app.cells.containing(.staticText, identifier: "Apple, raw").firstMatch.swipeLeft()
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()

        XCTAssertTrue(app.staticTexts["Apple, raw"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 kcal"].exists)
    }

    @MainActor
    func testDeleteFromTheEditScreen() throws {
        let app = launchApp()
        logSmallApple(in: app)

        app.staticTexts["Apple, raw"].tap()
        app.buttons["Delete food"].tap()

        XCTAssertTrue(app.staticTexts["Apple, raw"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 kcal"].exists)
    }

    @MainActor
    func testLoggingToAnEarlierDay() throws {
        let app = launchApp()

        app.buttons["Previous day"].tap()
        XCTAssertTrue(app.navigationBars["Yesterday"].waitForExistence(timeout: 5))
        logSmallApple(in: app)
        XCTAssertTrue(app.staticTexts["101 kcal"].exists)
        attachScreenshot(of: app, named: "6-yesterday-logged")

        app.buttons["Back to today"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 kcal"].exists)
        XCTAssertFalse(app.staticTexts["Apple, raw"].exists)

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Days logged, 1 of 7"].waitForExistence(timeout: 5))
    }

    /// Phase 3: describe a whole meal, review what the model found, and log it all.
    @MainActor
    func testDescribingAMealLogsEveryFood() throws {
        let app = launchApp()

        app.navigationBars.buttons["Add food"].tap()
        app.buttons["Describe your meal"].tap()

        let field = app.textFields["Two scrambled eggs and a coffee with milk"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("dos tacos al pastor y una coca")
        app.buttons["Find foods"].tap()

        let add = app.navigationBars.buttons["Add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["DOS TACOS AL PASTOR"].exists || app.staticTexts["dos tacos al pastor"].exists)
        attachScreenshot(of: app, named: "7-describe-review")
        add.tap()

        // The meal depends on the time of day, so its section may be off-screen. The day's
        // total is always visible: 180 g of taco (443 kcal) plus one 372 g can of cola (156 kcal).
        XCTAssertTrue(app.staticTexts["599 kcal"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "8-describe-logged")
    }

    /// Dictating fills in the description; the stub types "dos tacos al pastor y una coca".
    @MainActor
    func testDictatingAMeal() throws {
        let app = launchApp()

        app.navigationBars.buttons["Add food"].tap()
        app.buttons["Describe your meal"].tap()
        let dictate = app.buttons["dictation-toggle"]
        XCTAssertTrue(dictate.waitForExistence(timeout: 5))
        dictate.tap()

        let field = app.textFields.firstMatch
        let filledIn = NSPredicate(format: "value == %@", "dos tacos al pastor y una coca")
        wait(for: [expectation(for: filledIn, evaluatedWith: field)], timeout: 5)
        attachScreenshot(of: app, named: "9-dictated")
        app.buttons["Find foods"].tap()

        let add = app.navigationBars.buttons["Add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(app.staticTexts["599 kcal"].waitForExistence(timeout: 5))
    }

    /// The same flow with the real on-device model and the real USDA API. Opt-in, since it
    /// needs Apple Intelligence on the Mac and network access:
    /// `TEST_RUNNER_LIVE_UI_TESTS=1 xcodebuild test -only-testing:DietappUITests/DietappUITests/testLiveDescribeMeal …`
    @MainActor
    func testLiveDescribeMeal() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LIVE_UI_TESTS"] == "1", "Set TEST_RUNNER_LIVE_UI_TESTS=1 to run")
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory-store"]
        app.launch()

        app.navigationBars.buttons["Add food"].tap()
        app.buttons["Describe your meal"].tap()
        let field = app.textFields["Two scrambled eggs and a coffee with milk"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("dos tacos al pastor y una coca")
        app.buttons["Find foods"].tap()

        XCTAssertTrue(app.navigationBars.buttons["Add"].waitForExistence(timeout: 60))
        attachScreenshot(of: app, named: "live-review")
    }

    // MARK: - Helpers

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory-store", "-stub-search", "-stub-parser", "-stub-dictation"]
        app.launch()
        return app
    }

    /// Searches "apple" and logs 1 small apple, ending back on Today.
    @MainActor
    private func logSmallApple(in app: XCUIApplication) {
        app.navigationBars.buttons["Add food"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("apple")

        let result = app.staticTexts["Apple, raw"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "2-search-results")
        result.tap()

        attachScreenshot(of: app, named: "3-add-food")
        app.navigationBars.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["Apple, raw"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

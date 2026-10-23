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

        app.staticTexts["Apple, raw"].swipeLeft()
        app.buttons["Delete"].tap()

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

    // MARK: - Helpers

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory-store", "-stub-search"]
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

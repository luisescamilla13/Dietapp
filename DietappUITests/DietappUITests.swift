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

    /// Searches the real bundled database in Spanish. Offline, so it runs with the others.
    @MainActor
    func testSearchingInSpanish() throws {
        let app = launchApp(stubbingSearch: false)
        app.navigationBars.buttons["Add food"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("frijoles refritos")

        XCTAssertTrue(app.staticTexts["Refried beans"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "10-spanish-search")
    }

    /// The interface follows the device language, and so do the names of common foods.
    @MainActor
    func testSpanishInterface() throws {
        let app = launchApp(stubbingSearch: false, language: "es", region: "es_MX")
        XCTAssertTrue(app.navigationBars["Hoy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Desayuno"].exists)
        attachScreenshot(of: app, named: "11-spanish-today")

        app.navigationBars.buttons["Agregar alimento"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("huevo")
        let egg = app.staticTexts["Huevo entero, crudo"]
        XCTAssertTrue(egg.waitForExistence(timeout: 5))
        egg.tap()
        XCTAssertTrue(app.staticTexts["1 huevo (50 g)"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "12-spanish-add-food")
        app.navigationBars.buttons["Agregar"].tap()
        XCTAssertTrue(app.staticTexts["Huevo entero, crudo"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Historial"].tap()
        XCTAssertTrue(app.staticTexts["Días registrados, 1 de 7"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "13-spanish-history")
    }

    /// The same flow with the real on-device model and the bundled food database. Opt-in,
    /// since it needs Apple Intelligence on the Mac:
    /// `TEST_RUNNER_LIVE_UI_TESTS=1 xcodebuild test -only-testing:DietappUITests/DietappUITests/testLiveDescribeMeal …`
    @MainActor
    func testLiveDescribeMeal() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LIVE_UI_TESTS"] == "1", "Set TEST_RUNNER_LIVE_UI_TESTS=1 to run")
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory-store", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
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

    /// Xcode's accessibility audit on every screen: labels, contrast, hit regions and
    /// traits. Dynamic Type and clipping are checked by `testLargeTextLayouts` instead.
    @MainActor
    func testScreensPassTheAccessibilityAudit() throws {
        continueAfterFailure = true
        let app = launchApp()
        try audit(app, "Today")
        app.buttons["Previous day"].tap()
        XCTAssertTrue(app.navigationBars["Yesterday"].waitForExistence(timeout: 5))
        try audit(app, "Yesterday")
        app.buttons["Back to today"].tap()

        app.navigationBars.buttons["Goals"].tap()
        XCTAssertTrue(app.navigationBars["Goals"].waitForExistence(timeout: 5))
        try audit(app, "Goals")
        app.buttons["Cancel"].tap()

        app.navigationBars.buttons["Add food"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        try audit(app, "Add food")
        app.buttons["Describe your meal"].tap()
        XCTAssertTrue(app.buttons["Find foods"].waitForExistence(timeout: 5))
        try audit(app, "Describe your meal")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("apple")
        let result = app.staticTexts["Apple, raw"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        try audit(app, "Search results")
        result.tap()
        XCTAssertTrue(app.navigationBars.buttons["Add"].waitForExistence(timeout: 5))
        try audit(app, "Add a food")
        app.navigationBars.buttons["Add"].tap()

        app.staticTexts["Apple, raw"].tap()
        XCTAssertTrue(app.buttons["Delete food"].waitForExistence(timeout: 5))
        try audit(app, "Edit a food")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        try audit(app, "History")
    }

    /// At the largest accessibility text size, the macro rings become rows and the
    /// history chart labels fewer days, so nothing wraps mid-word or overlaps.
    @MainActor
    func testLargeTextLayouts() throws {
        let app = launchApp(textSize: "UICTContentSizeCategoryAccessibilityXXXL")
        // Each ring is one accessibility element, labeled with its macro.
        let protein = app.otherElements["Protein"]
        let carbs = app.otherElements["Carbs"]
        XCTAssertTrue(protein.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(carbs.frame.minY, protein.frame.maxY - 1, "Carbs sits below protein, not beside it")
        attachScreenshot(of: app, named: "14-large-text-today")

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "15-large-text-history")
    }

    // MARK: - Helpers

    @MainActor
    /// In English unless `language` says otherwise, whatever the simulator's language.
    private func launchApp(stubbingSearch: Bool = true, language: String = "en", region: String = "en_US", textSize: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory-store", "-stub-parser", "-stub-dictation", "-stub-recognizer"]
            + (stubbingSearch ? ["-stub-search"] : [])
            + ["-AppleLanguages", "(\(language))", "-AppleLocale", region]
            + (textSize.map { ["-UIPreferredContentSizeCategoryName", $0] } ?? [])
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

    /// Runs the audit and records every issue it finds, instead of stopping at the first.
    ///
    /// Leaves out what the system draws rather than the app, which the audit misreads:
    /// - Dynamic Type and clipped text, reported for system form rows, pickers and fields
    ///   that show their whole text. `testLargeTextLayouts` covers large text instead.
    /// - Anything on or behind the navigation and tab bars, whose glass the audit
    ///   measures as the background.
    /// - "Nearly passed" contrast, which is the system's secondary label color.
    /// - Text with no element, which is Swift Charts' axis labels. The chart itself is
    ///   one accessible element with a value for each day.
    @MainActor
    private func audit(_ app: XCUIApplication, _ screen: String) throws {
        let bars = [app.navigationBars.firstMatch, app.tabBars.firstMatch].filter(\.exists).map(\.frame)
        try app.performAccessibilityAudit(for: XCUIAccessibilityAuditType.all.subtracting([.dynamicType, .textClipped])) { issue in
            let isOnABar = issue.element.map { element in bars.contains { $0.intersects(element.frame) } } ?? false
            let isNearlyPassingContrast = issue.auditType == .contrast && issue.compactDescription.contains("nearly passed")
            let isChartText = issue.element == nil && issue.auditType == .elementDetection
            if isOnABar || isNearlyPassingContrast || isChartText {
                return true
            }
            let element = issue.element.map { "\($0.elementType) \"\($0.label)\"" } ?? "no element"
            XCTFail("\(screen): \(issue.compactDescription) (\(element))")
            return true
        }
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

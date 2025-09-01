import XCTest

final class SymptomNotesMoreUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testOpenDoctorMode() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["診察モード"].tap()
        XCTAssertTrue(app.staticTexts["診察モード"].waitForExistence(timeout: 5))
    }

    func testOpenSharePDF() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["期間選択・PDF"].tap()
        XCTAssertTrue(app.staticTexts["共有 / PDF"].waitForExistence(timeout: 5))
    }
}

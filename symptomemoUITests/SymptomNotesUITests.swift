import XCTest

final class SymptomNotesUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func testCreateSaveAndList() {
        let app = XCUIApplication()
        app.launch()

        // ＋ボタンで今日のメモ作成
        app.buttons["今日のメモ"].tap()

        // エディタで本文入力
        let textViews = app.textViews
        XCTAssertTrue(textViews.element.waitForExistence(timeout: 5))
        textViews.element.tap()
        textViews.element.typeText("UIテストのメモ")

        // 保存
        app.buttons["保存"].tap()

        // 一覧に反映（先頭セルにテキストが一部見える想定）
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "UIテストのメモ")).firstMatch.waitForExistence(timeout: 5))
    }
}

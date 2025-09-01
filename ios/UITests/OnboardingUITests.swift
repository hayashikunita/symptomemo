import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testOnboardingFlow() {
        let app = XCUIApplication()
        app.launch()

        // 初回想定: シートに「次へ」ボタンがあり、ページングが進む
        let next = app.buttons["次へ"]
        if next.waitForExistence(timeout: 3) {
            next.tap()
            next.tap()
            next.tap() // 音声入力ステップまで進む
            app.buttons["はじめる"].tap()
        }

        // 固定ヘッダーのクイックアクションが見える
        XCTAssertTrue(app.staticTexts["今日のメモを書く"].exists || app.staticTexts["今日のメモを開く"].exists)
    }
}

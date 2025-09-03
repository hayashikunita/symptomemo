import XCTest

final class AIAdviceViewUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    private func openAIAdvice() {
        let button = app.buttons["AIアドバイス"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "AIアドバイスボタンが見つかりません")
        button.tap()
    }

    private func ensureAtLeastOneEntry() {
        // 既に生成済みかもしれないので、AIアドバイスを閉じてから作成
        app.buttons["閉じる"].firstMatch.tap()

        let newToday = app.buttons["今日のメモ"]
        XCTAssertTrue(newToday.waitForExistence(timeout: 5), "今日のメモボタンが見つかりません")
        newToday.tap()

        // エディタの保存
        let save = app.buttons["保存"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "保存ボタンが見つかりません")
        save.tap()
    }

    func testAPIKeySaveDeleteAndEnablement() {
        openAIAdvice()

        // メモが0件なら作成してから再度開く
        let disabledGenerate = app.buttons["アドバイスを生成"]
        if app.staticTexts["メモが0件のため生成ボタンは無効です。まずメモを1件以上作成してください。"].waitForExistence(timeout: 1) {
            ensureAtLeastOneEntry()
            openAIAdvice()
        }

        let generate = app.buttons["アドバイスを生成"]
        XCTAssertTrue(generate.waitForExistence(timeout: 5), "生成ボタンが見つかりません")
        XCTAssertFalse(generate.isEnabled, "APIキー未入力でも生成が有効になっています")

        // APIキー入力→保存
        let skField = app.secureTextFields["sk-..."]
        XCTAssertTrue(skField.waitForExistence(timeout: 5), "APIキー入力欄が見つかりません")
        skField.tap()
        skField.typeText("sk-test-1234")

        app.buttons["保存"].tap()

        // 保存直後に有効化される（ローカルstate反映）
        XCTAssertTrue(generate.isEnabled, "保存後に生成が有効になりません")

        // 閉じて再度開く（永続化確認）
        app.buttons["閉じる"].tap()
        openAIAdvice()
        XCTAssertTrue(app.buttons["アドバイスを生成"].isEnabled, "再起動相当の再表示後に生成が無効です（保存が保持されていません）")

        // 削除で無効化
        app.buttons["削除"].tap()
        XCTAssertFalse(app.buttons["アドバイスを生成"].isEnabled, "削除後も生成が有効のままです")
    }

    func testModelQuickPickAndSaveToast() {
        openAIAdvice()

        // モデルクイック選択→保存→トースト表示
        let quick = app.buttons["gpt-4o-mini"]
        XCTAssertTrue(quick.waitForExistence(timeout: 5), "モデルクイック選択が見つかりません")
        quick.tap()

        let saveModel = app.buttons["モデル保存"]
        XCTAssertTrue(saveModel.waitForExistence(timeout: 5), "モデル保存ボタンが見つかりません")
        saveModel.tap()

        XCTAssertTrue(app.staticTexts["保存しました"].waitForExistence(timeout: 3), "モデル保存トーストが表示されません")
    }
}

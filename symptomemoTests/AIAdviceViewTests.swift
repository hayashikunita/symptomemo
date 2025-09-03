import XCTest
@testable import symptomemo

final class AIAdviceViewTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // クリア
        AIKeyStore.setAPIKey(nil)
    }

    func testKeychainFallbackPersistence() {
        // 保存
        AIKeyStore.setAPIKey("sk-unit-abc")
        XCTAssertEqual(AIKeyStore.getAPIKey(), "sk-unit-abc")
        // 上書き
        AIKeyStore.setAPIKey("sk-unit-def")
        XCTAssertEqual(AIKeyStore.getAPIKey(), "sk-unit-def")
        // 削除
        AIKeyStore.setAPIKey(nil)
        XCTAssertNil(AIKeyStore.getAPIKey())
    }

    func testModelSanitizationFallback() async throws {
        // gpt-5やo3系を指定しても安全なデフォルトへ
        let s = AppSettings()
        s.aiModel = "gpt-5"
        let e = SymptomEntry(date: Date(), text: "t", severity: 1, medication: "", isImportant: false)
        do {
            // APIキーなしのためnoAPIKeyが投げられるのが期待結果（モデルのサニタイズでクラッシュしない）
            _ = try await AIService.getAdvice(for: [e], settings: s)
            XCTFail("Expected noAPIKey")
        } catch AIServiceError.noAPIKey {
            // OK
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

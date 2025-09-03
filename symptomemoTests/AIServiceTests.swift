import XCTest
import SwiftData
@testable import symptomemo

final class AIServiceTests: XCTestCase {
    func testBuildPrompt_SingleEntry_Tones() throws {
        let entry = SymptomEntry(date: Date(), text: "吐き気あり", severity: 6, medication: "ナウゼリン", isImportant: true)
        var opt = AIService.Options()
        opt.kind = .full
        opt.tone = .polite
        let p1 = AIService.buildPrompt(from: entry, options: opt)
        XCTAssertTrue(p1.contains("吐き気あり"))
        XCTAssertTrue(p1.contains("重症度: 6/10"))

        opt.tone = .clinician
        let p2 = AIService.buildPrompt(from: entry, options: opt)
        XCTAssertTrue(p2.contains("医療者向け"))
    }

    func testBuildPrompt_List_ShortBullets() throws {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let e1 = SymptomEntry(date: yesterday, text: "頭痛", severity: 4, medication: "ロキソニン", isImportant: false)
        let e2 = SymptomEntry(date: today, text: "改善", severity: 1, medication: "", isImportant: false)
        var opt = AIService.Options()
        opt.kind = .short
        opt.bullets = 4
        let prompt = AIService.buildPrompt(from: [e2, e1], options: opt)
        XCTAssertTrue(prompt.contains("最大4個"))
        // 簡易チェック（順序/日付フォーマットまではテストしない）
        XCTAssertTrue(prompt.contains("頭痛"))
        XCTAssertTrue(prompt.contains("改善"))
    }
}

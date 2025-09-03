import XCTest
@testable import symptomemo

final class AIPDFSummarizerTests: XCTestCase {
    func testSummary_PrefersShortOverFull_AndSkipsEmpty() {
        let cal = Calendar.current
        let d1 = cal.date(byAdding: .day, value: -2, to: Date())!
        let d2 = cal.date(byAdding: .day, value: -1, to: Date())!
        let d3 = Date()

        let e1 = SymptomEntry(date: d1, text: "", severity: 1, medication: "", isImportant: false)
        e1.aiAdvice = "フル1"
        e1.aiAdviceShort = "ショート1"

        let e2 = SymptomEntry(date: d2, text: "", severity: 1, medication: "", isImportant: false)
        e2.aiAdvice = "フル2" // shortがないのでフルを使用

        let e3 = SymptomEntry(date: d3, text: "", severity: 1, medication: "", isImportant: false)
        // どちらもない -> スキップ

        let text = AIPDFSummarizer.summaryText(from: d1, to: d3, entries: [e2, e3, e1])
        // e1: shortが採用される
        XCTAssertTrue(text.contains("ショート1"))
        XCTAssertFalse(text.contains("フル1"))
        // e2: fullが採用される
        XCTAssertTrue(text.contains("フル2"))
        // e3: 何も出ない
        XCTAssertFalse(text.contains("（記録がありません）"))
    }
}

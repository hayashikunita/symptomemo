import XCTest
@testable import symptomemo

final class ReportBuilderOrderTests: XCTestCase {
    func testSummary_SortsByDateAscending() {
        let cal = Calendar.current
        let d1 = cal.date(byAdding: .day, value: -2, to: Date())!
        let d2 = cal.date(byAdding: .day, value: -1, to: Date())!
        let e1 = SymptomEntry(date: d1, text: "A", severity: 1, medication: "", isImportant: false)
        let e2 = SymptomEntry(date: d2, text: "B", severity: 1, medication: "", isImportant: false)

        let text = ReportBuilder.makeSummary(from: d1, to: d2, entries: [e2, e1])
        // 文字列におけるAとBの出現順で判定
        let idxA = (text as NSString).range(of: "A").location
        let idxB = (text as NSString).range(of: "B").location
        XCTAssertTrue(idxA != NSNotFound && idxB != NSNotFound)
        XCTAssertLessThan(idxA, idxB)
    }
}

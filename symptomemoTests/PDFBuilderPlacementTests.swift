import XCTest
@testable import symptomemo

final class PDFBuilderPlacementTests: XCTestCase {
    func testPDF_WithSettingsPlacementDoesNotCrash() {
        let now = Date()
        let entries = [SymptomEntry(date: now, text: "PDF配置テスト", severity: 3, medication: "", isImportant: false)]
        let s = AppSettings()
        s.pdfAIPlacement = 0 // 前付け
        let url = PDFBuilder.makePDF(from: now, to: now, entries: entries, settings: s)
        let size = (try? Data(contentsOf: url).count) ?? 0
        XCTAssertTrue(size > 0)
    }
}

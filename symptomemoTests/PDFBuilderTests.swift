import XCTest
@testable import symptomemo

final class PDFBuilderTests: XCTestCase {
    func testMakePDF_GeneratesNonEmptyFile() {
        let now = Date()
        let entries = [
            SymptomEntry(date: now, text: "PDFテスト本文", severity: 4, medication: "薬A", isImportant: true)
        ]
    let url = PDFBuilder.makePDF(from: now, to: now, entries: entries, settings: nil)
        let size = (try? Data(contentsOf: url).count) ?? 0
        XCTAssertTrue(size > 0)
    }
}

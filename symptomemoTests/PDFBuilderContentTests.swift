import XCTest
@testable import symptomemo

final class PDFBuilderContentTests: XCTestCase {
    func testPDF_PerEntryPlacement_IncreasesSizeWhenAIContentPresent() {
        let now = Date()
        let emptyEntries = [SymptomEntry(date: now, text: "本文のみ", severity: 2, medication: "", isImportant: false)]

        let s = AppSettings(); s.pdfAIPlacement = 1 // 後付け

        let baseURL = PDFBuilder.makePDF(from: now, to: now, entries: emptyEntries, settings: s)
        let baseSize = (try? Data(contentsOf: baseURL).count) ?? 0

        // 同じ日にAI短い版を付与したエントリ
        let withAI = SymptomEntry(date: now, text: "本文のみ", severity: 2, medication: "", isImportant: false)
        withAI.aiAdviceShort = "ポイント1\nポイント2"

        let aiURL = PDFBuilder.makePDF(from: now, to: now, entries: [withAI], settings: s)
        let aiSize = (try? Data(contentsOf: aiURL).count) ?? 0

        XCTAssertTrue(baseSize > 0 && aiSize > 0)
        XCTAssertGreaterThan(aiSize, baseSize, "AI内容分だけPDFサイズが増えるはず")
    }
}

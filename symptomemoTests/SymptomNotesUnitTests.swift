import XCTest
import SwiftData
@testable import symptomemo

final class SymptomNotesUnitTests: XCTestCase {
    func testSwiftDataInMemory_SaveAndFetch() throws {
        let container = try ModelContainer(for: SymptomEntry.self, AppSettings.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let entry = SymptomEntry(date: Date(), text: "テスト", severity: 5, medication: "内服A", isImportant: true)
        context.insert(entry)
        try context.save()

        let descriptor = FetchDescriptor<SymptomEntry>(sortBy: [.init(\SymptomEntry.date)])
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.text, "テスト")
        XCTAssertEqual(fetched.first?.severity, 5)
        XCTAssertEqual(fetched.first?.isImportant, true)
    }

    func testSummaryBuilder_Empty() {
        let now = Date()
        let text = ReportBuilder.makeSummary(from: now, to: now, entries: [])
        XCTAssertTrue(text.contains("（記録がありません）"))
    }

    func testSummaryBuilder_Content() {
        let cal = Calendar.current
        let day1 = cal.date(byAdding: .day, value: -1, to: Date())!
        let day2 = Date()
        let e1 = SymptomEntry(date: day1, text: "少し痛み", severity: 3, medication: "鎮痛剤", isImportant: false)
        let e2 = SymptomEntry(date: day2, text: "落ち着いた", severity: 1, medication: "", isImportant: true)
        let text = ReportBuilder.makeSummary(from: day1, to: day2, entries: [e2, e1])
        XCTAssertTrue(text.contains("重症度: 3/10"))
        XCTAssertTrue(text.contains("[重要]"))
        XCTAssertTrue(text.contains("鎮痛剤"))
        XCTAssertTrue(text.contains("落ち着いた"))
    }
}

import XCTest
import SwiftData
@testable import symptomemo

final class AIHistoryCascadeTests: XCTestCase {
    func testCascadeDelete_RemovesHistory() throws {
        let container = try ModelContainer(for: SymptomEntry.self, AIAdviceRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let entry = SymptomEntry(date: Date(), text: "", severity: 0, medication: "", isImportant: false)
        context.insert(entry)

        let r1 = AIAdviceRecord(kind: "full", text: "フル", entry: entry)
        let r2 = AIAdviceRecord(kind: "short", bullets: 5, text: "ショート", entry: entry)
        context.insert(r1)
        context.insert(r2)
        try context.save()

        var hist = try context.fetch(FetchDescriptor<AIAdviceRecord>())
        XCTAssertEqual(hist.count, 2)

        context.delete(entry)
        try context.save()

        hist = try context.fetch(FetchDescriptor<AIAdviceRecord>())
        XCTAssertEqual(hist.count, 0, "Cascade delete should remove related AIAdviceRecord")
    }
}

import XCTest
import SwiftData
@testable import symptomemo

final class ModelsMigrationTests: XCTestCase {
    func testAppSettings_OptionalAIPlacement_Defaults() throws {
        let container = try ModelContainer(for: SymptomEntry.self, AppSettings.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let s = AppSettings()
        context.insert(s)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<AppSettings>())
        XCTAssertEqual(fetched.count, 1)
        // Optional attribute should be nil initially or defaulted
        XCTAssertTrue(fetched.first?.pdfAIPlacement == nil || fetched.first?.pdfAIPlacement == 1)
    }

    func testInsertAndAutoSaveEntry() throws {
        let container = try ModelContainer(for: SymptomEntry.self, AppSettings.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let e = SymptomEntry(date: Date(), text: "test", severity: 2, medication: "", isImportant: false)
        context.insert(e)
        try context.save()
        let list = try context.fetch(FetchDescriptor<SymptomEntry>())
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.first?.text, "test")
    }
}

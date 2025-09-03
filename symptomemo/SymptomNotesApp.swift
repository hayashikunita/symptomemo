import SwiftUI
import SwiftData

@main
struct SymptomNotesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    .modelContainer(for: [SymptomEntry.self, AppSettings.self, AIAdviceRecord.self])
    }
}

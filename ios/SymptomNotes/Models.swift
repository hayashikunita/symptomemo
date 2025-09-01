import Foundation
import SwiftData

@Model
final class SymptomEntry: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var text: String
    var severity: Int
    var medication: String
    var isImportant: Bool

    init(id: UUID = UUID(), date: Date = Date(), text: String = "", severity: Int = 0, medication: String = "", isImportant: Bool = false) {
        self.id = id
        self.date = date
        self.text = text
        self.severity = severity
        self.medication = medication
        self.isImportant = isImportant
    }
}

@Model
final class AppSettings {
    var enableHaptics: Bool
    var enableSound: Bool
    var accentHex: String
    var hasSeenOnboarding: Bool
    var quickActionTitle: String?
    var quickActionSubtitle: String?
    var quickActionScale: Double
    var textScale: Int // 0:標準,1:大,2:特大
    var highContrast: Bool
    var simpleMode: Bool

    init(
        enableHaptics: Bool = true,
        enableSound: Bool = true,
        accentHex: String = "#C19A6B",
        hasSeenOnboarding: Bool = false,
        quickActionTitle: String? = nil,
        quickActionSubtitle: String? = nil,
        quickActionScale: Double = 1.0,
        textScale: Int = 0,
        highContrast: Bool = false,
        simpleMode: Bool = false
    ) {
        self.enableHaptics = enableHaptics
        self.enableSound = enableSound
        self.accentHex = accentHex
        self.hasSeenOnboarding = hasSeenOnboarding
        self.quickActionTitle = quickActionTitle
        self.quickActionSubtitle = quickActionSubtitle
        self.quickActionScale = quickActionScale
        self.textScale = textScale
        self.highContrast = highContrast
        self.simpleMode = simpleMode
    }
}

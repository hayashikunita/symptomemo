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
    // AI generated advice (saved)
    var aiAdvice: String?
    var aiAdviceShort: String?
    @Relationship(deleteRule: .cascade, inverse: \AIAdviceRecord.entry) var aiHistory: [AIAdviceRecord] = []

    init(id: UUID = UUID(), date: Date = Date(), text: String = "", severity: Int = 5, medication: String = "", isImportant: Bool = false) {
        self.id = id
        self.date = date
        self.text = text
        self.severity = severity
        self.medication = medication
        self.isImportant = isImportant
    }
}

@Model
final class AIAdviceRecord: Identifiable {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var kind: String // "full" or "short"
    var tone: String? // "polite", "concise", "clinician"
    var bullets: Int?
    var model: String?
    var text: String
    var entry: SymptomEntry?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        kind: String,
        tone: String? = nil,
        bullets: Int? = nil,
        model: String? = "gpt-4o-mini",
        text: String,
        entry: SymptomEntry? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.tone = tone
        self.bullets = bullets
        self.model = model
        self.text = text
        self.entry = entry
    }
}

@Model
final class AppSettings {
    var enableHaptics: Bool
    var enableSound: Bool
    var accentHex: String
    var hasSeenOnboarding: Bool
    // サブスク購入フラグ（後方互換のためオプショナル）
    var isPremium: Bool?
    // 無料トライアル状態/終了日時（後方互換のためオプショナル）
    var isInTrial: Bool?
    var trialEndAt: Date?
    // トライアル中のAIアドバイス日次回数制限（後方互換のためオプショナル）
    var aiTrialDailyCountDate: Date?
    var aiTrialDailyCount: Int?
    var quickActionTitle: String?
    var quickActionSubtitle: String?
    var quickActionScale: Double
    var textScale: Int // 0:標準,1:大,2:特大
    var highContrast: Bool
    var simpleMode: Bool
    var pdfAIPlacement: Int? // 0: 前付け, 1: 後付け（既存データ移行用にオプショナル）
    var aiModel: String?
    var aiSystemPrompt: String?

    init(
        enableHaptics: Bool = true,
        enableSound: Bool = true,
        accentHex: String = "#C19A6B",
        hasSeenOnboarding: Bool = false,
    isInTrial: Bool? = nil,
    trialEndAt: Date? = nil,
    aiTrialDailyCountDate: Date? = nil,
    aiTrialDailyCount: Int? = nil,
        quickActionTitle: String? = nil,
        quickActionSubtitle: String? = nil,
        quickActionScale: Double = 1.0,
        textScale: Int = 0,
        highContrast: Bool = false,
    simpleMode: Bool = false,
    isPremium: Bool? = nil,
    pdfAIPlacement: Int? = 1,
    aiModel: String? = nil,
    aiSystemPrompt: String? = nil
    ) {
        self.enableHaptics = enableHaptics
        self.enableSound = enableSound
        self.accentHex = accentHex
        self.hasSeenOnboarding = hasSeenOnboarding
    self.isInTrial = isInTrial
    self.trialEndAt = trialEndAt
    self.aiTrialDailyCountDate = aiTrialDailyCountDate
    self.aiTrialDailyCount = aiTrialDailyCount
        self.quickActionTitle = quickActionTitle
        self.quickActionSubtitle = quickActionSubtitle
        self.quickActionScale = quickActionScale
        self.textScale = textScale
        self.highContrast = highContrast
    self.simpleMode = simpleMode
    self.isPremium = isPremium
    self.pdfAIPlacement = pdfAIPlacement
    self.aiModel = aiModel
    self.aiSystemPrompt = aiSystemPrompt
    }
}

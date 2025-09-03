import Foundation

struct AIAdviceRequest: Codable {
    let model: String
    let messages: [Message]
    let temperature: Double?

    struct Message: Codable {
        let role: String
        let content: String
    }
}

struct AIAdviceResponse: Codable {
    struct Choice: Codable { let message: AIAdviceRequest.Message }
    let choices: [Choice]
}

enum AIServiceError: Error { case noAPIKey, invalidResponse }

enum AIService {
    private static let defaultModel = "gpt-4o-mini"

    private static func sanitizeModel(_ name: String?) -> String {
        guard let m = name?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty else { return defaultModel }
        // Chat Completionsで非対応の代表モデルはデフォルトへフォールバック
        let lower = m.lowercased()
    let unsupported = ["o3", "o3-mini", "gpt-o3"]
        if unsupported.contains(lower) { return defaultModel }
        return m
    }
    static func buildPrompt(from entries: [SymptomEntry], options: Options) -> String {
        let df = DateFormatter(); df.locale = .current; df.dateStyle = .medium
        let style: String
        switch options.tone {
        case .polite: style = "丁寧な敬体（です・ます調）で、一般の方向けにわかりやすく"
        case .concise: style = "簡潔に、短文中心で分かりやすく"
        case .clinician: style = "医療者向けに専門用語を適切に用い、簡潔かつ明確に"
        }
        let purpose: String = options.kind == .short ? "重要ポイントのみの箇条書きサマリー" : "症状の評価と助言"
        var head = "あなたは親切な日本語のヘルスアシスタントです。以下の症状メモ一覧を読み、\(purpose)を出力してください。表現は\(style)。\n\n"
        if options.kind == .short {
            let n = options.bullets ?? 5
            head += "・最大\(n)個の箇条書き。各行は1文で60字以内。不要な前置きは省く。\n\n"
        } else {
            head += "重要ポイントと行動可能なアドバイスを含めてください。診断は行わず、緊急時は受診を促してください。\n\n"
        }
        var list = ""
        for e in entries.sorted(by: { $0.date < $1.date }) {
            var line = "- \(df.string(from: e.date)) [重症度: \(e.severity)/10]"
            if e.isImportant { line += " [重要]" }
            if !e.medication.isEmpty { line += " 薬: \(e.medication)" }
            if !e.text.isEmpty { line += "\n  \(e.text)" }
            list += line + "\n"
        }
        return head + list
    }

    struct Options {
        var tone: Tone = .polite
        var bullets: Int? = nil // number of bullet points for short
        var kind: Kind = .full
        enum Tone: String { case polite, concise, clinician }
        enum Kind { case full, short }
    }

    static func buildPrompt(from entry: SymptomEntry, options: Options) -> String {
        var lines: [String] = []
        let style: String
        switch options.tone {
        case .polite: style = "丁寧な敬体（です・ます調）で、一般の方向けにわかりやすく"
        case .concise: style = "簡潔に、短文中心で分かりやすく"
        case .clinician: style = "医療者向けに専門用語を適切に用い、簡潔かつ明確に"
        }
        let purpose: String = options.kind == .short ? "重要ポイントのみの箇条書きサマリー" : "症状の評価と助言"
        lines.append("以下は患者の日誌です。\(purpose)を日本語で提供してください。表現は\(style)。")
        lines.append("日付: \(formatDate(entry.date))")
        lines.append("重症度: \(entry.severity)/10")
        if !entry.medication.isEmpty { lines.append("服用: \(entry.medication)") }
        if !entry.text.isEmpty { lines.append("本文: \(entry.text)") }
        if options.kind == .short {
            let n = options.bullets ?? 5
            lines.append("・最大\(n)個の箇条書き。各行は1文で60字以内を目安に。不要な前置きは省く。")
        } else {
            lines.append("重要ポイントと行動可能なアドバイスを含めてください。")
        }
        return lines.joined(separator: "\n")
    }

    private static func formatDate(_ date: Date) -> String {
        let df = DateFormatter(); df.locale = .current; df.dateStyle = .medium
        return df.string(from: date)
    }

    static func getAdvice(
        for entries: [SymptomEntry],
        options: Options = .init(),
        settings: AppSettings? = nil,
        modelOverride: String? = nil,
        systemOverride: String? = nil
    ) async throws -> String {
        guard let apiKey = AIKeyStore.getAPIKey() else { throw AIServiceError.noAPIKey }
        let prompt = buildPrompt(from: entries, options: options)

    let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

    let modelName = sanitizeModel(modelOverride ?? settings?.aiModel ?? defaultModel)
        var messages: [AIAdviceRequest.Message] = []
    if let sys = systemOverride ?? settings?.aiSystemPrompt, !sys.isEmpty {
            messages.append(.init(role: "system", content: sys))
        } else {
            messages.append(.init(role: "system", content: "あなたは有能な日本語の医療アシスタントです。一般的な情報とセルフケアの助言を提供し、診断は行わず、緊急時は受診を促します。"))
        }
        messages.append(.init(role: "user", content: prompt))
        let body = AIAdviceRequest(
            model: modelName,
            messages: messages,
            temperature: 0.2
        )
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { throw AIServiceError.invalidResponse }
        let decoded = try JSONDecoder().decode(AIAdviceResponse.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }

    static func getShortAdvice(for entries: [SymptomEntry], bullets: Int = 5, tone: Options.Tone = .polite, settings: AppSettings? = nil) async throws -> String {
        var opt = Options()
        opt.kind = .short
        opt.bullets = bullets
        opt.tone = tone
        return try await getAdvice(for: entries, options: opt, settings: settings)
    }
}

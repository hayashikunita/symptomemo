import SwiftUI
import SwiftData
import PDFKit

struct ShareAndPDFView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \\SymptomEntry.date) private var allEntries: [SymptomEntry]

    enum Preset: String, CaseIterable, Identifiable { case last7 = "直近7日", last14 = "直近14日", last30 = "直近30日", thisMonth = "今月", custom = "カスタム"; var id: String { rawValue } }
    @State private var preset: Preset = .last7
    @State private var from: Date = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    @State private var to: Date = Date()
    @State private var showShare = false
    @State private var shareItems: [Any] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("期間") {
                    Picker("プリセット", selection: $preset) {
                        ForEach(Preset.allCases) { p in Text(p.rawValue).tag(p) }
                    }
                    .onChange(of: preset) { applyPreset() }

                    DatePicker("開始", selection: $from, displayedComponents: .date)
                        .disabled(preset != .custom)
                    DatePicker("終了", selection: $to, displayedComponents: .date)
                        .disabled(preset != .custom)
                }

                Section("プレビュー") {
                    Text(sampleSummaryText())
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(8)
                }

                Section {
                    Button("テキストを共有") { shareText() }
                    Button("PDFを書き出して共有") { sharePDF() }
                }
            }
            .navigationTitle("共有 / PDF")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(activityItems: shareItems)
        }
        .onAppear { applyPreset() }
    }

    private func entriesInRange() -> [SymptomEntry] {
        let cal = Calendar.current
        let fromDay = cal.startOfDay(for: from)
        let toDayEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: to) ?? to
        return allEntries.filter { $0.date >= fromDay && $0.date <= toDayEnd }.sorted { $0.date < $1.date }
    }

    private func summaryText(from: Date, to: Date, entries: [SymptomEntry]) -> String {
        var lines: [String] = []
        let df = DateFormatter(); df.locale = .current; df.dateStyle = .medium
        lines.append("【症状経過まとめ】")
        lines.append("期間: \(df.string(from: from)) 〜 \(df.string(from: to))")
        lines.append("")
        for e in entries {
            let d = df.string(from: e.date)
            var row = "- \(d) [\(e.severity)/10]"
            if e.isImportant { row += " [重要]" }
            if !e.medication.isEmpty { row += " 薬: \(e.medication)" }
            lines.append(row)
            if !e.text.isEmpty { lines.append("  \(e.text)") }
        }
        if lines.count <= 3 { lines.append("（記録がありません）") }
        return lines.joined(separator: "\n")
    }

    private func sampleSummaryText() -> String {
        summaryText(from: from, to: to, entries: entriesInRange())
    }

    private func applyPreset() {
        let cal = Calendar.current
        switch preset {
        case .last7:
            from = cal.date(byAdding: .day, value: -6, to: Date()) ?? Date()
            to = Date()
        case .last14:
            from = cal.date(byAdding: .day, value: -13, to: Date()) ?? Date()
            to = Date()
        case .last30:
            from = cal.date(byAdding: .day, value: -29, to: Date()) ?? Date()
            to = Date()
        case .thisMonth:
            let comps = cal.dateComponents([.year, .month], from: Date())
            from = cal.date(from: comps) ?? Date()
            to = Date()
        case .custom:
            break
        }
    }

    private func shareText() {
        let text = summaryText(from: from, to: to, entries: entriesInRange())
        shareItems = [text]
        showShare = true
    }

    private func sharePDF() {
        let pdf = PDFBuilder.makePDF(from: from, to: to, entries: entriesInRange())
        shareItems = [pdf]
        showShare = true
    }
}

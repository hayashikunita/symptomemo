import Foundation

enum ReportBuilder {
    static func makeSummary(from: Date, to: Date, entries: [SymptomEntry]) -> String {
        var lines: [String] = []
        let df = DateFormatter(); df.locale = .current; df.dateStyle = .medium
        lines.append("【症状経過まとめ】")
        lines.append("期間: \(df.string(from: from)) 〜 \(df.string(from: to))")
        lines.append("")
        let sorted = entries.sorted(by: { $0.date < $1.date })
        for e in sorted {
            let d = df.string(from: e.date)
            var row = "- \(d) [重症度: \(e.severity)/10]"
            if e.isImportant { row += " [重要]" }
            if !e.medication.isEmpty { row += " 薬: \(e.medication)" }
            lines.append(row)
            if !e.text.isEmpty { lines.append("  \(e.text)") }
        }
        if lines.count <= 3 { lines.append("（記録がありません）") }
        return lines.joined(separator: "\n")
    }
}

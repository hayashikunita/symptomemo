import SwiftUI
import SwiftData

struct DoctorModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SymptomEntry.date) private var allEntries: [SymptomEntry]

    @State private var currentDate: Date
    enum Mode: String, CaseIterable, Identifiable { case daily = "日ごと", list = "一覧"; var id: String { rawValue } }
    @State private var mode: Mode = .daily

    init(initialDate: Date = Date()) {
        _currentDate = State(initialValue: Calendar.current.startOfDay(for: initialDate))
    }

    var body: some View {
        VStack(spacing: 20) {
            // モード切替
            Picker("表示", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            if mode == .daily {
                // 日付切替
                HStack {
                    Button { currentDate = dayByAdding(-1, to: currentDate) } label: {
                        Label("前日", systemImage: "chevron.left")
                            .font(.title3).bold()
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Text(dateString(currentDate))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .minimumScaleFactor(0.8)

                    Spacer()

                    Button { currentDate = dayByAdding(1, to: currentDate) } label: {
                        Label("翌日", systemImage: "chevron.right")
                            .font(.title3).bold()
                    }
                    .buttonStyle(.borderedProminent)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let entry = entryFor(currentDate) {
                            // 重要バナー
                            if entry.isImportant {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.white)
                                    Text("重要な出来事").font(.title2).bold()
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }

                            // 重症度
                            severityPill(entry.severity)

                            // 服用メモ
                            if !entry.medication.isEmpty {
                                sectionCard(title: "服用", systemImage: "pills.fill", content: entry.medication)
                            }

                            // 本文
                            sectionTextBlock(title: "症状メモ", text: entry.text.isEmpty ? "（記載なし）" : entry.text)
                                .textSelection(.enabled)
                        } else {
                            ContentUnavailableView(
                                "記録がありません",
                                systemImage: "calendar.badge.exclamationmark",
                                description: Text("この日に登録されたメモはありません")
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                // 一覧表示
                if allEntries.isEmpty {
                    ContentUnavailableView(
                        "記録がありません",
                        systemImage: "text.magnifyingglass",
                        description: Text("まだメモがありません")
                    )
                } else {
                    List {
                        ForEach(allEntries) { e in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    Text(shortDate(e.date)).font(.title3).bold()
                                    if e.isImportant { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                                    if e.severity > 0 { smallSeverityPill(e.severity) }
                                    Spacer()
                                }
                                if !e.medication.isEmpty {
                                    Text("服用: \(e.medication)").font(.callout).foregroundStyle(.primary)
                                }
                                if !e.text.isEmpty {
                                    Text(e.text).font(.body).foregroundStyle(.primary).lineLimit(4).lineSpacing(4)
                                }
                            }
                                .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation { currentDate = Calendar.current.startOfDay(for: e.date); mode = .daily }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .environment(\.colorScheme, .light) // 高コントラストを狙った明色
    .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
            }
        }
    .navigationTitle("診察モード")
    .navigationBarTitleDisplayMode(.large)
    }

    private func entryFor(_ day: Date) -> SymptomEntry? {
        let cal = Calendar.current
        return allEntries.first { cal.isDate($0.date, inSameDayAs: day) }
    }

    private func dayByAdding(_ days: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date).map { Calendar.current.startOfDay(for: $0) } ?? date
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .full
        return f.string(from: date)
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .medium
        return f.string(from: date)
    }

    // MARK: - UI Helpers
    private func severityColor(_ sev: Int) -> Color {
        switch sev {
        case 7...10: return .red
        case 4...6: return .orange
        case 1...3: return .green
        default: return .gray
        }
    }

    @ViewBuilder
    private func severityPill(_ sev: Int) -> some View {
        let color = severityColor(sev)
        HStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg")
                .font(.title)
                .foregroundStyle(color)
            Text("重症度: \(sev)/10")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func smallSeverityPill(_ sev: Int) -> some View {
        let color = severityColor(sev)
        HStack(spacing: 6) {
            Image(systemName: "waveform.path.ecg").font(.subheadline)
            Text("\(sev)").font(.subheadline).monospacedDigit()
        }
        .padding(.vertical, 4).padding(.horizontal, 8)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func sectionCard(title: String, systemImage: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.title3).bold()
            Text(content).font(.title3)
        }
        .cardPadded()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func sectionTextBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3).bold()
            Text(text)
                .font(.title2)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardPadded()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

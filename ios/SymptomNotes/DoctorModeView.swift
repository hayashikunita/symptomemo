import SwiftUI
import SwiftData

struct DoctorModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \\SymptomEntry.date) private var allEntries: [SymptomEntry]

    @State private var currentDate: Date

    init(initialDate: Date = Date()) {
        _currentDate = State(initialValue: Calendar.current.startOfDay(for: initialDate))
    }

    var body: some View {
        VStack(spacing: 16) {
            // 日付切替
            HStack {
                Button {
                    currentDate = dayByAdding(-1, to: currentDate)
                } label: {
                    Label("前日", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Text(dateString(currentDate))
                    .font(.largeTitle).bold()

                Spacer()

                Button {
                    currentDate = dayByAdding(1, to: currentDate)
                } label: {
                    Label("翌日", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                        .flipsForRightToLeftLayoutDirection(true)
                }
                .buttonStyle(.borderedProminent)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let entry = entryFor(currentDate) {
                        if entry.isImportant {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("重要な出来事")
                                    .font(.title3).bold()
                            }
                        }

                        // 重症度
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: "waveform.path.ecg")
                                .foregroundStyle(.red)
                                .font(.title2)
                            Text("重症度: \(entry.severity)/10")
                                .font(.title2).bold()
                        }

                        // 服用メモ
                        if !entry.medication.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("服用メモ")
                                    .font(.title3).bold()
                                Text(entry.medication)
                                    .font(.title3)
                            }
                        }

                        // 本文
                        VStack(alignment: .leading, spacing: 8) {
                            Text("症状メモ")
                                .font(.title3).bold()
                            Text(entry.text.isEmpty ? "（記載なし）" : entry.text)
                                .font(.title2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
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
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .environment(\.colorScheme, .light) // 高コントラストを狙った明色
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("閉じる") { dismiss() }
            }
        }
        .navigationTitle("診察モード")
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
}

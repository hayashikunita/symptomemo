import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SymptomEntry.date, order: .reverse) private var entries: [SymptomEntry]
    @Query private var settings: [AppSettings]

    @State private var showEditor = false
    @State private var showSettings = false
    @State private var editingEntry: SymptomEntry?
    @State private var showShare = false
    @State private var shareText: String = ""
    @State private var showDoctorMode = false
    @State private var showSharePDF = false
    @State private var showOnboarding = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // 固定ヘッダーのクイックアクション
        Button(action: { newOrEditToday() }) {
                    HStack(spacing: 16) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.primary)
                        VStack(alignment: .leading, spacing: 4) {
                Text(primaryQuickTitle)
                                .font(.headline)
                Text(secondaryQuickTitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
            .padding(16 * quickScale)
                    .glassCard()
                }
                .accessibilityLabel("今日のメモ")

                // 一覧（簡易モード時は重要/今日のみを優先表示に縮約も可。ここでは全件表示を維持）
                List {

                ForEach(entries) { entry in
                    NavigationLink(value: entry) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(formattedDate(entry.date))
                                .font(.headline)
                                .overlay(alignment: .trailing) {
                                    HStack(spacing: 8) {
                                        if entry.isImportant {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundStyle(.orange)
                                        }
                                        if entry.severity > 0 {
                                            Label("\(entry.severity)", systemImage: "waveform.path.ecg")
                                                .labelStyle(.iconOnly)
                                                .foregroundStyle(.red)
                                        }
                                    }
                                }
                            Text(entry.text)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(12)
                        .glassCard()
                    }
                    .listRowBackground(Color.clear)
                }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("症状メモ")
            .navigationDestination(for: SymptomEntry.self) { entry in
                EditorView(entry: entry)
                .buttonStyle(PressableButtonStyle())
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }.pressable()
                    .accessibilityLabel("設定")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { newOrEditToday() } label: {
                        Image(systemName: "plus")
                    }.pressable()
                    .accessibilityLabel("今日のメモ")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { prepareShare() } label: {
                        Image(systemName: "square.and.arrow.up")
                    }.pressable()
                    .accessibilityLabel("診察用テキスト共有")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSharePDF = true } label: {
                        Image(systemName: "list.bullet.rectangle.portrait")
                    }.pressable()
                    .accessibilityLabel("期間選択とPDF共有")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showDoctorMode = true } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }.pressable()
                    .accessibilityLabel("診察モード")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .presentationCornerRadius(24)
            .sheet(item: $editingEntry) { entry in
                NavigationStack {
                    EditorView(entry: entry)
                }
            }
            .sheet(isPresented: $showShare) {
                ShareSheet(activityItems: [shareText])
            }
            .presentationCornerRadius(24)
            .sheet(isPresented: $showDoctorMode) {
                NavigationStack { DoctorModeView() }
            }
            .presentationCornerRadius(24)
            .sheet(isPresented: $showSharePDF) {
                ShareAndPDFView()
            }
            .presentationCornerRadius(24)
            .sheet(isPresented: $showOnboarding) {
                OnboardingView()
                    .presentationDetents([.medium])
            }
            .task { maybeShowOnboarding() }
        }
    .appGradientBackground()
    .tint(accentColor)
    .environment(\.sizeCategory, sizeCategory)
    }

    private var accentColor: Color {
        if let s = settings.first { return Color.fromHex(s.accentHex) }
        return .accentColor
    }

    private var quickScale: CGFloat { CGFloat(settings.first?.quickActionScale ?? 1.0).clamped(to: 0.8...1.4) }
    private var sizeCategory: ContentSizeCategory {
        switch settings.first?.textScale ?? 0 {
        case 1: return .accessibilityLarge
        case 2: return .accessibilityExtraExtraExtraLarge
        default: return .large
        }
    }
    private var primaryQuickTitle: String {
        if let t = settings.first?.quickActionTitle, !t.isEmpty { return t }
        return todaysEntry == nil ? "今日のメモを書く" : "今日のメモを開く"
    }
    private var secondaryQuickTitle: String {
        if let t = settings.first?.quickActionSubtitle, !t.isEmpty { return t }
        return "タップしてすぐ書けます"
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .long
        return f.string(from: date)
    }

    private func newOrEditToday() {
        let cal = Calendar.current
    if let existing = entries.first(where: { cal.isDate($0.date, inSameDayAs: Date()) }) {
            Feedback.haptic(.light)
            if (settings.first?.enableSound ?? true) { Feedback.clickSound() }
            editingEntry = existing
            return
        }
        let e = SymptomEntry(date: Date(), text: "")
        context.insert(e)
        do { try context.save() } catch { print("save error: \(error)") }
        Feedback.haptic(.success)
        if (settings.first?.enableSound ?? true) { Feedback.clickSound() }
        editingEntry = e
    }

    private var todaysEntry: SymptomEntry? {
        let cal = Calendar.current
        return entries.first { cal.isDate($0.date, inSameDayAs: Date()) }
    }

    // 診察向け 期間まとめの共有テキストを作成
    private func prepareShare() {
        let cal = Calendar.current
        // 直近7日を例示（後で期間選択UIに拡張可）
        guard let from = cal.date(byAdding: .day, value: -6, to: Date()) else { return }
        let rangeEntries = entries.filter { $0.date >= cal.startOfDay(for: from) }
    shareText = ReportBuilder.makeSummary(from: from, to: Date(), entries: rangeEntries)
        showShare = true
    }

    private func maybeShowOnboarding() {
        // AppSettings がなければ作成
        let s: AppSettings
        if let existing = settings.first { s = existing }
        else {
            let created = AppSettings()
            context.insert(created)
            s = created
        }
        if !s.hasSeenOnboarding { showOnboarding = true }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .modelContainer(for: [SymptomEntry.self, AppSettings.self], inMemory: true)
    }
}

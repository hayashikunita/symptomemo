import SwiftUI
import SwiftData
import StoreKit

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
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
    @State private var showDateCreator = false
    @State private var dateForCreation: Date = Date()
    @State private var showAIAdvice = false
    @State private var pulse = false
    @State private var navPath = NavigationPath()

    var body: some View {
    NavigationStack(path: $navPath) {
            VStack(spacing: 12) {
                // 一覧（簡易モード時は重要/今日のみを優先表示に縮約も可。ここでは全件表示を維持）
                List {

                ForEach(entries) { entry in
                    NavigationLink(value: entry) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(formattedDate(entry.date))
                                    .font(.headline)
                                Spacer(minLength: 8)
                                HStack(spacing: listIconSpacing) {
                                    if entry.isImportant {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: listIconSize, weight: .semibold))
                                            .foregroundStyle(.orange)
                                            .accessibilityLabel("重要")
                                    }
                                    if entry.severity > 0 {
                                        Image(systemName: "waveform.path.ecg")
                                            .font(.system(size: listIconSize, weight: .semibold))
                                            .foregroundStyle(entry.severity >= 7 ? .red : (entry.severity >= 4 ? .orange : .green))
                                            .accessibilityLabel("重症度 \(entry.severity)")
                                    }
                                }
                            }
                            Text(entry.text)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .cardPadded()
                        .glassCard()
                    }
                    .listRowBackground(Color.clear)
                }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("症状メモ")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: SymptomEntry.self) { entry in
                EditorView(entry: entry)
                .buttonStyle(PressableButtonStyle())
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 22, weight: .semibold))
                    }.pressable()
                    .accessibilityLabel("設定")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { newOrEditToday() } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                    }.pressable()
                    .accessibilityLabel("今日のメモ")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showDateCreator = true } label: {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 22, weight: .semibold))
                    }.pressable()
                    .accessibilityLabel("別の日のメモを作成")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { prepareShare() } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 22, weight: .semibold))
                    }.pressable()
                    .accessibilityLabel("診察用テキスト共有")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSharePDF = true } label: {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .font(.system(size: 22, weight: .semibold))
                    }.pressable()
                    .accessibilityLabel("期間選択とPDF共有")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showDoctorMode = true } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 22, weight: .semibold))
                    }.pressable()
                    .accessibilityLabel("診察モード")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAIAdvice = true } label: {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 22, weight: .semibold))
                    }.pressable()
                    .accessibilityLabel("AIアドバイス")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .presentationCornerRadius(24)
            .sheet(item: $editingEntry) { entry in
                NavigationStack {
                    EditorView(entry: entry, isModal: true)
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
            .sheet(isPresented: $showDateCreator) {
                NavigationStack {
                    Form {
                        Section("日付を選択") {
                            DatePicker("日付", selection: $dateForCreation, displayedComponents: .date)
                        }
                        Section {
                            Button("作成 / 開く") {
                                newOrEdit(on: dateForCreation)
                                showDateCreator = false
                            }
                            Button("キャンセル", role: .cancel) { showDateCreator = false }
                        }
                    }
                    .navigationTitle("別の日のメモ")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { showDateCreator = false } } }
                }
            }
            .sheet(isPresented: $showAIAdvice) {
                AIAdviceView()
                    .environment(\.isPremiumOverride, DeveloperOverrides.forcePremium)
            }
            .task { maybeShowOnboarding() }
        }
    .appGradientBackground()
    .tint(accentColor)
    .environment(\.sizeCategory, sizeCategory)
    .onChange(of: scenePhase) { _, phase in
        if phase == .inactive || phase == .background {
            do { try context.save() } catch { print("scene save error: \(error)") }
        }
    }
    // 設定から「チュートリアルをもう一度見る」を押した際に、戻ったら自動表示
    .onChange(of: settings.first?.hasSeenOnboarding ?? true) { _, newValue in
        if newValue == false { showOnboarding = true }
    }
    // 画面下部に常時CTA
    .safeAreaInset(edge: .bottom) {
        if navPath.isEmpty && !showSettings && !showShare && !showDoctorMode && !showSharePDF && !showOnboarding && !showDateCreator && !showAIAdvice {
        Button(action: { newOrEditToday() }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 36, height: 36)
                    Image(systemName: todaysEntry == nil ? "plus.circle.fill" : "doc.text.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                        .scaleEffect((todaysEntry == nil) ? (pulse ? 1.25 : 0.95) : 1.0)
                        .opacity((todaysEntry == nil) ? (pulse ? 0.25 : 0.05) : 0)
                )
                Text(todaysEntry == nil ? "今日のメモを書く" : "今日のメモを開く")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .ctaButtonBackground(accent: accentColor)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
    }
    }

    private var accentColor: Color {
        if let s = settings.first { return Color.fromHex(s.accentHex) }
        return .accentColor
    }
    private var sizeCategory: ContentSizeCategory {
        switch settings.first?.textScale ?? 0 {
        case 1: return .accessibilityLarge
        case 2: return .accessibilityExtraExtraExtraLarge
        default: return .large
        }
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

    private func newOrEdit(on date: Date) {
        let cal = Calendar.current
        if let existing = entries.first(where: { cal.isDate($0.date, inSameDayAs: date) }) {
            Feedback.haptic(.light)
            if (settings.first?.enableSound ?? true) { Feedback.clickSound() }
            editingEntry = existing
            return
        }
        let e = SymptomEntry(date: date, text: "")
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

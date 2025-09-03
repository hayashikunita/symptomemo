import SwiftUI
import SwiftData

struct EditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]

    @Bindable var entry: SymptomEntry
    var isModal: Bool = false
    @State private var dictation = DictationHelper()
    @State private var showSavedToast = false
    // AI 診断
    @State private var aiLoading = false
    @State private var aiResult: String = ""
    @State private var aiError: String?
    @State private var aiResultShort: String = ""
    @State private var saveAdviceOnGenerate = true
    @State private var aiTone: AIService.Options.Tone = .polite
    // 短い版の点数（UIを削除したため管理しない）
    @State private var showHistory = false
    @State private var autoSaveWork: DispatchWorkItem?

    var body: some View {
    ScrollView {
            VStack(spacing: 16) {
                // 上段: 左に日付、右に重症度+重要マーク（横幅が狭い場合は縦積み）
                ViewThatFits(in: .horizontal) {
                    // 横に並べる（広い画面）
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("日付")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            DatePicker("", selection: $entry.date, displayedComponents: .date)
                                .labelsHidden()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 12) {
                            // 重症度カード
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("重症度")
                                    Spacer()
                                    Text("\(entry.severity)/10")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                                Slider(value: Binding(get: { Double(entry.severity) }, set: { entry.severity = Int($0) }), in: 0...10, step: 1)
                                    .controlSize(.large)
                                    .tint(accentColor)
                                HStack {
                                    Text("0").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("10").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .cardPadded()
                            .glassCard()
                        }
                        .frame(maxWidth: 360)
                    }

                    // 縦に積む（狭い画面）
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("日付")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            DatePicker("", selection: $entry.date, displayedComponents: .date)
                                .labelsHidden()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("重症度")
                                Spacer()
                                Text("\(entry.severity)/10")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                            Slider(value: Binding(get: { Double(entry.severity) }, set: { entry.severity = Int($0) }), in: 0...10, step: 1)
                                .controlSize(.large)
                                .tint(accentColor)
                            HStack {
                                Text("0").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text("10").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .cardPadded()
                        .glassCard()
                    }
                    // ViewThatFits の候補ビュー定義をここで閉じる
                }
                        // 下側に移動: 重要フラグカード
                        HStack(alignment: .center, spacing: 12) {
                            Label("重要な出来事としてマーク", systemImage: entry.isImportant ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                                .font(.body)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Spacer(minLength: 8)
                            Toggle("", isOn: $entry.isImportant)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: accentColor))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { entry.isImportant.toggle() }
                        .cardPadded()
                        .glassCard()

                // 症状本文
                VStack(alignment: .leading, spacing: 8) {
                    Text("症状メモ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack {
                        Spacer()
                        DictationButton(helper: dictation) { text in
                            if !text.isEmpty {
                                if entry.text.isEmpty { entry.text = text }
                                else { entry.text += "\n" + text }
                            }
                        }
                        Spacer()
                    }
                    ZStack(alignment: .topLeading) {
                        if entry.text.isEmpty {
                            Text("例: 朝から頭痛。昼に鎮痛剤を服用、夕方に軽減。メモや気づきを自由に書いてください。")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 22)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $entry.text)
                            .scrollContentBackground(.hidden)
                    }
                        .frame(minHeight: 160)
                        .cardPadded()
                        .glassCard()
                }

                

                // 当日の診断（AI）
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("当日の診断（AI）")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if aiLoading { ProgressView().controlSize(.small) }
                    }
                    Text("現在のメモ内容と重症度、服用情報をもとに一般的なアドバイスを生成します（医療判断は医師へ）。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    HStack {
                        Picker("口調", selection: $aiTone) {
                            Text("丁寧").tag(AIService.Options.Tone.polite)
                            Text("簡潔").tag(AIService.Options.Tone.concise)
                            Text("医療者向け").tag(AIService.Options.Tone.clinician)
                        }.pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    // 短い版の点数 UI は削除
                    if let msg = aiError { Text(msg).foregroundStyle(.red).font(.footnote) }
                    if !aiResult.isEmpty {
                        Text(aiResult)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !aiResultShort.isEmpty {
                        Divider()
                        Text("重要ポイント（短い版）")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(aiResultShort)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Toggle("生成と同時に保存（この日のメモに反映）", isOn: $saveAdviceOnGenerate)
                        .font(.footnote)
                        .tint(.accentColor)
                    HStack(spacing: 12) {
                        Button(action: { generateAIAdvice() }) {
                            Label("生成", systemImage: "wand.and.stars")
                                .font(.headline)
                        }
                        .buttonStyle(.plain)
                        .modernPillPrimary(accent: accentColor)
                        .disabled((AIKeyStore.getAPIKey() ?? "").isEmpty)

                        Button(action: { generateAIAdviceShort() }) {
                            Label("短い版", systemImage: "sparkles")
                                .font(.headline)
                        }
                        .buttonStyle(.plain)
                        .modernPillSecondary(accent: accentColor)
                        .disabled((AIKeyStore.getAPIKey() ?? "").isEmpty)

                        if !aiResultShort.isEmpty || !aiResult.isEmpty {
                            Button(action: { aiResult = ""; aiResultShort = "" }) {
                                Label("クリア", systemImage: "xmark.circle")
                                    .font(.headline)
                            }
                            .buttonStyle(.plain)
                            .modernPillSecondary(accent: accentColor)
                        }

                        Button(action: { showHistory = true }) {
                            Label("履歴", systemImage: "clock.arrow.circlepath")
                                .font(.headline)
                        }
                        .buttonStyle(.plain)
                        .modernPillSecondary(accent: accentColor)
                    }
                }
                .cardPadded()
                .glassCard()
                .sheet(isPresented: $showHistory) {
                    NavigationStack {
                        List {
                            ForEach(entry.aiHistory.sorted(by: { $0.createdAt > $1.createdAt })) { rec in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(rec.kind == "short" ? "短い版" : "フル")
                                            .font(.caption)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Color.gray.opacity(0.1)).clipShape(Capsule())
                                        if let t = rec.tone { Text(t).font(.caption).foregroundStyle(.secondary) }
                                        if let b = rec.bullets { Text("・\(b)").font(.caption).foregroundStyle(.secondary) }
                                        Spacer()
                                        Text(rec.createdAt, style: .date).font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Text(rec.text).font(.body).textSelection(.enabled)
                                }
                            }
                        }.navigationTitle("AI履歴")
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { showHistory = false } } }
                    }
                }

                // 服用メモ
                VStack(alignment: .leading, spacing: 8) {
                    Text("服用メモ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("服用した薬や量など", text: $entry.medication)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                .cardPadded()
                .glassCard()

                
            }
            .padding(16)
        }
    .navigationTitle("メモ編集")
    .navigationBarTitleDisplayMode(.large)
        .toolbar {
            // モーダル表示時は先頭に「閉じる」
            if isModal {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .pressable()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { saveAndClose() }
                    .buttonStyle(.borderedProminent)
                    .pressable()
            }
        }
    .tint(accentColor)
    .saveToast(isPresented: $showSavedToast)
    // 入力中の自動保存（遅延デバウンス）
    .onChange(of: entry.text) { triggerAutoSave() }
    .onChange(of: entry.severity) { triggerAutoSave() }
    .onChange(of: entry.medication) { triggerAutoSave() }
    .onChange(of: entry.isImportant) { triggerAutoSave() }
    .onChange(of: entry.date) { triggerAutoSave() }
    // 画面離脱時にも保存（戻るボタン対策）
    .onDisappear { try? context.save() }
    }

    private var accentColor: Color {
        if let s = settings.first { return Color.fromHex(s.accentHex) }
        return .accentColor
    }

    private func saveAndClose() {
        do {
            try context.save()
            Feedback.haptic(.success)
            if (settings.first?.enableSound ?? true) { Feedback.clickSound() }
            showSavedToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                showSavedToast = false
                dismiss()
            }
        } catch {
            Feedback.haptic(.error)
            print("save error: \(error)")
        }
    }

    private func triggerAutoSave(delay: TimeInterval = 0.8) {
        autoSaveWork?.cancel()
        let work = DispatchWorkItem {
            do { try context.save() } catch { print("autosave error: \(error)") }
        }
        autoSaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    @MainActor
    private func generateAIAdvice() {
        aiError = nil
        aiResult = ""
        aiLoading = true
        Task {
            defer { aiLoading = false }
            do {
                var opt = AIService.Options()
                opt.tone = aiTone
                opt.kind = .full
                let text = try await AIService.getAdvice(for: [entry], options: opt, settings: settings.first)
                aiResult = text
                // 履歴は常に保存
                let rec = AIAdviceRecord(
                    kind: "full",
                    tone: aiTone.rawValue,
                    bullets: nil,
                    model: settings.first?.aiModel ?? "gpt-4o-mini",
                    text: text,
                    entry: entry
                )
                context.insert(rec)
                if saveAdviceOnGenerate { entry.aiAdvice = text }
                try? context.save()
            } catch AIServiceError.noAPIKey {
                aiError = "APIキーを設定してください（右上のワンドから設定できます）。"
            } catch {
                aiError = "生成に失敗しました：\(error.localizedDescription)"
            }
        }
    }

    @MainActor
    private func generateAIAdviceShort() {
        aiError = nil
        aiResultShort = ""
        aiLoading = true
        Task {
            defer { aiLoading = false }
            do {
                let text = try await AIService.getShortAdvice(for: [entry], tone: aiTone, settings: settings.first)
                aiResultShort = text
                // 履歴は常に保存
                let rec = AIAdviceRecord(
                    kind: "short",
                    tone: aiTone.rawValue,
                    bullets: nil,
                    model: settings.first?.aiModel ?? "gpt-4o-mini",
                    text: text,
                    entry: entry
                )
                context.insert(rec)
                if saveAdviceOnGenerate { entry.aiAdviceShort = text }
                try? context.save()
            } catch AIServiceError.noAPIKey {
                aiError = "APIキーを設定してください（右上のワンドから設定できます）。"
            } catch {
                aiError = "生成に失敗しました：\(error.localizedDescription)"
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .long
        return f.string(from: date)
    }
}

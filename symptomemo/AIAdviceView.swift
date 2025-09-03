import SwiftUI
import SwiftData

struct AIAdviceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    // サブスク無効化期間のため未使用
    @Query private var allEntries: [SymptomEntry]
    @Query private var settings: [AppSettings]

    @State private var apiKey: String = AIKeyStore.getAPIKey() ?? ""
    @State private var keySavedToast = false
    @State private var keyDeletedToast = false
    @State private var keyErrorToast: String?
    @State private var showDeleteConfirm = false
    @State private var result: String = ""
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var tone: AIService.Options.Tone = .polite
    @State private var selectedModel: String = "gpt-4o-mini"
    // 点数は廃止

    var body: some View {
        NavigationStack {
            Form {
                let setting = settings.first ?? {
                    let s = AppSettings(); context.insert(s); return s
                }()
                // サブスク表示は一時的に非表示
                Section("APIキー（OpenAI）") {
                    SecureField("sk-...", text: $apiKey)
                    Button("保存") {
                        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            keyErrorToast = "空のキーは保存できません。削除するには『削除』を押してください。"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { keyErrorToast = nil }
                        } else {
                            apiKey = trimmed
                            AIKeyStore.setAPIKey(trimmed)
                keySavedToast = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { keySavedToast = false }
                        }
                    }
                    .buttonStyle(.borderedProminent)
            .controlSize(.large)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if keySavedToast { Text("保存しました").font(.footnote).foregroundStyle(.secondary) }
                    if let em = keyErrorToast { Text(em).font(.footnote).foregroundStyle(.red) }
                }

                Section("APIキーの削除") {
                    Text("OpenAIのAPIキーをデバイスから削除します。元に戻せません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("削除", role: .destructive) { showDeleteConfirm = true }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
                .alert("APIキーを削除しますか？", isPresented: $showDeleteConfirm) {
                    Button("削除", role: .destructive) {
                        AIKeyStore.setAPIKey(nil)
                        apiKey = ""
                        keyDeletedToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { keyDeletedToast = false }
                    }
                    Button("キャンセル", role: .cancel) { }
                } message: {
                    Text("OpenAIのAPIキーをデバイスから削除します。元に戻せません。")
                }
                if keyDeletedToast { Text("削除しました").font(.footnote).foregroundStyle(.secondary) }
                Section("AIアドバイス") {
            // 設定は先頭で作成済み
                    // モデル選択
                    let modelOptions: [(id: String, label: String)] = [
                        ("gpt-4o-mini", "高速・低コスト（gpt-4o-mini）"),
                        ("gpt-4o", "高品質（gpt-4o）"),
                        ("gpt-5", "次世代（gpt-5）")
                    ]
                    Picker("モデル", selection: $selectedModel) {
                        ForEach(modelOptions, id: \.id) { opt in
                            Text(opt.label).tag(opt.id)
                        }
                    }
                    .onChange(of: selectedModel) { newVal in
                        setting.aiModel = newVal
                        try? context.save()
                    }
                    Text("OpenAI Chat Completions対応モデルから選択できます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    // モデル編集UIは現在非表示
                    HStack {
                        Picker("口調", selection: $tone) {
                            Text("丁寧").tag(AIService.Options.Tone.polite)
                            Text("簡潔").tag(AIService.Options.Tone.concise)
                            Text("医療者向け").tag(AIService.Options.Tone.clinician)
                        }.pickerStyle(.segmented)
                    }
                    // 点数UIは削除
                    if loading {
                        ProgressView("分析中...")
                    } else {
                        HStack(spacing: 12) {
                            Button(action: { Task { await run() } }) {
                                Label("生成", systemImage: "wand.and.stars")
                                    .font(.headline)
                            }
                            .buttonStyle(.plain)
                            .modernPillPrimary(accent: accentColor)

                            Button(action: { Task { await runShort() } }) {
                                Label("短い版", systemImage: "sparkles")
                                    .font(.headline)
                            }
                            .buttonStyle(.plain)
                            .modernPillSecondary(accent: accentColor)
                        }
                            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || allEntries.isEmpty)
                        if allEntries.isEmpty {
                            Text("メモが0件のため生成ボタンは無効です。まずメモを1件以上作成してください。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let msg = errorMessage { Text(msg).foregroundStyle(.red) }
                    if !result.isEmpty {
                        Text(result).textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("AIアドバイス")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        if (settings.first?.enableSound ?? true) { Feedback.clickSound() }
                        dismiss()
                    }
                }
            }
            .onAppear {
                apiKey = AIKeyStore.getAPIKey() ?? ""
                // モデル初期値を設定から復元
                let current = settings.first?.aiModel
                selectedModel = (current?.isEmpty == false) ? current! : "gpt-4o-mini"
            }
        }
    .tint(accentColor)
    }

    private var accentColor: Color {
        if let s = settings.first { return Color.fromHex(s.accentHex) }
        return .accentColor
    }

    // サブスク・トライアル関連の補助は一旦無効化

    @MainActor
    private func run() async {
        loading = true; errorMessage = nil; result = ""
        do {
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            AIKeyStore.setAPIKey(trimmed)
            var opt = AIService.Options()
            opt.tone = tone
            opt.kind = .full
            let text = try await AIService.getAdvice(for: allEntries, options: opt, settings: settings.first)
            result = text
            // サブスク無効化期間のためカウント無効
        } catch AIServiceError.noAPIKey {
            errorMessage = "APIキーを設定してください。"
        } catch {
            errorMessage = "通信エラー：\(error.localizedDescription)"
        }
        loading = false
    }

    @MainActor
    private func runShort() async {
        loading = true; errorMessage = nil; result = ""
        do {
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            AIKeyStore.setAPIKey(trimmed)
            let text = try await AIService.getShortAdvice(for: allEntries, tone: tone, settings: settings.first)
            result = text
            // サブスク無効化期間のためカウント無効
        } catch AIServiceError.noAPIKey {
            errorMessage = "APIキーを設定してください。"
        } catch {
            errorMessage = "通信エラー：\(error.localizedDescription)"
        }
        loading = false
    }

    // カウント無効
}
// サブスク拡張は今は未使用

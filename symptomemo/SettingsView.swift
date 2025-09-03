import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]

    private var setting: AppSettings {
        if let s = settings.first { return s }
        let s = AppSettings()
        context.insert(s)
        return s
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("フィードバック")) {
                    Toggle("ハプティクス", isOn: binding(\AppSettings.enableHaptics))
                    Toggle("サウンド", isOn: binding(\AppSettings.enableSound))
                    Button("テスト再生") {
                        if setting.enableHaptics { Feedback.haptic(.light) }
                        if setting.enableSound { Feedback.clickSound() }
                    }.pressable()
                }

                Section(header: Text("テーマ")) {
                    ColorPickerRow(title: "アクセントカラー", hex: binding(\AppSettings.accentHex))
                }

                Section(header: Text("見やすさ")) {
                    Picker("文字サイズ", selection: binding(\AppSettings.textScale)) {
                        Text("標準").tag(0)
                        Text("大").tag(1)
                        Text("特大").tag(2)
                    }
                    Toggle("高コントラスト（読みやすさ重視）", isOn: binding(\AppSettings.highContrast))
                    Toggle("簡易モード（ホームの項目を最小化）", isOn: binding(\AppSettings.simpleMode))
                }

                Section(header: Text("PDF / AI")) {
                    Picker("AIセクション配置", selection: Binding(
                        get: { setting.pdfAIPlacement ?? 1 },
                        set: { setting.pdfAIPlacement = $0; try? context.save() }
                    )) {
                        Text("前付け（先頭にまとめ）").tag(0)
                        Text("後付け（各日後に掲載）").tag(1)
                    }
                }

                Section(header: Text("AI設定"), footer: Text("システムプロンプトは安全で一般的な注意喚起を含めるのがおすすめです。")) {
                    TextField("システムプロンプト（任意）", text: Binding(
                        get: { setting.aiSystemPrompt ?? "" },
                        set: { setting.aiSystemPrompt = $0.isEmpty ? nil : $0; try? context.save() }
                    ), axis: .vertical)
                    .lineLimit(3...8)
                }


                Section(header: Text("ヘルプ")) {
                    Button("チュートリアルをもう一度見る") {
                        setting.hasSeenOnboarding = false
                        try? context.save()
                    }
                }

#if DEBUG
                Section(header: Text("開発用"), footer: Text("このデバイスでのみ有効。リリースビルドでは無効です。")) {
                    Toggle(
                        "プレミアム強制（このデバイスのみ）",
                        isOn: Binding(
                            get: { DeveloperOverrides.forcePremium },
                            set: { DeveloperOverrides.forcePremium = $0 }
                        )
                    )
                }
#endif
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .pressable()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func binding<T>(_ keyPath: ReferenceWritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding<T>(
            get: { setting[keyPath: keyPath] },
            set: { newValue in
                setting[keyPath: keyPath] = newValue
                do { try context.save() } catch { print("save error: \(error)") }
            }
        )
    }
}

private struct ColorPickerRow: View {
    let title: String
    @Binding var hex: String

    init(title: String, hex: Binding<String>) {
        self.title = title
        self._hex = hex
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.fromHex(hex))
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(.white.opacity(0.2)))
            Text(title)
            Spacer()
            Menu("変更") {
                ForEach(palette, id: \.self) { item in
                    Button(action: { hex = item }) {
                        HStack {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(Color.fromHex(item))
                            Text(item)
                        }
                    }
                }
            }
        }
    }

    private var palette: [String] {
        ["#C19A6B", "#EED9C4", "#A67B5B", "#7BC67E", "#F5A524", "#5B8DEF", "#EF4E7B"]
    }
}

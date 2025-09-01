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
                    Toggle("ハプティクス", isOn: binding(\\AppSettings.enableHaptics))
                    Toggle("サウンド", isOn: binding(\\AppSettings.enableSound))
                    Button("テスト再生") {
                        if setting.enableHaptics { Feedback.haptic(.light) }
                        if setting.enableSound { Feedback.clickSound() }
                    }.pressable()
                }

                Section(header: Text("テーマ")) {
                    ColorPickerRow(title: "アクセントカラー", hex: binding(\\AppSettings.accentHex))
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

                Section(header: Text("クイックアクション"), footer: Text("サイズは0.8〜1.4倍。")) {
                    TextField("タイトル（任意）", text: Binding(
                        get: { setting.quickActionTitle ?? "" },
                        set: { setting.quickActionTitle = $0.isEmpty ? nil : $0; try? context.save() }
                    ))
                    TextField("サブタイトル（任意）", text: Binding(
                        get: { setting.quickActionSubtitle ?? "" },
                        set: { setting.quickActionSubtitle = $0.isEmpty ? nil : $0; try? context.save() }
                    ))
                    HStack {
                        Text("サイズ")
                        Slider(value: Binding(
                            get: { setting.quickActionScale },
                            set: { setting.quickActionScale = min(1.4, max(0.8, $0)); try? context.save() }
                        ), in: 0.8...1.4)
                    }
                }

                Section(header: Text("ヘルプ")) {
                    Button("チュートリアルをもう一度見る") {
                        setting.hasSeenOnboarding = false
                        try? context.save()
                    }
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }.pressable()
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
                        Label(item, systemImage: "circle.fill")
                            .foregroundStyle(Color.fromHex(item))
                    }
                }
            }
        }
    }

    private var palette: [String] {
    ["#C19A6B", "#EED9C4", "#A67B5B", "#7BC67E", "#F5A524", "#5B8DEF", "#EF4E7B"]
    }
}

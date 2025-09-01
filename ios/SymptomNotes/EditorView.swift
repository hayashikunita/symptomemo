import SwiftUI
import SwiftData

struct EditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]

    @Bindable var entry: SymptomEntry
    @State private var dictation = DictationHelper()
    @State private var showSavedToast = false

    var body: some View {
    ScrollView {
            VStack(spacing: 16) {
                Text(formattedDate(entry.date))
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 症状本文
                VStack(alignment: .leading, spacing: 8) {
                    Text("症状メモ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack {
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
                        .padding(12)
                        .glassCard()
                }

                // 重症度
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("重症度")
                        Spacer()
                        Text("\(entry.severity)/10")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    Slider(value: Binding(get: { Double(entry.severity) }, set: { entry.severity = Int($0) }), in: 0...10, step: 1)
                        .tint(.orange)
                }
                .padding(12)
                .glassCard()

                // 服用メモ
                VStack(alignment: .leading, spacing: 8) {
                    Text("服用メモ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("服用した薬や量など", text: $entry.medication)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                .padding(12)
                .glassCard()

                // 重要フラグ
                Toggle(isOn: $entry.isImportant) {
                    Label("重要な出来事としてマーク", systemImage: entry.isImportant ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                }
                .padding(12)
                .glassCard()
            }
            .padding(16)
        }
        .navigationTitle("メモ編集")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") { saveAndClose() }.pressable()
            }
        }
    .tint(accentColor)
    .saveToast(isPresented: $showSavedToast)
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

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .long
        return f.string(from: date)
    }
}

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]

    private var setting: AppSettings {
        if let s = settings.first { return s }
        let s = AppSettings()
        context.insert(s)
        return s
    }

    @State private var page = 0

    var body: some View {
        VStack(spacing: 16) {
            TabView(selection: $page) {
                StepView(
                    image: "square.and.pencil",
                    title: "すぐ書ける",
                    text: "上の『今日のメモ』から、ワンタップで編集へ。"
                ).tag(0)
                StepView(
                    image: "waveform.path.ecg",
                    title: "診察に役立つ",
                    text: "重症度・服用・重要マークを一緒に記録。"
                ).tag(1)
                StepView(
                    image: "doc.text.image",
                    title: "共有も簡単",
                    text: "期間まとめをテキスト/PDFで共有できます。"
                ).tag(2)
                StepView(
                    image: "mic.circle",
                    title: "音声入力",
                    text: "編集画面の『音声入力』をタップし、話した内容を自動で文字起こし。停止すると本文に追記されます。初回はマイク/音声認識の許可が必要です。"
                ).tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 220)

            Button(action: page < 3 ? { page += 1 } : done) {
                Text(page < 3 ? "次へ" : "はじめる")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .pressable()
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(20)
    }

    private func done() {
        setting.hasSeenOnboarding = true
        try? context.save()
        dismiss()
    }
}

private struct StepView: View {
    let image: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: image)
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.tint)
            Text(title).font(.title2).bold()
            Text(text)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
        }
    }
}

import SwiftUI
import SwiftData
import UIKit
// Premium override (DEBUG/testing)
private struct PremiumOverrideKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isPremiumOverride: Bool {
        get { self[PremiumOverrideKey.self] }
        set { self[PremiumOverrideKey.self] = newValue }
    }
}

extension Color {
    static func fromHex(_ hex: String) -> Color {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        // サポート: RGB(3桁), RRGGBB(6桁), RRGGBBAA(8桁)
        if clean.count == 3 {
            // 例: F0A -> FF 00 AA に展開
            clean = clean.map { "\($0)\($0)" }.joined()
        }
        if clean.count == 6 {
            clean += "FF" // 不透明
        }
        guard clean.count == 8, let value = UInt64(clean, radix: 16) else {
            return Color.accentColor
        }
        let r = Double((value & 0xFF000000) >> 24) / 255.0
        let g = Double((value & 0x00FF0000) >> 16) / 255.0
        let b = Double((value & 0x0000FF00) >> 8) / 255.0
        let a = Double(value & 0x000000FF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

struct GradientBackground: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Query private var settings: [AppSettings]

    func body(content: Content) -> some View {
        ZStack {
            LinearGradient(colors: bgColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            // さりげない光の当たり方を演出
            RadialGradient(colors: [Color.white.opacity(0.06), .clear], center: .topLeading, startRadius: 0, endRadius: 600)
                .ignoresSafeArea()
            content
        }
        .preferredColorScheme(preferredScheme)
        .environment(\.legibilityWeight, (settings.first?.highContrast ?? false) ? .bold : nil)
    }

    private var bgColors: [Color] {
        if scheme == .dark {
            return [Color(#colorLiteral(red: 0.07, green: 0.09, blue: 0.16, alpha: 1)),
                    Color(#colorLiteral(red: 0.17, green: 0.19, blue: 0.33, alpha: 1))]
        } else {
        // ベージュ系（明るめ→少し濃いめ）
        return [Color(#colorLiteral(red: 0.98, green: 0.96, blue: 0.92, alpha: 1)), // クリーム
            Color(#colorLiteral(red: 0.93, green: 0.88, blue: 0.80, alpha: 1))] // ライトベージュ
        }
    }

    private var preferredScheme: ColorScheme? {
        // 高コントラストON時はライト固定（読みやすさ重視）。必要なら設定で切替可に拡張可能
        (settings.first?.highContrast ?? false) ? .light : nil
    }
}

extension View {
    // Design Tokens
    var cardCornerRadius: CGFloat { 16 }
    var cardPadding: CGFloat { 12 }
    var cardShadowColor: Color { Color.black.opacity(0.10) }
    var cardShadowRadius: CGFloat { 18 }
    var cardShadowY: CGFloat { 10 }
    var listIconSize: CGFloat { 18 }
    var listIconSpacing: CGFloat { 8 }
    // CTA Tokens
    var ctaCornerRadius: CGFloat { 16 }
    var ctaShadowColor: Color { Color.black.opacity(0.20) }
    var ctaShadowRadius: CGFloat { 10 }
    var ctaShadowY: CGFloat { 6 }

    func appGradientBackground() -> some View { self.modifier(GradientBackground()) }

    func glassCard() -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            // エッジに柔らかいハイライト
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.18))
            )
            // 上からの光を強調するグラデーションストローク
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
            )
            .shadow(color: cardShadowColor, radius: cardShadowRadius, x: 0, y: cardShadowY)
    }

    // 統一パディングを付与するヘルパ
    func cardPadded() -> some View { self.padding(cardPadding) }

    // ホーム下部CTAの立体感とグラデーション背景
    func ctaButtonBackground(accent: Color) -> some View {
        self
            .background(
                LinearGradient(
                    colors: [
                        accent.opacity(0.98),
                        accent.opacity(0.88)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: ctaCornerRadius, style: .continuous)
            )
            // 上部ハイライト
            .overlay(
                RoundedRectangle(cornerRadius: ctaCornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
            )
            // エッジの軽い線
            .overlay(
                RoundedRectangle(cornerRadius: ctaCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12))
            )
            .shadow(color: ctaShadowColor, radius: ctaShadowRadius, x: 0, y: ctaShadowY)
    }

    // モダンなピル型ボタン（塗り）
    func modernPillPrimary(accent: Color) -> some View {
        self
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(colors: [accent.opacity(0.98), accent.opacity(0.88)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    // モダンなピル型ボタン（アウトライン）
    func modernPillSecondary(accent: Color) -> some View {
        self
            .foregroundStyle(accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(Color.white.opacity(0.1))
            )
            .overlay(
                Capsule().stroke(accent.opacity(0.35), lineWidth: 1)
            )
    }
}

// 押下時にわずかに縮小・沈み込むボタンスタイル
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let reduced = UIAccessibility.isReduceMotionEnabled
        return configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .offset(y: configuration.isPressed ? 1.0 : 0)
            .animation(reduced ? .default.speed(2) : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    // 任意のボタンに個別で適用したい場合に使用
    func pressable() -> some View { self.buttonStyle(PressableButtonStyle()) }
}

// 保存時の簡易トースト
struct SaveToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                VStack {
                    Text(message)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .shadow(radius: 8)
                    Spacer().frame(height: 8)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: isPresented)
            }
        }
    }
}

extension View {
    func saveToast(isPresented: Binding<Bool>, message: String = "保存しました") -> some View {
        self.modifier(SaveToastModifier(isPresented: isPresented, message: message))
    }
}

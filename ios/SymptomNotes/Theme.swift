import SwiftUI
import SwiftData
import UIKit

extension Color {
    static func fromHex(_ hex: String) -> Color {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if clean.hasPrefix("#") { clean.removeFirst() }
        guard clean.count == 6, let value = UInt64(clean, radix: 16) else {
            return Color.accentColor
        }
        let r = Double((value & 0xFF0000) >> 16) / 255.0
        let g = Double((value & 0x00FF00) >> 8) / 255.0
        let b = Double(value & 0x0000FF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}

struct GradientBackground: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Query private var settings: [AppSettings]

    func body(content: Content) -> some View {
        ZStack {
            LinearGradient(colors: bgColors, startPoint: .topLeading, endPoint: .bottomTrailing)
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
    func appGradientBackground() -> some View { self.modifier(GradientBackground()) }

    func glassCard() -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.15))
            )
            .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
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

import SwiftUI

/// アプリ共通の見た目（やわらかいパステル調）。
enum Theme {

    /// プレイヤーごとの差し色。少しくすませた優しい色にそろえる。
    static let playerColors: [Color] = [
        Color(red: 0.95, green: 0.45, blue: 0.60),  // ピンク
        Color(red: 0.35, green: 0.62, blue: 0.92),  // ブルー
        Color(red: 0.36, green: 0.75, blue: 0.55),  // グリーン
        Color(red: 0.97, green: 0.62, blue: 0.30),  // オレンジ
        Color(red: 0.66, green: 0.50, blue: 0.90),  // パープル
        Color(red: 0.30, green: 0.74, blue: 0.75),  // ティール
    ]

    static func playerColor(_ index: Int) -> Color {
        playerColors[((index % playerColors.count) + playerColors.count) % playerColors.count]
    }

    /// お題（アプリが出した単語）の色。
    static let seedColor = Color(red: 0.55, green: 0.55, blue: 0.62)

    /// 丸ゴシック風の見出しフォント。
    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    static func rounded(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// 画面全体の背景。やわらかい色のにじみを重ねたパステル背景。
/// `opaque` を true にすると下の画面が透けない（スプラッシュ用）。
struct AppBackground: View {
    var opaque: Bool = false

    var body: some View {
        ZStack {
            // 下地。これがあるので背面の画面が透けない。
            Color(.systemBackground)

            // やわらかい色のにじみ。
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    blob(Color(red: 1.0, green: 0.72, blue: 0.80))
                        .frame(width: w * 0.9, height: w * 0.9)
                        .position(x: w * 0.15, y: h * 0.12)
                    blob(Color(red: 0.72, green: 0.85, blue: 1.0))
                        .frame(width: w * 0.95, height: w * 0.95)
                        .position(x: w * 0.9, y: h * 0.3)
                    blob(Color(red: 1.0, green: 0.88, blue: 0.70))
                        .frame(width: w * 0.85, height: w * 0.85)
                        .position(x: w * 0.2, y: h * 0.85)
                    blob(Color(red: 0.80, green: 0.95, blue: 0.85))
                        .frame(width: w * 0.8, height: w * 0.8)
                        .position(x: w * 0.95, y: h * 0.92)
                }
            }
            .opacity(opaque ? 0.9 : 0.55)
            .blur(radius: 40)
        }
        .ignoresSafeArea()
    }

    private func blob(_ color: Color) -> some View {
        Circle().fill(color)
    }
}

/// ふんわりしたカード風の背景。
struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = 18
    var tint: Color = .clear

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = 18, tint: Color = .clear) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius, tint: tint))
    }
}

/// まるっこい主要ボタン。
struct CuteButtonStyle: ButtonStyle {
    var color: Color = .accentColor
    var filled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.rounded(17, weight: .bold))
            .foregroundStyle(filled ? Color.white : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(filled ? color : color.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(filled ? Color.clear : color.opacity(0.35), lineWidth: 1.5)
            )
            .shadow(color: filled ? color.opacity(0.35) : .clear, radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

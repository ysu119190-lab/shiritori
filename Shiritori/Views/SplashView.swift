import SwiftUI

/// アプリ起動時のスプラッシュ。タイトルの各文字が弾んで現れるモーション付き。
struct SplashView: View {
    private let title = Array("しりとり")
    private let colors: [Color] = Theme.playerColors

    @State private var shown = false
    @State private var bounce = false

    var body: some View {
        ZStack {
            // 不透明な背景。下の設定画面が透けないようにする。
            AppBackground(opaque: true)

            VStack(spacing: 18) {
                HStack(spacing: 6) {
                    ForEach(Array(title.enumerated()), id: \.offset) { index, ch in
                        Text(String(ch))
                            .font(Theme.title(56))
                            .foregroundStyle(colors[index % colors.count])
                            .shadow(color: colors[index % colors.count].opacity(0.3), radius: 6, y: 3)
                            .rotationEffect(.degrees(bounce ? 4 : -4))
                            .offset(y: shown ? 0 : -50)
                            .opacity(shown ? 1 : 0)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.5)
                                    .delay(Double(index) * 0.12),
                                value: shown
                            )
                            .animation(
                                .easeInOut(duration: 0.9)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.12),
                                value: bounce
                            )
                    }
                }

                Text("ことばをつなげよう")
                    .font(Theme.rounded(16))
                    .foregroundStyle(.secondary)
                    .opacity(shown ? 1 : 0)
                    .animation(.easeIn(duration: 0.4).delay(0.7), value: shown)
            }
        }
        .onAppear {
            shown = true
            bounce = true
        }
    }
}

#Preview {
    SplashView()
}

import SwiftUI

/// アプリ起動時のスプラッシュ。タイトルの各文字が弾んで現れるモーション付き。
struct SplashView: View {
    private let title = Array("しりとり")
    private let colors: [Color] = [.pink, .blue, .green, .orange]

    @State private var shown = false
    @State private var bounce = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.pink.opacity(0.22),
                    Color.orange.opacity(0.18),
                    Color.blue.opacity(0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack(spacing: 6) {
                    ForEach(Array(title.enumerated()), id: \.offset) { index, ch in
                        Text(String(ch))
                            .font(.system(size: 54, weight: .heavy, design: .rounded))
                            .foregroundStyle(colors[index % colors.count])
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
                    .font(.headline)
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

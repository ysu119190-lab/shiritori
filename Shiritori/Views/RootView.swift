import SwiftUI

/// フェーズに応じて画面を切り替えるルート。
struct RootView: View {
    @EnvironmentObject private var game: ShiritoriGame

    @State private var showSplash = true

    var body: some View {
        ZStack {
            switch game.phase {
            case .setup:
                SetupView()
            case .playing:
                GameView()
            case .finished:
                ResultView()
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: game.phase)
        .task {
            // 広告 SDK の初期化と先読み。
            AdManager.shared.start()

            // 起動モーションを見せてからフェードアウト。
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }

            // 起動時の広告。フェードアウトが終わってから出す。
            try? await Task.sleep(nanoseconds: 600_000_000)
            AdManager.shared.show(.launch)
        }
    }
}

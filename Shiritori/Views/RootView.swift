import SwiftUI

/// フェーズに応じて画面を切り替えるルート。
struct RootView: View {
    @EnvironmentObject private var game: ShiritoriGame

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
        }
        .animation(.easeInOut(duration: 0.25), value: game.phase)
    }
}

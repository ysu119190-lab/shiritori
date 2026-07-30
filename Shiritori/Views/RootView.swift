import SwiftUI

/// フェーズに応じて画面を切り替えるルート。
struct RootView: View {
    @EnvironmentObject private var game: ShiritoriGame
    @ObservedObject private var online = OnlineMatchManager.shared

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
        .sheet(isPresented: $online.isShowingMatchmaker) {
            TurnBasedMatchmakerView(request: online.makeMatchRequest()) { errorMessage in
                online.matchmakerFinished(errorMessage: errorMessage)
            }
        }
        .task {
            // 広告 SDK の初期化と先読み。
            AdManager.shared.start()

            // オンライン対戦の受け口をつないでから Game Center へサインインする。
            connectOnlineMatch()
            OnlineMatchManager.shared.authenticate()

            // 起動モーションを見せてからフェードアウト。
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }

            // 起動時の広告。フェードアウトが終わってから出す。
            try? await Task.sleep(nanoseconds: 600_000_000)
            AdManager.shared.show(.launch)
        }
    }

    /// ゲームと Game Center を双方向につなぐ。
    ///
    /// `game` はアプリの生存期間ずっと使われる1個のオブジェクトなので、
    /// ここでは素直に強参照で captured しておく。
    private func connectOnlineMatch() {
        let manager = OnlineMatchManager.shared
        let currentGame = game

        // 自分が打った手を Game Center へ送る。
        currentGame.onlineTurnSender = { state, isGameOver in
            if isGameOver {
                manager.endMatch(state: state)
            } else {
                manager.sendTurn(state: state)
            }
        }

        // 相手の手や対局の選択が届いたらゲームへ反映する。
        manager.onTurnReceived = { turn in
            if let state = turn.state {
                currentGame.applyOnlineState(
                    state,
                    localSeat: turn.localSeat,
                    playerNames: turn.playerNames,
                    isMatchEnded: turn.isMatchEnded
                )
            } else {
                // matchData が空 ＝ 作られたばかりの対局。こちらがお題を出して始める。
                currentGame.startOnline(localSeat: turn.localSeat, playerNames: turn.playerNames)
            }
        }
    }
}

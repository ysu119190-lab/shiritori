import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(GameKit)
import GameKit
#endif

/// `sheet(item:)` で UIViewController を出すための包み。
struct IdentifiableController: Identifiable {
    let id = UUID()
    let controller: UIViewController
}

/// フェーズに応じて画面を切り替えるルート。
struct RootView: View {
    @EnvironmentObject private var game: ShiritoriGame

    @State private var showSplash = true
    /// Game Center から渡されたサインイン画面。
    @State private var gameCenterAuthController: UIViewController?

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
        #if canImport(GameKit)
        .sheet(item: Binding(
            get: { gameCenterAuthController.map(IdentifiableController.init) },
            set: { if $0 == nil { gameCenterAuthController = nil } }
        )) { wrapper in
            HostedViewController(controller: wrapper.controller)
                .ignoresSafeArea()
        }
        #endif
        .task {
            #if DEBUG
            // ストア用スクリーンショットの撮影中は、スプラッシュ・広告・
            // Game Center のサインインをすべて省いて、目的の画面だけを出す。
            if let scene = ScreenshotMode.scene {
                showSplash = false
                switch scene {
                case .game, .keyboard:
                    game.configureForScreenshot(finished: false)
                case .result:
                    game.configureForScreenshot(finished: true)
                case .setup, .solo, .nearby, .help:
                    game.settings = ScreenshotMode.demoSettings()
                    if scene == .solo { game.settings.isSoloMode = true }
                }
                return
            }
            #endif

            // 広告 SDK の初期化と先読み。
            AdManager.shared.start()

            // Game Center へのサインイン。失敗してもアプリは普通に遊べる
            // （オンライン対戦だけが使えなくなる）。
            #if canImport(GameKit)
            GameCenterManager.shared.authenticate { controller in
                gameCenterAuthController = controller
            }
            #endif

            // 起動モーションを見せてからフェードアウト。
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }

            // 起動時の広告。フェードアウトが終わってから出す。
            try? await Task.sleep(nanoseconds: 600_000_000)
            AdManager.shared.show(.launch)
        }
    }
}

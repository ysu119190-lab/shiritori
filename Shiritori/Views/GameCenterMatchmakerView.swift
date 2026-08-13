import SwiftUI
#if canImport(GameKit)
import GameKit
#endif

#if canImport(GameKit)
/// Game Center の対戦相手さがし画面（GKTurnBasedMatchmakerViewController）を SwiftUI から出す。
///
/// 選ばれた対戦そのものはデリゲートではなく `GKLocalPlayerListener` 経由で届く
/// （iOS 14 以降の作法）。この画面は「閉じられたこと」だけを伝える。
struct GameCenterMatchmakerView: UIViewControllerRepresentable {

    /// 閉じられた（またはエラー）ときに呼ばれる。
    var onCancel: (String?) -> Void

    func makeUIViewController(context: Context) -> GKTurnBasedMatchmakerViewController {
        let request = GKMatchRequest()
        // しりとりは1対1で遊ぶ。
        request.minPlayers = 2
        request.maxPlayers = 2
        request.defaultNumberOfPlayers = 2

        let controller = GKTurnBasedMatchmakerViewController(matchRequest: request)
        controller.turnBasedMatchmakerDelegate = context.coordinator
        controller.showExistingMatches = true
        return controller
    }

    func updateUIViewController(_ controller: GKTurnBasedMatchmakerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCancel: onCancel)
    }

    final class Coordinator: NSObject, GKTurnBasedMatchmakerViewControllerDelegate {
        private let onCancel: (String?) -> Void

        init(onCancel: @escaping (String?) -> Void) {
            self.onCancel = onCancel
        }

        func turnBasedMatchmakerViewControllerWasCancelled(_ viewController: GKTurnBasedMatchmakerViewController) {
            onCancel(nil)
        }

        func turnBasedMatchmakerViewController(_ viewController: GKTurnBasedMatchmakerViewController, didFailWithError error: Error) {
            onCancel(error.localizedDescription)
        }
    }
}

/// GameKit が渡してくる UIViewController（サインイン画面など）を SwiftUI から出す。
struct HostedViewController: UIViewControllerRepresentable {
    let controller: UIViewController

    func makeUIViewController(context: Context) -> UIViewController { controller }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}
#endif

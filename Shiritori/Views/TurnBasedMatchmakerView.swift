import SwiftUI
import GameKit

/// Game Center 標準のマッチメイキング画面。
///
/// この画面ひとつに「友達を招待」「自動マッチング」「進行中の対局一覧」が入っている。
/// 自前で作るより確実なので、UI はまるごと Game Center に任せる。
///
/// 対局が選ばれたときの通知はデリゲートではなく `GKLocalPlayerListener` に来る
/// （選択時のデリゲートは非推奨）。ここではキャンセルとエラーだけ扱う。
struct TurnBasedMatchmakerView: UIViewControllerRepresentable {

    let request: GKMatchRequest
    /// 画面が閉じられたときに呼ばれる。エラーがあればその内容。
    var onFinish: (String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> GKTurnBasedMatchmakerViewController {
        let controller = GKTurnBasedMatchmakerViewController(matchRequest: request)
        controller.turnBasedMatchmakerDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: GKTurnBasedMatchmakerViewController, context: Context) {
        // 表示後に更新するものはない。
    }

    final class Coordinator: NSObject, GKTurnBasedMatchmakerViewControllerDelegate {

        private let onFinish: (String?) -> Void

        init(onFinish: @escaping (String?) -> Void) {
            self.onFinish = onFinish
        }

        func turnBasedMatchmakerViewControllerWasCancelled(
            _ viewController: GKTurnBasedMatchmakerViewController
        ) {
            onFinish(nil)
        }

        func turnBasedMatchmakerViewController(
            _ viewController: GKTurnBasedMatchmakerViewController,
            didFailWithError error: Error
        ) {
            onFinish(error.localizedDescription)
        }
    }
}

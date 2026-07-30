import Foundation
import GameKit
#if canImport(UIKit)
import UIKit
#endif

/// 受け取った1手番ぶんの状況。オンライン対戦をゲームへ反映するのに必要な情報をまとめたもの。
struct OnlineTurn {
    let match: GKTurnBasedMatch
    /// 相手から届いた状態。新規対局（`matchData` が空）のときは nil。
    let state: OnlineMatchState?
    /// この対局での自分の席番号。
    let localSeat: Int
    /// 席順のプレイヤー表示名。
    let playerNames: [String]
    /// いま自分の手番か。
    let isLocalTurn: Bool
    /// 対局が終了しているか。
    let isMatchEnded: Bool
}

/// Game Center を使ったオンライン対戦（2人・ターン制）の管理。
///
/// 方式は `GKTurnBasedMatch`（非同期ターン制）。対局データは Apple のサーバーが
/// 預かるので、こちらでサーバーを持つ必要がない。相手が同時にオンラインでなくても
/// 成立し、手番が回ってくると Game Center が通知を出してくれる。
///
/// `PointsStore` と同様に @MainActor にはせず、コールバックの中で明示的に
/// メインスレッドへ戻す（GameKit の呼び出し元スレッドが保証されないため）。
final class OnlineMatchManager: NSObject, ObservableObject {

    static let shared = OnlineMatchManager()

    /// 1手あたりの制限時間（1週間）。非同期対戦なので長めに取る。
    static let turnTimeout: TimeInterval = 7 * 24 * 60 * 60

    /// Game Center にサインインできているか。
    @Published private(set) var isAuthenticated = false
    /// 自分の表示名。
    @Published private(set) var localDisplayName = ""
    /// 状態の説明（サインイン失敗や送信失敗など）。表示できないときは nil。
    @Published private(set) var statusMessage: String?
    /// マッチメイキング画面（Game Center 標準UI）を出すか。
    @Published var isShowingMatchmaker = false
    /// 送信中か（二重送信を防ぐ）。
    @Published private(set) var isSending = false

    /// 進行中の対局。
    private(set) var currentMatch: GKTurnBasedMatch?

    /// 手番が届いたときに呼ばれる。
    var onTurnReceived: ((OnlineTurn) -> Void)?

    private var isListenerRegistered = false

    private override init() {
        super.init()
    }

    // MARK: - サインイン

    /// Game Center へサインインする。アプリ起動時に一度呼ぶ。
    ///
    /// 未サインインの端末ではサインイン画面が渡されてくるので、最前面に出す。
    /// サインインしない選択もできるため、失敗してもアプリは普通に遊べる状態を保つ。
    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            DispatchQueue.main.async {
                self?.handleAuthentication(viewController: viewController, error: error)
            }
        }
    }

    private func handleAuthentication(viewController: UIViewController?, error: Error?) {
        if let viewController {
            presentOnTop(viewController)
            return
        }

        let local = GKLocalPlayer.local
        isAuthenticated = local.isAuthenticated
        localDisplayName = local.displayName

        if local.isAuthenticated {
            statusMessage = nil
            registerListenerIfNeeded()
        } else if let error {
            statusMessage = "Game Center にサインインできませんでした（\(error.localizedDescription)）"
        } else {
            statusMessage = "Game Center にサインインしていません。設定アプリからサインインするとオンライン対戦が使えます。"
        }
    }

    private func registerListenerIfNeeded() {
        guard isAuthenticated, !isListenerRegistered else { return }
        GKLocalPlayer.local.register(self)
        isListenerRegistered = true
    }

    // MARK: - マッチメイキング

    /// 標準のマッチメイキング画面に渡すリクエスト。
    /// この画面には「友達を招待」と「自動マッチング」の両方が入っている。
    func makeMatchRequest() -> GKMatchRequest {
        let request = GKMatchRequest()
        request.minPlayers = OnlineMatchState.playerCount
        request.maxPlayers = OnlineMatchState.playerCount
        request.defaultNumberOfPlayers = OnlineMatchState.playerCount
        return request
    }

    /// マッチメイキング画面を開く。
    func presentMatchmaker() {
        guard isAuthenticated else {
            statusMessage = "先に Game Center へサインインしてください。"
            return
        }
        isShowingMatchmaker = true
    }

    /// マッチメイキング画面が閉じられた（キャンセル・エラー）。
    func matchmakerFinished(errorMessage: String?) {
        isShowingMatchmaker = false
        if let errorMessage {
            statusMessage = "対局を始められませんでした（\(errorMessage)）"
        }
    }

    // MARK: - 手番の送信

    /// 自分の手を送って相手に手番を渡す。
    func sendTurn(state: OnlineMatchState) {
        guard let match = currentMatch else { return }
        guard let data = encode(state) else { return }

        isSending = true
        match.endTurn(
            withNextParticipants: nextParticipants(for: match, seat: state.currentSeat),
            turnTimeout: Self.turnTimeout,
            matchData: data
        ) { [weak self] error in
            DispatchQueue.main.async {
                self?.isSending = false
                if let error {
                    self?.statusMessage = "手を送れませんでした（\(error.localizedDescription)）"
                }
            }
        }
    }

    /// 決着した状態を送って対局を終了する。
    func endMatch(state: OnlineMatchState) {
        guard let match = currentMatch else { return }
        guard let data = encode(state) else { return }

        // 勝敗を各参加者に記録する。Game Center の対局一覧に結果として残る。
        for (seat, participant) in match.participants.enumerated() {
            if let loser = state.loserSeat {
                participant.matchOutcome = (seat == loser) ? .lost : .won
            } else {
                participant.matchOutcome = .tied
            }
        }

        isSending = true
        match.endMatchInTurn(withMatch: data) { [weak self] error in
            DispatchQueue.main.async {
                self?.isSending = false
                if let error {
                    self?.statusMessage = "対局を終了できませんでした（\(error.localizedDescription)）"
                }
            }
        }
    }

    /// 進行中の対局を手放す（対局そのものは Game Center 側に残る）。
    func clearCurrentMatch() {
        currentMatch = nil
    }

    private func encode(_ state: OnlineMatchState) -> Data? {
        do {
            return try state.encoded()
        } catch {
            statusMessage = "対局データを書き出せませんでした"
            return nil
        }
    }

    // MARK: - 対局情報の取り出し

    /// 自分がこの対局で何席目か。見つからなければ 0。
    private func localSeat(in match: GKTurnBasedMatch) -> Int {
        let myID = GKLocalPlayer.local.gamePlayerID
        return match.participants.firstIndex { $0.player?.gamePlayerID == myID } ?? 0
    }

    /// 席順の表示名。まだ参加していない席は待機中として表示する。
    private func seatNames(for match: GKTurnBasedMatch) -> [String] {
        match.participants.map { $0.player?.displayName ?? "あいてをまってます" }
    }

    /// いま自分の手番か。
    private func isLocalTurn(in match: GKTurnBasedMatch) -> Bool {
        guard let current = match.currentParticipant?.player else { return false }
        return current.gamePlayerID == GKLocalPlayer.local.gamePlayerID
    }

    /// 手番を渡す相手。席番号から決められないときは自分以外の参加者に渡す。
    private func nextParticipants(for match: GKTurnBasedMatch, seat: Int) -> [GKTurnBasedParticipant] {
        if match.participants.indices.contains(seat) {
            return [match.participants[seat]]
        }
        let myID = GKLocalPlayer.local.gamePlayerID
        return match.participants.filter { $0.player?.gamePlayerID != myID }
    }

    /// 届いた対局を取り込んで、ゲームへ反映するための情報を組み立てる。
    private func adopt(match: GKTurnBasedMatch, isMatchEnded: Bool) {
        currentMatch = match
        statusMessage = nil

        let turn = OnlineTurn(
            match: match,
            state: OnlineMatchState.decode(from: match.matchData),
            localSeat: localSeat(in: match),
            playerNames: seatNames(for: match),
            isLocalTurn: isLocalTurn(in: match),
            isMatchEnded: isMatchEnded
        )

        // マッチメイキング画面から対局を選んだ場合はここに来る
        // （選択時に呼ばれるデリゲートは非推奨のため、受け取り口はこの1本）。
        // 閉じる遷移の途中で画面を切り替えると表示が崩れるので、閉じ切ってから反映する。
        guard isShowingMatchmaker else {
            onTurnReceived?(turn)
            return
        }
        isShowingMatchmaker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.onTurnReceived?(turn)
        }
    }
}

// MARK: - Game Center からの通知

extension OnlineMatchManager: GKLocalPlayerListener {

    /// 相手が手を打った / 対局一覧から対局が選ばれた。
    ///
    /// マッチメイキング画面で対局を選んだときもここに来る（`didFind` 系の
    /// デリゲートは非推奨のため、対局の受け取り口はこの1本に集約する）。
    func player(
        _ player: GKPlayer,
        receivedTurnEventFor match: GKTurnBasedMatch,
        didBecomeActive: Bool
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.adopt(match: match, isMatchEnded: false)
        }
    }

    /// 対局が終了した。
    func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
        DispatchQueue.main.async { [weak self] in
            self?.adopt(match: match, isMatchEnded: true)
        }
    }
}

// MARK: - 画面の表示

extension OnlineMatchManager {

    /// 最前面のビューコントローラにモーダルを出す。
    /// （`AdManager` と同じ考え方。遷移中は避ける）
    private func presentOnTop(_ viewController: UIViewController) {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            return
        }

        var top = root
        while let presented = top.presentedViewController {
            if presented.isBeingPresented || presented.isBeingDismissed { return }
            top = presented
        }
        top.present(viewController, animated: true)
    }
}

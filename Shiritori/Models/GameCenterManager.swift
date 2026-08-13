import Foundation
#if canImport(GameKit)
import GameKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Game Center の認証状態。
enum GameCenterAuthState: Equatable {
    case unknown
    case authenticating
    case authenticated(playerName: String)
    case unavailable(String)

    var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }
}

/// Game Center（ターン制対戦）まわりをまとめて扱う。
///
/// ターン制にしているのは、しりとりが「順番に単語を出す」ゲームで、
/// 相手がオフラインでも後から続きを打てるほうが遊びやすいため。
///
/// 対戦データ（`OnlineMatchState`）は手番の端末だけが書き換えて次の人へ渡すので、
/// 同時に書き換わることがない。
final class GameCenterManager: NSObject, ObservableObject {

    static let shared = GameCenterManager()

    @Published private(set) var authState: GameCenterAuthState = .unknown
    /// 進行中の対戦の状態。
    @Published private(set) var matchState: OnlineMatchState?
    /// いま自分の手番か。
    @Published private(set) var isMyTurn = false
    /// 通信まわりの通知（エラーなど）。
    @Published var message: String?

    /// 対戦データが更新されたときに呼ばれる（メインスレッド）。
    /// 新しく作られた対戦では状態がまだ無いので nil が渡る。
    var onMatchUpdated: ((OnlineMatchState?, Bool) -> Void)?
    /// 対戦が終わったときに呼ばれる。
    var onMatchEnded: ((OnlineMatchState) -> Void)?

    #if canImport(GameKit)
    /// 進行中の対戦。
    private(set) var currentMatch: GKTurnBasedMatch?

    /// 自分の Game Center ID。未認証なら nil。
    var localPlayerID: String? {
        GKLocalPlayer.local.isAuthenticated ? GKLocalPlayer.local.gamePlayerID : nil
    }

    var localPlayerName: String {
        GKLocalPlayer.local.isAuthenticated ? GKLocalPlayer.local.displayName : "じぶん"
    }

    private override init() {
        super.init()
    }

    // MARK: - 認証

    /// Game Center にサインインする。認証画面が必要な場合は `presenter` で表示する。
    /// 未サインインでもアプリは普通に遊べるようにし、オンライン対戦だけを無効にする。
    func authenticate(presenter: @escaping (UIViewController) -> Void) {
        guard !GKLocalPlayer.local.isAuthenticated else {
            authState = .authenticated(playerName: GKLocalPlayer.local.displayName)
            registerListener()
            return
        }
        authState = .authenticating
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let viewController {
                    presenter(viewController)
                    return
                }
                if GKLocalPlayer.local.isAuthenticated {
                    self.authState = .authenticated(playerName: GKLocalPlayer.local.displayName)
                    self.registerListener()
                } else {
                    let reason = error?.localizedDescription ?? "Game Center にサインインしていません"
                    self.authState = .unavailable(reason)
                }
            }
        }
    }

    private var didRegisterListener = false

    private func registerListener() {
        guard !didRegisterListener else { return }
        didRegisterListener = true
        GKLocalPlayer.local.register(self)
    }

    // MARK: - 対戦の開始

    /// 進行中の対戦を読み込んで反映する（アプリ起動時や画面表示時）。
    func loadOngoingMatches() {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        GKTurnBasedMatch.loadMatches { [weak self] matches, _ in
            DispatchQueue.main.async {
                guard let self, let match = matches?.first else { return }
                self.adopt(match, alertOnTurn: false)
            }
        }
    }

    /// 対戦を採用して状態を読み込む。
    /// 新規作成された対戦は matchData が空なので、状態は nil のまま呼び出し側へ渡す。
    func adopt(_ match: GKTurnBasedMatch, alertOnTurn: Bool) {
        currentMatch = match
        let state = match.matchData.flatMap(OnlineMatchState.decode)
        matchState = state
        isMyTurn = (match.currentParticipant?.player?.gamePlayerID == localPlayerID)
        onMatchUpdated?(state, alertOnTurn)
        if let state, state.isFinished { onMatchEnded?(state) }
    }

    /// まだ手番を渡さずに、初期状態だけ保存する（対戦を作った直後）。
    func saveInitialState(_ state: OnlineMatchState) {
        guard let match = currentMatch, let data = try? state.encoded() else { return }
        matchState = state
        match.saveCurrentTurn(withMatch: data) { _ in }
    }

    // MARK: - 手番の受け渡し

    /// 手を打ったあと、状態を保存して次の人へ手番を渡す。
    func endTurn(with state: OnlineMatchState) {
        guard let match = currentMatch else { return }
        guard let data = try? state.encoded() else {
            message = "対戦データを保存できませんでした"
            return
        }
        // 次の手番の人＝いまの自分以外。
        let others = match.participants.filter {
            $0.player?.gamePlayerID != localPlayerID
        }
        matchState = state
        isMyTurn = false
        match.endTurn(
            withNextParticipants: others,
            turnTimeout: GKTurnTimeoutDefault,
            match: data
        ) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.message = "手番を渡せませんでした: \(error.localizedDescription)"
                    self?.isMyTurn = true
                }
            }
        }
    }

    /// 決着させて対戦を終える。
    func finishMatch(with state: OnlineMatchState) {
        guard let match = currentMatch else { return }
        guard let data = try? state.encoded() else { return }
        matchState = state
        isMyTurn = false

        // 勝敗を各参加者に設定する。
        for participant in match.participants {
            guard let id = participant.player?.gamePlayerID else { continue }
            participant.matchOutcome = (id == state.loserID) ? .lost : .won
        }
        match.endMatchInTurn(withMatch: data) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.message = "対戦を終了できませんでした: \(error.localizedDescription)"
                }
            }
        }
    }

    /// 自分から降参して対戦を抜ける。
    func resign(state: OnlineMatchState) {
        guard let match = currentMatch else { return }
        var finished = state
        finished.isFinished = true
        finished.loserID = localPlayerID
        let loserName = localPlayerID.flatMap { id in
            state.index(of: id).map { state.playerNames[$0] }
        } ?? "あなた"
        finished.resultMessage = "\(loserName)さんが降参しました"
        finishMatch(with: finished)
    }

    /// 対戦から離れる（状態は残す）。
    func leaveMatch() {
        currentMatch = nil
        matchState = nil
        isMyTurn = false
        message = nil
    }
    #else
    // GameKit が使えない環境では常に利用不可にする。
    var localPlayerID: String? { nil }
    var localPlayerName: String { "じぶん" }
    func loadOngoingMatches() {}
    func endTurn(with state: OnlineMatchState) {}
    func finishMatch(with state: OnlineMatchState) {}
    func resign(state: OnlineMatchState) {}
    func leaveMatch() {}
    #endif
}

#if canImport(GameKit)

// MARK: - 対戦イベントの受け取り

extension GameCenterManager: GKLocalPlayerListener {

    /// 相手が手を打った / 自分の番になった。
    func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.adopt(match, alertOnTurn: true)
        }
    }

    /// 対戦が終了した。
    func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentMatch = match
            if let state = match.matchData.flatMap(OnlineMatchState.decode) {
                self.matchState = state
                self.isMyTurn = false
                self.onMatchEnded?(state)
            }
        }
    }
}

#endif

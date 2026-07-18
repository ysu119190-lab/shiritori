import Foundation
import SwiftUI

/// 1手の記録。
struct Move: Identifiable, Equatable {
    let id = UUID()
    let word: String          // 入力された表示用の語（ひらがな）
    let reading: String       // 判定に使った読み（ひらがな）
    let playerIndex: Int      // 打ったプレイヤー
    let acceptedByChallenge: Bool // 辞書に無いが参加者判断で認めた語か
}

/// 単語提出の判定結果。
enum SubmitResult: Equatable {
    case accepted                    // 受理（次のプレイヤーへ）
    case gameOverByN(loser: Int)     // 「ん」で終わったので負け
    case rejected(reason: String)    // ルール違反。同じプレイヤーが打ち直す。
    case needsExistenceConfirmation(reading: String) // 辞書に無い。参加者の承認待ち。
}

/// ゲーム進行のフェーズ。
enum GamePhase: Equatable {
    case setup     // 設定画面
    case playing   // 対戦中
    case finished  // 決着
}

/// しりとりの進行を管理する中心オブジェクト。
final class ShiritoriGame: ObservableObject {

    @Published var settings: GameSettings
    @Published private(set) var phase: GamePhase = .setup

    @Published private(set) var history: [Move] = []
    @Published private(set) var currentPlayerIndex: Int = 0
    /// 次の単語が始まるべき音。nil のとき（初手）は何から始めてもよい。
    @Published private(set) var requiredStartKana: Character? = nil

    /// 決着時の負けプレイヤー。
    @Published private(set) var loserIndex: Int? = nil
    /// 決着理由の説明。
    @Published private(set) var resultMessage: String = ""

    /// 今回の対戦で最長記録を更新したか。
    @Published private(set) var didSetNewRecord: Bool = false

    /// 残り時間（制限時間ありのとき）。
    @Published var remainingTime: Int = 0

    private var usedReadings: Set<String> = []
    private let validator: WordValidator

    init(settings: GameSettings = .load()) {
        self.settings = settings.sanitized()
        self.validator = WordValidator(useSystemDictionary: settings.useSystemDictionary)
    }

    var bundledWordCount: Int { validator.bundledWordCount }

    var players: [String] { settings.playerNames }

    var currentPlayerName: String {
        guard players.indices.contains(currentPlayerIndex) else { return "" }
        return players[currentPlayerIndex]
    }

    var lastMove: Move? { history.last }

    var isTimed: Bool { settings.turnTimeLimit > 0 }

    // MARK: - 進行制御

    /// 設定を確定してゲームを開始する。
    func start() {
        settings = settings.sanitized()
        settings.save()
        validator.useSystemDictionary = settings.useSystemDictionary

        history.removeAll()
        usedReadings.removeAll()
        currentPlayerIndex = 0
        requiredStartKana = nil
        loserIndex = nil
        resultMessage = ""
        didSetNewRecord = false
        remainingTime = settings.turnTimeLimit
        phase = .playing
    }

    /// 設定画面へ戻る。
    func backToSetup() {
        phase = .setup
    }

    /// もう一度同じ設定で遊ぶ。
    func restart() {
        start()
    }

    // MARK: - 単語の提出

    /// 単語を提出する。`allowChallengeOverride` は辞書に無い語を承認して強制受理する場合に true。
    @discardableResult
    func submit(_ rawInput: String, forceAcceptExistence: Bool = false) -> SubmitResult {
        let reading = KanaUtils.normalize(rawInput)

        // 入力の基本チェック
        if reading.isEmpty {
            return .rejected(reason: "単語を入力してください")
        }
        guard KanaUtils.isAllKana(reading) else {
            return .rejected(reason: "ひらがな（またはカタカナ）で入力してください")
        }

        // 文字数チェック
        let length = reading.count
        if length < settings.minLength {
            return .rejected(reason: "\(settings.minLength)文字以上で入力してください")
        }
        if settings.isMaxLengthEnabled && length > settings.maxLength {
            return .rejected(reason: "\(settings.maxLength)文字以内で入力してください")
        }

        // すでに使われた語か
        if usedReadings.contains(reading) {
            return .rejected(reason: "「\(reading)」はすでに使われています")
        }

        // つながりチェック
        if let required = requiredStartKana {
            guard let start = KanaUtils.startKana(of: reading) else {
                return .rejected(reason: "「\(required)」から始まる単語を入力してください")
            }
            if !KanaUtils.connects(previousEnd: required, nextStart: start, ignoreDakuten: settings.ignoreDakuten) {
                return .rejected(reason: "「\(required)」から始まる単語を入力してください")
            }
        }

        // 実在チェック（承認済みならスキップ）
        if settings.checkExistence && !forceAcceptExistence {
            if !validator.exists(reading) {
                if settings.allowChallengeOverride {
                    return .needsExistenceConfirmation(reading: reading)
                } else {
                    return .rejected(reason: "「\(reading)」は辞書に見つかりませんでした")
                }
            }
        }

        // ここまで通れば受理。まず記録する。
        let move = Move(
            word: reading,
            reading: reading,
            playerIndex: currentPlayerIndex,
            acceptedByChallenge: forceAcceptExistence
        )
        history.append(move)
        usedReadings.insert(reading)

        // 「ん」止まりなら、この語は有効だが打った人の負け。
        if KanaUtils.endsWithN(reading) {
            finish(loser: currentPlayerIndex, message: "「\(reading)」は『ん』で終わりました")
            return .gameOverByN(loser: currentPlayerIndex)
        }

        // 次のプレイヤーへ
        requiredStartKana = KanaUtils.connectingKana(of: reading)
        advanceTurn()
        return .accepted
    }

    /// 手番のプレイヤーが降参する。
    func giveUp() {
        finish(loser: currentPlayerIndex, message: "\(currentPlayerName)さんが降参しました")
    }

    /// 制限時間切れ。手番のプレイヤーの負け。
    func timeExpired() {
        guard phase == .playing else { return }
        finish(loser: currentPlayerIndex, message: "\(currentPlayerName)さんの時間切れです")
    }

    // MARK: - 内部処理

    private func advanceTurn() {
        currentPlayerIndex = (currentPlayerIndex + 1) % players.count
        remainingTime = settings.turnTimeLimit
    }

    private func finish(loser: Int, message: String) {
        loserIndex = loser
        resultMessage = message
        // 続いた単語数（＝最後の「ん」止まりの語も含む）を記録に反映。
        didSetNewRecord = GameRecord.update(chain: history.count)
        phase = .finished
        Haptics.gameOver()
    }

    /// これまでの最長連鎖記録。
    var longestChainRecord: Int { GameRecord.longestChain }

    /// 勝者（負けた人以外）の名前一覧。
    var winnerNames: [String] {
        guard let loser = loserIndex else { return [] }
        return players.enumerated()
            .filter { $0.offset != loser }
            .map { $0.element }
    }

    var loserName: String {
        guard let loser = loserIndex, players.indices.contains(loser) else { return "" }
        return players[loser]
    }
}

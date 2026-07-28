import Foundation
import SwiftUI

/// 1手の記録。
struct Move: Identifiable, Equatable, Codable {
    var id = UUID()
    let word: String          // 入力された表示用の語（ひらがな）
    let reading: String       // 判定に使った読み（ひらがな）
    let playerIndex: Int      // 打ったプレイヤー（お題の語は -1）
    let acceptedByChallenge: Bool // 辞書に無いが参加者判断で認めた語か
    let acceptedByWeb: Bool   // 辞書に無いが Wikipedia で見つかって認めた語か
    var isSeed: Bool = false  // ゲーム開始時にアプリが出した最初の単語か
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

    /// ランダム文字数モードで、この手番に要求される「ちょうどの文字数」。
    /// 通常モードでは nil。
    @Published private(set) var requiredLength: Int? = nil

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
    private let webValidator: WebValidator

    init(settings: GameSettings = .load(), webValidator: WebValidator = WebValidator()) {
        self.settings = settings.sanitized()
        self.validator = WordValidator(useSystemDictionary: settings.useSystemDictionary)
        self.webValidator = webValidator
    }

    /// 実在チェックでウェブ（Wikipedia）判定を使う状態か。
    var isWebSearchEnabled: Bool { settings.checkExistence && settings.useWebSearch }

    /// 読み（ひらがな）が Wikipedia に見つかるかを非同期で判定する。
    func webExists(_ reading: String) async -> Bool {
        await webValidator.exists(reading)
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
        earnedPoints = 0
        hintText = nil
        hintCountThisTurn = 0
        remainingTime = settings.turnTimeLimit
        seedFirstWord()
        rollRequiredLength()
        phase = .playing
        discardSavedGame()
    }

    /// 最初の単語をアプリ側が出題する。以降のプレイヤーはこの語に続けていく。
    private func seedFirstWord() {
        guard let seed = validator.randomStartWord() else { return }
        let move = Move(
            word: seed,
            reading: seed,
            playerIndex: -1,
            acceptedByChallenge: false,
            acceptedByWeb: false,
            isSeed: true
        )
        history.append(move)
        usedReadings.insert(seed)
        requiredStartKana = KanaUtils.connectingKana(of: seed)
    }

    /// ランダム文字数モードのとき、この手番のお題文字数を 1〜9 で決める。
    /// 通常モードでは nil にする。
    private func rollRequiredLength() {
        requiredLength = settings.isRandomLengthMode
            ? Int.random(in: GameSettings.randomLengthRange)
            : nil
    }

    /// 設定画面へ戻る（保存はしない）。
    func backToSetup() {
        phase = .setup
    }

    /// もう一度同じ設定で遊ぶ。
    func restart() {
        start()
    }

    // MARK: - 中断と再開

    /// 中断できる状態か（対戦中で、何か記録がある）。
    var canSuspend: Bool { phase == .playing && !history.isEmpty }

    /// 続きから再開できる保存データがあるか。
    @Published private(set) var hasSavedGame: Bool = SavedGame.exists

    /// 今の対戦を保存して設定画面へ戻る。
    func suspendAndSave() {
        guard phase == .playing else { return }
        SavedGame(
            settings: settings,
            history: history,
            currentPlayerIndex: currentPlayerIndex,
            requiredStartKana: requiredStartKana.map(String.init),
            requiredLength: requiredLength,
            remainingTime: remainingTime,
            savedAt: Date()
        ).save()
        hasSavedGame = true
        phase = .setup
    }

    /// 保存しておいた対戦を復元して再開する。
    func resumeSavedGame() {
        guard let saved = SavedGame.load() else { return }
        settings = saved.settings.sanitized()
        validator.useSystemDictionary = settings.useSystemDictionary
        history = saved.history
        usedReadings = Set(saved.history.map(\.reading))
        currentPlayerIndex = saved.currentPlayerIndex
        requiredStartKana = saved.requiredStartKana?.first
        requiredLength = saved.requiredLength
        remainingTime = saved.remainingTime
        loserIndex = nil
        resultMessage = ""
        didSetNewRecord = false
        phase = .playing
        discardSavedGame()
    }

    /// 保存データを捨てる。
    func discardSavedGame() {
        SavedGame.clear()
        hasSavedGame = false
    }

    /// 保存データの概要（設定画面での表示用）。
    var savedGameSummary: SavedGame? { SavedGame.load() }

    // MARK: - 単語の提出

    /// 単語を提出する。
    /// - `forceAcceptExistence`: 実在チェックを飛ばして受理する（承認またはウェブ判定OKのとき）。
    /// - `acceptedViaWeb`: ウェブ（Wikipedia）判定で受理した場合は true。履歴のバッジ表示に使う。
    @discardableResult
    func submit(_ rawInput: String, forceAcceptExistence: Bool = false, acceptedViaWeb: Bool = false) -> SubmitResult {
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
        if settings.isRandomLengthMode {
            // ランダム文字数モード：ちょうどお題の文字数でなければならない。
            if let required = requiredLength, length != required {
                return .rejected(reason: "ちょうど\(required)文字で入力してください")
            }
        } else {
            if length < settings.minLength {
                return .rejected(reason: "\(settings.minLength)文字以上で入力してください")
            }
            if settings.isMaxLengthEnabled && length > settings.maxLength {
                return .rejected(reason: "\(settings.maxLength)文字以内で入力してください")
            }
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

        // 実在チェック（承認・ウェブ判定OKならスキップ）。
        // ローカル辞書で見つからない場合は .needsExistenceConfirmation を返し、
        // ウェブ判定や参加者承認へ進むかは呼び出し側（View）が決める。
        if settings.checkExistence && !forceAcceptExistence {
            if !validator.exists(reading) {
                return .needsExistenceConfirmation(reading: reading)
            }
        }

        // ここまで通れば受理。まず記録する。
        let move = Move(
            word: reading,
            reading: reading,
            playerIndex: currentPlayerIndex,
            acceptedByChallenge: forceAcceptExistence && !acceptedViaWeb,
            acceptedByWeb: acceptedViaWeb
        )
        history.append(move)
        usedReadings.insert(reading)
        // 単語が1つ通るたびにしりとりポイントを獲得。
        PointsStore.shared.award(PointsStore.pointsPerWord)

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
        rollRequiredLength()
        hintText = nil
        hintCountThisTurn = 0
    }

    private func finish(loser: Int, message: String) {
        loserIndex = loser
        resultMessage = message
        // 続いた単語数（＝最後の「ん」止まりの語も含む）を記録に反映。
        // アプリが出したお題の語は数えない。
        didSetNewRecord = GameRecord.update(chain: chainCount)

        // 対戦をやり切ったボーナス。記録更新ならさらに上乗せ。
        earnedPoints = PointsStore.finishBonus + (didSetNewRecord ? PointsStore.recordBonus : 0)
        PointsStore.shared.award(earnedPoints)

        phase = .finished
        discardSavedGame()
        Haptics.gameOver()
    }

    /// 決着時に獲得したボーナスポイント（結果画面の表示用）。
    @Published private(set) var earnedPoints: Int = 0

    /// プレイヤーが実際につないだ語数（お題の語は含めない）。
    var chainCount: Int { history.filter { !$0.isSeed }.count }

    // MARK: - ヒント

    /// 直近のヒント文。表示中でなければ nil。
    @Published var hintText: String? = nil
    /// この手番でヒントを使った回数。
    @Published private(set) var hintCountThisTurn: Int = 0

    /// ヒントを作る。答えそのものは出さず、「文字数」と「最後の音」だけ教える難しめのヒント。
    func requestHint() {
        guard phase == .playing else { return }
        guard let start = requiredStartKana else {
            hintText = "最初の単語は何でもOK。好きな言葉からどうぞ。"
            return
        }
        let candidate = validator.hintWord(
            startKana: start,
            ignoreDakuten: settings.ignoreDakuten,
            exactLength: requiredLength,
            minLength: settings.isRandomLengthMode ? 1 : settings.minLength,
            maxLength: (!settings.isRandomLengthMode && settings.isMaxLengthEnabled) ? settings.maxLength : nil,
            used: usedReadings
        )
        guard let candidate, let lastKana = candidate.last else {
            hintText = "うーん、辞書の中には見つかりませんでした。自由に考えてみて！"
            return
        }
        hintCountThisTurn += 1
        // 難しめ：答えは伏せて、長さと終わりの音だけ。
        if requiredLength != nil {
            hintText = "終わりの音は「\(lastKana)」"
        } else {
            hintText = "\(candidate.count)文字で、終わりの音は「\(lastKana)」"
        }
    }

    /// ヒント表示を消す。
    func clearHint() {
        hintText = nil
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

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
    case sentToHost                  // 近くの端末対戦：相手（ホスト）へ送った。判定待ち。
}

/// 対戦の形式。
enum PlayMode: Equatable {
    case local        // 同じ端末（パス＆プレイ、または CPU 対戦）
    case nearbyHost   // 近くの端末と対戦：自分がホスト（判定はこちらが行う）
    case nearbyGuest  // 近くの端末と対戦：自分がゲスト（判定はホストに任せる）

    var isNearby: Bool { self != .local }
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

    // MARK: - 1人プレイ（CPU対戦）

    /// 1人プレイ（CPU対戦）モードか。近くの端末と対戦しているときは CPU は使わない。
    var isSoloMode: Bool { settings.isSoloMode && !playMode.isNearby }

    /// ソロモードでのCPUのプレイヤー番号（人間が0、CPUが1）。
    let cpuPlayerIndex = 1

    /// いまCPUの手番か。
    var isCPUTurn: Bool { isSoloMode && currentPlayerIndex == cpuPlayerIndex && phase == .playing }

    /// CPUが「考え中」の表示を出すためのフラグ。
    @Published private(set) var isCPUThinking = false

    /// ソロ対戦の結果（結果画面用）。nil のときはソロ以外か未決着。
    @Published private(set) var soloWon: Bool? = nil
    /// ソロ勝利で獲得した難易度ボーナス。
    @Published private(set) var soloWinBonus: Int = 0
    /// 今回の勝利で最高連勝を更新したか。
    @Published private(set) var didSetBestStreak: Bool = false

    private var cpuTask: Task<Void, Never>? = nil

    var players: [String] {
        if let nearbyPlayerNames { return nearbyPlayerNames }
        if isSoloMode {
            let humanName = settings.playerNames.first ?? "あなた"
            return [humanName, settings.cpuDifficulty.cpuName]
        }
        return settings.playerNames
    }

    var currentPlayerName: String {
        guard players.indices.contains(currentPlayerIndex) else { return "" }
        return players[currentPlayerIndex]
    }

    var lastMove: Move? { history.last }

    var isTimed: Bool { settings.turnTimeLimit > 0 }

    /// つなげてよい開始音の候補。長音「ー」終わりの語は、直前のかなに加えて母音でも受理する。
    private var acceptableStartKanas: [Character] {
        guard let reading = history.last?.reading else {
            return requiredStartKana.map { [$0] } ?? []
        }
        let options = KanaUtils.connectingKanaOptions(of: reading)
        return options.isEmpty ? (requiredStartKana.map { [$0] } ?? []) : options
    }

    /// 「◯から始まる単語を…」の案内文。母音接続も許すときは両方の音を示す。
    private var startHintMessage: String {
        let options = acceptableStartKanas
        if options.count >= 2 {
            let list = options.map(String.init).joined(separator: "」か「")
            return "「\(list)」から始まる単語を入力してください"
        }
        if let required = requiredStartKana {
            return "「\(required)」から始まる単語を入力してください"
        }
        return "単語を入力してください"
    }

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
        soloWon = nil
        soloWinBonus = 0
        didSetBestStreak = false
        cpuTask?.cancel()
        isCPUThinking = false
        remainingTime = settings.turnTimeLimit
        seedFirstWord()
        rollRequiredLength()
        phase = .playing
        discardSavedGame()
        // 近くの端末対戦なら、開始状態を相手にも配る。
        broadcastIfHost()
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

    /// ランダム文字数モードのとき、この手番のお題文字数を設定の幅（randomLengthMin〜Max）で決める。
    /// 通常モードでは nil にする。
    private func rollRequiredLength() {
        guard settings.isRandomLengthMode else {
            requiredLength = nil
            return
        }
        let lo = min(settings.randomLengthMin, settings.randomLengthMax)
        let hi = max(settings.randomLengthMin, settings.randomLengthMax)
        requiredLength = Int.random(in: lo...hi)
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
        soloWon = nil
        soloWinBonus = 0
        didSetBestStreak = false
        phase = .playing
        discardSavedGame()
        // 中断時が CPU の手番だった場合は、再開と同時に打たせる。
        scheduleCPUTurnIfNeeded()
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
    func submit(
        _ rawInput: String,
        forceAcceptExistence: Bool = false,
        acceptedViaWeb: Bool = false,
        byCPU: Bool = false
    ) -> SubmitResult {
        let reading = KanaUtils.normalize(rawInput)

        // 近くの端末対戦のゲストは自分で判定しない。ホストへ送って結果を待つ。
        if playMode == .nearbyGuest {
            guard !reading.isEmpty else {
                return .rejected(reason: "単語を入力してください")
            }
            networkMessage = nil
            nearby?.send(.submit(word: reading))
            return .sentToHost
        }

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

        // つながりチェック（長音「ー」終わりは、直前のかな・その母音のどちらでも許容）。
        if requiredStartKana != nil {
            guard let start = KanaUtils.startKana(of: reading) else {
                return .rejected(reason: startHintMessage)
            }
            let ok = acceptableStartKanas.contains {
                KanaUtils.connects(previousEnd: $0, nextStart: start, ignoreDakuten: settings.ignoreDakuten)
            }
            if !ok {
                return .rejected(reason: startHintMessage)
            }
        }

        // 実在チェック（承認・ウェブ判定OKならスキップ）。
        // ローカル辞書で見つからない場合は .needsExistenceConfirmation を返し、
        // ウェブ判定や参加者承認へ進むかは呼び出し側（View）が決める。
        if settings.checkExistence && !forceAcceptExistence {
            if !validator.exists(reading) {
                // 近くの端末対戦では、待ち時間や食い違いを避けるため
                // 同梱辞書（約46,000語）だけで即断する。
                if playMode.isNearby {
                    return .rejected(reason: "「\(reading)」は辞書に見つかりませんでした")
                }
                return .needsExistenceConfirmation(reading: reading)
            }
        }

        // ここまで通れば受理。まず記録する。
        let move = Move(
            word: reading,
            reading: reading,
            playerIndex: currentPlayerIndex,
            // CPU は辞書から選んでいるので「承認」扱いにはしない。
            acceptedByChallenge: forceAcceptExistence && !acceptedViaWeb && !byCPU,
            acceptedByWeb: acceptedViaWeb
        )
        history.append(move)
        usedReadings.insert(reading)
        // 単語が1つ通るたびにしりとりポイントを獲得。
        PointsStore.shared.award(PointsStore.pointsPerWord)

        // 「ん」止まりなら、この語は有効だが打った人の負け。
        if KanaUtils.endsWithN(reading) {
            let loser = currentPlayerIndex
            finish(loser: loser, message: "「\(reading)」は『ん』で終わりました")
            return .gameOverByN(loser: loser)
        }

        // 次のプレイヤーへ
        requiredStartKana = KanaUtils.connectingKana(of: reading)
        advanceTurn()
        broadcastIfHost()
        return .accepted
    }

    /// 手番のプレイヤーが降参する。
    func giveUp() {
        // ゲストはホストに伝えるだけ。決着はホストが宣言する。
        if playMode == .nearbyGuest {
            nearby?.send(.giveUp)
            return
        }
        finish(loser: currentPlayerIndex, message: "\(currentPlayerName)さんが降参しました")
    }

    /// 制限時間切れ。手番のプレイヤーの負け。
    /// ゲストの時計は表示だけなので、決着を宣言するのはホスト（またはローカル対戦）だけ。
    func timeExpired() {
        guard phase == .playing else { return }
        guard playMode != .nearbyGuest else { return }
        finish(loser: currentPlayerIndex, message: "\(currentPlayerName)さんの時間切れです")
    }

    // MARK: - 内部処理

    private func advanceTurn() {
        currentPlayerIndex = (currentPlayerIndex + 1) % players.count
        remainingTime = settings.turnTimeLimit
        rollRequiredLength()
        hintText = nil
        hintCountThisTurn = 0
        scheduleCPUTurnIfNeeded()
    }

    // MARK: - CPU の手番

    /// CPU の手番なら、少し「考えて」から手を打つ。
    private func scheduleCPUTurnIfNeeded() {
        guard isCPUTurn else { return }
        cpuTask?.cancel()
        isCPUThinking = true
        cpuTask = Task { @MainActor [weak self] in
            // すぐ返すと機械的すぎるので、少し間を置く。
            let delay = Double.random(in: 0.9...1.8)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.playCPUTurn()
        }
    }

    /// CPU が実際に単語を打つ（打てなければ降参）。
    private func playCPUTurn() {
        isCPUThinking = false
        guard isCPUTurn else { return }

        let candidates = validator.candidateWords(
            startKanas: acceptableStartKanas,
            ignoreDakuten: settings.ignoreDakuten,
            exactLength: requiredLength,
            minLength: settings.isRandomLengthMode ? 1 : settings.minLength,
            maxLength: (!settings.isRandomLengthMode && settings.isMaxLengthEnabled) ? settings.maxLength : nil,
            used: usedReadings,
            // よわい CPU は厳選辞書だけ＝身近な語しか使わない。
            includeExtended: settings.cpuDifficulty != .easy
        )

        let opponent = CPUOpponent(
            difficulty: settings.cpuDifficulty,
            followUpCount: { [weak self] kana in
                self?.validator.wordCount(startingWith: kana) ?? 0
            }
        )
        let cpuTurns = history.filter { $0.playerIndex == cpuPlayerIndex }.count

        guard let word = opponent.chooseWord(from: candidates, turnCount: cpuTurns) else {
            // 続けられる語が無い（または諦めた）＝ CPU の負け。
            finish(loser: cpuPlayerIndex, message: "\(players[cpuPlayerIndex])は言葉が見つかりませんでした")
            return
        }
        // CPU の語は辞書から選んでいるので実在チェックは不要。
        submit(word, forceAcceptExistence: true, byCPU: true)
    }

    /// CPU の思考を止める（画面を離れるときなど）。
    func cancelCPUTurn() {
        cpuTask?.cancel()
        isCPUThinking = false
    }

    // MARK: - 近くの端末との対戦

    /// 対戦の形式。
    @Published private(set) var playMode: PlayMode = .local
    /// 近くの端末対戦で使うプレイヤー名（ホスト, ゲスト の順）。
    @Published private(set) var nearbyPlayerNames: [String]? = nil
    /// 自分のプレイヤー番号（ホスト=0 / ゲスト=1）。
    @Published private(set) var myPlayerIndex: Int = 0
    /// 相手から届いた却下理由など、通信まわりの通知。
    @Published var networkMessage: String? = nil
    /// 相手との接続が切れたか。
    @Published private(set) var didLoseConnection = false

    private var nearby: NearbySession?

    /// 自分の手番か（近くの端末対戦のときだけ意味を持つ）。
    var isMyTurn: Bool {
        guard playMode.isNearby else { return true }
        return currentPlayerIndex == myPlayerIndex
    }

    /// 近くの端末との対戦を始める。
    /// - Parameters:
    ///   - session: 接続済みのセッション。
    ///   - asHost: 自分がホストか。ホストが判定と進行を受け持つ。
    ///   - myName: 自分の表示名。
    ///   - opponentName: 相手の表示名。
    func startNearbyGame(session: NearbySession, asHost: Bool, myName: String, opponentName: String) {
        nearby = session
        didLoseConnection = false
        networkMessage = nil
        playMode = asHost ? .nearbyHost : .nearbyGuest
        myPlayerIndex = asHost ? 0 : 1
        // 名前は「ホスト, ゲスト」の順にそろえる。
        nearbyPlayerNames = asHost ? [myName, opponentName] : [opponentName, myName]

        session.onReceive = { [weak self] message in
            self?.handle(message)
        }
        session.onDisconnect = { [weak self] in
            self?.handleDisconnect()
        }

        if asHost {
            // ホストだけがゲームを初期化する（start() の中で状態を配る）。
            start()
        }
    }

    /// 近くの端末との対戦を終える（画面を離れるとき）。
    func endNearbyGame() {
        nearby?.send(.quit)
        nearby?.stop()
        nearby = nil
        playMode = .local
        nearbyPlayerNames = nil
        myPlayerIndex = 0
        networkMessage = nil
    }

    /// 受け取ったメッセージを処理する。
    private func handle(_ message: PeerMessage) {
        switch message {
        case .hello:
            // 参加時の挨拶。名前は接続時にすでに反映済みなので何もしない。
            break

        case .submit(let word):
            // ホストだけが判定する。ゲストの手番でなければ無視。
            guard playMode == .nearbyHost, currentPlayerIndex != myPlayerIndex else { return }
            let result = submit(word)
            if case .rejected(let reason) = result {
                // 却下のときは状態が変わらないので、理由だけ返す。
                nearby?.send(.rejected(reason: reason))
            }
            // 受理・決着時の状態配信は submit / finish 側で行う。

        case .giveUp:
            guard playMode == .nearbyHost, phase == .playing else { return }
            let guestIndex = 1
            finish(loser: guestIndex, message: "\(players[guestIndex])さんが降参しました")

        case .snapshot(let snapshot):
            guard playMode == .nearbyGuest else { return }
            apply(snapshot)

        case .rejected(let reason):
            guard playMode == .nearbyGuest else { return }
            networkMessage = reason

        case .quit:
            handleDisconnect()
        }
    }

    private func handleDisconnect() {
        guard playMode.isNearby else { return }
        didLoseConnection = true
        if phase == .playing {
            resultMessage = "相手との接続が切れました"
            loserIndex = nil
            phase = .finished
        }
    }

    /// ホストが今の状態をゲストへ配る。
    private func broadcastSnapshot() {
        guard playMode == .nearbyHost else { return }
        let snapshot = GameSnapshot(
            playerNames: players,
            history: history,
            currentPlayerIndex: currentPlayerIndex,
            requiredStartKana: requiredStartKana.map(String.init),
            requiredLength: requiredLength,
            remainingTime: remainingTime,
            isFinished: phase == .finished,
            loserIndex: loserIndex,
            resultMessage: resultMessage,
            guestPlayerIndex: 1,
            minLength: settings.minLength,
            maxLength: settings.isMaxLengthEnabled ? settings.maxLength : nil,
            isTimed: isTimed
        )
        nearby?.send(.snapshot(snapshot))
    }

    /// ゲストが受け取った状態を反映する。
    private func apply(_ snapshot: GameSnapshot) {
        nearbyPlayerNames = snapshot.playerNames
        myPlayerIndex = snapshot.guestPlayerIndex
        history = snapshot.history
        usedReadings = Set(snapshot.history.map(\.reading))
        currentPlayerIndex = snapshot.currentPlayerIndex
        requiredStartKana = snapshot.requiredStartKana?.first
        requiredLength = snapshot.requiredLength
        remainingTime = snapshot.remainingTime
        loserIndex = snapshot.loserIndex
        resultMessage = snapshot.resultMessage
        // 表示に使うルールもそろえる。
        settings.minLength = snapshot.minLength
        settings.isMaxLengthEnabled = snapshot.maxLength != nil
        if let maxLength = snapshot.maxLength { settings.maxLength = maxLength }
        settings.turnTimeLimit = snapshot.isTimed ? max(settings.turnTimeLimit, 1) : 0

        let newPhase: GamePhase = snapshot.isFinished ? .finished : .playing
        if newPhase == .finished, phase != .finished {
            Haptics.gameOver()
        }
        phase = newPhase
    }

    /// ホストが自分の手を打ったあとに状態を配るためのフック。
    fileprivate func broadcastIfHost() {
        broadcastSnapshot()
    }

    private func finish(loser: Int, message: String) {
        cancelCPUTurn()
        loserIndex = loser
        resultMessage = message
        // 続いた単語数（＝最後の「ん」止まりの語も含む）を記録に反映。
        // アプリが出したお題の語は数えない。
        didSetNewRecord = GameRecord.update(chain: chainCount)

        // 対戦をやり切ったボーナス。記録更新ならさらに上乗せ。
        earnedPoints = PointsStore.finishBonus + (didSetNewRecord ? PointsStore.recordBonus : 0)

        // 1人プレイなら戦績と連勝を記録し、勝利ボーナスを上乗せする。
        if isSoloMode {
            let won = (loser == cpuPlayerIndex)
            soloWon = won
            didSetBestStreak = SoloStats.shared.recordResult(won: won, difficulty: settings.cpuDifficulty)
            if won {
                soloWinBonus = SoloStats.winBonus(for: settings.cpuDifficulty)
                    + (didSetBestStreak ? SoloStats.bestStreakBonus : 0)
                earnedPoints += soloWinBonus
            }
        }

        PointsStore.shared.award(earnedPoints)

        phase = .finished
        discardSavedGame()
        Haptics.gameOver()
        broadcastIfHost()
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

    /// 1手番で使えるヒントの上限。連打で答えを絞り込みすぎないための制限。
    static let maxHintsPerTurn = 2

    /// この手番でまだヒントを使えるか。
    var canUseHint: Bool { hintCountThisTurn < Self.maxHintsPerTurn }

    /// ヒントを作る。答えそのものは出さず、「文字数」と「最後の音」だけ教える難しめのヒント。
    func requestHint() {
        guard phase == .playing else { return }
        guard let start = requiredStartKana else {
            hintText = "最初の単語は何でもOK。好きな言葉からどうぞ。"
            return
        }
        guard canUseHint else {
            hintText = "この手番のヒントはここまで。次の手番でまた使えます。"
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

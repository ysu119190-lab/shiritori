import XCTest
@testable import Shiritori

/// オンライン対戦で受け渡す状態（`OnlineMatchState`）と、
/// オンライン用のルール調整のテスト。
///
/// Game Center 本体（マッチメイキングや通信）は実機・実アカウントが必要なので
/// ここでは扱わない。ここで押さえるのは「相手に渡すデータが壊れないこと」と
/// 「オンラインで不公平なルールが落ちること」。
final class OnlineMatchStateTests: XCTestCase {

    private func makeState(currentSeat: Int = 1, loserSeat: Int? = nil) -> OnlineMatchState {
        let history = [
            Move(word: "りんご", reading: "りんご", playerIndex: -1,
                 acceptedByChallenge: false, acceptedByWeb: false, isSeed: true),
            Move(word: "ごりら", reading: "ごりら", playerIndex: 0,
                 acceptedByChallenge: false, acceptedByWeb: false)
        ]
        return OnlineMatchState(
            settings: .default,
            history: history,
            currentSeat: currentSeat,
            requiredStartKana: "ら",
            requiredLength: nil,
            loserSeat: loserSeat,
            resultMessage: loserSeat == nil ? "" : "テスト"
        )
    }

    // MARK: - matchData との変換

    func testEncodeDecodeRoundTrip() throws {
        let original = makeState()
        let data = try original.encoded()
        let decoded = OnlineMatchState.decode(from: data)
        // Move の id まで含めて同一に戻ること（履歴が入れ替わらない）。
        XCTAssertEqual(decoded, original)
    }

    func testDecodeFromEmptyOrNilDataIsNil() {
        // 新規対局では matchData が空。初期化が必要な合図として nil を返す。
        XCTAssertNil(OnlineMatchState.decode(from: nil))
        XCTAssertNil(OnlineMatchState.decode(from: Data()))
    }

    func testDecodeFromGarbageIsNil() {
        XCTAssertNil(OnlineMatchState.decode(from: Data("これはJSONではない".utf8)))
    }

    func testChainCountExcludesSeed() {
        // お題の語は語数に数えない（ローカル対戦と同じ扱い）。
        XCTAssertEqual(makeState().chainCount, 1)
    }

    func testIsFinished() {
        XCTAssertFalse(makeState(loserSeat: nil).isFinished)
        XCTAssertTrue(makeState(loserSeat: 0).isFinished)
    }

    func testPlayerCountIsTwo() {
        XCTAssertEqual(OnlineMatchState.playerCount, 2)
    }

    // MARK: - オンライン用のルール調整

    func testOnlineSanitizedDropsDeviceDependentAndLocalOnlyRules() {
        var s = GameSettings.default
        s.useSystemDictionary = true
        s.allowChallengeOverride = true
        s.checkExistence = false
        s.turnTimeLimit = 30

        let online = s.onlineSanitized()

        // 端末辞書は端末ごとに結果が変わるので使わない。
        XCTAssertFalse(online.useSystemDictionary)
        // 参加者承認は相手に口頭確認できないので使わない。
        XCTAssertFalse(online.allowChallengeOverride)
        // 実在判定そのものは必ず有効。
        XCTAssertTrue(online.checkExistence)
        // 非同期対戦なので秒単位の制限時間は使わない。
        XCTAssertEqual(online.turnTimeLimit, 0)
    }

    func testOnlineSanitizedKeepsWebSearchChoice() {
        // Wikipedia 判定は残す（判定は常に語を出した本人の端末で行うため）。
        var s = GameSettings.default
        s.useWebSearch = true
        XCTAssertTrue(s.onlineSanitized().useWebSearch)

        s.useWebSearch = false
        XCTAssertFalse(s.onlineSanitized().useWebSearch)
    }

    func testOnlineSanitizedForcesTwoPlayers() {
        var s = GameSettings.default
        s.playerNames = ["A", "B", "C", "D"]
        XCTAssertEqual(s.onlineSanitized().playerNames.count, 2)
    }

    func testOnlineSanitizedKeepsLengthRules() {
        // 文字数ルールは対局を作った側の設定として引き継がれる。
        var s = GameSettings.default
        s.isRandomLengthMode = true
        s.minLength = 3
        let online = s.onlineSanitized()
        XCTAssertTrue(online.isRandomLengthMode)
        XCTAssertEqual(online.minLength, 3)
    }
}

/// オンライン対戦時の `ShiritoriGame` の手番制御。
final class OnlineGameTurnTests: XCTestCase {

    /// 相手の手番の状態を流し込んだゲームを作る。
    private func makeGame(currentSeat: Int, localSeat: Int) -> ShiritoriGame {
        let game = ShiritoriGame(settings: .default)
        let state = OnlineMatchState(
            settings: .default,
            history: [
                Move(word: "りんご", reading: "りんご", playerIndex: -1,
                     acceptedByChallenge: false, acceptedByWeb: false, isSeed: true)
            ],
            currentSeat: currentSeat,
            requiredStartKana: "ご"
        )
        game.applyOnlineState(
            state,
            localSeat: localSeat,
            playerNames: ["じぶん", "あいて"],
            isMatchEnded: false
        )
        return game
    }

    func testApplyOnlineStateSwitchesToOnlineMode() {
        let game = makeGame(currentSeat: 0, localSeat: 0)
        XCTAssertEqual(game.mode, .online)
        XCTAssertEqual(game.phase, .playing)
        XCTAssertEqual(game.localSeat, 0)
        XCTAssertEqual(game.requiredStartKana, "ご")
        // 履歴は相手側で再判定せず、そのまま受け入れる。
        XCTAssertEqual(game.history.count, 1)
    }

    func testIsMyTurnOnLocalSeat() {
        let mine = makeGame(currentSeat: 1, localSeat: 1)
        XCTAssertTrue(mine.isMyTurn)
        XCTAssertFalse(mine.isWaitingForOpponent)
    }

    func testIsWaitingWhenOpponentsTurn() {
        let theirs = makeGame(currentSeat: 0, localSeat: 1)
        XCTAssertFalse(theirs.isMyTurn)
        XCTAssertTrue(theirs.isWaitingForOpponent)
        XCTAssertEqual(theirs.opponentName, "じぶん")
    }

    func testSubmitRejectedWhenNotLocalTurn() {
        let game = makeGame(currentSeat: 0, localSeat: 1)
        // 相手の番なので、つながる語でも受理されない。
        let result = game.submit("ごりら")
        guard case .rejected(let reason) = result else {
            return XCTFail("相手の手番では受理されないはず。実際: \(result)")
        }
        XCTAssertTrue(reason.contains("番です"), "手番を待つ案内が出るはず。実際: \(reason)")
        XCTAssertEqual(game.history.count, 1, "拒否されたので履歴は増えない")
    }

    func testPassAndPlayIsAlwaysMyTurn() {
        // ローカル対戦では手番制御は入らない。
        let game = ShiritoriGame(settings: .default)
        XCTAssertEqual(game.mode, .passAndPlay)
        XCTAssertTrue(game.isMyTurn)
        XCTAssertFalse(game.isWaitingForOpponent)
    }

    func testOnlineMatchCannotBeSuspendedLocally() {
        // オンライン対局は Game Center が預かるので、中断保存の対象外。
        let game = makeGame(currentSeat: 1, localSeat: 1)
        XCTAssertFalse(game.canSuspend)
    }

    func testSnapshotCarriesCurrentSeat() {
        let game = makeGame(currentSeat: 1, localSeat: 1)
        let snapshot = game.onlineStateSnapshot()
        XCTAssertEqual(snapshot.currentSeat, 1)
        XCTAssertEqual(snapshot.requiredStartKana, "ご")
        XCTAssertFalse(snapshot.isFinished)
    }

    func testStartOnlineWaitingDoesNotSeedOrTakeTurn() {
        // 招待されたが相手がまだ初手を打っていない状況。
        // ここで出題して打ってしまうと Game Center 側に手番が無く送信が失敗するので、
        // 出題せず待機状態にする。
        let game = ShiritoriGame(settings: .default)
        game.startOnlineWaiting(localSeat: 1, currentSeat: 0, playerNames: ["あいて", "じぶん"])

        XCTAssertEqual(game.mode, .online)
        XCTAssertEqual(game.phase, .playing)
        XCTAssertTrue(game.history.isEmpty, "お題を出さない")
        XCTAssertFalse(game.isMyTurn)
        XCTAssertTrue(game.isWaitingForOpponent)

        // 待機中は打てない。
        guard case .rejected = game.submit("りんご") else {
            return XCTFail("待機中は受理されないはず")
        }
    }

    func testLeaveOnlineMatchReturnsToSetup() {
        let game = makeGame(currentSeat: 1, localSeat: 1)
        game.leaveOnlineMatch()
        XCTAssertEqual(game.mode, .passAndPlay)
        XCTAssertEqual(game.phase, .setup)
    }
}

import XCTest
@testable import Shiritori

/// Game Center の対戦データ（matchData）として持ち回る状態のテスト。
/// この形が壊れると、進行中の対戦が読めなくなるので往復と要点を固定する。
final class OnlineMatchStateTests: XCTestCase {

    private func makeState() -> OnlineMatchState {
        OnlineMatchState(
            playerIDs: [],
            playerNames: [],
            history: [],
            requiredStartKana: nil,
            requiredLength: nil,
            rules: OnlineMatchState.Rules(from: .default),
            isFinished: false,
            loserID: nil,
            resultMessage: ""
        )
    }

    func testEncodeDecodeRoundTrip() throws {
        var state = makeState()
        _ = state.ensurePlayer(id: "A", name: "あきら")
        _ = state.ensurePlayer(id: "B", name: "ばんり")
        state.history = [
            Move(word: "りんご", reading: "りんご", playerIndex: -1,
                 acceptedByChallenge: false, acceptedByWeb: false, isSeed: true),
            Move(word: "ごりら", reading: "ごりら", playerIndex: 0,
                 acceptedByChallenge: false, acceptedByWeb: false)
        ]
        state.requiredStartKana = "ら"

        let data = try state.encoded()
        let restored = try XCTUnwrap(OnlineMatchState.decode(data))
        XCTAssertEqual(restored, state)
    }

    func testDecodeRejectsEmptyData() {
        // 対戦を作った直後は matchData が空。nil を返して「未初期化」と分かるようにする。
        XCTAssertNil(OnlineMatchState.decode(Data()))
    }

    func testEnsurePlayerAssignsStableIndices() {
        var state = makeState()
        let first = state.ensurePlayer(id: "A", name: "あきら")
        let second = state.ensurePlayer(id: "B", name: "ばんり")
        XCTAssertEqual(first, 0)
        XCTAssertEqual(second, 1)

        // 同じIDなら何度呼んでも同じ番号。参加の順番に依存しないための性質。
        XCTAssertEqual(state.ensurePlayer(id: "A", name: "あきら"), 0)
        XCTAssertEqual(state.playerIDs.count, 2)
    }

    func testEnsurePlayerUpdatesDisplayName() {
        var state = makeState()
        _ = state.ensurePlayer(id: "A", name: "ふるいなまえ")
        _ = state.ensurePlayer(id: "A", name: "あたらしいなまえ")
        XCTAssertEqual(state.playerNames, ["あたらしいなまえ"])
    }

    func testIndexOfUnknownPlayerIsNil() {
        var state = makeState()
        _ = state.ensurePlayer(id: "A", name: "あきら")
        XCTAssertEqual(state.index(of: "A"), 0)
        XCTAssertNil(state.index(of: "Z"))
    }

    func testChainCountExcludesSeedWord() {
        var state = makeState()
        state.history = [
            Move(word: "りんご", reading: "りんご", playerIndex: -1,
                 acceptedByChallenge: false, acceptedByWeb: false, isSeed: true),
            Move(word: "ごりら", reading: "ごりら", playerIndex: 0,
                 acceptedByChallenge: false, acceptedByWeb: false),
            Move(word: "らっぱ", reading: "らっぱ", playerIndex: 1,
                 acceptedByChallenge: false, acceptedByWeb: false)
        ]
        XCTAssertEqual(state.chainCount, 2, "アプリが出したお題は数えない")
    }

    func testRulesRoundTripThroughSettings() {
        var settings = GameSettings.default
        settings.minLength = 3
        settings.isMaxLengthEnabled = true
        settings.maxLength = 7
        settings.isRandomLengthMode = true
        settings.randomLengthMin = 3
        settings.randomLengthMax = 5
        settings.ignoreDakuten = false

        let rules = OnlineMatchState.Rules(from: settings)
        var applied = GameSettings.default
        rules.apply(to: &applied)

        XCTAssertEqual(applied.minLength, 3)
        XCTAssertTrue(applied.isMaxLengthEnabled)
        XCTAssertEqual(applied.maxLength, 7)
        XCTAssertTrue(applied.isRandomLengthMode)
        XCTAssertEqual(applied.randomLengthMin, 3)
        XCTAssertEqual(applied.randomLengthMax, 5)
        XCTAssertFalse(applied.ignoreDakuten)
    }

    func testRulesDisableFeaturesThatNeedWaiting() {
        // オンライン対戦では待ち時間が読めないので、ウェブ判定・参加者承認・
        // 手番の秒数制限・CPU対戦は使わない。
        var settings = GameSettings.default
        settings.useWebSearch = true
        settings.allowChallengeOverride = true
        settings.turnTimeLimit = 30
        settings.isSoloMode = true

        var applied = settings
        OnlineMatchState.Rules(from: settings).apply(to: &applied)

        XCTAssertFalse(applied.useWebSearch)
        XCTAssertFalse(applied.allowChallengeOverride)
        XCTAssertEqual(applied.turnTimeLimit, 0)
        XCTAssertFalse(applied.isSoloMode)
    }

    func testRulesKeepUnlimitedMaxLength() {
        var settings = GameSettings.default
        settings.isMaxLengthEnabled = false

        let rules = OnlineMatchState.Rules(from: settings)
        XCTAssertNil(rules.maxLength)

        var applied = GameSettings.default
        applied.isMaxLengthEnabled = true
        rules.apply(to: &applied)
        XCTAssertFalse(applied.isMaxLengthEnabled)
    }
}

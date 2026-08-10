import XCTest
@testable import Shiritori

/// 設定の丸め込み（`sanitized`）と後方互換デコードのテスト。
final class GameSettingsTests: XCTestCase {

    func testSanitizeClampsPlayerCount() {
        var s = GameSettings.default
        s.playerNames = ["A"]
        XCTAssertEqual(s.sanitized().playerNames.count, GameSettings.minPlayers)

        s.playerNames = Array(repeating: "X", count: 10)
        XCTAssertEqual(s.sanitized().playerNames.count, GameSettings.maxPlayers)
    }

    func testSanitizeFillsEmptyNames() {
        var s = GameSettings.default
        s.playerNames = ["   ", "たろう"]
        let sanitized = s.sanitized()
        XCTAssertEqual(sanitized.playerNames[0], "プレイヤー1")
        XCTAssertEqual(sanitized.playerNames[1], "たろう")
    }

    func testSanitizeClampsLengths() {
        var s = GameSettings.default
        s.minLength = 99
        s.maxLength = 1
        let sanitized = s.sanitized()
        XCTAssertLessThanOrEqual(sanitized.minLength, 10)
        // 上限は下限を下回らないよう補正される。
        XCTAssertGreaterThanOrEqual(sanitized.maxLength, sanitized.minLength)
    }

    func testSanitizeClampsTimeLimit() {
        var s = GameSettings.default
        s.turnTimeLimit = 999
        XCTAssertLessThanOrEqual(s.sanitized().turnTimeLimit, 120)
        s.turnTimeLimit = -5
        XCTAssertGreaterThanOrEqual(s.sanitized().turnTimeLimit, 0)
    }

    func testBackwardCompatibleDecodingSuppliesDefaults() throws {
        // 新フィールド（useWebSearch / isRandomLengthMode / useKanaKeyboard /
        // kanaKeyboardStyle）が無い旧 JSON でも既定値で読み込めること。
        let json = """
        {
          "playerNames": ["A", "B"],
          "minLength": 2,
          "isMaxLengthEnabled": false,
          "maxLength": 6,
          "checkExistence": true,
          "useSystemDictionary": true,
          "ignoreDakuten": true,
          "turnTimeLimit": 0,
          "allowChallengeOverride": true
        }
        """
        let decoded = try JSONDecoder().decode(GameSettings.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.playerNames, ["A", "B"])
        XCTAssertTrue(decoded.useWebSearch)                 // ?? true
        XCTAssertFalse(decoded.isRandomLengthMode)          // ?? false
        XCTAssertEqual(decoded.kanaKeyboardStyle, .flick)   // ?? .flick
    }

    func testRandomLengthBounds() {
        // 設定できる上下限を固定して確認する。
        XCTAssertEqual(GameSettings.randomLengthBounds.lowerBound, 2)
        XCTAssertEqual(GameSettings.randomLengthBounds.upperBound, 9)
    }

    func testRandomLengthDefaults() {
        // 既定はランダム文字数の幅いっぱい（2〜9）。
        XCTAssertEqual(GameSettings.default.randomLengthMin, 2)
        XCTAssertEqual(GameSettings.default.randomLengthMax, 9)
    }

    func testRandomLengthSanitizeClampsAndOrders() {
        var s = GameSettings.default
        // 上下限を超えた値と、min > max の逆転を丸める。
        s.randomLengthMin = 0    // 下限 2 未満
        s.randomLengthMax = 20   // 上限 9 超過
        var t = s.sanitized()
        XCTAssertEqual(t.randomLengthMin, 2)
        XCTAssertEqual(t.randomLengthMax, 9)

        s.randomLengthMin = 8
        s.randomLengthMax = 4    // min > max
        t = s.sanitized()
        XCTAssertLessThanOrEqual(t.randomLengthMin, t.randomLengthMax)
    }
}

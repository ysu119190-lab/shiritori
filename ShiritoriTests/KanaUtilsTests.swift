import XCTest
@testable import Shiritori

/// かな正規化・しりとり接続判定の中心ロジック `KanaUtils` のテスト。
final class KanaUtilsTests: XCTestCase {

    // MARK: - 正規化

    func testToHiragana() {
        XCTAssertEqual(KanaUtils.toHiragana("リンゴ"), "りんご")
        XCTAssertEqual(KanaUtils.toHiragana("りんご"), "りんご")
        // 長音符「ー」はカタカナ範囲外なのでそのまま残る。
        XCTAssertEqual(KanaUtils.toHiragana("コーヒー"), "こーひー")
    }

    func testToKatakanaRoundTrip() {
        XCTAssertEqual(KanaUtils.toKatakana("りんご"), "リンゴ")
        XCTAssertEqual(KanaUtils.toHiragana(KanaUtils.toKatakana("さくら")), "さくら")
    }

    func testNormalizeTrimsAndConverts() {
        XCTAssertEqual(KanaUtils.normalize("  リンゴ \n"), "りんご")
        XCTAssertEqual(KanaUtils.normalize("すいか"), "すいか")
    }

    func testIsAllKana() {
        XCTAssertTrue(KanaUtils.isAllKana("りんご"))
        XCTAssertTrue(KanaUtils.isAllKana("こーひー"))     // 長音符は許可
        XCTAssertFalse(KanaUtils.isAllKana(""))            // 空文字は不可
        XCTAssertFalse(KanaUtils.isAllKana("リンゴ"))      // カタカナは正規化前提で不可
        XCTAssertFalse(KanaUtils.isAllKana("りんご123"))   // 数字混在は不可
        XCTAssertFalse(KanaUtils.isAllKana("犬"))          // 漢字は不可
    }

    // MARK: - しりとり判定

    func testStartKanaNormalizesSmall() {
        XCTAssertEqual(KanaUtils.startKana(of: "りんご"), "り")
        XCTAssertEqual(KanaUtils.startKana(of: "ぁい"), "あ") // 小書き→大文字
        XCTAssertNil(KanaUtils.startKana(of: ""))
    }

    func testEndsWithN() {
        XCTAssertTrue(KanaUtils.endsWithN("みかん"))
        XCTAssertFalse(KanaUtils.endsWithN("りんご"))
        XCTAssertFalse(KanaUtils.endsWithN(""))
    }

    func testConnectingKanaBasic() {
        XCTAssertEqual(KanaUtils.connectingKana(of: "りんご"), "ご")
        XCTAssertEqual(KanaUtils.connectingKana(of: "しゃ"), "や") // 小書き→大文字
        XCTAssertNil(KanaUtils.connectingKana(of: ""))
    }

    func testConnectingKanaProlonged() {
        // 末尾の長音符はスキップして手前の実音を採用する。
        XCTAssertEqual(KanaUtils.connectingKana(of: "こーひー"), "ひ")
        XCTAssertEqual(KanaUtils.connectingKana(of: "すきー"), "き")
    }

    func testConnectingKanaOptionsProlongedAddsVowel() {
        // 「コーヒー」は「ひ」でも母音「い」でもつなげられる。
        XCTAssertEqual(KanaUtils.connectingKanaOptions(of: "こーひー"), ["ひ", "い"])
        // 「カー」は「か」でも母音「あ」でも。
        XCTAssertEqual(KanaUtils.connectingKanaOptions(of: "かー"), ["か", "あ"])
        // 長音で終わらない語は1音のみ。
        XCTAssertEqual(KanaUtils.connectingKanaOptions(of: "りんご"), ["ご"])
        // 直前が母音そのものなら重複させない。
        XCTAssertEqual(KanaUtils.connectingKanaOptions(of: "あー"), ["あ"])
    }

    func testConnectsWithDakuten() {
        // 濁点を区別しない設定では「き」と「ぎ」がつながる。
        XCTAssertTrue(KanaUtils.connects(previousEnd: "き", nextStart: "ぎ", ignoreDakuten: true))
        XCTAssertFalse(KanaUtils.connects(previousEnd: "き", nextStart: "ぎ", ignoreDakuten: false))
        // 半濁音も清音扱い。
        XCTAssertTrue(KanaUtils.connects(previousEnd: "は", nextStart: "ぱ", ignoreDakuten: true))
        // 同じ音は設定に関わらずつながる。
        XCTAssertTrue(KanaUtils.connects(previousEnd: "き", nextStart: "き", ignoreDakuten: false))
    }

    func testEndsWithProlongedMark() {
        XCTAssertTrue(KanaUtils.endsWithProlongedMark("こーひー"))
        XCTAssertFalse(KanaUtils.endsWithProlongedMark("りんご"))
        XCTAssertFalse(KanaUtils.endsWithProlongedMark(""))
    }
}

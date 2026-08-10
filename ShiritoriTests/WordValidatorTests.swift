import XCTest
@testable import Shiritori

/// 同梱辞書（厳選＋拡張）による実在判定のテスト。
/// 端末辞書・ネットは使わず、オフラインの同梱辞書だけで判定できることを確かめる。
final class WordValidatorTests: XCTestCase {

    private var validator: WordValidator!

    override func setUp() {
        super.setUp()
        // 端末の国語辞書は環境依存なのでオフにし、同梱辞書のみで検証する。
        validator = WordValidator(useSystemDictionary: false)
    }

    func testBundledDictionariesAreLoaded() {
        // 厳選(約1,200) + 拡張(約45,000)。読み込み失敗していればここで気づく。
        XCTAssertGreaterThan(validator.bundledWordCount, 40_000)
    }

    func testCommonNounsExistOffline() {
        // 漢字表記が普通の一般名詞。以前は Wikipedia のタイトル完全一致に頼っていて
        // 誤って「実在しない」と判定されがちだった代表例（拡張辞書で救う）。
        for word in ["えんとつ", "はなたば", "てすり", "でんちゅう", "べんきょう", "げんき"] {
            XCTAssertTrue(validator.exists(word), "「\(word)」は実在と判定されるべき")
        }
    }

    func testCuratedWordsStillExist() {
        for word in ["りんご", "ごりら", "ぱんだ"] where validator.exists(word) == false {
            XCTFail("厳選辞書の「\(word)」が判定できない")
        }
    }

    func testNonsenseDoesNotExist() {
        for word in ["ぬれぱち", "きぞらまど", "あぱらけっと"] {
            XCTAssertFalse(validator.exists(word), "「\(word)」は実在しない語")
        }
    }

    func testRandomStartWordIsPlayable() {
        // 出題は厳選辞書から。しりとりとして続けられる語であること。
        for _ in 0..<20 {
            guard let seed = validator.randomStartWord() else {
                return XCTFail("出題語が選べない")
            }
            XCTAssertFalse(KanaUtils.endsWithN(seed), "出題語が「ん」で終わっている: \(seed)")
            XCTAssertNotNil(KanaUtils.connectingKana(of: seed))
            XCTAssertTrue((2...5).contains(seed.count), "出題語の長さが範囲外: \(seed)")
        }
    }
}

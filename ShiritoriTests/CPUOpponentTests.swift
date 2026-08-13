import XCTest
@testable import Shiritori

final class CPUOpponentTests: XCTestCase {

    /// 乱数を固定して決定的に検証する。
    private func opponent(
        _ difficulty: CPUDifficulty,
        random: @escaping () -> Double = { 0 },
        followUpCount: @escaping (Character) -> Int = { _ in 100 }
    ) -> CPUOpponent {
        CPUOpponent(difficulty: difficulty, followUpCount: followUpCount, random: random)
    }

    func testNeverPlaysWordEndingWithN() {
        // 「ん」で終わる語しか無ければ、打たずに降参する（自滅しない）。
        let cpu = opponent(.normal)
        XCTAssertNil(cpu.chooseWord(from: ["みかん", "ぱん"], turnCount: 0))
    }

    func testPicksOnlyPlayableWord() {
        let cpu = opponent(.normal)
        let word = cpu.chooseWord(from: ["みかん", "りんご"], turnCount: 0)
        XCTAssertEqual(word, "りんご")
    }

    func testReturnsNilWhenNoCandidates() {
        XCTAssertNil(opponent(.normal).chooseWord(from: [], turnCount: 0))
    }

    func testEasyPrefersShortWords() {
        // よわい CPU は短い語を選ぶ（最短+1 まで）。
        // turnCount 0 なら降参確率 0 なので、乱数 0 でも降参しない。
        let cpu = opponent(.easy, random: { 0 })
        let candidates = ["おおきなかぶ", "ねこ", "こうえん"]
        let word = cpu.chooseWord(from: candidates, turnCount: 0)
        XCTAssertEqual(word, "ねこ", "最短の語が選ばれるはず")
    }

    func testEasyNeverGivesUpEarly() {
        // 序盤（4手目まで）は降参確率 0。乱数がどんな値でも打つ。
        let cpu = opponent(.easy, random: { 0.0 })
        XCTAssertNotNil(cpu.chooseWord(from: ["ねこ"], turnCount: 0))
        XCTAssertNotNil(cpu.chooseWord(from: ["ねこ"], turnCount: 4))
    }

    func testEasyMayGiveUpWhenGameDragsOn() {
        // 長引くと降参確率が上がる（上限 0.5）。
        // 乱数が確率を下回れば降参し、上回れば打ち続ける。
        let unlucky = opponent(.easy, random: { 0.49 })
        XCTAssertNil(unlucky.chooseWord(from: ["ねこ"], turnCount: 30))

        let lucky = opponent(.easy, random: { 0.99 })
        XCTAssertNotNil(lucky.chooseWord(from: ["ねこ"], turnCount: 30))
    }

    func testHardPrefersWordThatLimitsOpponent() {
        // 「つよい」は、終わりの音から続けられる語が少ない語を選ぶ。
        // 「ら」で終わる語＝続きが少ない、と見せかける。
        let cpu = opponent(.hard, random: { 0 }, followUpCount: { kana in
            kana == "ら" ? 1 : 500
        })
        let word = cpu.chooseWord(from: ["ごりら", "ごま", "ごはんつぶ"], turnCount: 0)
        XCTAssertEqual(word, "ごりら")
    }

    func testNormalCanPickAnyPlayableWord() {
        // 乱数を振り切ると最後の候補が選ばれる（範囲外アクセスしないこと）。
        let cpu = opponent(.normal, random: { 0.999999 })
        let candidates = ["あり", "いぬ", "うま"]
        let word = cpu.chooseWord(from: candidates, turnCount: 0)
        XCTAssertNotNil(word)
        XCTAssertTrue(candidates.contains(word!))
    }
}

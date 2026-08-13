import XCTest
@testable import Shiritori

final class SoloStatsTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        // 本物の UserDefaults を汚さないよう、テスト専用のスイートを使う。
        suiteName = "SoloStatsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testStartsEmpty() {
        let stats = SoloStats(defaults: defaults)
        XCTAssertEqual(stats.record(for: .normal), SoloStats.Record())
        XCTAssertEqual(stats.currentStreak, 0)
        XCTAssertEqual(stats.bestStreak, 0)
    }

    func testWinIncrementsStreakAndRecord() {
        let stats = SoloStats(defaults: defaults)
        let isBest = stats.recordResult(won: true, difficulty: .normal)
        XCTAssertTrue(isBest, "初勝利は最高連勝の更新になる")
        XCTAssertEqual(stats.record(for: .normal).wins, 1)
        XCTAssertEqual(stats.currentStreak, 1)
        XCTAssertEqual(stats.bestStreak, 1)
    }

    func testLossResetsStreakButKeepsBest() {
        let stats = SoloStats(defaults: defaults)
        stats.recordResult(won: true, difficulty: .normal)
        stats.recordResult(won: true, difficulty: .normal)
        XCTAssertEqual(stats.currentStreak, 2)

        let isBest = stats.recordResult(won: false, difficulty: .normal)
        XCTAssertFalse(isBest)
        XCTAssertEqual(stats.currentStreak, 0, "負けたら連勝は途切れる")
        XCTAssertEqual(stats.bestStreak, 2, "最高連勝は残る")
        XCTAssertEqual(stats.record(for: .normal).losses, 1)
    }

    func testRecordsAreSeparatePerDifficulty() {
        let stats = SoloStats(defaults: defaults)
        stats.recordResult(won: true, difficulty: .easy)
        stats.recordResult(won: false, difficulty: .hard)

        XCTAssertEqual(stats.record(for: .easy).wins, 1)
        XCTAssertEqual(stats.record(for: .easy).losses, 0)
        XCTAssertEqual(stats.record(for: .hard).wins, 0)
        XCTAssertEqual(stats.record(for: .hard).losses, 1)
        XCTAssertEqual(stats.totalWins, 1)
        XCTAssertEqual(stats.totalLosses, 1)
    }

    func testPersistsAcrossInstances() {
        let first = SoloStats(defaults: defaults)
        first.recordResult(won: true, difficulty: .hard)
        first.recordResult(won: true, difficulty: .hard)

        let reloaded = SoloStats(defaults: defaults)
        XCTAssertEqual(reloaded.record(for: .hard).wins, 2)
        XCTAssertEqual(reloaded.currentStreak, 2)
        XCTAssertEqual(reloaded.bestStreak, 2)
    }

    func testWinBonusIncreasesWithDifficulty() {
        XCTAssertLessThan(SoloStats.winBonus(for: .easy), SoloStats.winBonus(for: .normal))
        XCTAssertLessThan(SoloStats.winBonus(for: .normal), SoloStats.winBonus(for: .hard))
    }
}

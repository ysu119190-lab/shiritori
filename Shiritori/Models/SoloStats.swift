import Foundation

/// 1人プレイ（CPU対戦）の戦績。やりこみ要素として勝敗・連勝を記録する。
final class SoloStats: ObservableObject {

    static let shared = SoloStats()

    /// 難易度ごとの勝敗。
    struct Record: Codable, Equatable {
        var wins = 0
        var losses = 0
    }

    @Published private(set) var records: [String: Record]
    /// いまの連勝数（難易度をまたいで数える。負けると0に戻る）。
    @Published private(set) var currentStreak: Int
    /// これまでの最高連勝数。
    @Published private(set) var bestStreak: Int

    private let defaults: UserDefaults

    private enum Key {
        static let records = "SoloStats.records.v1"
        static let currentStreak = "SoloStats.currentStreak.v1"
        static let bestStreak = "SoloStats.bestStreak.v1"
    }

    /// 難易度に応じた勝利ボーナス（しりとりポイント）。
    static func winBonus(for difficulty: CPUDifficulty) -> Int {
        switch difficulty {
        case .easy: return 10
        case .normal: return 20
        case .hard: return 30
        }
    }

    /// 最高連勝を更新したときの追加ボーナス。
    static let bestStreakBonus = 15

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Key.records),
           let decoded = try? JSONDecoder().decode([String: Record].self, from: data) {
            records = decoded
        } else {
            records = [:]
        }
        currentStreak = defaults.integer(forKey: Key.currentStreak)
        bestStreak = defaults.integer(forKey: Key.bestStreak)
    }

    func record(for difficulty: CPUDifficulty) -> Record {
        records[difficulty.rawValue] ?? Record()
    }

    var totalWins: Int { records.values.reduce(0) { $0 + $1.wins } }
    var totalLosses: Int { records.values.reduce(0) { $0 + $1.losses } }

    /// 対戦結果を記録する。
    /// - Returns: 最高連勝を更新したら true。
    @discardableResult
    func recordResult(won: Bool, difficulty: CPUDifficulty) -> Bool {
        var record = records[difficulty.rawValue] ?? Record()
        var isNewBest = false
        if won {
            record.wins += 1
            currentStreak += 1
            if currentStreak > bestStreak {
                bestStreak = currentStreak
                isNewBest = true
            }
        } else {
            record.losses += 1
            currentStreak = 0
        }
        records[difficulty.rawValue] = record
        persist()
        return isNewBest
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Key.records)
        }
        defaults.set(currentStreak, forKey: Key.currentStreak)
        defaults.set(bestStreak, forKey: Key.bestStreak)
    }
}

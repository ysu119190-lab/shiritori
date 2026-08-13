import Foundation

/// CPU対戦の難易度。
enum CPUDifficulty: String, Codable, CaseIterable {
    case easy
    case normal
    case hard

    /// 設定画面などでの表示名。
    var displayName: String {
        switch self {
        case .easy: return "よわい"
        case .normal: return "ふつう"
        case .hard: return "つよい"
        }
    }

    /// 対戦画面で表示するCPUの名前。
    var cpuName: String {
        switch self {
        case .easy: return "ロボにゃん"
        case .normal: return "ロボまる"
        case .hard: return "ロボキング"
        }
    }
}

/// 1人プレイでCPUの手を決める。
///
/// 候補語の抽出は `WordValidator` が行い、ここでは「どの語を選ぶか」だけを決める。
/// 乱数と辞書参照を注入できるようにして、ユニットテストで決定的に検証できるようにしている。
struct CPUOpponent {

    let difficulty: CPUDifficulty

    /// 語の「終わりの音」で始められる語が辞書にいくつあるか（相手の残り手数の目安）。
    /// つよいCPUが相手の選択肢を狭める語を選ぶのに使う。
    let followUpCount: (Character) -> Int

    /// 0.0..<1.0 の乱数（テストでは固定値を注入する）。
    var random: () -> Double = { Double.random(in: 0..<1) }

    /// CPUの手を決める。nil を返したら降参（プレイヤーの勝ち）。
    /// - Parameters:
    ///   - candidates: 現在のルール（開始音・文字数・未使用）を満たす候補語。
    ///   - turnCount: これまでにCPUが打った手数。よわいCPUは長引くほど降参しやすくなる。
    func chooseWord(from candidates: [String], turnCount: Int) -> String? {
        // 「ん」で終わる語を打つと自滅なので除く。残らなければ降参。
        let playable = candidates.filter { !KanaUtils.endsWithN($0) }
        guard !playable.isEmpty else { return nil }

        switch difficulty {
        case .easy:
            // 長引くほど降参しやすい（5手目以降、1手ごとに+6%。上限50%）。
            let giveUpChance = min(max(0, Double(turnCount - 4)) * 0.06, 0.5)
            if random() < giveUpChance { return nil }
            // 短くてやさしい語を選ぶ（最短の長さの語からランダム）。
            let shortest = playable.map(\.count).min() ?? 2
            let easyPool = playable.filter { $0.count <= shortest + 1 }
            return pickRandom(from: easyPool)

        case .normal:
            return pickRandom(from: playable)

        case .hard:
            // 相手が続けにくい語（終わりの音から始まる語が少ない語）を選ぶ。
            // 完全に決定的だと単調なので、良い方から3語の中からランダムに選ぶ。
            let scored = playable.map { word -> (word: String, score: Int) in
                let ending = KanaUtils.connectingKana(of: word)
                return (word, ending.map(followUpCount) ?? Int.max)
            }
            let best = scored.sorted { $0.score < $1.score }.prefix(3).map(\.word)
            return pickRandom(from: best)
        }
    }

    private func pickRandom(from pool: [String]) -> String? {
        guard !pool.isEmpty else { return nil }
        let index = min(Int(random() * Double(pool.count)), pool.count - 1)
        return pool[index]
    }
}

import Foundation

/// これまでの最長連鎖記録を保存・復元する。
enum GameRecord {

    private static let key = "GameRecord.longestChain.v1"

    /// 最長連鎖（続いた単語数）。
    static var longestChain: Int {
        UserDefaults.standard.integer(forKey: key)
    }

    /// 新しい記録を反映する。更新された場合は true を返す。
    @discardableResult
    static func update(chain: Int) -> Bool {
        if chain > longestChain {
            UserDefaults.standard.set(chain, forKey: key)
            return true
        }
        return false
    }
}

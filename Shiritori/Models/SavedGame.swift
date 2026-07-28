import Foundation

/// 中断したゲームの保存データ。設定画面に戻っても続きから再開できるようにする。
struct SavedGame: Codable {

    var settings: GameSettings
    var history: [Move]
    var currentPlayerIndex: Int
    /// 次に始めるべき音（Character は Codable ではないので String で持つ）。
    var requiredStartKana: String?
    var requiredLength: Int?
    var remainingTime: Int
    var savedAt: Date

    /// 中断時点までに続いた単語数（お題の語は含めない）。
    var chainCount: Int { history.filter { !$0.isSeed }.count }

    // MARK: - 永続化

    private static let storageKey = "SavedGame.v1"

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    static func load() -> SavedGame? {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(SavedGame.self, from: data)
        else {
            return nil
        }
        return decoded
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    static var exists: Bool { load() != nil }
}

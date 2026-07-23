import Foundation

/// ゲームのルール設定。UserDefaults に保存され、次回起動時に復元される。
struct GameSettings: Codable, Equatable {

    /// プレイヤー名（2〜6人）。
    var playerNames: [String]

    /// 文字数の下限（この文字数未満は不可）。
    var minLength: Int

    /// 文字数の上限を有効にするか。
    var isMaxLengthEnabled: Bool

    /// 文字数の上限（isMaxLengthEnabled が true のときのみ適用）。
    var maxLength: Int

    /// 単語が実在するかを自動判定するか。
    var checkExistence: Bool

    /// 端末の国語辞書も判定に使うか。
    var useSystemDictionary: Bool

    /// 濁音・半濁音を区別せずにつなぐか（例: 「か」の後に「が」から始まる語を許可）。
    var ignoreDakuten: Bool

    /// 1手ごとの制限時間（秒）。0 のときは無制限。
    var turnTimeLimit: Int

    /// 辞書に無い単語でも、参加者が認めれば続行できるようにするか。
    var allowChallengeOverride: Bool

    static let minPlayers = 2
    static let maxPlayers = 6

    static let `default` = GameSettings(
        playerNames: ["プレイヤー1", "プレイヤー2"],
        minLength: 2,
        isMaxLengthEnabled: false,
        maxLength: 6,
        checkExistence: true,
        useSystemDictionary: true,
        ignoreDakuten: true,
        turnTimeLimit: 0,
        allowChallengeOverride: true
    )

    /// 有効な設定へ丸める（人数・文字数の範囲を正す）。
    func sanitized() -> GameSettings {
        var s = self
        // 人数を 2〜6 に収める。
        if s.playerNames.count < Self.minPlayers {
            while s.playerNames.count < Self.minPlayers {
                s.playerNames.append("プレイヤー\(s.playerNames.count + 1)")
            }
        } else if s.playerNames.count > Self.maxPlayers {
            s.playerNames = Array(s.playerNames.prefix(Self.maxPlayers))
        }
        // 空名を補完。
        s.playerNames = s.playerNames.enumerated().map { index, name in
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? "プレイヤー\(index + 1)" : trimmed
        }
        s.minLength = max(1, min(s.minLength, 10))
        s.maxLength = max(s.minLength, min(s.maxLength, 12))
        s.turnTimeLimit = max(0, min(s.turnTimeLimit, 120))
        return s
    }

    // MARK: - 永続化

    private static let storageKey = "GameSettings.v1"

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    static func load() -> GameSettings {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(GameSettings.self, from: data)
        else {
            return .default
        }
        return decoded.sanitized()
    }
}

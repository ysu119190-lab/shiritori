import Foundation

/// アプリ内かなキーボードの種類。
enum KanaKeyboardStyle: String, Codable, CaseIterable {
    case flick   // フリック入力
    case grid    // 50音タップ
}

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

    /// 辞書に無い語を、日本語 Wikipedia でも判定するか。
    /// オンにするとキャラクター名・固有名詞なども、記事があれば実在扱いになる。
    var useWebSearch: Bool

    /// 濁音・半濁音を区別せずにつなぐか（例: 「か」の後に「が」から始まる語を許可）。
    var ignoreDakuten: Bool

    /// 1手ごとの制限時間（秒）。0 のときは無制限。
    var turnTimeLimit: Int

    /// 辞書に無い単語でも、参加者が認めれば続行できるようにするか。
    var allowChallengeOverride: Bool

    /// ラリー（手番）ごとにお題の文字数を 1〜9 文字でランダムに決めるモード。
    /// オンのときは minLength / maxLength ではなく「ちょうどN文字」で判定する。
    var isRandomLengthMode: Bool

    /// アプリ内のかなキーボードで入力するか（システムIMEの予測変換・変換候補を避ける）。
    var useKanaKeyboard: Bool

    /// アプリ内かなキーボードの種類（フリック / 50音タップ）。
    var kanaKeyboardStyle: KanaKeyboardStyle

    static let minPlayers = 2
    static let maxPlayers = 6

    /// ランダム文字数モードで使う文字数の範囲。
    /// 1文字は続けられる語がほぼ無く詰んでしまうため 2 文字から。
    static let randomLengthRange = 2...9

    static let `default` = GameSettings(
        playerNames: ["プレイヤー1", "プレイヤー2"],
        minLength: 2,
        isMaxLengthEnabled: false,
        maxLength: 6,
        checkExistence: true,
        useSystemDictionary: true,
        useWebSearch: true,
        ignoreDakuten: true,
        turnTimeLimit: 0,
        allowChallengeOverride: true,
        isRandomLengthMode: false,
        useKanaKeyboard: true,
        kanaKeyboardStyle: .flick
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

    // v2: かなキーボードを既定オンにしたので、旧保存値（既定オフ）を引き継がず
    // 新しい既定から始める。プレイヤー名などは初回のみ再入力になる。
    private static let storageKey = "GameSettings.v2"

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

extension GameSettings {
    /// 後方互換のためのデコード。既存の保存データに新フィールドが無くても
    /// 既定値で補って読み込めるようにする（encode は自動合成をそのまま使う）。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        playerNames = try c.decode([String].self, forKey: .playerNames)
        minLength = try c.decode(Int.self, forKey: .minLength)
        isMaxLengthEnabled = try c.decode(Bool.self, forKey: .isMaxLengthEnabled)
        maxLength = try c.decode(Int.self, forKey: .maxLength)
        checkExistence = try c.decode(Bool.self, forKey: .checkExistence)
        useSystemDictionary = try c.decode(Bool.self, forKey: .useSystemDictionary)
        ignoreDakuten = try c.decode(Bool.self, forKey: .ignoreDakuten)
        // 既存の保存データに無い場合は既定オン（?? true）。
        useWebSearch = try c.decodeIfPresent(Bool.self, forKey: .useWebSearch) ?? true
        turnTimeLimit = try c.decode(Int.self, forKey: .turnTimeLimit)
        allowChallengeOverride = try c.decode(Bool.self, forKey: .allowChallengeOverride)
        // 新規フィールドは無い場合があるので decodeIfPresent で補完する。
        isRandomLengthMode = try c.decodeIfPresent(Bool.self, forKey: .isRandomLengthMode) ?? false
        useKanaKeyboard = try c.decodeIfPresent(Bool.self, forKey: .useKanaKeyboard) ?? false
        // フリック入力を既定にする。
        kanaKeyboardStyle = try c.decodeIfPresent(KanaKeyboardStyle.self, forKey: .kanaKeyboardStyle) ?? .flick
    }
}

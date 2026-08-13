import Foundation

/// Game Center のターン制対戦で、対戦データとしてやり取りするゲーム状態。
///
/// 近距離対戦（ホスト権威）と違い、こちらは**状態そのものを持ち回る**方式にする。
/// 自分の手番の端末だけが状態を書き換えて次の人へ渡すので、同時に書き換わることがない。
/// GameKit の matchData は 64KB まで。しりとりの履歴は十分小さく収まる。
struct OnlineMatchState: Codable, Equatable {

    /// 参加者の Game Center ID（手番の順）。
    var playerIDs: [String]
    /// 表示名（playerIDs と同じ並び）。
    var playerNames: [String]

    /// これまでの手。
    var history: [Move]
    /// 次に始めるべき音（Character は Codable ではないので String で持つ）。
    var requiredStartKana: String?
    /// ランダム文字数モードでの、この手番の指定文字数。
    var requiredLength: Int?

    /// 対戦のルール（作った人の設定を全員で共有する）。
    var rules: Rules

    /// 決着したか。
    var isFinished: Bool
    /// 負けた人の Game Center ID。
    var loserID: String?
    /// 決着理由。
    var resultMessage: String

    /// 対戦中に共有するルール。表示と判定に必要な範囲だけを持つ。
    struct Rules: Codable, Equatable {
        var minLength: Int
        var maxLength: Int?
        var isRandomLengthMode: Bool
        var randomLengthMin: Int
        var randomLengthMax: Int
        var ignoreDakuten: Bool
        var checkExistence: Bool

        init(from settings: GameSettings) {
            minLength = settings.minLength
            maxLength = settings.isMaxLengthEnabled ? settings.maxLength : nil
            isRandomLengthMode = settings.isRandomLengthMode
            randomLengthMin = settings.randomLengthMin
            randomLengthMax = settings.randomLengthMax
            ignoreDakuten = settings.ignoreDakuten
            checkExistence = settings.checkExistence
        }

        /// 受け取ったルールを、いまの設定へ反映する（表示と判定をそろえるため）。
        func apply(to settings: inout GameSettings) {
            settings.minLength = minLength
            settings.isMaxLengthEnabled = maxLength != nil
            if let maxLength { settings.maxLength = maxLength }
            settings.isRandomLengthMode = isRandomLengthMode
            settings.randomLengthMin = randomLengthMin
            settings.randomLengthMax = randomLengthMax
            settings.ignoreDakuten = ignoreDakuten
            settings.checkExistence = checkExistence
            // オンライン対戦では待ち時間が読めないので、ウェブ判定と参加者承認は使わない。
            settings.useWebSearch = false
            settings.allowChallengeOverride = false
            // 手番の制限時間は GameKit 側のターン期限に任せる。
            settings.turnTimeLimit = 0
            settings.isSoloMode = false
        }
    }

    /// プレイヤーが実際につないだ語数（アプリが出したお題は数えない）。
    var chainCount: Int { history.filter { !$0.isSeed }.count }

    /// 指定した Game Center ID のプレイヤー番号。
    func index(of playerID: String) -> Int? {
        playerIDs.firstIndex(of: playerID)
    }

    /// プレイヤーを登録して番号を返す。すでにいればその番号を返す。
    ///
    /// Game Center では、対戦を作った直後は相手がまだ参加しておらず ID が分からない。
    /// そのため「手番が回ってきた人から順に登録する」形にして、参加の順番に依存しないようにする。
    mutating func ensurePlayer(id: String, name: String) -> Int {
        if let existing = playerIDs.firstIndex(of: id) {
            // 表示名は新しいものに更新しておく。
            if playerNames.indices.contains(existing) {
                playerNames[existing] = name
            }
            return existing
        }
        playerIDs.append(id)
        playerNames.append(name)
        return playerIDs.count - 1
    }

    /// プレイヤー番号から表示名を引く。
    func name(at index: Int) -> String {
        playerNames.indices.contains(index) ? playerNames[index] : "あいて"
    }

    // MARK: - 受け渡し

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func decode(_ data: Data) -> OnlineMatchState? {
        guard !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(OnlineMatchState.self, from: data)
    }
}

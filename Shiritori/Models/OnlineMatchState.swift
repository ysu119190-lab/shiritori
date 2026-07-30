import Foundation

/// オンライン対戦で相手と受け渡すゲーム状態。
///
/// `GKTurnBasedMatch.matchData` に JSON で載せる。Game Center が対局データを
/// 預かってくれるので、こちらでサーバーを持つ必要はない。
///
/// 中断保存（`SavedGame`）とほぼ同じ内容だが、こちらは
/// 「相手に渡すもの」なので端末固有の値（残り時間など）は持たない。
struct OnlineMatchState: Codable, Equatable {

    /// オンライン対戦の人数（Phase 1 は2人固定）。
    static let playerCount = 2

    /// 保存形式のバージョン。将来フィールドを増やしたときの互換判定に使う。
    static let currentVersion = 1

    var version: Int
    var settings: GameSettings
    var history: [Move]
    /// いま手番の席番号（0 または 1）。`GKTurnBasedMatch.participants` の並び順に対応する。
    var currentSeat: Int
    /// 次に始めるべき音（Character は Codable ではないので String で持つ）。
    var requiredStartKana: String?
    var requiredLength: Int?
    /// 決着していれば負けた席。進行中は nil。
    var loserSeat: Int?
    /// 決着理由の説明。
    var resultMessage: String

    init(
        version: Int = OnlineMatchState.currentVersion,
        settings: GameSettings,
        history: [Move],
        currentSeat: Int,
        requiredStartKana: String? = nil,
        requiredLength: Int? = nil,
        loserSeat: Int? = nil,
        resultMessage: String = ""
    ) {
        self.version = version
        self.settings = settings
        self.history = history
        self.currentSeat = currentSeat
        self.requiredStartKana = requiredStartKana
        self.requiredLength = requiredLength
        self.loserSeat = loserSeat
        self.resultMessage = resultMessage
    }

    /// プレイヤーが実際につないだ語数（お題の語は含めない）。
    var chainCount: Int { history.filter { !$0.isSeed }.count }

    /// 決着済みか。
    var isFinished: Bool { loserSeat != nil }

    // MARK: - matchData との変換

    /// `matchData` に載せる形へ書き出す。
    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// `matchData` から読み込む。新規対局では空なので nil を返す。
    static func decode(from data: Data?) -> OnlineMatchState? {
        guard let data, !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(OnlineMatchState.self, from: data)
    }
}

extension GameSettings {

    /// オンライン対戦向けにルールをそろえる。
    ///
    /// 同一端末前提の機能や、端末ごとに結果が変わる判定を落とす。
    /// - 端末の国語辞書：どの辞書を入れているかで結果が変わり不公平になるので使わない。
    /// - 参加者承認：相手に口頭で確認できないので使わない。
    /// - 制限時間：非同期対戦なので秒単位の制限は意味がない（Game Center 側の
    ///   ターン制限を使う）。
    ///
    /// なお Wikipedia 判定は残す。履歴に載った語は相手側で再判定しないため、
    /// 判定するのは常に「その語を出した本人の端末」で一貫している。
    func onlineSanitized() -> GameSettings {
        var s = sanitized()
        s.playerNames = Array(s.playerNames.prefix(OnlineMatchState.playerCount))
        s.checkExistence = true
        s.useSystemDictionary = false
        s.allowChallengeOverride = false
        s.turnTimeLimit = 0
        return s
    }
}

import Foundation

/// 近くの端末と対戦するときの、ゲーム状態のスナップショット。
/// ホストが自分の状態をそのまま送り、ゲストはこれを表示するだけにする
/// （＝ホスト権威。判定はホスト側だけで行い、食い違いが起きないようにする）。
struct GameSnapshot: Codable, Equatable {
    var playerNames: [String]
    var history: [Move]
    var currentPlayerIndex: Int
    /// 次に始めるべき音（Character は Codable ではないので String で持つ）。
    var requiredStartKana: String?
    var requiredLength: Int?
    var remainingTime: Int
    var isFinished: Bool
    var loserIndex: Int?
    var resultMessage: String
    /// ゲストが自分の手番かどうかを判断するための、ゲストのプレイヤー番号。
    var guestPlayerIndex: Int
    /// 表示に必要な範囲のルール設定。
    var minLength: Int
    var maxLength: Int?
    var isTimed: Bool
}

/// 端末間でやり取りするメッセージ。
enum PeerMessage: Codable {
    /// ゲスト → ホスト: 参加時に自分の表示名を伝える。
    case hello(name: String)
    /// ホスト → ゲスト: 現在のゲーム状態。
    case snapshot(GameSnapshot)
    /// ゲスト → ホスト: この単語で打ちたい。
    case submit(word: String)
    /// ホスト → ゲスト: その単語は使えない（理由つき）。
    case rejected(reason: String)
    /// ゲスト → ホスト: 降参する。
    case giveUp
    /// どちらか → 相手: 対戦を終了して切断する。
    case quit

    // MARK: - エンコード

    private enum Kind: String, Codable {
        case hello, snapshot, submit, rejected, giveUp, quit
    }

    private enum CodingKeys: String, CodingKey {
        case kind, name, snapshot, word, reason
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .hello(let name):
            try c.encode(Kind.hello, forKey: .kind)
            try c.encode(name, forKey: .name)
        case .snapshot(let snapshot):
            try c.encode(Kind.snapshot, forKey: .kind)
            try c.encode(snapshot, forKey: .snapshot)
        case .submit(let word):
            try c.encode(Kind.submit, forKey: .kind)
            try c.encode(word, forKey: .word)
        case .rejected(let reason):
            try c.encode(Kind.rejected, forKey: .kind)
            try c.encode(reason, forKey: .reason)
        case .giveUp:
            try c.encode(Kind.giveUp, forKey: .kind)
        case .quit:
            try c.encode(Kind.quit, forKey: .kind)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .hello:
            self = .hello(name: try c.decode(String.self, forKey: .name))
        case .snapshot:
            self = .snapshot(try c.decode(GameSnapshot.self, forKey: .snapshot))
        case .submit:
            self = .submit(word: try c.decode(String.self, forKey: .word))
        case .rejected:
            self = .rejected(reason: try c.decode(String.self, forKey: .reason))
        case .giveUp:
            self = .giveUp
        case .quit:
            self = .quit
        }
    }
}

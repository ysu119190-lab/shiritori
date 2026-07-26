import Foundation

/// 日本語 Wikipedia を使って「その読みの語が実在するか」を非同期で判定する。
///
/// 同梱辞書・端末辞書に無い語（キャラクター名・固有名詞など）でも、
/// Wikipedia に記事が見つかれば「名詞として実在する」とみなす。
/// - 通信は HTTPS のみ。失敗・タイムアウト時は false（＝実在扱いしない）で安全側に倒す。
final class WebValidator {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// 読み（ひらがな）に対応する記事が Wikipedia に存在すれば true。
    ///
    /// 全文検索だと無関係な語もほぼ必ずヒットしてしまうため、
    /// 「記事タイトルの完全一致（リダイレクト解決込み）」で判定する。
    /// 読みのひらがな表記とカタカナ表記の両方を候補にすることで、
    /// カタカナ表記のキャラクター名・固有名詞（例:「ぴかちゅう」→「ピカチュウ」）も拾える。
    func exists(_ reading: String) async -> Bool {
        let hiragana = reading.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hiragana.isEmpty else { return false }

        // 完全一致の候補（ひらがな／カタカナ）。同じなら1つだけ。
        let katakana = KanaUtils.toKatakana(hiragana)
        let titles = (katakana == hiragana) ? hiragana : "\(hiragana)|\(katakana)"

        guard var comps = URLComponents(string: "https://ja.wikipedia.org/w/api.php") else {
            return false
        }
        comps.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "titles", value: titles),
            URLQueryItem(name: "redirects", value: "1"),
            URLQueryItem(name: "formatversion", value: "2"),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = comps.url else { return false }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        // Wikipedia API のマナーとして User-Agent を明示する。
        request.setValue("Shiritori-iOS/1.0 (shiritori game app)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return false }
            let decoded = try JSONDecoder().decode(TitlesResponse.self, from: data)
            // 実在するページ（missing でなく pageid を持つ）が1つでもあれば実在とみなす。
            return decoded.query?.pages.contains { $0.missing != true && $0.pageid != nil } ?? false
        } catch {
            return false
        }
    }

    // MARK: - レスポンス（formatversion=2）

    private struct TitlesResponse: Decodable {
        struct Query: Decodable {
            let pages: [Page]
        }
        struct Page: Decodable {
            let pageid: Int?
            let missing: Bool?
        }
        let query: Query?
    }
}

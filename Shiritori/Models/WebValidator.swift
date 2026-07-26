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

    /// 読み（ひらがな）で Wikipedia を全文検索し、ヒットすれば true。
    func exists(_ reading: String) async -> Bool {
        let trimmed = reading.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        guard var comps = URLComponents(string: "https://ja.wikipedia.org/w/api.php") else {
            return false
        }
        comps.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "list", value: "search"),
            URLQueryItem(name: "srsearch", value: trimmed),
            URLQueryItem(name: "srlimit", value: "1"),
            URLQueryItem(name: "srinfo", value: "totalhits"),
            URLQueryItem(name: "srprop", value: ""),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "utf8", value: "1"),
        ]
        guard let url = comps.url else { return false }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        // Wikipedia API のマナーとして User-Agent を明示する。
        request.setValue("Shiritori-iOS/1.0 (shiritori game app)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return false }
            let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
            return decoded.query.searchinfo.totalhits > 0
        } catch {
            return false
        }
    }

    // MARK: - レスポンス

    private struct SearchResponse: Decodable {
        struct Query: Decodable {
            struct SearchInfo: Decodable {
                let totalhits: Int
            }
            let searchinfo: SearchInfo
        }
        let query: Query
    }
}

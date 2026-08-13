import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// 単語が実在するかを判定する。
/// 1. アプリに同梱したひらがな辞書（words.txt ＋ words-large.txt）
/// 2. iOS標準の国語辞書（`UIReferenceLibraryViewController.dictionaryHasDefinition`）
/// の2段構えで判定する。
///
/// 同梱辞書は2層に分かれている:
/// - words.txt … 厳選版（約1,200語）。**出題・ヒントにも使う**ので、子どもにも
///   見せられる分かりやすい語だけを収録する。
/// - words-large.txt … 検証用の拡張辞書（mecab-ipadic の名詞・約45,000語）。
///   **実在判定にのみ**使い、出題・ヒントには使わない（難語・専門語を含むため）。
final class WordValidator {

    /// 厳選辞書（出題・ヒント・判定に使う）。
    private let curatedDictionary: Set<String>

    /// 検証用の拡張辞書（判定にのみ使う）。
    private let extendedDictionary: Set<String>

    /// 端末の国語辞書も利用するか。
    var useSystemDictionary: Bool

    /// 開始音（濁点を清音へ寄せたキー）ごとの収録語数。
    /// 「その音から始められる語がどれだけ残っているか」の目安として、CPUの戦略に使う。
    private let startKanaCounts: [Character: Int]

    init(useSystemDictionary: Bool = true) {
        let curated = WordValidator.loadWordList(named: "words")
        let extended = WordValidator.loadWordList(named: "words-large")
        self.curatedDictionary = curated
        self.extendedDictionary = extended
        self.useSystemDictionary = useSystemDictionary

        var counts: [Character: Int] = [:]
        for word in curated.union(extended) {
            guard let first = KanaUtils.startKana(of: word) else { continue }
            counts[KanaUtils.matchKey(first, ignoreDakuten: true), default: 0] += 1
        }
        self.startKanaCounts = counts
    }

    /// 指定した音から始められる語のおおよその数（濁点は区別しない）。
    func wordCount(startingWith kana: Character) -> Int {
        startKanaCounts[KanaUtils.matchKey(kana, ignoreDakuten: true)] ?? 0
    }

    /// 同梱辞書の収録語数（設定画面などで表示する用）。厳選＋拡張の合計。
    var bundledWordCount: Int { curatedDictionary.count + extendedDictionary.count }

    /// ゲーム開始時に出題する最初の単語をランダムに選ぶ（厳選辞書から）。
    /// 「ん」で終わる語や、次につなげられない語は除く。
    func randomStartWord() -> String? {
        let candidates = curatedDictionary.filter { word in
            let count = word.count
            guard count >= 2, count <= 5 else { return false }
            guard !KanaUtils.endsWithN(word) else { return false }
            // 次の音が取り出せない語（記号だけ等）は除外。
            return KanaUtils.connectingKana(of: word) != nil
        }
        return candidates.randomElement()
    }

    /// ヒント用に、条件を満たす単語を厳選辞書から1つ選ぶ。
    /// - Parameters:
    ///   - startKana: この音から始まること。
    ///   - ignoreDakuten: 濁点を区別せずにつなぐか。
    ///   - exactLength: ちょうどこの文字数（ランダム文字数モード）。nil なら min/max で判定。
    ///   - used: すでに使われた語（除外する）。
    func hintWord(
        startKana: Character,
        ignoreDakuten: Bool,
        exactLength: Int?,
        minLength: Int,
        maxLength: Int?,
        used: Set<String>
    ) -> String? {
        let required = KanaUtils.matchKey(startKana, ignoreDakuten: ignoreDakuten)
        let candidates = curatedDictionary.filter { word in
            guard !used.contains(word) else { return false }
            guard !KanaUtils.endsWithN(word) else { return false }
            guard let first = KanaUtils.startKana(of: word) else { return false }
            guard KanaUtils.matchKey(first, ignoreDakuten: ignoreDakuten) == required else { return false }
            let count = word.count
            if let exact = exactLength {
                return count == exact
            }
            if count < minLength { return false }
            if let maxLength, count > maxLength { return false }
            return true
        }
        return candidates.randomElement()
    }

    /// CPUの手の候補となる語を抽出する。
    /// - Parameters:
    ///   - startKanas: このいずれかの音から始まる語（長音終わりの母音接続に対応するため複数）。
    ///   - includeExtended: 拡張辞書も候補に含めるか（よわいCPUは厳選辞書だけ＝やさしい語だけ）。
    func candidateWords(
        startKanas: [Character],
        ignoreDakuten: Bool,
        exactLength: Int?,
        minLength: Int,
        maxLength: Int?,
        used: Set<String>,
        includeExtended: Bool
    ) -> [String] {
        let requiredKeys = Set(startKanas.map { KanaUtils.matchKey($0, ignoreDakuten: ignoreDakuten) })
        let pool = includeExtended ? curatedDictionary.union(extendedDictionary) : curatedDictionary
        return pool.filter { word in
            guard !used.contains(word) else { return false }
            guard let first = KanaUtils.startKana(of: word) else { return false }
            guard requiredKeys.contains(KanaUtils.matchKey(first, ignoreDakuten: ignoreDakuten)) else { return false }
            let count = word.count
            if let exact = exactLength {
                return count == exact
            }
            if count < minLength { return false }
            if let maxLength, count > maxLength { return false }
            return true
        }
    }

    /// 指定した読み（ひらがな）が実在するか。
    func exists(_ hiraganaReading: String) -> Bool {
        if curatedDictionary.contains(hiraganaReading) || extendedDictionary.contains(hiraganaReading) {
            return true
        }
        if useSystemDictionary, WordValidator.systemHasDefinition(for: hiraganaReading) {
            return true
        }
        return false
    }

    // MARK: - 同梱辞書の読み込み

    private static func loadWordList(named name: String) -> Set<String> {
        guard
            let url = Bundle.main.url(forResource: name, withExtension: "txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return []
        }
        var set = Set<String>()
        text.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return }
            set.insert(KanaUtils.toHiragana(trimmed))
        }
        return set
    }

    // MARK: - 端末辞書

    /// 端末にインストールされている国語辞書に定義があるか。
    /// 辞書アセットが未ダウンロードの端末では常に false になる場合があるため、
    /// 同梱辞書のフォールバックと併用する。
    static func systemHasDefinition(for term: String) -> Bool {
        #if canImport(UIKit)
        // このAPIはメインスレッドから呼ぶ必要がある。
        if Thread.isMainThread {
            return UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: term)
        } else {
            return DispatchQueue.main.sync {
                UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: term)
            }
        }
        #else
        return false
        #endif
    }
}

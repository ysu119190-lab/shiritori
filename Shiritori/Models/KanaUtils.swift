import Foundation

/// かな文字にまつわる正規化・しりとり判定のためのユーティリティ。
enum KanaUtils {

    // MARK: - 正規化

    /// カタカナをひらがなに変換する（ぁ-ゖ の範囲へマッピング）。
    static func toHiragana(_ s: String) -> String {
        var result = ""
        result.unicodeScalars.reserveCapacity(s.unicodeScalars.count)
        for scalar in s.unicodeScalars {
            let v = scalar.value
            // カタカナ (0x30A1...0x30F6) → ひらがな (-0x60)
            if v >= 0x30A1 && v <= 0x30F6, let converted = Unicode.Scalar(v - 0x60) {
                result.unicodeScalars.append(converted)
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    /// ひらがなをカタカナに変換する（ぁ-ゖ の範囲を +0x60 でマッピング）。長音符などはそのまま。
    static func toKatakana(_ s: String) -> String {
        var result = ""
        result.unicodeScalars.reserveCapacity(s.unicodeScalars.count)
        for scalar in s.unicodeScalars {
            let v = scalar.value
            // ひらがな (0x3041...0x3096) → カタカナ (+0x60)
            if v >= 0x3041 && v <= 0x3096, let converted = Unicode.Scalar(v + 0x60) {
                result.unicodeScalars.append(converted)
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    /// 前後の空白を除去し、カタカナをひらがなへそろえた「読み」を返す。
    static func normalize(_ s: String) -> String {
        toHiragana(s.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// ひらがな・長音符「ー」だけで構成されているか。
    static func isAllKana(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        for scalar in s.unicodeScalars {
            let v = scalar.value
            let isHiragana = (v >= 0x3041 && v <= 0x3096) // ぁ-ゖ
            let isProlonged = (v == 0x30FC)               // ー
            if !(isHiragana || isProlonged) { return false }
        }
        return true
    }

    // MARK: - 変換テーブル

    /// 小書き文字 → 大文字への対応。
    static let smallToLarge: [Character: Character] = [
        "ぁ": "あ", "ぃ": "い", "ぅ": "う", "ぇ": "え", "ぉ": "お",
        "ゃ": "や", "ゅ": "ゆ", "ょ": "よ", "ゎ": "わ",
        "っ": "つ", "ゕ": "か", "ゖ": "け"
    ]

    /// 各かなの母音（あ行の代表文字）を返すためのマップ。
    /// 長音「ー」で終わる語を、母音でもつなげられるようにする際に使う（`connectingKanaOptions`）。
    static let vowelMap: [Character: Character] = {
        var map: [Character: Character] = [:]
        let rows: [(Character, String)] = [
            ("あ", "あかさたなはまやらわがざだばぱぁゃゎ"),
            ("い", "いきしちにひみりぎじぢびぴぃ"),
            ("う", "うくすつぬふむゆるぐずづぶぷぅゅっ"),
            ("え", "えけせてねへめれげぜでべぺぇ"),
            ("お", "おこそとのほもよろをごぞどぼぽぉょ")
        ]
        for (vowel, chars) in rows {
            for c in chars { map[c] = vowel }
        }
        return map
    }()

    /// 「小゛゜」キー用：直前の文字を 濁点→半濁点→小書き … と循環させる表。
    /// アプリ内キーボード（50音タップ・フリック）で共用する。
    static let modifierCycle: [Character: Character] = [
        "あ": "ぁ", "ぁ": "あ",
        "い": "ぃ", "ぃ": "い",
        "う": "ぅ", "ぅ": "ゔ", "ゔ": "う",
        "え": "ぇ", "ぇ": "え",
        "お": "ぉ", "ぉ": "お",
        "か": "が", "が": "か",
        "き": "ぎ", "ぎ": "き",
        "く": "ぐ", "ぐ": "く",
        "け": "げ", "げ": "け",
        "こ": "ご", "ご": "こ",
        "さ": "ざ", "ざ": "さ",
        "し": "じ", "じ": "し",
        "す": "ず", "ず": "す",
        "せ": "ぜ", "ぜ": "せ",
        "そ": "ぞ", "ぞ": "そ",
        "た": "だ", "だ": "た",
        "ち": "ぢ", "ぢ": "ち",
        "つ": "っ", "っ": "づ", "づ": "つ",
        "て": "で", "で": "て",
        "と": "ど", "ど": "と",
        "は": "ば", "ば": "ぱ", "ぱ": "は",
        "ひ": "び", "び": "ぴ", "ぴ": "ひ",
        "ふ": "ぶ", "ぶ": "ぷ", "ぷ": "ふ",
        "へ": "べ", "べ": "ぺ", "ぺ": "へ",
        "ほ": "ぼ", "ぼ": "ぽ", "ぽ": "ほ",
        "や": "ゃ", "ゃ": "や",
        "ゆ": "ゅ", "ゅ": "ゆ",
        "よ": "ょ", "ょ": "よ",
        "わ": "ゎ", "ゎ": "わ",
    ]

    /// 濁音・半濁音を清音へ戻すマップ（濁点を区別しないマッチ用）。
    static let dakutenBase: [Character: Character] = [
        "が": "か", "ぎ": "き", "ぐ": "く", "げ": "け", "ご": "こ",
        "ざ": "さ", "じ": "し", "ず": "す", "ぜ": "せ", "ぞ": "そ",
        "だ": "た", "ぢ": "ち", "づ": "つ", "で": "て", "ど": "と",
        "ば": "は", "び": "ひ", "ぶ": "ふ", "べ": "へ", "ぼ": "ほ",
        "ぱ": "は", "ぴ": "ひ", "ぷ": "ふ", "ぺ": "へ", "ぽ": "ほ"
    ]

    // MARK: - しりとり判定

    /// 単語の「最初の音」。次の単語がここから始まっていなければならない基準。
    /// 小書き文字は大文字へ寄せる。
    static func startKana(of word: String) -> Character? {
        guard let first = word.first else { return nil }
        return smallToLarge[first] ?? first
    }

    /// 単語の末尾が「ん」で終わるか（＝しりとりで負け）。
    static func endsWithN(_ word: String) -> Bool {
        word.last == "ん"
    }

    /// 次の単語がつながるべき「基準の音」を1つ返す。
    /// - 末尾の長音「ー」（および「〜」「～」）はスキップし、その手前の音を採用する
    ///   （例:「コーヒー」→「ひ」、「スキー」→「き」）。
    /// - 小書き文字は大文字へ寄せる（例:「しゃ」→「や」）。
    ///
    /// なお、長音終わりのときに母音でもつなげてよいかどうかは `connectingKanaOptions` が扱う。
    static func connectingKana(of word: String) -> Character? {
        let chars = Array(word)
        guard !chars.isEmpty else { return nil }

        var index = chars.count - 1
        // 末尾の長音符をたどって、手前の実音まで戻る。
        while index >= 0 {
            let c = chars[index]
            if c == "ー" || c == "〜" || c == "～" {
                index -= 1
                continue
            }
            // 小書き文字は大文字へ寄せる。
            let normalized = smallToLarge[c] ?? c
            return normalized
        }
        return nil
    }

    /// つなげてよい開始音の候補を返す。
    /// 通常は `connectingKana` と同じ1音のみ。ただし語が長音「ー」で終わっている場合は、
    /// 直前のかな（例:「コーヒー」→「ひ」）に加えて、その母音（「い」）でもつなげられるようにする。
    /// 「長音は母音とみなす」流派にも配慮し、どちらの音から始めても受理する。
    static func connectingKanaOptions(of word: String) -> [Character] {
        guard let base = connectingKana(of: word) else { return [] }
        guard endsWithProlongedMark(word),
              let vowel = vowelMap[base], vowel != base
        else {
            return [base]
        }
        return [base, vowel]
    }

    /// 語が長音符（ー・〜・～）で終わっているか。
    static func endsWithProlongedMark(_ word: String) -> Bool {
        guard let last = word.last else { return false }
        return last == "ー" || last == "〜" || last == "～"
    }

    /// マッチ判定に使うキーへ変換する。濁点無視オプションが有効なら清音へ寄せる。
    static func matchKey(_ c: Character, ignoreDakuten: Bool) -> Character {
        guard ignoreDakuten else { return c }
        return dakutenBase[c] ?? c
    }

    /// 2つの音がしりとりとしてつながるか。
    static func connects(previousEnd: Character, nextStart: Character, ignoreDakuten: Bool) -> Bool {
        matchKey(previousEnd, ignoreDakuten: ignoreDakuten) == matchKey(nextStart, ignoreDakuten: ignoreDakuten)
    }

    /// 表示用に「〜から始まる」を分かりやすくする（長音などを丸めた1文字）。
    static func displayKana(_ c: Character) -> String {
        String(c)
    }
}

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

    /// 各かなの母音（あ行の代表文字）を返すためのマップ。長音「ー」の直前の音を求める際に使う。
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

    /// 次の単語がつながるべき音を返す。
    /// - 長音「ー」で終わる場合は直前のかなの母音を採用。
    /// - 小書き文字で終わる場合は大文字へ寄せる（例: 「しゃ」→「や」）。
    static func connectingKana(of word: String) -> Character? {
        let chars = Array(word)
        guard !chars.isEmpty else { return nil }

        var index = chars.count - 1
        // 末尾の長音符をたどって、母音を採用する音を探す。
        while index >= 0 {
            let c = chars[index]
            if c == "ー" || c == "〜" || c == "～" {
                index -= 1
                continue
            }
            // 小書き文字は大文字へ寄せてから母音判定にも使えるようにする。
            let normalized = smallToLarge[c] ?? c
            return normalized
        }
        return nil
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

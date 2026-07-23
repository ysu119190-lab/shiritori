import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// 単語が実在するかを判定する。
/// 1. アプリに同梱したひらがな辞書（words.txt）
/// 2. iOS標準の国語辞書（`UIReferenceLibraryViewController.dictionaryHasDefinition`）
/// の2段構えで判定する。
final class WordValidator {

    /// 同梱辞書（ひらがなに正規化済み）。
    private let bundledDictionary: Set<String>

    /// 端末の国語辞書も利用するか。
    var useSystemDictionary: Bool

    init(useSystemDictionary: Bool = true) {
        self.bundledDictionary = WordValidator.loadBundledDictionary()
        self.useSystemDictionary = useSystemDictionary
    }

    /// 同梱辞書の収録語数（設定画面などで表示する用）。
    var bundledWordCount: Int { bundledDictionary.count }

    /// 指定した読み（ひらがな）が実在するか。
    func exists(_ hiraganaReading: String) -> Bool {
        if bundledDictionary.contains(hiraganaReading) {
            return true
        }
        if useSystemDictionary, WordValidator.systemHasDefinition(for: hiraganaReading) {
            return true
        }
        return false
    }

    // MARK: - 同梱辞書の読み込み

    private static func loadBundledDictionary() -> Set<String> {
        guard
            let url = Bundle.main.url(forResource: "words", withExtension: "txt"),
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

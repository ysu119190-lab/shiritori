import Foundation

#if DEBUG

/// ストア用スクリーンショットで撮りたい画面。
enum ScreenshotScene: String, CaseIterable {
    case setup      // 設定画面（あそびかたの4択が見える）
    case solo       // 設定画面（ひとりで＝戦績が見える）
    case game       // 対戦画面（履歴つき）
    case keyboard   // 対戦画面（かなキーボードで入力中）
    case nearby     // 近くの人と対戦のロビー
    case help       // あそびかたの説明
    case result     // 結果画面
}

/// ストア用スクリーンショットを自動で撮るための仕込み。
///
/// 起動引数 `-screenshotScene <名前>` が渡されたときだけ有効になり、
/// 決まった内容の画面を再現する。毎回同じ絵が撮れるので、CI で自動化できる。
///
/// **Debug ビルドにしか存在しない**（`#if DEBUG`）。リリース版には一切含まれない。
enum ScreenshotMode {

    /// 起動引数で指定された画面。指定が無ければ nil（＝通常起動）。
    static let scene: ScreenshotScene? = {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-screenshotScene"),
              index + 1 < args.count else { return nil }
        return ScreenshotScene(rawValue: args[index + 1])
    }()

    /// スクリーンショット撮影中か。スプラッシュや広告を出さないための判定に使う。
    static var isActive: Bool { scene != nil }

    /// 見栄えのする内容にそろえた設定。
    static func demoSettings() -> GameSettings {
        var settings = GameSettings.default
        settings.playerNames = ["さくら", "ゆうと"]
        settings.checkExistence = true
        settings.useWebSearch = false      // 撮影中に通信しない
        settings.useKanaKeyboard = true
        settings.kanaKeyboardStyle = .flick
        settings.turnTimeLimit = 30
        return settings
    }

    /// 対戦画面に出す、お題（先頭）とそれに続く手。
    /// 判定を通さずそのまま並べるので、辞書の中身に左右されず毎回同じ絵になる。
    static let demoSeed = "りんご"
    static let demoMoves = ["ごりら", "らっぱ", "ぱんだ", "だんご"]

    /// かなキーボードの画面で、入力途中に見せる文字。
    static let demoTypingInput = "ごま"
}

#endif

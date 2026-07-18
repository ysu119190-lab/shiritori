import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// 触覚フィードバックの薄いラッパー。
enum Haptics {

    /// 単語が受理されたとき。
    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// ルール違反などで却下されたとき。
    static func error() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }

    /// 決着（勝負あり）のとき。
    static func gameOver() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    /// 軽いタップ感（ボタンなど）。
    static func tap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

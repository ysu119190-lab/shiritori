import SwiftUI

/// アプリ内のかなキーボード。
///
/// システムの日本語IMEを使わずに 50音をタップで入力するため、
/// 予測変換・変換候補バーが一切出ない。しりとりで手が読まれてしまうのを防ぐ。
struct KanaKeyboard: View {

    /// 入力中のテキスト（ひらがな）。
    @Binding var text: String
    /// 送信ボタンが押されたとき。
    var onSubmit: () -> Void
    /// 送信を許可するか（空入力などのとき false）。
    var canSubmit: Bool

    /// キーの種類。
    private enum Key: Hashable {
        case char(String)   // その文字を挿入する
        case modifier       // 直前の文字を 濁点→半濁点→小書き … と切り替える
        case backspace      // 末尾を1文字削除
        case submit         // 送信
    }

    /// 50音の配列（段=あいうえお を列に、行を縦に並べる）。
    private static let rows: [[Key]] = [
        ["あ", "い", "う", "え", "お"].map(Key.char),
        ["か", "き", "く", "け", "こ"].map(Key.char),
        ["さ", "し", "す", "せ", "そ"].map(Key.char),
        ["た", "ち", "つ", "て", "と"].map(Key.char),
        ["な", "に", "ぬ", "ね", "の"].map(Key.char),
        ["は", "ひ", "ふ", "へ", "ほ"].map(Key.char),
        ["ま", "み", "む", "め", "も"].map(Key.char),
        [.char("や"), .char("ゆ"), .char("よ"), .char("ん"), .char("ー")],
        ["ら", "り", "る", "れ", "ろ"].map(Key.char),
        [.char("わ"), .char("を"), .modifier, .backspace, .submit],
    ]

    /// 直前の文字が切り替え可能か。
    private var canModify: Bool {
        guard let last = text.last else { return false }
        return KanaUtils.modifierCycle[last] != nil
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                        keyButton(key)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func keyButton(_ key: Key) -> some View {
        switch key {
        case .char(let s):
            Button {
                Haptics.tap()
                text.append(s)
            } label: {
                keyLabel(Text(s).font(.title3))
            }
            .buttonStyle(KanaKeyStyle())

        case .modifier:
            Button {
                Haptics.tap()
                applyModifier()
            } label: {
                keyLabel(Text("小゛゜").font(.callout))
            }
            .buttonStyle(KanaKeyStyle())
            .disabled(!canModify)

        case .backspace:
            Button {
                Haptics.tap()
                if !text.isEmpty { text.removeLast() }
            } label: {
                keyLabel(Image(systemName: "delete.left").font(.title3))
            }
            .buttonStyle(KanaKeyStyle())
            .disabled(text.isEmpty)

        case .submit:
            Button {
                onSubmit()
            } label: {
                keyLabel(Image(systemName: "paperplane.fill").font(.title3))
                    .foregroundStyle(.white)
            }
            .buttonStyle(KanaKeyStyle(kind: .submit))
            .disabled(!canSubmit)
        }
    }

    private func keyLabel<Content: View>(_ content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: 40)
    }

    /// 末尾の文字を濁点・半濁点・小書きへ切り替える。
    private func applyModifier() {
        guard let last = text.last, let next = KanaUtils.modifierCycle[last] else { return }
        text.removeLast()
        text.append(next)
    }
}

/// かなキーの見た目。
private struct KanaKeyStyle: ButtonStyle {
    enum Kind { case normal, submit }
    var kind: Kind = .normal

    func makeBody(configuration: Configuration) -> some View {
        let isSubmit = kind == .submit
        return configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(background(pressed: configuration.isPressed, isSubmit: isSubmit))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(isSubmit ? 0 : 0.08), lineWidth: 0.5)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }

    private func background(pressed: Bool, isSubmit: Bool) -> Color {
        if isSubmit {
            return pressed ? Color.accentColor.opacity(0.8) : Color.accentColor
        }
        return pressed ? Color.secondary.opacity(0.25) : Color.secondary.opacity(0.12)
    }
}

#Preview {
    struct Demo: View {
        @State private var text = "しり"
        var body: some View {
            VStack {
                Text(text.isEmpty ? "（入力）" : text)
                    .font(.largeTitle)
                    .frame(height: 60)
                KanaKeyboard(text: $text, onSubmit: {}, canSubmit: !text.isEmpty)
            }
        }
    }
    return Demo()
}

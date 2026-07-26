import SwiftUI

/// アプリ内のフリック入力キーボード。
///
/// システムの日本語IMEを使わずにフリックで入力するため、予測変換・変換候補が出ない。
/// 各キーは中央タップ＝あ段、左＝い段、上＝う段、右＝え段、下＝お段（iOS標準と同じ配置）。
struct FlickKeyboard: View {

    @Binding var text: String
    var onSubmit: () -> Void
    var canSubmit: Bool

    /// 1キーのフリック候補（中央＋上下左右）。
    private struct FlickSet {
        let center: String
        var left: String? = nil
        var up: String? = nil
        var right: String? = nil
        var down: String? = nil
    }

    /// あ〜ら行（3列×3段）。
    private static let kanaRows: [[FlickSet]] = [
        [
            FlickSet(center: "あ", left: "い", up: "う", right: "え", down: "お"),
            FlickSet(center: "か", left: "き", up: "く", right: "け", down: "こ"),
            FlickSet(center: "さ", left: "し", up: "す", right: "せ", down: "そ"),
        ],
        [
            FlickSet(center: "た", left: "ち", up: "つ", right: "て", down: "と"),
            FlickSet(center: "な", left: "に", up: "ぬ", right: "ね", down: "の"),
            FlickSet(center: "は", left: "ひ", up: "ふ", right: "へ", down: "ほ"),
        ],
        [
            FlickSet(center: "ま", left: "み", up: "む", right: "め", down: "も"),
            FlickSet(center: "や", up: "ゆ", down: "よ"),
            FlickSet(center: "ら", left: "り", up: "る", right: "れ", down: "ろ"),
        ],
    ]

    /// 最下段の「わ」キー（を・ん・長音符）。
    private static let waSet = FlickSet(center: "わ", left: "を", up: "ん", down: "ー")

    /// 直前の文字が「小゛゜」で切り替え可能か。
    private var canModify: Bool {
        guard let last = text.last else { return false }
        return KanaUtils.modifierCycle[last] != nil
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(Self.kanaRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, set in
                        FlickKey(set: set, onInput: input)
                    }
                }
            }

            HStack(spacing: 6) {
                functionKey(label: Text("小゛゜").font(.callout), enabled: canModify) {
                    applyModifier()
                }
                FlickKey(set: Self.waSet, onInput: input)
                functionKey(label: Image(systemName: "delete.left").font(.title3), enabled: !text.isEmpty) {
                    if !text.isEmpty { text.removeLast() }
                }
            }

            Button(action: onSubmit) {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor))
            }
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func input(_ s: String) {
        Haptics.tap()
        text.append(s)
    }

    private func applyModifier() {
        guard let last = text.last, let next = KanaUtils.modifierCycle[last] else { return }
        Haptics.tap()
        text.removeLast()
        text.append(next)
    }

    private func functionKey<Content: View>(label: Content, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    // MARK: - 1キー

    private struct FlickKey: View {
        let set: FlickSet
        let onInput: (String) -> Void

        @State private var preview: String?

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(preview != nil ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.12))
                Text(set.center)
                    .font(.title3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .overlay(alignment: .top) {
                if let preview {
                    Text(preview)
                        .font(.title.bold())
                        .frame(width: 52, height: 52)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor))
                        .foregroundStyle(.white)
                        .offset(y: -56)
                        .shadow(radius: 4)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        preview = kana(for: value.translation)
                    }
                    .onEnded { value in
                        onInput(kana(for: value.translation))
                        preview = nil
                    }
            )
        }

        /// ドラッグ量から入力するかなを決める。しきい値未満は中央（あ段）。
        private func kana(for t: CGSize) -> String {
            let threshold: CGFloat = 20
            if hypot(t.width, t.height) < threshold { return set.center }
            if abs(t.width) > abs(t.height) {
                return (t.width < 0 ? set.left : set.right) ?? set.center
            } else {
                return (t.height < 0 ? set.up : set.down) ?? set.center
            }
        }
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
                FlickKeyboard(text: $text, onSubmit: {}, canSubmit: !text.isEmpty)
            }
        }
    }
    return Demo()
}

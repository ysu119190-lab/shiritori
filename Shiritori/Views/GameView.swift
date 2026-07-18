import SwiftUI

/// 対戦中の画面。
struct GameView: View {
    @EnvironmentObject private var game: ShiritoriGame

    @State private var input: String = ""
    @State private var errorMessage: String?
    @State private var pendingReading: String?   // 実在確認待ちの語
    @State private var showGiveUpConfirm = false
    @FocusState private var inputFocused: Bool

    // 制限時間用タイマー（1秒間隔）。
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// プレイヤーごとの差し色。
    private static let playerColors: [Color] = [.pink, .blue, .green, .orange, .purple, .teal]

    private var playerColor: Color {
        Self.playerColors[game.currentPlayerIndex % Self.playerColors.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if game.isTimed { timerBar }
            Divider()
            historyList
            inputBar
        }
        .tint(playerColor)
        .onAppear { inputFocused = true }
        .onReceive(ticker) { _ in tick() }
        .alert("辞書に見つかりません", isPresented: existenceAlertBinding) {
            Button("認めて続行") { confirmExistence() }
            Button("取り消す", role: .cancel) { pendingReading = nil }
        } message: {
            Text("「\(pendingReading ?? "")」は辞書にありませんでした。参加者みんなが認めるなら続行できます。")
        }
        .confirmationDialog("降参しますか？", isPresented: $showGiveUpConfirm, titleVisibility: .visible) {
            Button("降参する", role: .destructive) { game.giveUp() }
            Button("やめる", role: .cancel) {}
        } message: {
            Text("\(game.currentPlayerName)さんの負けになります。")
        }
    }

    // MARK: - ヘッダー

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    Haptics.tap()
                    game.backToSetup()
                } label: {
                    Label("設定", systemImage: "gearshape")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
                Spacer()
                Text("\(game.history.count) 語")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                if game.isTimed {
                    timerBadge
                }
            }

            kanaBadge

            VStack(spacing: 2) {
                Text("\(game.currentPlayerName) さんの番")
                    .font(.title3.bold())
                    .foregroundStyle(playerColor)
                if let last = game.lastMove {
                    Text("前の単語：\(last.word)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    /// 次にどの音から始めるかを大きく見せるバッジ。
    private var kanaBadge: some View {
        VStack(spacing: 6) {
            if let required = game.requiredStartKana {
                ZStack {
                    Circle()
                        .fill(playerColor.opacity(0.15))
                    Circle()
                        .strokeBorder(playerColor.opacity(0.5), lineWidth: 3)
                    Text(KanaUtils.displayKana(required))
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(playerColor)
                }
                .frame(width: 120, height: 120)
                Text("この文字から始まる単語")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ZStack {
                    Circle().fill(playerColor.opacity(0.12))
                    Image(systemName: "sparkles")
                        .font(.system(size: 44))
                        .foregroundStyle(playerColor)
                }
                .frame(width: 120, height: 120)
                Text("最初の単語を自由に入力")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.spring(duration: 0.3), value: game.requiredStartKana)
    }

    private var timerBadge: some View {
        let low = game.remainingTime <= 5
        return Label("\(game.remainingTime)", systemImage: "timer")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(low ? Color.red : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(low ? Color.red.opacity(0.15) : Color.secondary.opacity(0.12))
            )
    }

    /// 残り時間のプログレスバー。
    private var timerBar: some View {
        let total = max(game.settings.turnTimeLimit, 1)
        let fraction = Double(game.remainingTime) / Double(total)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.secondary.opacity(0.12))
                Rectangle()
                    .fill(game.remainingTime <= 5 ? Color.red : playerColor)
                    .frame(width: geo.size.width * fraction)
                    .animation(.linear(duration: 0.3), value: game.remainingTime)
            }
        }
        .frame(height: 4)
    }

    // MARK: - 履歴

    private var historyList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if game.history.isEmpty {
                        Text("まだ単語がありません。\nしりとりを始めましょう！")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    }
                    ForEach(game.history) { move in
                        MoveRow(
                            move: move,
                            playerName: playerName(move.playerIndex),
                            color: Self.playerColors[move.playerIndex % Self.playerColors.count]
                        )
                        .id(move.id)
                    }
                    Color.clear.frame(height: 1).id(bottomAnchor)
                }
                .padding()
            }
            .onChange(of: game.history.count) { _, _ in
                withAnimation {
                    proxy.scrollTo(bottomAnchor, anchor: .bottom)
                }
            }
        }
    }

    private let bottomAnchor = "BOTTOM"

    private func playerName(_ index: Int) -> String {
        game.players.indices.contains(index) ? game.players[index] : ""
    }

    // MARK: - 入力バー

    private var inputBar: some View {
        VStack(spacing: 6) {
            HStack {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }
                Spacer()
                Text(charCountText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(charCountColor)
            }

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    Haptics.tap()
                    showGiveUpConfirm = true
                } label: {
                    Image(systemName: "flag.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)

                TextField("ひらがなで入力", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.send)
                    .focused($inputFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { attemptSubmit() }

                Button {
                    attemptSubmit()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .background(.bar)
    }

    /// 入力中の文字数と制限の表示。
    private var charCountText: String {
        let count = KanaUtils.normalize(input).count
        if game.settings.isMaxLengthEnabled {
            return "\(count) / \(game.settings.minLength)〜\(game.settings.maxLength)文字"
        } else {
            return "\(count) 文字（\(game.settings.minLength)文字以上）"
        }
    }

    private var charCountColor: Color {
        let count = KanaUtils.normalize(input).count
        guard count > 0 else { return .secondary }
        if count < game.settings.minLength { return .secondary }
        if game.settings.isMaxLengthEnabled && count > game.settings.maxLength { return .red }
        return .green
    }

    // MARK: - アクション

    private func attemptSubmit() {
        let result = game.submit(input)
        handle(result)
    }

    private func confirmExistence() {
        guard let reading = pendingReading else { return }
        pendingReading = nil
        let result = game.submit(reading, forceAcceptExistence: true)
        handle(result)
    }

    private func handle(_ result: SubmitResult) {
        switch result {
        case .accepted:
            Haptics.success()
            input = ""
            withAnimation { errorMessage = nil }
            inputFocused = true
        case .gameOverByN:
            // 決着ハプティクスは finish() 側で発火。
            input = ""
            withAnimation { errorMessage = nil }
        case .rejected(let reason):
            Haptics.error()
            withAnimation { errorMessage = reason }
        case .needsExistenceConfirmation(let reading):
            pendingReading = reading
        }
    }

    private func tick() {
        guard game.phase == .playing, game.isTimed else { return }
        if game.remainingTime > 0 {
            game.remainingTime -= 1
        }
        if game.remainingTime <= 0 {
            game.timeExpired()
        }
    }

    private var existenceAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingReading != nil },
            set: { if !$0 { pendingReading = nil } }
        )
    }
}

/// 履歴の1行。
private struct MoveRow: View {
    let move: Move
    let playerName: String
    let color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
            VStack(alignment: .leading, spacing: 2) {
                Text(move.word)
                    .font(.title3.bold())
                Text(playerName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if move.acceptedByChallenge {
                Label("承認", systemImage: "checkmark.seal")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
        )
    }
}

#Preview {
    GameView()
        .environmentObject({
            let g = ShiritoriGame()
            g.start()
            g.submit("りんご")
            return g
        }())
}

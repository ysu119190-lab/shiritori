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

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            historyList
            inputBar
        }
        .onAppear { inputFocused = true }
        .onReceive(ticker) { _ in tick() }
        .alert("辞書に見つかりません", isPresented: existenceAlertBinding) {
            Button("認めて続行", role: .none) { confirmExistence() }
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
        VStack(spacing: 8) {
            HStack {
                Button {
                    game.backToSetup()
                } label: {
                    Label("設定", systemImage: "gearshape")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
                Spacer()
                if game.isTimed {
                    timerBadge
                }
            }

            Text("\(game.currentPlayerName) さんの番")
                .font(.title2.bold())

            if let required = game.requiredStartKana {
                Text("「\(KanaUtils.displayKana(required))」から始まる単語")
                    .font(.headline)
                    .foregroundStyle(.tint)
            } else {
                Text("最初の単語を入力してください")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private var timerBadge: some View {
        let low = game.remainingTime <= 5
        return Label("\(game.remainingTime)", systemImage: "timer")
            .font(.headline.monospacedDigit())
            .foregroundStyle(low ? Color.red : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(low ? Color.red.opacity(0.15) : Color.secondary.opacity(0.12))
            )
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
                        MoveRow(move: move, playerName: playerName(move.playerIndex))
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
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
            HStack(spacing: 10) {
                Button(role: .destructive) {
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

    // MARK: - アクション

    private func attemptSubmit() {
        let text = input
        let result = game.submit(text)
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
        case .accepted, .gameOverByN:
            input = ""
            withAnimation { errorMessage = nil }
            inputFocused = true
        case .rejected(let reason):
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

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
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
                .fill(Color.secondary.opacity(0.08))
        )
    }
}

#Preview {
    GameView()
        .environmentObject({
            let g = ShiritoriGame()
            g.start()
            return g
        }())
}

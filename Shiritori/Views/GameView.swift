import SwiftUI

/// 対戦中の画面。
struct GameView: View {
    @EnvironmentObject private var game: ShiritoriGame

    @State private var input: String = ""
    @State private var errorMessage: String?
    @State private var pendingReading: String?   // 実在確認待ちの語
    @State private var showGiveUpConfirm = false
    @State private var burstID: Int?             // 受理時のキラッと演出のトリガー
    @State private var isChecking = false         // ウェブ（Wikipedia）確認中
    @State private var showExitOptions = false    // 中断メニュー
    @FocusState private var inputFocused: Bool

    // 制限時間用タイマー（1秒間隔）。
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var playerColor: Color {
        Theme.playerColor(game.currentPlayerIndex)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if game.isTimed { timerBar }
            Divider()
            historyList
            inputBar
        }
        .background(AppBackground())
        .overlay(alignment: .top) {
            if let id = burstID {
                SparkleBurst(color: playerColor)
                    .id(id)
                    .offset(y: 150)
                    .allowsHitTesting(false)
            }
        }
        .tint(playerColor)
        .onAppear {
            // かなキーボード使用時はシステムキーボードを出さない。
            if !game.settings.useKanaKeyboard { inputFocused = true }
        }
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
        .confirmationDialog("対戦を中断しますか？", isPresented: $showExitOptions, titleVisibility: .visible) {
            Button("中断して保存") {
                Haptics.success()
                game.suspendAndSave()
            }
            Button("保存せずに終了", role: .destructive) { game.backToSetup() }
            Button("対戦を続ける", role: .cancel) {}
        } message: {
            Text("「中断して保存」なら、設定画面から続きを再開できます。")
        }
    }

    // MARK: - ヘッダー

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    Haptics.tap()
                    showExitOptions = true
                } label: {
                    Label("中断", systemImage: "pause.circle")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                }
                Spacer()
                Text("\(game.chainCount) 語")
                    .font(Theme.rounded(15, weight: .bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                if game.isTimed {
                    timerBadge
                }
            }

            if let required = game.requiredLength {
                lengthBadge(required)
            }

            kanaBadge

            VStack(spacing: 3) {
                Text("\(game.currentPlayerName) さんの番")
                    .font(Theme.rounded(20, weight: .bold))
                    .foregroundStyle(playerColor)
                if let last = game.lastMove {
                    Text(last.isSeed ? "お題：\(last.word)" : "前の単語：\(last.word)")
                        .font(Theme.rounded(12))
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
                        .font(Theme.title(58))
                        .foregroundStyle(playerColor)
                }
                .frame(width: 120, height: 120)
                .shadow(color: playerColor.opacity(0.25), radius: 10, y: 4)
                Text("この文字から始まる単語")
                    .font(Theme.rounded(14))
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
                    .font(Theme.rounded(14))
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.spring(duration: 0.3), value: game.requiredStartKana)
    }

    /// ランダム文字数モードで、この手番のお題文字数を大きく見せるバッジ。
    private func lengthBadge(_ required: Int) -> some View {
        Label("ちょうど \(required) 文字", systemImage: "target")
            .font(.callout.bold())
            .foregroundStyle(playerColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(playerColor.opacity(0.15))
            )
            .overlay(
                Capsule().strokeBorder(playerColor.opacity(0.4), lineWidth: 1.5)
            )
            .contentTransition(.numericText())
            .animation(.spring(duration: 0.3), value: required)
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
                            color: move.isSeed ? Theme.seedColor : Theme.playerColor(move.playerIndex)
                        )
                        .id(move.id)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                    Color.clear.frame(height: 1).id(bottomAnchor)
                }
                .padding()
                .animation(.spring(duration: 0.35), value: game.history.count)
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
                if isChecking {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("確認中…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                } else if let errorMessage {
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

            if game.settings.useKanaKeyboard {
                kanaInputRow
            } else {
                systemInputRow
            }
        }
        .padding(game.settings.useKanaKeyboard ? .init(top: 8, leading: 8, bottom: 6, trailing: 8) : .init(top: 16, leading: 16, bottom: 16, trailing: 16))
        .background(.bar)
    }

    /// システムキーボード（TextField）を使う通常の入力行。
    private var systemInputRow: some View {
        HStack(spacing: 10) {
            giveUpButton

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
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isChecking)
        }
    }

    /// アプリ内かなキーボードを使う入力（予測変換が出ない）。
    private var kanaInputRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                giveUpButton
                kanaDisplayField
            }
            switch game.settings.kanaKeyboardStyle {
            case .flick:
                FlickKeyboard(
                    text: $input,
                    onSubmit: { attemptSubmit() },
                    canSubmit: !input.trimmingCharacters(in: .whitespaces).isEmpty && !isChecking
                )
            case .grid:
                KanaKeyboard(
                    text: $input,
                    onSubmit: { attemptSubmit() },
                    canSubmit: !input.trimmingCharacters(in: .whitespaces).isEmpty && !isChecking
                )
            }
        }
    }

    /// かなキーボード入力時の、入力中テキストの表示欄。
    private var kanaDisplayField: some View {
        HStack {
            if input.isEmpty {
                Text("ここに文字が入ります")
                    .foregroundStyle(.secondary)
            } else {
                Text(input)
                    .font(.title3)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(playerColor.opacity(0.4), lineWidth: 1)
        )
    }

    private var giveUpButton: some View {
        Button(role: .destructive) {
            Haptics.tap()
            showGiveUpConfirm = true
        } label: {
            Image(systemName: "flag.fill")
                .font(.title3)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.bordered)
    }

    /// 入力中の文字数と制限の表示。
    private var charCountText: String {
        let count = KanaUtils.normalize(input).count
        if let required = game.requiredLength {
            return "\(count) / ちょうど\(required)文字"
        }
        if game.settings.isMaxLengthEnabled {
            return "\(count) / \(game.settings.minLength)〜\(game.settings.maxLength)文字"
        } else {
            return "\(count) 文字（\(game.settings.minLength)文字以上）"
        }
    }

    private var charCountColor: Color {
        let count = KanaUtils.normalize(input).count
        guard count > 0 else { return .secondary }
        if let required = game.requiredLength {
            if count == required { return .green }
            if count > required { return .red }
            return .secondary
        }
        if count < game.settings.minLength { return .secondary }
        if game.settings.isMaxLengthEnabled && count > game.settings.maxLength { return .red }
        return .green
    }

    // MARK: - アクション

    private func attemptSubmit() {
        guard !isChecking else { return }
        let result = game.submit(input)
        if case .needsExistenceConfirmation(let reading) = result {
            resolveExistence(reading)
        } else {
            handle(result)
        }
    }

    /// ローカル辞書で見つからなかったとき、ウェブ判定→参加者承認の順に解決する。
    private func resolveExistence(_ reading: String) {
        guard game.isWebSearchEnabled else {
            fallbackAfterMiss(reading, webTried: false)
            return
        }
        isChecking = true
        withAnimation { errorMessage = nil }
        Task { @MainActor in
            let found = await game.webExists(reading)
            isChecking = false
            // 確認中に時間切れ等で決着していたら何もしない。
            guard game.phase == .playing else { return }
            if found {
                handle(game.submit(reading, forceAcceptExistence: true, acceptedViaWeb: true))
            } else {
                fallbackAfterMiss(reading, webTried: true)
            }
        }
    }

    /// 辞書・ウェブどちらでも見つからなかったときの後処理。
    private func fallbackAfterMiss(_ reading: String, webTried: Bool) {
        if game.settings.allowChallengeOverride {
            pendingReading = reading
        } else {
            let source = webTried ? "辞書・ウェブ" : "辞書"
            handle(.rejected(reason: "「\(reading)」は\(source)に見つかりませんでした"))
        }
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
            triggerAcceptEffect()
            if !game.settings.useKanaKeyboard { inputFocused = true }
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

    /// 単語が受理されたときのキラッと演出を出し、少ししたら消す。
    private func triggerAcceptEffect() {
        let newID = (burstID ?? 0) + 1
        burstID = newID
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            if burstID == newID { burstID = nil }
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
                    .font(Theme.rounded(20, weight: .bold))
                Text(move.isSeed ? "お題" : playerName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if move.isSeed {
                Label("スタート", systemImage: "flag.fill")
                    .font(.caption2)
                    .foregroundStyle(Theme.seedColor)
            } else if move.acceptedByWeb {
                Label("ウェブ", systemImage: "globe")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            } else if move.acceptedByChallenge {
                Label("承認", systemImage: "checkmark.seal")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(cornerRadius: 16, tint: color)
    }
}

/// 単語受理時に外へ広がるキラキラ演出。出現時に一度だけアニメーションして消える。
private struct SparkleBurst: View {
    let color: Color
    @State private var animate = false

    private let count = 8

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let angle = Double(i) / Double(count) * 2 * .pi
                Image(systemName: "sparkle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color)
                    .offset(
                        x: animate ? cos(angle) * 60 : 0,
                        y: animate ? sin(angle) * 60 : 0
                    )
                    .scaleEffect(animate ? 0.2 : 1.0)
                    .opacity(animate ? 0 : 1)
            }
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(color)
                .scaleEffect(animate ? 1.4 : 0.4)
                .opacity(animate ? 0 : 1)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { animate = true }
        }
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

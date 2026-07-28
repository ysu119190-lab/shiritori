import SwiftUI

/// 対戦前の設定画面。プレイヤー・文字数制限・判定ルールを決める。
struct SetupView: View {
    @EnvironmentObject private var game: ShiritoriGame
    @ObservedObject private var points = PointsStore.shared

    var body: some View {
        NavigationStack {
            Form {
                if game.hasSavedGame {
                    resumeSection
                }
                pointsSection
                playersSection
                lengthSection
                inputSection
                judgeSection
                timeSection
                infoSection
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("しりとり")
            .safeAreaInset(edge: .bottom) {
                startButton
            }
        }
    }

    // MARK: - 中断した対戦の再開

    private var resumeSection: some View {
        Section {
            Button {
                Haptics.tap()
                game.resumeSavedGame()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.playerColor(0))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("続きから再開する")
                            .font(Theme.rounded(16, weight: .bold))
                            .foregroundStyle(.primary)
                        if let saved = game.savedGameSummary {
                            Text("\(saved.chainCount)語まで進行中")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }

            Button(role: .destructive) {
                Haptics.tap()
                game.discardSavedGame()
            } label: {
                Text("保存した対戦を削除")
                    .font(.subheadline)
            }
        } header: {
            Text("中断した対戦")
        } footer: {
            Text("前回「中断して保存」した対戦の続きから再開できます。新しく始めると保存データは消えます。")
        }
    }

    // MARK: - しりとりポイント

    private var pointsSection: some View {
        Section {
            NavigationLink {
                ShopView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkle")
                        .font(.title3)
                        .foregroundStyle(Theme.playerColor(3))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(points.points) ポイント")
                            .font(Theme.rounded(16, weight: .bold))
                        Text("アイコンと交換する")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("しりとりポイント")
        } footer: {
            Text("遊ぶほどポイントが貯まります。単語が1つ通るたび +\(PointsStore.pointsPerWord)、決着で +\(PointsStore.finishBonus)、最長記録の更新で +\(PointsStore.recordBonus)。")
        }
    }

    // MARK: - プレイヤー

    private var playersSection: some View {
        Section {
            ForEach(game.settings.playerNames.indices, id: \.self) { index in
                HStack {
                    Image(systemName: points.iconID(forPlayer: index))
                        .foregroundStyle(Theme.playerColor(index))
                        .frame(width: 22)
                    TextField("プレイヤー\(index + 1)", text: Binding(
                        get: { game.settings.playerNames[index] },
                        set: { game.settings.playerNames[index] = $0 }
                    ))
                    .textInputAutocapitalization(.never)
                }
            }
            Stepper(
                "人数: \(game.settings.playerNames.count)人",
                value: Binding(
                    get: { game.settings.playerNames.count },
                    set: { setPlayerCount($0) }
                ),
                in: GameSettings.minPlayers...GameSettings.maxPlayers
            )
        } header: {
            Text("プレイヤー")
        } footer: {
            Text("同じ端末で順番に交代しながら対戦します。")
        }
    }

    private func setPlayerCount(_ newCount: Int) {
        var names = game.settings.playerNames
        if newCount > names.count {
            while names.count < newCount {
                names.append("プレイヤー\(names.count + 1)")
            }
        } else if newCount < names.count {
            names = Array(names.prefix(newCount))
        }
        game.settings.playerNames = names
    }

    // MARK: - 文字数制限

    private var lengthSection: some View {
        Section {
            Toggle("ラリーごとにランダム文字数", isOn: $game.settings.isRandomLengthMode)

            if !game.settings.isRandomLengthMode {
                Stepper("最小: \(game.settings.minLength)文字", value: $game.settings.minLength, in: 1...10)

                Toggle("最大文字数を制限する", isOn: $game.settings.isMaxLengthEnabled)
                if game.settings.isMaxLengthEnabled {
                    Stepper(
                        "最大: \(game.settings.maxLength)文字",
                        value: $game.settings.maxLength,
                        in: max(1, game.settings.minLength)...12
                    )
                }
            }
        } header: {
            Text("文字数")
        } footer: {
            Text(lengthFooter)
        }
    }

    private var lengthFooter: String {
        if game.settings.isRandomLengthMode {
            let r = GameSettings.randomLengthRange
            return "毎ターン、\(r.lowerBound)〜\(r.upperBound)文字の中からお題の文字数がランダムに決まります。ちょうどその文字数の単語だけ使えます（最小・最大の設定は無視されます）。"
        }
        if game.settings.isMaxLengthEnabled {
            return "\(game.settings.minLength)〜\(game.settings.maxLength)文字の単語だけ使えます。"
        } else {
            return "\(game.settings.minLength)文字以上の単語が使えます。"
        }
    }

    // MARK: - 入力方法

    private var inputSection: some View {
        Section {
            Toggle("アプリ内かなキーボードを使う", isOn: $game.settings.useKanaKeyboard)
            if game.settings.useKanaKeyboard {
                Picker("キーボードの種類", selection: $game.settings.kanaKeyboardStyle) {
                    Text("フリック入力").tag(KanaKeyboardStyle.flick)
                    Text("50音タップ").tag(KanaKeyboardStyle.grid)
                }
            }
        } header: {
            Text("入力方法")
        } footer: {
            Text("オンにすると、システムのキーボードの代わりにアプリ内のかなキーボードで入力します。予測変換や変換候補が出ないので、しりとりで次の手が読まれてしまうのを防げます。フリック入力は各キーを上下左右にはじいて「い・う・え・お」段を入力します。")
        }
    }

    // MARK: - 判定ルール

    private var judgeSection: some View {
        Section {
            Toggle("単語が実在するか自動判定", isOn: $game.settings.checkExistence)
            if game.settings.checkExistence {
                Toggle("端末の国語辞書も使う", isOn: $game.settings.useSystemDictionary)
                Toggle("ウェブ（Wikipedia）でも調べる", isOn: $game.settings.useWebSearch)
                Toggle("辞書に無くても参加者が認めればOK", isOn: $game.settings.allowChallengeOverride)
            }
            Toggle("濁音・半濁音を区別しない", isOn: $game.settings.ignoreDakuten)
        } header: {
            Text("判定ルール")
        } footer: {
            Text("「ウェブ（Wikipedia）でも調べる」をオンにすると、辞書に無いキャラクター名や固有名詞でも、Wikipedia に記事があれば名詞として認めます（判定時にインターネット通信を行います）。")
        }
    }

    // MARK: - 制限時間

    private var timeSection: some View {
        Section {
            Toggle("1手ごとの制限時間", isOn: Binding(
                get: { game.settings.turnTimeLimit > 0 },
                set: { game.settings.turnTimeLimit = $0 ? 30 : 0 }
            ))
            if game.settings.turnTimeLimit > 0 {
                Stepper(
                    "\(game.settings.turnTimeLimit)秒",
                    value: $game.settings.turnTimeLimit,
                    in: 5...120,
                    step: 5
                )
            }
        } header: {
            Text("制限時間")
        } footer: {
            Text("時間内に単語を入力できないと、その人の負けになります。")
        }
    }

    private var infoSection: some View {
        Section {
            HStack {
                Label("最長記録", systemImage: "trophy.fill")
                    .foregroundStyle(.orange)
                Spacer()
                Text(game.longestChainRecord > 0 ? "\(game.longestChainRecord)語" : "—")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("同梱辞書")
                Spacer()
                Text("\(game.bundledWordCount)語")
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text("同梱辞書に加えて、端末にインストールされた国語辞書でも判定します。判定が厳しすぎる場合は「参加者が認めればOK」をご利用ください。")
        }
    }

    // MARK: - 開始

    private var startButton: some View {
        Button {
            Haptics.tap()
            game.start()
            // 対戦画面へ切り替わってから広告を出す（頻度制限あり）。
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                AdManager.shared.show(.gameStart)
            }
        } label: {
            Label("ゲームを始める", systemImage: "sparkles")
        }
        .buttonStyle(CuteButtonStyle(color: Theme.playerColor(0)))
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

#Preview {
    SetupView()
        .environmentObject(ShiritoriGame())
}

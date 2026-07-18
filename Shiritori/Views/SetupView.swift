import SwiftUI

/// 対戦前の設定画面。プレイヤー・文字数制限・判定ルールを決める。
struct SetupView: View {
    @EnvironmentObject private var game: ShiritoriGame

    var body: some View {
        NavigationStack {
            Form {
                playersSection
                lengthSection
                judgeSection
                timeSection
                infoSection
            }
            .navigationTitle("しりとり")
            .safeAreaInset(edge: .bottom) {
                startButton
            }
        }
    }

    // MARK: - プレイヤー

    private var playersSection: some View {
        Section {
            ForEach(game.settings.playerNames.indices, id: \.self) { index in
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
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
            Stepper("最小: \(game.settings.minLength)文字", value: $game.settings.minLength, in: 1...10)

            Toggle("最大文字数を制限する", isOn: $game.settings.isMaxLengthEnabled)
            if game.settings.isMaxLengthEnabled {
                Stepper(
                    "最大: \(game.settings.maxLength)文字",
                    value: $game.settings.maxLength,
                    in: max(1, game.settings.minLength)...12
                )
            }
        } header: {
            Text("文字数制限")
        } footer: {
            Text(lengthFooter)
        }
    }

    private var lengthFooter: String {
        if game.settings.isMaxLengthEnabled {
            return "\(game.settings.minLength)〜\(game.settings.maxLength)文字の単語だけ使えます。"
        } else {
            return "\(game.settings.minLength)文字以上の単語が使えます。"
        }
    }

    // MARK: - 判定ルール

    private var judgeSection: some View {
        Section {
            Toggle("単語が実在するか自動判定", isOn: $game.settings.checkExistence)
            if game.settings.checkExistence {
                Toggle("端末の国語辞書も使う", isOn: $game.settings.useSystemDictionary)
                Toggle("辞書に無くても参加者が認めればOK", isOn: $game.settings.allowChallengeOverride)
            }
            Toggle("濁音・半濁音を区別しない", isOn: $game.settings.ignoreDakuten)
        } header: {
            Text("判定ルール")
        } footer: {
            Text("「濁音・半濁音を区別しない」をオンにすると、例えば『か』の後に『が』から始まる語もつなげられます。")
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
            game.start()
        } label: {
            Text("ゲームを始める")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .padding()
        .background(.bar)
    }
}

#Preview {
    SetupView()
        .environmentObject(ShiritoriGame())
}

import SwiftUI

/// あそびかたの説明。とくに通信対戦は準備が必要なので、手順を具体的に書く。
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    modesCard
                    nearbyCard
                    onlineCard
                    rulesCard
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle("あそびかた")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("とじる") { dismiss() }
                }
            }
        }
    }

    // MARK: - 4つのあそびかた

    private var modesCard: some View {
        card(title: "4つのあそびかた", icon: "square.grid.2x2.fill", tint: Theme.playerColor(0)) {
            modeLine(
                icon: "person.2.fill",
                title: "みんなで（1台で交代）",
                body: "1台の端末を回して2〜6人で対戦します。準備はいりません。"
            )
            modeLine(
                icon: "cpu",
                title: "ひとりで（CPU対戦）",
                body: "コンピュータと1対1。よわい・ふつう・つよいの3段階から選べます。"
            )
            modeLine(
                icon: "iphone.gen3.radiowaves.left.and.right",
                title: "近くの人と対戦",
                body: "同じ部屋にある2台をつないで、それぞれの画面で対戦します。"
            )
            modeLine(
                icon: "globe",
                title: "はなれた人と対戦",
                body: "Game Center で、離れた友だちと順番に単語を送り合います。"
            )
        }
    }

    // MARK: - 近くの人と対戦

    private var nearbyCard: some View {
        card(
            title: "近くの人と対戦するには",
            icon: "iphone.gen3.radiowaves.left.and.right",
            tint: Theme.playerColor(2)
        ) {
            Text("2台の端末を直接つないで遊びます。インターネットは使いません。")
                .font(Theme.rounded(14))
                .foregroundStyle(.secondary)

            stepList([
                "2台とも Wi-Fi と Bluetooth をオンにします（同じWi-Fiでなくても、近くにあればつながります）",
                "どちらか一方が「近くの人と対戦する」→「部屋をつくる」を選びます",
                "もう一方が「近くの人と対戦する」→「部屋に入る」を選びます",
                "相手の名前が出たらタップしてつなぎます",
                "つながったら、部屋をつくった人が「対戦を始める」を押します"
            ])

            noteBox(
                icon: "exclamationmark.bubble.fill",
                tint: .orange,
                lines: [
                    "はじめて使うときに「ローカルネットワークへのアクセス」を聞かれます。「許可」を選んでください（断ると相手を見つけられません）。",
                    "ルールは部屋をつくった人の設定が使われます。",
                    "この対戦では、単語の判定はアプリ内の辞書だけで行います（すぐに判定するため）。",
                    "対戦中に相手が離れると、その場で対戦は終了します。"
                ]
            )

            troubleBox([
                "相手が見つからない → 2台とも Wi-Fi と Bluetooth がオンか確認してください。機内モードもオフに。",
                "つながらない → 一度どちらも「やめる」を押して、最初からやり直すと直ることがあります。",
                "離れすぎ → 同じ部屋にいる距離で使ってください。"
            ])
        }
    }

    // MARK: - はなれた人と対戦

    private var onlineCard: some View {
        card(title: "はなれた人と対戦するには", icon: "globe", tint: Theme.playerColor(4)) {
            Text("Game Center を使って、順番に単語を送り合うターン制の対戦です。相手がすぐ返せなくても大丈夫。あとで続きから遊べます。")
                .font(Theme.rounded(14))
                .foregroundStyle(.secondary)

            stepList([
                "端末の「設定」アプリ →「Game Center」でサインインします",
                "アプリの「はなれた人と対戦する」を選びます",
                "友だちを招待するか、相手が見つかるのを待ちます",
                "自分の番になったら単語を入力して送ります",
                "相手が返してきたら、また自分の番です"
            ])

            noteBox(
                icon: "clock.fill",
                tint: Theme.playerColor(4),
                lines: [
                    "自分の番でないときは入力できません。相手が返すまで待ちます。",
                    "アプリを閉じても対戦は続きます。あとで開けば続きから遊べます。"
                ]
            )
        }
    }

    // MARK: - ルール

    private var rulesCard: some View {
        card(title: "しりとりのルール", icon: "checkmark.seal.fill", tint: Theme.playerColor(1)) {
            bullet("前の単語の最後の音から始まる言葉を答えます。")
            bullet("「ん」で終わる言葉を言った人の負けです。")
            bullet("一度使った言葉は使えません。")
            bullet("のばす音「ー」で終わるときは、その前の音でも母音でもつなげます（コーヒー →「ひ」でも「い」でもOK）。")
            bullet("小さい文字で終わるときは大きい文字にします（おちゃ →「や」）。")
            bullet("濁点は、設定で「区別しない」を選べば「か」→「が」もつなげられます。")
            bullet("言葉が実在するかは、約46,000語の辞書で自動で判定します。")
        }
    }

    // MARK: - パーツ

    private func card<Content: View>(
        title: String,
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(title)
                    .font(Theme.rounded(18, weight: .bold))
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardStyle(tint: tint)
    }

    private func modeLine(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.rounded(15, weight: .bold))
                Text(body)
                    .font(Theme.rounded(13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stepList(_ steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(Theme.rounded(13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Theme.playerColor(index % 6)))
                    Text(step)
                        .font(Theme.rounded(14))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func noteBox(icon: String, tint: Color, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(tint)
                    Text(line)
                        .font(Theme.rounded(13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }

    private func troubleBox(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("うまくいかないとき")
                .font(Theme.rounded(14, weight: .bold))
            ForEach(lines, id: \.self) { line in
                Text("・\(line)")
                    .font(Theme.rounded(13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.1))
        )
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("・")
                .font(Theme.rounded(14))
            Text(text)
                .font(Theme.rounded(14))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    HelpView()
}

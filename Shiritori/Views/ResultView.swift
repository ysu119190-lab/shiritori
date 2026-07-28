import SwiftUI

/// 決着画面。
struct ResultView: View {
    @EnvironmentObject private var game: ShiritoriGame

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "flag.checkered")
                .font(.system(size: 64))
                .foregroundStyle(Theme.playerColor(0))

            Text("しょうぶあり！")
                .font(Theme.title(36))

            VStack(spacing: 8) {
                Text("\(game.loserName) さんの負け")
                    .font(Theme.rounded(22, weight: .bold))
                    .foregroundStyle(.red)
                Text(game.resultMessage)
                    .font(Theme.rounded(14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(18)
            .cardStyle(tint: .red)

            if !game.winnerNames.isEmpty {
                VStack(spacing: 4) {
                    Text("勝ち")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(game.winnerNames.joined(separator: "・"))
                        .font(Theme.rounded(17, weight: .bold))
                }
                .padding(.top, 4)
            }

            VStack(spacing: 6) {
                Text("続いた単語数: \(game.chainCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if game.didSetNewRecord {
                    Label("最長記録を更新！", systemImage: "trophy.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.orange.opacity(0.15)))
                } else {
                    Text("最長記録: \(game.longestChainRecord)語")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Haptics.tap()
                    game.restart()
                } label: {
                    Label("もう一度あそぶ", systemImage: "arrow.clockwise")
                }
                .buttonStyle(CuteButtonStyle(color: Theme.playerColor(0)))

                Button {
                    Haptics.tap()
                    game.backToSetup()
                } label: {
                    Text("設定を変える")
                }
                .buttonStyle(CuteButtonStyle(color: Theme.playerColor(1), filled: false))
            }
            .padding(.horizontal)
        }
        .padding()
        .background(AppBackground())
    }
}

#Preview {
    ResultView()
        .environmentObject({
            let g = ShiritoriGame()
            g.start()
            g.submit("りんご")
            g.submit("ごりら")
            g.giveUp()
            return g
        }())
}

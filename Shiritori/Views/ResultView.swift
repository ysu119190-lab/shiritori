import SwiftUI

/// 決着画面。
struct ResultView: View {
    @EnvironmentObject private var game: ShiritoriGame

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "flag.checkered")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("しょうぶあり！")
                .font(.largeTitle.bold())

            VStack(spacing: 8) {
                Text("\(game.loserName) さんの負け")
                    .font(.title2.bold())
                    .foregroundStyle(.red)
                Text(game.resultMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !game.winnerNames.isEmpty {
                VStack(spacing: 4) {
                    Text("勝ち")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(game.winnerNames.joined(separator: "・"))
                        .font(.headline)
                }
                .padding(.top, 4)
            }

            Text("続いた単語数: \(game.history.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    game.restart()
                } label: {
                    Text("もう一度あそぶ")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    game.backToSetup()
                } label: {
                    Text("設定を変える")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
        .padding()
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

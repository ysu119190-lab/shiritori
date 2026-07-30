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

                Label("しりとりポイント +\(game.chainCount * PointsStore.pointsPerWord + game.earnedPoints)", systemImage: "sparkle")
                    .font(Theme.rounded(14, weight: .bold))
                    .foregroundStyle(Theme.playerColor(3))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.playerColor(3).opacity(0.15)))
                    .padding(.top, 2)
            }

            Spacer()

            VStack(spacing: 12) {
                if game.mode == .online {
                    // オンライン対戦は同じ設定で即再開できないので、
                    // 新しい対局は設定画面から作り直してもらう。
                    Button {
                        Haptics.tap()
                        game.leaveOnlineMatch()
                    } label: {
                        Label("設定画面へもどる", systemImage: "house.fill")
                    }
                    .buttonStyle(CuteButtonStyle(color: Theme.playerColor(0)))
                } else {
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
            }
            .padding(.horizontal)
        }
        .padding()
        .background(AppBackground())
        .task {
            // 決着画面が出そろってから広告を出す（頻度制限あり）。
            try? await Task.sleep(nanoseconds: 600_000_000)
            AdManager.shared.show(.gameEnd)
        }
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

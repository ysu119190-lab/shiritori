import SwiftUI

/// 決着画面。
struct ResultView: View {
    @EnvironmentObject private var game: ShiritoriGame
    @ObservedObject private var solo = SoloStats.shared

    /// ソロ対戦の勝敗（ソロでなければ nil）。
    private var soloWon: Bool? { game.soloWon }

    /// 1人プレイの戦績まとめ。
    private var soloSummary: some View {
        VStack(spacing: 6) {
            if game.didSetBestStreak {
                Label("最高連勝を更新！ \(solo.bestStreak)連勝", systemImage: "flame.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.orange.opacity(0.15)))
            } else if solo.currentStreak > 1 {
                Label("\(solo.currentStreak)連勝中", systemImage: "flame.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
            }
            let record = solo.record(for: game.settings.cpuDifficulty)
            Text("\(game.settings.cpuDifficulty.displayName)：\(record.wins)勝 \(record.losses)敗")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: soloWon == true ? "trophy.fill" : (soloWon == false ? "face.dashed" : "flag.checkered"))
                .font(.system(size: 64))
                .foregroundStyle(soloWon == true ? .orange : Theme.playerColor(0))

            Text(soloWon == true ? "かち！" : (soloWon == false ? "まけ…" : "しょうぶあり！"))
                .font(Theme.title(36))

            VStack(spacing: 8) {
                if game.loserIndex != nil {
                    Text(soloWon == nil ? "\(game.loserName) さんの負け" : "\(game.loserName) の負け")
                        .font(Theme.rounded(22, weight: .bold))
                        .foregroundStyle(.red)
                }
                Text(game.resultMessage)
                    .font(Theme.rounded(14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(18)
            .cardStyle(tint: .red)

            if game.isSoloMode {
                soloSummary
            } else if !game.winnerNames.isEmpty {
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
                if game.playMode.isNetworked {
                    // 近距離対戦はホストだけが次の対戦を始められる。
                    // オンライン対戦は Game Center 側で新しい対戦を作り直す。
                    if game.playMode == .nearbyHost && !game.didLoseConnection {
                        Button {
                            Haptics.tap()
                            game.restart()
                        } label: {
                            Label("もう一度あそぶ", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(CuteButtonStyle(color: Theme.playerColor(0)))
                    } else if game.playMode == .nearbyGuest && !game.didLoseConnection {
                        Text("ホストが次の対戦を始めるのを待っています…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Haptics.tap()
                        game.leaveNetworkedGame()
                        game.backToSetup()
                    } label: {
                        Text("対戦をおわる")
                    }
                    .buttonStyle(CuteButtonStyle(color: Theme.playerColor(1), filled: false))
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

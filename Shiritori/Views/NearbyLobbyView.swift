import SwiftUI

/// 近くの端末とつなぐための待ち合わせ画面。
/// 片方が「部屋をつくる」、もう片方が「部屋に入る」を選んでつなぐ。
struct NearbyLobbyView: View {
    @EnvironmentObject private var game: ShiritoriGame
    @Environment(\.dismiss) private var dismiss

    @StateObject private var session: NearbySession
    @State private var didStartGame = false

    /// 自分の表示名。
    private let myName: String

    init(myName: String) {
        self.myName = myName
        _session = StateObject(wrappedValue: NearbySession(displayName: myName))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                header

                switch session.state {
                case .idle:
                    roleButtons
                case .hosting:
                    waitingCard(
                        title: "相手をまっています",
                        detail: "もう一方の端末で「部屋に入る」を選んでください。"
                    )
                case .browsing:
                    browsingList
                case .connecting:
                    waitingCard(title: "つないでいます…", detail: nil)
                case .connected:
                    connectedCard
                case .failed(let reason):
                    failedCard(reason)
                }

                Spacer()
            }
            .padding()
            .background(AppBackground())
            .navigationTitle("近くの人と対戦")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("とじる") {
                        if !didStartGame { session.stop() }
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            // 対戦を開始していないのに閉じたら、探索・接続を必ず止める。
            if !didStartGame { session.stop() }
        }
        .onChange(of: game.phase) { _, newPhase in
            // ゲストはホストが始めるまで待ち、対戦が始まったら画面を閉じる。
            if didStartGame, newPhase == .playing {
                dismiss()
            }
        }
    }

    // MARK: - パーツ

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.system(size: 44))
                .foregroundStyle(Theme.playerColor(2))
            Text("同じ部屋にいる2台をつないで対戦します")
                .font(Theme.rounded(14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var roleButtons: some View {
        VStack(spacing: 14) {
            Button {
                Haptics.tap()
                session.startHosting()
            } label: {
                Label("部屋をつくる", systemImage: "plus.circle.fill")
            }
            .buttonStyle(CuteButtonStyle(color: Theme.playerColor(0)))

            Button {
                Haptics.tap()
                session.startBrowsing()
            } label: {
                Label("部屋に入る", systemImage: "magnifyingglass")
            }
            .buttonStyle(CuteButtonStyle(color: Theme.playerColor(1), filled: false))

            Text("どちらか一方が「部屋をつくる」を選んでください。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private func waitingCard(title: String, detail: String?) -> some View {
        VStack(spacing: 10) {
            ProgressView()
            Text(title)
                .font(Theme.rounded(16, weight: .bold))
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("やめる") {
                session.stop()
            }
            .font(.subheadline)
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .cardStyle(tint: Theme.playerColor(2))
    }

    private var browsingList: some View {
        VStack(spacing: 12) {
            if session.foundPeerNames.isEmpty {
                waitingCard(
                    title: "近くの部屋をさがしています…",
                    detail: "相手の端末で「部屋をつくる」を選んでもらってください。"
                )
            } else {
                VStack(spacing: 10) {
                    Text("見つかった部屋")
                        .font(Theme.rounded(14, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(session.foundPeerNames, id: \.self) { name in
                        Button {
                            Haptics.tap()
                            session.invitePeer(named: name)
                        } label: {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                Text(name)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .cardStyle(tint: Theme.playerColor(1))
                    }
                }
            }
        }
    }

    private var connectedCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("\(session.connectedPeerName ?? "相手") とつながりました")
                .font(Theme.rounded(16, weight: .bold))
                .multilineTextAlignment(.center)

            if session.isHost {
                Button {
                    Haptics.tap()
                    startGame()
                } label: {
                    Label("対戦を始める", systemImage: "sparkles")
                }
                .buttonStyle(CuteButtonStyle(color: Theme.playerColor(0)))
                Text("あなたがホストです。ルールはこの端末の設定を使います。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                ProgressView()
                Text("ホストが始めるのを待っています…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .cardStyle(tint: .green)
        .onAppear {
            // ゲストは接続できた時点で対戦画面へ入り、ホストからの開始を待つ。
            if !session.isHost { startGame() }
        }
    }

    private func failedCard(_ reason: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text(reason)
                .font(Theme.rounded(15, weight: .bold))
                .multilineTextAlignment(.center)
            Button("もう一度") {
                session.stop()
            }
            .buttonStyle(CuteButtonStyle(color: Theme.playerColor(0), filled: false))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .cardStyle(tint: .orange)
    }

    // MARK: - 開始

    private func startGame() {
        guard !didStartGame else { return }
        didStartGame = true
        game.startNearbyGame(
            session: session,
            asHost: session.isHost,
            myName: myName,
            opponentName: session.connectedPeerName ?? "あいて"
        )
        // ホストはこの時点で対戦が始まる。ゲストは最初の状態が届いたら
        // onChange(of: game.phase) で閉じる。
        if session.isHost { dismiss() }
    }
}

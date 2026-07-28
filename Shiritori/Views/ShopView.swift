import SwiftUI

/// しりとりポイントでアイコンと交換する画面。
struct ShopView: View {
    @ObservedObject private var store = PointsStore.shared
    @EnvironmentObject private var game: ShiritoriGame

    /// どのプレイヤーのアイコンを選んでいるか。
    @State private var selectedPlayer: Int = 0

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                pointsHeader
                playerPicker
                iconGrid
            }
            .padding()
        }
        .background(AppBackground())
        .navigationTitle("こうかん所")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 所持ポイント

    private var pointsHeader: some View {
        VStack(spacing: 6) {
            Label("\(store.points) ポイント", systemImage: "sparkle")
                .font(Theme.rounded(22, weight: .bold))
                .foregroundStyle(Theme.playerColor(3))
            Text("単語が1つ通るたび +\(PointsStore.pointsPerWord)、決着で +\(PointsStore.finishBonus)、記録更新で +\(PointsStore.recordBonus)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .cardStyle(tint: Theme.playerColor(3))
    }

    // MARK: - どのプレイヤーに設定するか

    private var playerPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("だれのアイコンにする？")
                .font(Theme.rounded(14, weight: .bold))
                .foregroundStyle(.secondary)
            Picker("プレイヤー", selection: $selectedPlayer) {
                ForEach(game.players.indices, id: \.self) { index in
                    Text(game.players[index]).tag(index)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - アイコン一覧

    private var iconGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(IconCatalog.all) { icon in
                iconCell(icon)
            }
        }
    }

    private func iconCell(_ icon: ShopIcon) -> some View {
        let unlocked = store.isUnlocked(icon)
        let isSelected = store.iconID(forPlayer: selectedPlayer) == icon.id
        let color = Theme.playerColor(selectedPlayer)

        return Button {
            Haptics.tap()
            if unlocked {
                store.setIcon(icon.id, forPlayer: selectedPlayer)
            } else if store.unlock(icon) {
                Haptics.success()
                store.setIcon(icon.id, forPlayer: selectedPlayer)
            } else {
                Haptics.error()
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(unlocked ? color.opacity(0.18) : Color.secondary.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: unlocked ? icon.symbolName : "lock.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(unlocked ? color : Color.secondary)
                }

                Text(icon.title)
                    .font(Theme.rounded(12, weight: .bold))
                    .foregroundStyle(.primary)

                if unlocked {
                    Text(isSelected ? "つかっている" : "つかう")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? color : .secondary)
                } else {
                    Label("\(icon.cost)", systemImage: "sparkle")
                        .font(.caption2)
                        .foregroundStyle(store.canAfford(icon) ? color : .secondary)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .cardStyle(cornerRadius: 16, tint: isSelected ? color : .clear)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .opacity(unlocked || store.canAfford(icon) ? 1 : 0.55)
    }
}

#Preview {
    NavigationStack {
        ShopView()
            .environmentObject(ShiritoriGame())
    }
}

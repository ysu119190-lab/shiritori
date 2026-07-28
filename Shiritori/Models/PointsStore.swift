import Foundation
import SwiftUI

/// 交換できるアイコン。SF Symbols を使うので画像アセットは不要。
struct ShopIcon: Identifiable, Equatable {
    let id: String        // SF Symbol 名をそのまま ID にする
    let title: String
    let cost: Int

    var symbolName: String { id }
}

/// 交換できるアイコン一覧。安いものから順に並べる。
enum IconCatalog {
    static let all: [ShopIcon] = [
        ShopIcon(id: "person.fill",         title: "ひと",       cost: 0),
        ShopIcon(id: "star.fill",           title: "ほし",       cost: 20),
        ShopIcon(id: "heart.fill",          title: "ハート",     cost: 30),
        ShopIcon(id: "leaf.fill",           title: "はっぱ",     cost: 40),
        ShopIcon(id: "pawprint.fill",       title: "にくきゅう", cost: 50),
        ShopIcon(id: "flame.fill",          title: "ほのお",     cost: 60),
        ShopIcon(id: "bolt.fill",           title: "いなずま",   cost: 70),
        ShopIcon(id: "moon.fill",           title: "つき",       cost: 80),
        ShopIcon(id: "sun.max.fill",        title: "たいよう",   cost: 90),
        ShopIcon(id: "crown.fill",          title: "おうかん",   cost: 120),
        ShopIcon(id: "sparkles",            title: "きらきら",   cost: 150),
        ShopIcon(id: "gamecontroller.fill", title: "ゲーム",     cost: 200),
    ]

    static let defaultIconID = "person.fill"

    static func icon(id: String) -> ShopIcon? {
        all.first { $0.id == id }
    }
}

/// しりとりポイントと、交換したアイコンの持ち物を管理する。
/// 遊ぶほどポイントが貯まり、ポイントでアイコンと交換できる。
///
/// ゲーム進行（`ShiritoriGame`）から加算するため、あえて MainActor 限定にはしない。
/// 実際の呼び出しは画面操作かゲーム進行なので、いずれもメインスレッド上で動く。
final class PointsStore: ObservableObject {

    static let shared = PointsStore()

    /// 持っているポイント。
    @Published private(set) var points: Int
    /// 交換済み（使えるようになった）アイコン。
    @Published private(set) var unlockedIconIDs: Set<String>
    /// プレイヤーごとに選んでいるアイコン。
    @Published private(set) var playerIconIDs: [String]

    // MARK: - 獲得ルール

    /// 単語が1つ通るたびの獲得ポイント。
    static let pointsPerWord = 1
    /// 対戦を最後までやり切ったときのボーナス。
    static let finishBonus = 5
    /// 最長記録を更新したときのボーナス。
    static let recordBonus = 10

    private enum Key {
        static let points = "Points.total.v1"
        static let unlocked = "Points.unlocked.v1"
        static let playerIcons = "Points.playerIcons.v1"
    }

    private init() {
        let defaults = UserDefaults.standard
        points = defaults.integer(forKey: Key.points)

        let saved = defaults.stringArray(forKey: Key.unlocked) ?? []
        // 既定アイコンは最初から使える。
        unlockedIconIDs = Set(saved).union([IconCatalog.defaultIconID])

        playerIconIDs = defaults.stringArray(forKey: Key.playerIcons) ?? []
    }

    // MARK: - ポイント

    /// ポイントを加算する。
    func award(_ amount: Int) {
        guard amount > 0 else { return }
        points += amount
        UserDefaults.standard.set(points, forKey: Key.points)
    }

    // MARK: - アイコン

    func isUnlocked(_ icon: ShopIcon) -> Bool {
        unlockedIconIDs.contains(icon.id)
    }

    func canAfford(_ icon: ShopIcon) -> Bool {
        points >= icon.cost
    }

    /// ポイントを使ってアイコンを交換する。足りなければ false。
    @discardableResult
    func unlock(_ icon: ShopIcon) -> Bool {
        guard !isUnlocked(icon) else { return true }
        guard canAfford(icon) else { return false }
        points -= icon.cost
        unlockedIconIDs.insert(icon.id)
        let defaults = UserDefaults.standard
        defaults.set(points, forKey: Key.points)
        defaults.set(Array(unlockedIconIDs), forKey: Key.unlocked)
        return true
    }

    /// プレイヤーが使うアイコンを取得する。
    func iconID(forPlayer index: Int) -> String {
        guard index >= 0, index < playerIconIDs.count else { return IconCatalog.defaultIconID }
        let id = playerIconIDs[index]
        // 手放した／未所持のアイコンが残っていた場合は既定に戻す。
        return unlockedIconIDs.contains(id) ? id : IconCatalog.defaultIconID
    }

    /// プレイヤーが使うアイコンを設定する（所持しているものだけ）。
    func setIcon(_ iconID: String, forPlayer index: Int) {
        guard index >= 0, unlockedIconIDs.contains(iconID) else { return }
        while playerIconIDs.count <= index {
            playerIconIDs.append(IconCatalog.defaultIconID)
        }
        playerIconIDs[index] = iconID
        UserDefaults.standard.set(playerIconIDs, forKey: Key.playerIcons)
    }
}

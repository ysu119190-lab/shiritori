import Foundation
import GoogleMobileAds
#if canImport(UIKit)
import UIKit
#endif

/// 広告のID設定。実際の広告IDに差し替えるのはここだけ。
///
/// いまは Google 公式の**テストID**を使っている。開発中に本番IDを使うと
/// 無効トラフィック扱いでアカウント停止のリスクがあるため、実IDに変えるのは
/// リリース直前（かつ実機での動作確認が終わってから）にする。
enum AdConfig {

    /// テスト用インタースティシャル（Google 公式）。
    private static let testInterstitialUnitID = "ca-app-pub-3940256099942544/4411468910"

    /// 本番のインタースティシャル広告ユニットID。未設定のうちはテストIDを使う。
    private static let productionInterstitialUnitID: String? = nil

    /// 実際に使う広告ユニットID。
    static var interstitialUnitID: String {
        #if DEBUG
        // Debug ビルドでは必ずテストID。
        return testInterstitialUnitID
        #else
        return productionInterstitialUnitID ?? testInterstitialUnitID
        #endif
    }

    /// 広告を出す最短間隔（秒）。短い対戦で広告が連続しないようにする。
    static let minimumInterval: TimeInterval = 60
}

/// 全画面広告（インタースティシャル）の読み込みと表示をまとめて扱う。
///
/// 表示のタイミングは「アプリ起動時」「ゲーム開始時」「ゲーム終了時」の3つだが、
/// 前回表示から `AdConfig.minimumInterval` 秒たっていないときは出さない。
@MainActor
final class AdManager: ObservableObject {

    static let shared = AdManager()

    /// 広告を出す場面。
    enum Placement {
        case launch     // アプリ起動時
        case gameStart  // ゲーム開始時
        case gameEnd    // 決着時
    }

    private var interstitial: InterstitialAd?
    private var isLoading = false
    private var lastShownAt: Date?

    private init() {}

    /// SDK を初期化して、最初の広告を読み込んでおく。
    func start() {
        MobileAds.shared.start(completionHandler: nil)
        Task { await loadIfNeeded() }
    }

    /// 手持ちの広告が無ければ読み込む。
    func loadIfNeeded() async {
        guard interstitial == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            interstitial = try await InterstitialAd.load(
                with: AdConfig.interstitialUnitID,
                request: Request()
            )
        } catch {
            // 読み込めなくてもゲームは続行できるので、黙って諦めて次の機会に再挑戦する。
            interstitial = nil
        }
    }

    /// 条件を満たしていれば広告を表示する。出せないときは何もしない（ゲームは止めない）。
    func show(_ placement: Placement) {
        guard canShowNow else {
            Task { await loadIfNeeded() }
            return
        }
        guard let ad = interstitial, let controller = presentableViewController() else {
            Task { await loadIfNeeded() }
            return
        }

        interstitial = nil
        lastShownAt = Date()
        ad.present(from: controller)

        // 次回に備えて読み込んでおく。
        Task { await loadIfNeeded() }
    }

    /// 前回表示からの間隔が空いているか。
    private var canShowNow: Bool {
        guard let last = lastShownAt else { return true }
        return Date().timeIntervalSince(last) >= AdConfig.minimumInterval
    }

    // MARK: - 表示先の画面

    /// 広告を出せる状態の最前面のビューコントローラを返す。
    /// シートなどの遷移中は出さない（表示が重なって崩れるのを避ける）。
    private func presentableViewController() -> UIViewController? {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            return nil
        }

        var top = root
        while let presented = top.presentedViewController {
            // 何かを表示している最中なら、その遷移が終わるまで広告は出さない。
            if presented.isBeingPresented || presented.isBeingDismissed { return nil }
            top = presented
        }
        return top
    }
}

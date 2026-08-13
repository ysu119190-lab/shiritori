import Foundation
#if canImport(MultipeerConnectivity)
import MultipeerConnectivity
#endif

/// 近くの端末との接続状態。
enum NearbyState: Equatable {
    case idle          // 何もしていない
    case hosting       // 部屋を作って待っている
    case browsing      // 近くの部屋を探している
    case connecting    // 接続中
    case connected     // つながった
    case failed(String)
}

/// 近くの端末（同じWi-Fi / Bluetooth圏内）と直接つないで対戦するためのセッション。
///
/// - ホストが部屋を作って待ち、ゲストが探して参加する 1 対 1 の構成。
/// - サーバーは不要。追加費用もかからない。
/// - 通信は `PeerMessage` を JSON にして送る。
///
/// デリゲートは背景スレッドで呼ばれるため、公開プロパティの更新と
/// コールバックはすべてメインスレッドへ回す。
final class NearbySession: NSObject, ObservableObject {

    /// Bonjour のサービス名（15文字以内・英小文字/数字/ハイフンのみ）。
    /// Info.plist の NSBonjourServices と一致させること。
    static let serviceType = "shiritori-game"

    @Published private(set) var state: NearbyState = .idle
    /// 見つかった近くの部屋の表示名。
    @Published private(set) var foundPeerNames: [String] = []
    /// つながった相手の表示名。
    @Published private(set) var connectedPeerName: String?
    /// 自分がホストか。
    @Published private(set) var isHost = false

    /// 相手からメッセージが届いたときに呼ばれる（メインスレッド）。
    var onReceive: ((PeerMessage) -> Void)?
    /// 接続が切れたときに呼ばれる（メインスレッド）。
    var onDisconnect: (() -> Void)?

    #if canImport(MultipeerConnectivity)
    private let myPeerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var foundPeers: [MCPeerID] = []

    /// - Parameter displayName: 相手の画面に出る自分の名前（プレイヤー名を渡す）。
    ///   端末名は個人名を含みがちなので使わない。
    init(displayName: String) {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        // MCPeerID は 1〜63 バイト。空なら既定名にし、長すぎる名前は切り詰める。
        let safeName = trimmed.isEmpty ? "プレイヤー" : String(trimmed.prefix(16))
        myPeerID = MCPeerID(displayName: safeName)
        super.init()
    }

    // MARK: - ホスト（部屋を作る）

    func startHosting() {
        stop()
        isHost = true
        let session = makeSession()
        let advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: nil,
            serviceType: Self.serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
        self.session = session
        state = .hosting
    }

    // MARK: - ゲスト（探して参加する）

    func startBrowsing() {
        stop()
        isHost = false
        let session = makeSession()
        let browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
        self.session = session
        state = .browsing
    }

    /// 見つかった部屋に参加する。
    func invitePeer(named name: String) {
        guard let peer = foundPeers.first(where: { $0.displayName == name }),
              let session else { return }
        state = .connecting
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 20)
    }

    // MARK: - 送受信

    func send(_ message: PeerMessage) {
        guard let session, !session.connectedPeers.isEmpty else { return }
        guard let data = try? JSONEncoder().encode(message) else { return }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            state = .failed("送信できませんでした")
        }
    }

    /// 接続と探索をすべて止める。
    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        foundPeers.removeAll()
        foundPeerNames = []
        connectedPeerName = nil
        state = .idle
    }

    private func makeSession() -> MCSession {
        let session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        return session
    }

    /// メインスレッドで実行する（デリゲートは背景スレッドで呼ばれるため）。
    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
    #else
    // MultipeerConnectivity が使えない環境では何もしない。
    init(displayName: String) { super.init() }
    func startHosting() {}
    func startBrowsing() {}
    func invitePeer(named name: String) {}
    func send(_ message: PeerMessage) {}
    func stop() {}
    #endif
}

#if canImport(MultipeerConnectivity)

// MARK: - MCSessionDelegate

extension NearbySession: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange sessionState: MCSessionState) {
        onMain { [weak self] in
            guard let self else { return }
            switch sessionState {
            case .connected:
                self.connectedPeerName = peerID.displayName
                self.state = .connected
                // つながったら探索は止めてよい（1対1のため）。
                self.advertiser?.stopAdvertisingPeer()
                self.browser?.stopBrowsingForPeers()
            case .connecting:
                self.state = .connecting
            case .notConnected:
                // 接続済みだったのに切れた場合だけ通知する。
                if self.state == .connected {
                    self.connectedPeerName = nil
                    self.state = .failed("接続が切れました")
                    self.onDisconnect?()
                }
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(PeerMessage.self, from: data) else { return }
        onMain { [weak self] in
            self?.onReceive?(message)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - 広告（ホスト側）

extension NearbySession: MCNearbyServiceAdvertiserDelegate {

    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        onMain { [weak self] in
            guard let self, let session = self.session else {
                invitationHandler(false, nil)
                return
            }
            // 1対1なので、すでに誰かとつながっていたら断る。
            let accept = session.connectedPeers.isEmpty
            invitationHandler(accept, accept ? session : nil)
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        onMain { [weak self] in
            self?.state = .failed("部屋を作れませんでした。Wi-Fi と Bluetooth を確認してください。")
        }
    }
}

// MARK: - 探索（ゲスト側）

extension NearbySession: MCNearbyServiceBrowserDelegate {

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        onMain { [weak self] in
            guard let self, !self.foundPeers.contains(peerID) else { return }
            self.foundPeers.append(peerID)
            self.foundPeerNames = self.foundPeers.map(\.displayName)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        onMain { [weak self] in
            guard let self else { return }
            self.foundPeers.removeAll { $0 == peerID }
            self.foundPeerNames = self.foundPeers.map(\.displayName)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        onMain { [weak self] in
            self?.state = .failed("近くの端末を探せませんでした。Wi-Fi と Bluetooth を確認してください。")
        }
    }
}

#endif

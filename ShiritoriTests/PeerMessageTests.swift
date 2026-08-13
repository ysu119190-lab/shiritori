import XCTest
@testable import Shiritori

/// 端末間でやり取りするメッセージが、送って受け取っても壊れないことを確かめる。
/// 通信の中身が変わるとゲームが噛み合わなくなるため、往復（round-trip）を固定する。
final class PeerMessageTests: XCTestCase {

    private func roundTrip(_ message: PeerMessage) throws -> PeerMessage {
        let data = try JSONEncoder().encode(message)
        return try JSONDecoder().decode(PeerMessage.self, from: data)
    }

    func testHelloRoundTrip() throws {
        let decoded = try roundTrip(.hello(name: "たろう"))
        guard case .hello(let name) = decoded else {
            return XCTFail("hello として復元されるべき: \(decoded)")
        }
        XCTAssertEqual(name, "たろう")
    }

    func testSubmitRoundTrip() throws {
        let decoded = try roundTrip(.submit(word: "りんご"))
        guard case .submit(let word) = decoded else {
            return XCTFail("submit として復元されるべき: \(decoded)")
        }
        XCTAssertEqual(word, "りんご")
    }

    func testRejectedRoundTrip() throws {
        let decoded = try roundTrip(.rejected(reason: "「ご」から始めてください"))
        guard case .rejected(let reason) = decoded else {
            return XCTFail("rejected として復元されるべき: \(decoded)")
        }
        XCTAssertEqual(reason, "「ご」から始めてください")
    }

    func testGiveUpAndQuitRoundTrip() throws {
        guard case .giveUp = try roundTrip(.giveUp) else {
            return XCTFail("giveUp として復元されるべき")
        }
        guard case .quit = try roundTrip(.quit) else {
            return XCTFail("quit として復元されるべき")
        }
    }

    func testSnapshotRoundTripKeepsGameState() throws {
        let snapshot = GameSnapshot(
            playerNames: ["ホスト", "ゲスト"],
            history: [
                Move(word: "りんご", reading: "りんご", playerIndex: -1,
                     acceptedByChallenge: false, acceptedByWeb: false, isSeed: true),
                Move(word: "ごりら", reading: "ごりら", playerIndex: 0,
                     acceptedByChallenge: false, acceptedByWeb: false)
            ],
            currentPlayerIndex: 1,
            requiredStartKana: "ら",
            requiredLength: 4,
            remainingTime: 12,
            isFinished: false,
            loserIndex: nil,
            resultMessage: "",
            guestPlayerIndex: 1,
            minLength: 2,
            maxLength: 6,
            isTimed: true
        )

        let decoded = try roundTrip(.snapshot(snapshot))
        guard case .snapshot(let restored) = decoded else {
            return XCTFail("snapshot として復元されるべき: \(decoded)")
        }
        XCTAssertEqual(restored, snapshot)
        // 手番の判断に使う値は特に重要なので個別にも確認する。
        XCTAssertEqual(restored.currentPlayerIndex, 1)
        XCTAssertEqual(restored.guestPlayerIndex, 1)
        XCTAssertEqual(restored.requiredStartKana, "ら")
        XCTAssertEqual(restored.history.count, 2)
        XCTAssertTrue(restored.history[0].isSeed)
    }

    func testSnapshotWithoutOptionalValues() throws {
        let snapshot = GameSnapshot(
            playerNames: ["A", "B"],
            history: [],
            currentPlayerIndex: 0,
            requiredStartKana: nil,
            requiredLength: nil,
            remainingTime: 0,
            isFinished: true,
            loserIndex: 1,
            resultMessage: "Bさんが降参しました",
            guestPlayerIndex: 1,
            minLength: 2,
            maxLength: nil,
            isTimed: false
        )
        let decoded = try roundTrip(.snapshot(snapshot))
        guard case .snapshot(let restored) = decoded else {
            return XCTFail("snapshot として復元されるべき")
        }
        XCTAssertEqual(restored, snapshot)
        XCTAssertNil(restored.maxLength)
        XCTAssertNil(restored.requiredStartKana)
        XCTAssertEqual(restored.loserIndex, 1)
    }

    func testServiceTypeIsValidForBonjour() {
        // Bonjour のサービス名は15文字以内・英小文字/数字/ハイフンのみ。
        let type = NearbySession.serviceType
        XCTAssertLessThanOrEqual(type.count, 15)
        XCTAssertFalse(type.isEmpty)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        XCTAssertTrue(
            type.unicodeScalars.allSatisfy { allowed.contains($0) },
            "使える文字は英小文字・数字・ハイフンだけ: \(type)"
        )
    }
}

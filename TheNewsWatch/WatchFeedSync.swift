import Foundation
import WatchConnectivity

@MainActor
final class WatchFeedSync: NSObject {
    static let shared = WatchFeedSync()

    private static let openURLMessageKey = "openURL"

    func activate() {
        guard WCSession.isSupported(), WCSession.default.delegate == nil else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func openOnPhone(_ url: URL) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        let message = [Self.openURLMessageKey: url.absoluteString]
        if session.activationState != .activated {
            session.activate()
        }
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { _ in
                session.transferUserInfo(message)
            }
        } else {
            session.transferUserInfo(message)
        }
    }

    private func applyReceivedSelection(_ ids: [String]) {
        WatchFeedConfiguration.save(ids)
        NotificationCenter.default.post(name: WatchFeedConfiguration.didChangeNotification, object: nil)
    }
}

extension WatchFeedSync: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard let ids = session.receivedApplicationContext[WatchFeedConfiguration.contextKey] as? [String] else { return }
        Task { @MainActor [weak self] in
            self?.applyReceivedSelection(ids)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let ids = applicationContext[WatchFeedConfiguration.contextKey] as? [String] else { return }
        Task { @MainActor [weak self] in
            self?.applyReceivedSelection(ids)
        }
    }
}

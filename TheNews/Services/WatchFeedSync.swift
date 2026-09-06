import Foundation
#if os(iOS) || os(watchOS)
import WatchConnectivity
#endif

@MainActor
final class WatchFeedSync: NSObject {
    static let shared = WatchFeedSync()

    #if os(iOS)
    static let openURLRequestedNotification = Notification.Name("WatchFeedSyncOpenURLRequested")
    static let openURLUserInfoKey = "url"
    private static let openURLMessageKey = "openURL"
    #endif

    #if os(iOS) || os(watchOS)
    private var session: WCSession? {
        WCSession.isSupported() ? .default : nil
    }
    private var activated = false
    #endif

    func activate() {
        #if os(iOS) || os(watchOS)
        guard let session, session.delegate == nil else { return }
        session.delegate = self
        session.activate()
        #endif
    }

    func selectedFeedIDs() -> [String] {
        WatchFeedConfiguration.load()
    }

    func updateSelection(_ ids: [String]) {
        let sanitized = WatchFeedConfiguration.sanitizedFeedIDs(ids)
        WatchFeedConfiguration.save(sanitized)
        notifyLocalChange()

        #if os(iOS)
        sendSelectionToWatch(sanitized)
        #endif
    }

    #if os(iOS)
    private func sendSelectionToWatch(_ ids: [String]? = nil) {
        guard let session, activated, session.isPaired, session.isWatchAppInstalled else { return }
        let payload = [WatchFeedConfiguration.contextKey: ids ?? selectedFeedIDs()]
        try? session.updateApplicationContext(payload)
    }
    #endif

    private func applyReceivedSelection(_ ids: [String]) {
        WatchFeedConfiguration.save(ids)
        notifyLocalChange()
    }

    #if os(iOS)
    private func requestOpenURL(from payload: [String: Any]) {
        guard
            let value = payload[Self.openURLMessageKey] as? String,
            let url = URL(string: value)
        else { return }
        NotificationCenter.default.post(
            name: Self.openURLRequestedNotification,
            object: nil,
            userInfo: [Self.openURLUserInfoKey: url]
        )
    }
    #endif

    private func notifyLocalChange() {
        NotificationCenter.default.post(name: WatchFeedConfiguration.didChangeNotification, object: nil)
    }
}

#if os(iOS) || os(watchOS)
extension WatchFeedSync: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.activated = activationState == .activated
            #if os(iOS)
            if self.activated { self.sendSelectionToWatch() }
            #endif
            if let ids = session.receivedApplicationContext[WatchFeedConfiguration.contextKey] as? [String] {
                self.applyReceivedSelection(ids)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let ids = applicationContext[WatchFeedConfiguration.contextKey] as? [String] else { return }
        Task { @MainActor [weak self] in
            self?.applyReceivedSelection(ids)
        }
    }

    #if os(iOS)
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor [weak self] in
            self?.requestOpenURL(from: message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor [weak self] in
            self?.requestOpenURL(from: userInfo)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
#endif

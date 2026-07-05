import Foundation
import Observation
import UserNotifications

/// Achemine un tap de notification vers l'article concerné (deep-link intra-app).
@Observable
@MainActor
final class NotificationRouter {
    static let shared = NotificationRouter()
    /// Identifiant de l'article à ouvrir suite à un tap sur notification.
    var pendingArticleID: String?
}

/// Gère les notifications locales : permission, statut, émission pour les articles
/// correspondant aux sujets de veille, présentation au premier plan et deep-link.
/// Cross-plateforme (`UserNotifications` existe sur macOS et iOS).
@Observable
@MainActor
final class NotificationService: NSObject {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    /// Dernier statut connu (rafraîchi via `refreshStatus()`).
    private(set) var status: UNAuthorizationStatus = .notDetermined

    var isAuthorized: Bool { status == .authorized || status == .provisional }

    /// À appeler une fois au démarrage pour recevoir les taps et l'affichage foreground.
    func configureDelegate() {
        center.delegate = self
    }

    func refreshStatus() async {
        status = await center.notificationSettings().authorizationStatus
    }

    /// Demande l'autorisation ; met à jour `status`. Renvoie `true` si accordée.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshStatus()
        return granted
    }

    /// Émet des notifications pour de nouveaux articles correspondant à la veille.
    /// 1 article → notification détaillée ; plusieurs → une notification de synthèse.
    func notify(articles: [Article]) async {
        guard isAuthorized, !articles.isEmpty else { return }

        if articles.count == 1, let a = articles.first {
            await add(id: a.id, title: a.feed?.title ?? "TheNews", body: a.title, articleID: a.id)
        } else {
            let title = "TheNews"
            let body = String(format: bodyFormat(articles.count), articles.count)
            await add(id: "alerts-summary-\(articles.first?.id ?? "")", title: title, body: body,
                      articleID: articles.first?.id)
        }
    }

    /// Identifiant de la notification quotidienne de briefing (remplacée à chaque reprogrammation).
    private static let briefingID = "daily-briefing"

    /// (Re)programme la notification de briefing quotidien à `hour` (répétée chaque jour).
    /// Sans effet — et annule l'existante — si l'autorisation manque ou `enabled` est faux.
    func scheduleDailyBriefing(enabled: Bool, hour: Int) async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.briefingID])
        guard enabled, isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "TheNews"
        content.body = AppLocale.identifier.hasPrefix("fr")
            ? "Votre briefing du jour est prêt."
            : "Your daily briefing is ready."
        content.sound = .default

        var components = DateComponents()
        components.hour = min(max(hour, 0), 23)
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.briefingID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// Notification de démonstration (bouton « tester » des réglages).
    func sendTest() async {
        guard isAuthorized else { return }
        await add(id: "test-\(Int(Date().timeIntervalSince1970))",
                  title: "TheNews",
                  body: AppLocale.identifier.hasPrefix("fr")
                        ? "Ceci est une notification de test."
                        : "This is a test notification.",
                  articleID: nil)
    }

    // MARK: - Interne

    private func bodyFormat(_ count: Int) -> String {
        AppLocale.identifier.hasPrefix("fr")
            ? "%d nouveaux articles correspondent à votre veille."
            : "%d new articles match your watch topics."
    }

    private func add(id: String, title: String, body: String, articleID: String?) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let articleID { content.userInfo = ["articleID": articleID] }
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        try? await center.add(request)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    /// Affiche la notification même quand l'app est au premier plan.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Tap sur une notification → deep-link vers l'article.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let articleID = response.notification.request.content.userInfo["articleID"] as? String
        await MainActor.run {
            if let articleID { NotificationRouter.shared.pendingArticleID = articleID }
        }
    }
}

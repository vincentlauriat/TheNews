import Foundation
import Observation
import UserNotifications

/// Destination visée par un tap de notification (deep-link intra-app) : soit un article
/// précis, soit l'écran Alertes (notification de synthèse regroupant plusieurs articles,
/// pour lesquels aucun article unique n'est privilégié).
enum NotificationDestination: Equatable {
    case article(id: String)
    case alerts
}

/// Achemine un tap de notification vers sa destination.
@Observable
@MainActor
final class NotificationRouter {
    static let shared = NotificationRouter()
    /// Destination à ouvrir suite à un tap sur notification.
    var pending: NotificationDestination?
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
            await add(id: a.id, title: a.feed?.title ?? "TheNews", body: a.title,
                      userInfo: ["articleID": a.id])
        } else {
            let title = "TheNews"
            let body = String(format: bodyFormat(articles.count), articles.count)
            // Notif de synthèse : route vers l'écran Alertes plutôt qu'un seul article
            // arbitraire — sinon les autres articles groupés seraient inaccessibles depuis
            // la notification (l'ancien code ne référençait que `articles.first`).
            await add(id: "alerts-summary-\(articles.first?.id ?? "")", title: title, body: body,
                      userInfo: ["destination": "alerts"])
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
                        : "This is a test notification.")
    }

    // MARK: - Interne

    private func bodyFormat(_ count: Int) -> String {
        AppLocale.identifier.hasPrefix("fr")
            ? "%d nouveaux articles correspondent à votre veille."
            : "%d new articles match your watch topics."
    }

    private func add(id: String, title: String, body: String, userInfo: [AnyHashable: Any] = [:]) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
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

    /// Tap sur une notification → deep-link vers sa destination (article ou écran Alertes).
    /// Le briefing quotidien et la notif de test n'ont pas de `userInfo` de routage — pas de
    /// deep-link pour elles, comportement voulu.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let destination: NotificationDestination?
        if let articleID = info["articleID"] as? String {
            destination = .article(id: articleID)
        } else if info["destination"] as? String == "alerts" {
            destination = .alerts
        } else {
            destination = nil
        }
        guard let destination else { return }
        await MainActor.run { NotificationRouter.shared.pending = destination }
    }
}

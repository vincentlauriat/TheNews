import Foundation
import SwiftData

/// Abonnement de l'utilisateur à une rubrique (`Feed`). La présence d'une instance
/// signifie « abonné » ; `alertsEnabled` décide si les nouveaux articles de cette
/// rubrique peuvent déclencher une notification (utilisé en phase 4).
@Model
final class FeedSubscription {
    // Valeurs par défaut + pas de contrainte `.unique` : exigences SwiftData + CloudKit.
    // L'unicité par `feedID` est assurée par `SubscriptionStore` (vérif avant insertion).
    var feedID: String = ""
    var alertsEnabled: Bool = true
    var subscribedAt: Date = Date()

    init(feedID: String, alertsEnabled: Bool = true, subscribedAt: Date = Date()) {
        self.feedID = feedID
        self.alertsEnabled = alertsEnabled
        self.subscribedAt = subscribedAt
    }

    var feed: Feed? { Feed.byID(feedID) }
}

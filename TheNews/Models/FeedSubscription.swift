import Foundation
import SwiftData

/// Abonnement de l'utilisateur à une rubrique (`Feed`). La présence d'une instance
/// signifie « abonné » ; `alertsEnabled` décide si les nouveaux articles de cette
/// rubrique peuvent déclencher une notification (utilisé en phase 4).
@Model
final class FeedSubscription {
    @Attribute(.unique) var feedID: String
    var alertsEnabled: Bool
    var subscribedAt: Date

    init(feedID: String, alertsEnabled: Bool = true, subscribedAt: Date = Date()) {
        self.feedID = feedID
        self.alertsEnabled = alertsEnabled
        self.subscribedAt = subscribedAt
    }

    var feed: Feed? { Feed.byID(feedID) }
}

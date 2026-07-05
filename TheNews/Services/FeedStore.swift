import Foundation
import SwiftData

/// Insertion des articles parsés dans SwiftData, avec **déduplication** par `id`.
/// Opère sur le `MainActor` car il manipule le `ModelContext` de l'app.
@MainActor
struct FeedStore {
    let context: ModelContext

    /// Insère les articles absents et renvoie **uniquement les nouveaux** (utile pour
    /// déclencher des alertes sur les vraies nouveautés). Les doublons sont ignorés.
    @discardableResult
    func ingest(_ parsed: [ParsedArticle], feedID: String) throws -> [Article] {
        guard !parsed.isEmpty else { return [] }

        let incomingIDs = Set(parsed.map(\.id))
        // Les identifiants déjà connus, en une seule requête.
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { incomingIDs.contains($0.id) }
        )
        let existing = Set(try context.fetch(descriptor).map(\.id))

        let now = Date()
        var inserted: [Article] = []
        for p in parsed where !existing.contains(p.id) {
            let article = Article(
                id: p.id,
                feedID: feedID,
                title: p.title,
                summary: p.summary,
                link: p.link,
                imageURL: p.imageURL,
                publishedAt: p.publishedAt,
                fetchedAt: now
            )
            context.insert(article)
            inserted.append(article)
        }
        if !inserted.isEmpty { try context.save() }
        return inserted
    }

    /// Articles d'une rubrique, du plus récent au plus ancien.
    func articles(feedID: String) throws -> [Article] {
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.feedID == feedID },
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Articles mis en favori, du plus récent au plus ancien.
    func favorites() throws -> [Article] {
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.isFavorite },
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Articles agrégés de plusieurs rubriques, du plus récent au plus ancien.
    func articles(feedIDs: [String]) throws -> [Article] {
        guard !feedIDs.isEmpty else { return [] }
        let ids = Set(feedIDs)
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { ids.contains($0.feedID) },
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Purge les articles plus vieux que `days` jours et non favoris (borne la base).
    func prune(olderThan days: Int = 30) throws {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.fetchedAt < cutoff && !$0.isFavorite }
        )
        for stale in try context.fetch(descriptor) { context.delete(stale) }
        try context.save()
    }
}

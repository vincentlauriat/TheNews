import Foundation
import SwiftData

/// Insertion des articles parsés dans SwiftData, avec déduplication applicative.
/// Opère sur le `MainActor` car il manipule le `ModelContext` de l'app.
@MainActor
struct FeedStore {
    let context: ModelContext

    /// Insère les articles absents, réaligne ceux déjà connus sur ce que publie le flux,
    /// et renvoie **uniquement les nouveaux** (utile pour déclencher des alertes sur les
    /// vraies nouveautés).
    @discardableResult
    func ingest(_ parsed: [ParsedArticle], feedID: String) throws -> [Article] {
        guard !parsed.isEmpty else { return [] }

        let parsed = ParsedArticle.deduplicated(parsed)
        let incomingIDs = Set(parsed.map(\.id))
        // Rapprocher sur le seul `guid` ne suffit pas : un même billet peut être servi sous
        // deux `guid` différents selon la rubrique (Calipia publie `http://…/?p=N` dans
        // certaines et `https://…/?p=N` dans d'autres). L'identité qui fait foi partout
        // ailleurs — `dedupedByIdentity`, `pruneDuplicates` — est le lien canonique ; le
        // prédicat ne sachant pas normaliser un lien stocké, on lui fournit les écritures
        // plausibles et on retrie ensuite sur la clé canonique.
        let linkVariants = Set(parsed.flatMap { Self.linkVariants(of: $0.link) })
        // Les articles déjà connus, en une seule requête. Groupés et non réduits à un
        // ensemble d'identifiants : `Article.id` n'a pas de contrainte d'unicité (exigence
        // CloudKit), plusieurs lignes peuvent donc porter le même, et toutes doivent être
        // réalignées.
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { incomingIDs.contains($0.id) || linkVariants.contains($0.link) }
        )
        var existingByID: [String: [Article]] = [:]
        var existingByLink: [String: [Article]] = [:]
        for article in try context.fetch(descriptor) {
            existingByID[article.id, default: []].append(article)
            if let key = ParsedArticle.canonicalLink(from: article.link) {
                existingByLink[key, default: []].append(article)
            }
        }

        let now = Date()
        var inserted: [Article] = []
        var didRefresh = false
        for p in parsed {
            // Le lien canonique prime sur le `guid` : c'est lui qui décidera ensuite,
            // dans `pruneDuplicates`, quelle ligne survit. Rapprocher sur autre chose
            // reviendrait à insérer une ligne corrigée que la purge supprimerait au
            // profit de la plus ancienne, restée périmée.
            if let known = existingByLink[p.deduplicationKey] ?? existingByID[p.id] {
                for article in known where Self.refresh(article, from: p) { didRefresh = true }
                continue
            }
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
        if !inserted.isEmpty || didRefresh { try context.save() }
        return inserted
    }

    /// Réaligne un article déjà en base sur ce que publie le flux. Renvoie `true` si
    /// quelque chose a changé.
    ///
    /// Ne touche qu'aux champs dont le flux est la source de vérité. L'état utilisateur
    /// (`isRead`, `isFavorite`) lui appartient et doit survivre au rafraîchissement, tout
    /// comme `link` — clé d'identité de la déduplication, qu'on ne déplace pas en cours de
    /// route. Sans cette passe, un article garde à jamais la forme sous laquelle il a été
    /// téléchargé la première fois, puisque l'insertion saute les identifiants connus :
    /// chapô aux entités HTML non décodées, image en `http` que App Transport Security
    /// refuse de charger. C'est ce qui rendait les correctifs de `RSSParser` invisibles
    /// sur les articles déjà présents.
    private static func refresh(_ article: Article, from parsed: ParsedArticle) -> Bool {
        var changed = false
        if article.title != parsed.title {
            article.title = parsed.title
            changed = true
        }
        if article.summary != parsed.summary {
            article.summary = parsed.summary
            changed = true
        }
        if article.imageURL != parsed.imageURL {
            article.imageURL = parsed.imageURL
            changed = true
        }
        return changed
    }

    /// Les écritures plausibles d'un même lien : `http` et `https`, avec et sans barre
    /// oblique finale — les seules variations que `canonicalLink` absorbe. Sert uniquement
    /// à élargir le prédicat de récupération ; un faux positif est sans effet, le
    /// rapprochement réel se fait ensuite sur la clé canonique.
    private static func linkVariants(of url: URL) -> [URL] {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return [url] }
        let path = components.path
        let paths = path.hasSuffix("/") ? [path, String(path.dropLast())] : [path, path + "/"]
        var variants: [URL] = []
        for candidateScheme in ["http", "https"] {
            for candidatePath in paths {
                components.scheme = candidateScheme
                components.path = candidatePath
                if let variant = components.url { variants.append(variant) }
            }
        }
        return variants
    }

    /// Articles d'une rubrique, du plus récent au plus ancien.
    func articles(feedID: String, limit: Int? = nil) throws -> [Article] {
        var descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.feedID == feedID },
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        if let limit { descriptor.fetchLimit = limit }
        return dedupedByIdentity(try context.fetch(descriptor))
    }

    /// Articles mis en favori, du plus récent au plus ancien.
    func favorites(limit: Int? = nil) throws -> [Article] {
        var descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.isFavorite },
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        if let limit { descriptor.fetchLimit = limit }
        return dedupedByIdentity(try context.fetch(descriptor))
    }

    /// Articles agrégés de plusieurs rubriques, du plus récent au plus ancien.
    func articles(feedIDs: [String], limit: Int? = nil) throws -> [Article] {
        guard !feedIDs.isEmpty else { return [] }
        let ids = Set(feedIDs)
        var descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { ids.contains($0.feedID) },
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        if let limit { descriptor.fetchLimit = limit }
        return dedupedByIdentity(try context.fetch(descriptor))
    }

    /// Purge les articles plus vieux que `days` jours et non favoris (borne la base),
    /// puis retire les doublons éventuels.
    func prune(olderThan days: Int = 30) throws {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.fetchedAt < cutoff && !$0.isFavorite }
        )
        for stale in try context.fetch(descriptor) { context.delete(stale) }
        try context.save()
        try pruneDuplicates()
    }

    /// Supprime les articles en double, en conservant une seule instance — de préférence
    /// celle en favori, sinon la plus ancienne. Nécessaire car, pour la compatibilité
    /// CloudKit, `Article.id` n'a plus de contrainte d'unicité SwiftData et certains
    /// flux publient le même lien avec des `guid` différents.
    func pruneDuplicates() throws {
        let all = try context.fetch(FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.fetchedAt)]
        ))
        var keep: [String: Article] = [:]
        var toDelete: [Article] = []
        for article in all {
            let key = identityKey(for: article)
            if let existing = keep[key] {
                if article.isFavorite && !existing.isFavorite {
                    toDelete.append(existing)      // on préfère garder le favori
                    keep[key] = article
                } else {
                    toDelete.append(article)
                }
            } else {
                keep[key] = article
            }
        }
        guard !toDelete.isEmpty else { return }
        for duplicate in toDelete { context.delete(duplicate) }
        try context.save()
    }

    /// Retire les doublons d'une liste déjà triée (conserve la 1ʳᵉ occurrence).
    private func dedupedByIdentity(_ articles: [Article]) -> [Article] {
        var seen = Set<String>()
        return articles.filter { seen.insert(identityKey(for: $0)).inserted }
    }

    private func identityKey(for article: Article) -> String {
        ParsedArticle.canonicalLink(from: article.link) ?? "id:\(article.id)"
    }
}

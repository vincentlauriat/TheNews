import WidgetKit
import SwiftUI

// MARK: - Bundle (@main)

@main
struct TheNewsWidgetBundle: WidgetBundle {
    var body: some Widget {
        TheNewsWidget()
    }
}

// MARK: - Timeline

struct TheNewsEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct TheNewsProvider: TimelineProvider {
    func placeholder(in context: Context) -> TheNewsEntry {
        TheNewsEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (TheNewsEntry) -> Void) {
        let snap = context.isPreview ? .sample : WidgetSnapshotStore.read()
        completion(TheNewsEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TheNewsEntry>) -> Void) {
        let entry = TheNewsEntry(date: Date(), snapshot: WidgetSnapshotStore.read())
        // Rafraîchit régulièrement ; l'app force aussi un reload après chaque fetch.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Widget

struct TheNewsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TheNewsWidget", provider: TheNewsProvider()) { entry in
            TheNewsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("TheNews")
        .description("Les derniers sujets suivis, tous journaux confondus.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Vue

struct TheNewsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TheNewsEntry

    private var maxItems: Int {
        switch family {
        case .systemSmall:  return 2
        case .systemMedium: return 3
        default:            return 6
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "newspaper.fill")
                Text("TheNews").fontWeight(.bold)
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if entry.snapshot.articles.isEmpty {
                Spacer()
                Text("Ouvre l'app pour charger l'actualité.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.snapshot.articles.prefix(maxItems)) { article in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(article.source.uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tint)
                        Text(article.title)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .lineLimit(family == .systemSmall ? 2 : 2)
                    }
                    if article.id != entry.snapshot.articles.prefix(maxItems).last?.id {
                        Divider()
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Échantillon (previews / placeholder)

extension WidgetSnapshot {
    static let sample = WidgetSnapshot(
        articles: [
            WidgetArticle(id: "1", title: "Crédit Agricole monte à 29,3 % dans Banco BPM",
                          source: "Les Echos", sectionTitle: "Finance & Marchés", publishedAt: Date()),
            WidgetArticle(id: "2", title: "Incendies : près de 1 000 hectares brûlés",
                          source: "Le Monde", sectionTitle: "À la une", publishedAt: Date()),
            WidgetArticle(id: "3", title: "Retraites : ce que prévoit la nouvelle réforme",
                          source: "Le Monde", sectionTitle: "Politique", publishedAt: Date()),
        ],
        generatedAt: Date()
    )
}

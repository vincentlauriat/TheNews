import SwiftUI

/// Sidebar : liste des articles de la rubrique, sectionnée par date, avec
/// recherche et bouton de rafraîchissement. Adaptée de `ItemListView` du template.
struct ArticleListView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Bindable var vm: FeedViewModel
    @Binding var selectedId: String?

    @State private var showingDigest = false
    @State private var digest: String?
    @State private var generatingDigest = false

    var body: some View {
        List(selection: $selectedId) {
            ForEach(vm.grouped, id: \.key) { group in
                Section(settings.t(group.key)) {
                    ForEach(group.items) { article in
                        ArticleRowView(article: article)
                            .tag(article.id)
                    }
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.plain)
        #endif
        .searchable(text: $vm.searchText, prompt: settings.t("search_placeholder"))
        .navigationTitle(vm.title(settings.t))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await generateDigest() }
                } label: {
                    Label(settings.t("digest"), systemImage: "sparkles")
                }
                .disabled(vm.filtered.isEmpty || generatingDigest)
                .help(settings.t("digest"))
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    vm.markAllRead(context: modelContext)
                } label: {
                    Label(settings.t("mark_all_read"), systemImage: "checkmark.circle")
                }
                .disabled(vm.articles.allSatisfy(\.isRead))
                .help(settings.t("mark_all_read"))
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await vm.refresh(context: modelContext) }
                } label: {
                    if vm.isLoading {
                        ProgressView().scaleEffect(0.65)
                    } else {
                        Label(settings.t("refresh"), systemImage: "arrow.clockwise")
                    }
                }
                .disabled(vm.isLoading)
                .help(settings.t("refresh_help"))
            }
        }
        .overlay {
            if vm.articles.isEmpty && !vm.isLoading {
                ContentUnavailableView(
                    settings.t("no_items_title"),
                    systemImage: "newspaper",
                    description: Text(settings.t("no_items_desc"))
                )
            }
        }
        .sheet(isPresented: $showingDigest) { digestSheet }
    }

    // MARK: - Synthèse IA (niveau liste)

    private var digestSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Label(settings.t("digest_subtitle"), systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if generatingDigest {
                        HStack(spacing: 10) { ProgressView(); Text(settings.t("summarizing")) }
                            .foregroundStyle(.secondary)
                    } else if let digest {
                        Text(digest).textSelection(.enabled)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle(settings.t("digest"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.t("ok")) { showingDigest = false }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 340)
        #endif
    }

    private func generateDigest() async {
        showingDigest = true
        generatingDigest = true
        digest = nil
        let titles = vm.filtered.map(\.title)
        digest = await ArticleSummarizer.digest(titles: titles, lang: settings.effectiveLang)
        generatingDigest = false
    }
}

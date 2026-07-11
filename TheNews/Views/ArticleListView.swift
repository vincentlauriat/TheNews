import SwiftUI

/// Sidebar : liste des articles de la rubrique, sectionnée par date, avec
/// recherche et bouton de rafraîchissement. Adaptée de `ItemListView` du template.
struct ArticleListView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Bindable var vm: FeedViewModel
    @Binding var selectedId: String?

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
        .onSubmit(of: .search) {
            Task { await vm.smartSearch(lang: settings.effectiveLang) }
        }
        .task(id: vm.selection) {
            guard settings.smartAlertsEnabled else { return }
            await vm.refineAlertsIfNeeded(context: modelContext, lang: settings.effectiveLang)
        }
        .navigationTitle(vm.title(settings.t))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    selectedId = nil
                    Task {
                        await vm.generateDigest(
                            lang: settings.effectiveLang,
                            length: settings.digestLength,
                            format: settings.digestFormat,
                            tone: settings.digestTone,
                            count: settings.digestCount
                        )
                    }
                } label: {
                    Label(settings.t("digest"), systemImage: "sparkles")
                }
                .disabled(vm.filtered.isEmpty || vm.isGeneratingDigest)
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
                    Task { await vm.refresh(context: modelContext, lang: settings.effectiveLang) }
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
    }
}

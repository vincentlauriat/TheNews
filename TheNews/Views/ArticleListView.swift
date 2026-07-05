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
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles").foregroundStyle(.tint)
                        Text(settings.t("digest_subtitle"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if generatingDigest {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(settings.t("summarizing")).foregroundStyle(.secondary)
                        }
                        .padding(.top, 24)
                    } else if let digest, !digest.isEmpty {
                        digestBody(digest)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
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
        .frame(minWidth: 460, minHeight: 380)
        #endif
    }

    /// Rend la synthèse : puces stylées (si le modèle a produit une liste) ou
    /// paragraphes ; le gras Markdown est rendu.
    @ViewBuilder
    private func digestBody(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(digestLines(text).enumerated()), id: \.offset) { _, item in
                if item.isBullet {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(.tint)
                            .padding(.top, 7)
                        Text(markdown(item.text))
                            .font(.callout)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(.tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    Text(markdown(item.text))
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private struct DigestLine { let text: String; let isBullet: Bool }

    /// Découpe la synthèse en lignes en détectant les marqueurs de puce.
    private func digestLines(_ text: String) -> [DigestLine] {
        text.split(separator: "\n").compactMap { raw -> DigestLine? in
            var line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return nil }
            var isBullet = false
            for marker in ["- ", "• ", "* ", "– ", "· "] where line.hasPrefix(marker) {
                line = String(line.dropFirst(marker.count)); isBullet = true; break
            }
            return DigestLine(text: line, isBullet: isBullet)
        }
    }

    private func markdown(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s)) ?? AttributedString(s)
    }

    private func generateDigest() async {
        showingDigest = true
        generatingDigest = true
        digest = nil
        let titles = vm.filtered.map(\.title)
        digest = await ArticleSummarizer.digest(
            titles: titles,
            lang: settings.effectiveLang,
            length: settings.digestLength,
            format: settings.digestFormat,
            tone: settings.digestTone,
            count: settings.digestCount
        )
        generatingDigest = false
    }
}

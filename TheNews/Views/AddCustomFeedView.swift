import SwiftUI
import SwiftData

/// Formulaire d'ajout d'un flux RSS personnalisé (titre + URL). L'URL est validée
/// par une sonde réseau (le flux doit renvoyer au moins un article) avant l'ajout.
struct AddCustomFeedView: View {
    let editingFeed: CustomFeed?

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var urlString: String
    @State private var isValidating = false
    @State private var errorMessage: String?

    init(editingFeed: CustomFeed? = nil) {
        self.editingFeed = editingFeed
        _title = State(initialValue: editingFeed?.title ?? "")
        _urlString = State(initialValue: editingFeed?.urlString ?? "")
    }

    private var isEditing: Bool { editingFeed != nil }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
        && !urlString.trimmingCharacters(in: .whitespaces).isEmpty
        && !isValidating
    }

    var body: some View {
        Form {
            Section {
                TextField(settings.t("feed_title"), text: $title)
            } footer: {
                Text(settings.t("feed_title_footer"))
            }

            Section {
                TextField(settings.t("feed_url"), text: $urlString)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                    .autocorrectionDisabled()
            } header: {
                Text(settings.t("feed_url"))
            } footer: {
                Text(settings.t("feed_url_footer"))
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(settings.t(isEditing ? "feed_edit" : "feed_add"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(settings.t("cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isValidating {
                    ProgressView()
                } else {
                    Button(settings.t(isEditing ? "save" : "add")) { Task { await saveFeed() } }
                        .disabled(!canSave)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 300)
        #endif
    }

    private func saveFeed() async {
        isValidating = true
        errorMessage = nil
        do {
            try await CustomFeedStore.validate(urlString: urlString)
            let store = CustomFeedStore(context: modelContext)
            if let editingFeed {
                try store.update(editingFeed, title: title, urlString: urlString)
            } else {
                try store.add(title: title, urlString: urlString)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isValidating = false
    }
}

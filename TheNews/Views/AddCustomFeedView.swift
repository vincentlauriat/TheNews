import SwiftUI
import SwiftData

/// Formulaire d'ajout d'un flux RSS personnalisé (titre + URL). L'URL est validée
/// par une sonde réseau (le flux doit renvoyer au moins un article) avant l'ajout.
struct AddCustomFeedView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var urlString = ""
    @State private var isValidating = false
    @State private var errorMessage: String?

    private var canAdd: Bool {
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
        .navigationTitle(settings.t("feed_add"))
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
                    Button(settings.t("add")) { Task { await addFeed() } }
                        .disabled(!canAdd)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 300)
        #endif
    }

    private func addFeed() async {
        isValidating = true
        errorMessage = nil
        do {
            try await CustomFeedStore.validate(urlString: urlString)
            try CustomFeedStore(context: modelContext).add(title: title, urlString: urlString)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isValidating = false
    }
}

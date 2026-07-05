import SwiftUI
import SwiftData

/// Formulaire de création / édition d'un sujet de veille (libellé + mots-clés).
struct WatchTopicEditor: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Sujet à éditer, ou `nil` pour une création.
    var topic: WatchTopic?

    @State private var label = ""
    @State private var keywordsText = ""
    @State private var notify = true

    private var parsedKeywords: [String] {
        keywordsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty && !parsedKeywords.isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField(settings.t("topic_label"), text: $label)
            } footer: {
                Text(settings.t("topic_label_footer"))
            }

            Section {
                TextField(settings.t("topic_keywords"), text: $keywordsText, axis: .vertical)
                    .lineLimit(1...4)
            } header: {
                Text(settings.t("topic_keywords"))
            } footer: {
                Text(settings.t("topic_keywords_footer"))
            }

            Section {
                Toggle(settings.t("topic_notify"), isOn: $notify)
            } footer: {
                Text(settings.t("topic_notify_footer"))
            }
        }
        .formStyle(.grouped)
        .navigationTitle(settings.t(topic == nil ? "topic_new" : "topic_edit"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(settings.t("cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(settings.t("save")) { save() }.disabled(!canSave)
            }
        }
        .onAppear {
            if let topic {
                label = topic.label
                keywordsText = topic.keywordsText
                notify = topic.notify
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 360)
        #endif
    }

    private func save() {
        if let topic {
            topic.label = label
            topic.keywords = parsedKeywords
            topic.notify = notify
        } else {
            modelContext.insert(WatchTopic(label: label, keywords: parsedKeywords, notify: notify))
        }
        try? modelContext.save()
        dismiss()
    }
}

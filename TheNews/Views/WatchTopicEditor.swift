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
    @State private var keywords: [String] = []
    @State private var notify = true
    @State private var isEnabled = true

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty && !keywords.isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField(settings.t("topic_label"), text: $label)
            } footer: {
                Text(settings.t("topic_label_footer"))
            }

            Section {
                KeywordChipField(keywords: $keywords)
            } header: {
                Text(settings.t("topic_keywords"))
            } footer: {
                Text(settings.t("topic_keywords_footer"))
            }

            Section {
                Toggle(settings.t("topic_enabled"), isOn: $isEnabled)
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
                keywords = topic.keywords
                notify = topic.notify
                isEnabled = topic.isEnabled
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 360)
        #endif
    }

    private func save() {
        if let topic {
            topic.label = label
            topic.keywords = keywords
            topic.notify = notify
            topic.isEnabled = isEnabled
        } else {
            modelContext.insert(WatchTopic(label: label, keywords: keywords, isEnabled: isEnabled, notify: notify))
        }
        try? modelContext.save()
        dismiss()
    }
}

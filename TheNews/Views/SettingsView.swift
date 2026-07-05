import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @State private var notifications = NotificationService.shared

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                switch notifications.status {
                case .authorized, .provisional:
                    Label(settings.t("notif_on"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Button(settings.t("notif_test")) {
                        Task { await notifications.sendTest() }
                    }
                case .denied:
                    Label(settings.t("notif_denied"), systemImage: "xmark.circle.fill")
                        .foregroundStyle(.orange)
                default:
                    Button(settings.t("notif_enable")) {
                        Task { await notifications.requestAuthorization() }
                    }
                }
            } header: {
                Text(settings.t("notif_section"))
            } footer: {
                Text(settings.t("notif_footer"))
            }
            .task { await notifications.refreshStatus() }

            Section {
                Toggle(settings.t("briefing_enable"), isOn: $settings.briefingEnabled)
                if settings.briefingEnabled {
                    Picker(settings.t("briefing_hour"), selection: $settings.briefingHour) {
                        ForEach(0..<24, id: \.self) { h in
                            Text(String(format: "%02d:00", h)).tag(h)
                        }
                    }
                }
            } header: {
                Text(settings.t("briefing_section"))
            } footer: {
                Text(settings.t("briefing_footer"))
            }
            .onChange(of: settings.briefingEnabled) { _, _ in rescheduleBriefing() }
            .onChange(of: settings.briefingHour) { _, _ in rescheduleBriefing() }

            #if os(iOS)
            Section {
                Picker(settings.t("swipe_mode"), selection: $settings.swipeModeRaw) {
                    ForEach(ArticleSwipeMode.allCases) { mode in
                        Text(settings.t(mode.titleKey)).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text(settings.t("swipe_section"))
            } footer: {
                Text(settings.t("swipe_footer"))
            }
            #endif

            Section {
                Picker(settings.t("digest_length"), selection: $settings.digestLengthRaw) {
                    ForEach(DigestLength.allCases) { Text(settings.t($0.titleKey)).tag($0.rawValue) }
                }
                Picker(settings.t("digest_format"), selection: $settings.digestFormatRaw) {
                    ForEach(DigestFormat.allCases) { Text(settings.t($0.titleKey)).tag($0.rawValue) }
                }
                Picker(settings.t("digest_tone"), selection: $settings.digestToneRaw) {
                    ForEach(DigestTone.allCases) { Text(settings.t($0.titleKey)).tag($0.rawValue) }
                }
                Picker(settings.t("digest_count"), selection: $settings.digestCount) {
                    ForEach([15, 25, 50], id: \.self) { Text("\($0)").tag($0) }
                }
            } header: {
                Text(settings.t("digest_section"))
            } footer: {
                Text(settings.t("digest_section_footer"))
            }

            Section(settings.t("settings_appearance")) {
                Picker(settings.t("settings_appearance"), selection: $settings.appearanceRaw) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(settings.t(mode.titleKey)).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section(settings.t("settings_language")) {
                Picker(settings.t("settings_language"), selection: $settings.languageRaw) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang == .system ? settings.t("language_system") : lang.nativeName)
                            .tag(lang.rawValue)
                    }
                }
                .labelsHidden()
            }

            Section(settings.t("settings_about")) {
                Text(settings.t("settings_about_text"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .frame(width: 460, height: 420)
        #endif
    }

    /// (Re)programme le briefing quotidien selon les réglages courants.
    private func rescheduleBriefing() {
        Task {
            await notifications.scheduleDailyBriefing(
                enabled: settings.briefingEnabled,
                hour: settings.briefingHour
            )
        }
    }
}

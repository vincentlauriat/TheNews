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
}

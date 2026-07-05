import SwiftUI

struct EmptySelectionView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ContentUnavailableView(
            settings.t("empty_title"),
            systemImage: "square.dashed",
            description: Text(settings.t("empty_desc"))
        )
        .foregroundStyle(.secondary)
    }
}

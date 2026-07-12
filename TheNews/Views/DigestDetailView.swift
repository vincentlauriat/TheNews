import SwiftUI

/// Synthèse IA affichée dans la zone de détail (`ContentView`), à la place du
/// panneau article — plutôt que dans une fenêtre séparée. `vm.showingDigest`
/// pilote cet affichage ; sélectionner un article ailleurs le referme
/// (cf. `FeedViewModel.select(_:)`).
struct DigestDetailView: View {
    @Environment(AppSettings.self) private var settings
    @Bindable var vm: FeedViewModel

    /// Taille de police du texte de la synthèse, ajustable via le slider —
    /// persistée pour ne pas avoir à la régler à chaque ouverture.
    @AppStorage("digestFontSize") private var digestFontSize: Double = 15
    @State private var narrator = SpeechNarrator()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").foregroundStyle(.tint)
                        .accessibilityHidden(true)   // décoratif : redondant avec le texte à côté
                    Text(settings.t("digest_subtitle"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !vm.isGeneratingDigest, let digest = vm.digest, !digest.isEmpty {
                    HStack(spacing: 16) {
                        fontSizeControl
                        listenButton(for: digest)
                    }
                }

                if vm.isGeneratingDigest {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(settings.t("summarizing")).foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)
                } else if let digest = vm.digest, !digest.isEmpty {
                    digestBody(digest)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .navigationTitle(settings.t("digest"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        // Sur macOS, cet écran remplace parfois toute la zone de contenu (mode carte,
        // Briefing) — pas seulement le panneau détail à côté d'une liste toujours visible.
        // Sans ce bouton, rien ne permet d'en sortir dans ce cas.
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(settings.t("cancel")) { vm.showingDigest = false }
            }
        }
        #endif
        .onDisappear { narrator.stop() }
    }

    private var fontSizeControl: some View {
        HStack(spacing: 10) {
            Text("A").font(.system(size: 12)).foregroundStyle(.secondary)
            Slider(value: $digestFontSize, in: 12...26, step: 1)
                .frame(maxWidth: 160)
                .accessibilityLabel(settings.t("digest_font_size"))
            Text("A").font(.system(size: 20)).foregroundStyle(.secondary)
        }
    }

    private func listenButton(for digest: String) -> some View {
        Button {
            if narrator.isSpeaking {
                narrator.stop()
            } else {
                narrator.speak(digest, lang: settings.effectiveLang)
            }
        } label: {
            Label(
                settings.t(narrator.isSpeaking ? "stop_listening" : "listen"),
                systemImage: narrator.isSpeaking ? "stop.fill" : "speaker.wave.2.fill"
            )
        }
        .buttonStyle(.bordered)
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
                            .accessibilityHidden(true)   // puce décorative, pas un contenu à énoncer
                        Text(markdown(item.text))
                            .font(.system(size: digestFontSize))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(.tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    Text(markdown(item.text))
                        .font(.system(size: digestFontSize))
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
}

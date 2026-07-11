import ScreenSaver
import SwiftUI

/// Point d'entrée du bundle `.saver` (classe déclarée via `NSPrincipalClass` dans
/// Info.plist). Se contente d'héberger la hiérarchie SwiftUI du Briefing dans une
/// `NSHostingView` — la rotation du hero est pilotée par SwiftUI lui-même
/// (`BriefingScreenSaverContent`), pas par `animateOneFrame`, qui ne fait rien.
@objc(NewsScreenSaverView)
final class NewsScreenSaverView: ScreenSaverView {
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 30.0
        installHostingView(isPreview: isPreview)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installHostingView(isPreview: isPreview)
    }

    private func installHostingView(isPreview: Bool) {
        let hosting = NSHostingView(rootView: BriefingScreenSaverContent(isPreview: isPreview))
        hosting.frame = bounds
        hosting.autoresizingMask = [.width, .height]
        addSubview(hosting)
    }

    override func animateOneFrame() {}

    override var hasConfigureSheet: Bool { false }
}

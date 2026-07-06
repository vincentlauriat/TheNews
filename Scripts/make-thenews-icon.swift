#!/usr/bin/env swift
// Génère le jeu d'icônes de TheNews dans AppIcon.appiconset.
// Design : carré arrondi bleu nuit profond avec halo satiné, bec de plume
// (stylographe) doré à fente et trou d'air découpés en réserve, filet doré
// rehaussé d'un losange en pied — symbole intemporel de l'écriture/presse,
// registre papeterie de luxe, sans texte. Usage : ./Scripts/make-thenews-icon.swift
import AppKit

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let root = scriptDir.deletingLastPathComponent()
let fm = FileManager.default
guard let assets = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        .first(where: { $0.pathExtension == "" && fm.fileExists(atPath: $0.appendingPathComponent("Assets.xcassets").path) })
        .map({ $0.appendingPathComponent("Assets.xcassets/AppIcon.appiconset") }) else {
    FileHandle.standardError.write(Data("could not locate AppIcon.appiconset\n".utf8))
    exit(1)
}

let goldLight = (r: 0.97, g: 0.86, b: 0.58)
let goldDark = (r: 0.66, g: 0.48, b: 0.16)

// Silhouette du bec de plume, pointe vers le bas, fente et trou d'air en
// réserve (winding rule even-odd → ces sous-tracés deviennent des trous).
func nibPath(size s: CGFloat) -> NSBezierPath {
    let cx = s / 2
    let halfWidth = s * 0.17
    let shoulderY = s * 0.585
    let domePeakY = s * 0.72
    let tipY = s * 0.295

    let path = NSBezierPath()
    path.windingRule = .evenOdd

    let leftShoulder = NSPoint(x: cx - halfWidth, y: shoulderY)
    let rightShoulder = NSPoint(x: cx + halfWidth, y: shoulderY)
    let tip = NSPoint(x: cx, y: tipY)

    path.move(to: leftShoulder)
    path.curve(to: rightShoulder,
               controlPoint1: NSPoint(x: cx - halfWidth * 0.55, y: domePeakY),
               controlPoint2: NSPoint(x: cx + halfWidth * 0.55, y: domePeakY))
    path.curve(to: tip,
               controlPoint1: NSPoint(x: cx + halfWidth * 0.92, y: shoulderY - (shoulderY - tipY) * 0.35),
               controlPoint2: NSPoint(x: cx + halfWidth * 0.05, y: tipY + (shoulderY - tipY) * 0.22))
    path.curve(to: leftShoulder,
               controlPoint1: NSPoint(x: cx - halfWidth * 0.05, y: tipY + (shoulderY - tipY) * 0.22),
               controlPoint2: NSPoint(x: cx - halfWidth * 0.92, y: shoulderY - (shoulderY - tipY) * 0.35))
    path.close()

    // Fente d'encre : fin triangle du voisinage de la pointe jusqu'au trou d'air.
    let slitHalf = s * 0.009
    let slitTopY = s * 0.505
    let slitTipY = tipY + s * 0.02
    path.move(to: NSPoint(x: cx, y: slitTipY))
    path.line(to: NSPoint(x: cx - slitHalf, y: slitTopY))
    path.line(to: NSPoint(x: cx + slitHalf, y: slitTopY))
    path.close()

    // Trou d'air.
    let holeCenter = NSPoint(x: cx, y: slitTopY + s * 0.032)
    let holeRadius = s * 0.021
    path.appendOval(in: NSRect(x: holeCenter.x - holeRadius, y: holeCenter.y - holeRadius,
                                width: holeRadius * 2, height: holeRadius * 2))
    return path
}

// Rend un NSBezierPath dans un masque niveaux de gris (blanc = visible) afin
// de le remplir ensuite avec un dégradé or via CGContext.clip(to:mask:).
func pathMask(size: CGFloat, path: NSBezierPath) -> CGImage {
    let px = Int(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 1, hasAlpha: false, isPlanar: false,
        colorSpaceName: .deviceWhite, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.black.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()
    NSColor.white.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.cgImage!
}

func render(_ size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    let radius = s * 0.22
    let clip = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    clip.addClip()

    // Fond dégradé bleu nuit profond.
    let bg = NSGradient(colors: [
        NSColor(calibratedRed: 0.11, green: 0.19, blue: 0.40, alpha: 1),
        NSColor(calibratedRed: 0.03, green: 0.05, blue: 0.11, alpha: 1),
    ])!
    bg.draw(in: rect, angle: -90)

    // Halo satiné en partie haute (effet laqué/luxe, très subtil).
    let glossPath = NSBezierPath(ovalIn: NSRect(x: -s * 0.2, y: s * 0.15, width: s * 1.4, height: s * 1.4))
    let gloss = NSGradient(colors: [
        NSColor(calibratedWhite: 1, alpha: 0.16),
        NSColor(calibratedWhite: 1, alpha: 0),
    ])!
    gloss.draw(in: glossPath, relativeCenterPosition: NSPoint(x: 0, y: 0.55))

    // Bec de plume : dégradé or appliqué via masque (fente + trou en réserve).
    let mask = pathMask(size: s, path: nibPath(size: s))
    ctx.saveGState()
    ctx.clip(to: rect, mask: mask)
    let goldGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            CGColor(red: goldLight.r, green: goldLight.g, blue: goldLight.b, alpha: 1),
            CGColor(red: goldDark.r, green: goldDark.g, blue: goldDark.b, alpha: 1),
        ] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(goldGradient, start: CGPoint(x: 0, y: s * 0.72), end: CGPoint(x: 0, y: s * 0.28), options: [])
    ctx.restoreGState()

    // Filet doré en pied, rompu par un losange — clin d'œil au masthead de presse.
    let lineY = s * 0.155
    let lineH = s * 0.012
    let gapHalf = s * 0.032
    let lineHalfWidth = s * 0.155
    let goldSolid = NSColor(calibratedRed: goldDark.r + (goldLight.r - goldDark.r) * 0.6,
                             green: goldDark.g + (goldLight.g - goldDark.g) * 0.6,
                             blue: goldDark.b + (goldLight.b - goldDark.b) * 0.6, alpha: 0.92)
    goldSolid.setFill()
    NSBezierPath(roundedRect: NSRect(x: s / 2 - lineHalfWidth, y: lineY - lineH / 2, width: lineHalfWidth - gapHalf, height: lineH),
                 xRadius: lineH / 2, yRadius: lineH / 2).fill()
    NSBezierPath(roundedRect: NSRect(x: s / 2 + gapHalf, y: lineY - lineH / 2, width: lineHalfWidth - gapHalf, height: lineH),
                 xRadius: lineH / 2, yRadius: lineH / 2).fill()
    let diamond = NSBezierPath()
    let d = s * 0.024
    diamond.move(to: NSPoint(x: s / 2, y: lineY + d))
    diamond.line(to: NSPoint(x: s / 2 + d, y: lineY))
    diamond.line(to: NSPoint(x: s / 2, y: lineY - d))
    diamond.line(to: NSPoint(x: s / 2 - d, y: lineY))
    diamond.close()
    goldSolid.setFill()
    diamond.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    let url = assets.appendingPathComponent("icon_\(size).png")
    try! render(size).write(to: url)
    print("wrote \(url.lastPathComponent)")
}
print("✅ icône TheNews générée")

// Même design, rendu nativement à chaque taille attendue par l'AppIcon watchOS
// (évite de ré-échantillonner grossièrement le master 1024 pour les tailles
// notification/appLauncher très petites).
let watchAssets = root.appendingPathComponent("TheNewsWatch/Assets.xcassets/AppIcon.appiconset")
if fm.fileExists(atPath: watchAssets.path) {
    let watchSizes = [44, 48, 55, 58, 60, 64, 66, 80, 87, 88, 92, 100, 102, 108, 172, 196, 216, 234, 258, 1024]
    for size in watchSizes {
        let url = watchAssets.appendingPathComponent("\(size).png")
        try! render(size).write(to: url)
        print("wrote (watch) \(url.lastPathComponent)")
    }
    print("✅ icône TheNewsWatch générée")
}

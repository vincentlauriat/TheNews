#!/usr/bin/env swift
// Génère le jeu d'icônes de TheNews dans AppIcon.appiconset.
// Design : carré arrondi bleu nuit profond avec halo satiné, monogramme « TN »
// en Baskerville gras et dégradé or (champagne → bronze), filet doré rehaussé
// d'un losange en pied — registre éditorial haut de gamme, à mi-chemin entre
// masthead de presse et plaque gravée. Usage : ./Scripts/make-thenews-icon.swift
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

// Rend le monogramme dans un masque niveaux de gris (blanc = visible) afin de
// pouvoir le remplir ensuite avec un dégradé or via CGContext.clip(to:mask:).
func textMask(size: CGFloat, text: String, font: NSFont) -> CGImage {
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

    let para = NSMutableParagraphStyle(); para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: NSColor.white, .paragraphStyle: para,
    ]
    let ns = text as NSString
    let tsize = ns.size(withAttributes: attrs)
    let ty = (size - tsize.height) / 2 + size * 0.05
    ns.draw(at: NSPoint(x: (size - tsize.width) / 2, y: ty), withAttributes: attrs)
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

    // Fond dégradé bleu nuit profond (plus riche/contrasté que la v1).
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

    // Monogramme « TN » : dégradé or appliqué via masque de texte.
    let fontSize = s * 0.42
    let font = NSFont(name: "Baskerville-Bold", size: fontSize)
        ?? NSFont(name: "Georgia-Bold", size: fontSize)
        ?? NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let mask = textMask(size: s, text: "TN", font: font)
    ctx.saveGState()
    ctx.clip(to: rect, mask: mask)
    let goldGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            CGColor(red: goldLight.r, green: goldLight.g, blue: goldLight.b, alpha: 1),
            CGColor(red: goldDark.r, green: goldDark.g, blue: goldDark.b, alpha: 1),
        ] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(goldGradient, start: CGPoint(x: 0, y: rect.height), end: CGPoint(x: 0, y: 0), options: [])
    ctx.restoreGState()

    // Filet doré en pied, rompu par un losange — clin d'œil au masthead de presse.
    let lineY = s * 0.225
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

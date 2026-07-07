#!/usr/bin/env swift
// Génère le jeu d'icônes de TheNews dans AppIcon.appiconset.
// Design : carré arrondi bleu nuit profond avec halo satiné, rosace à 8
// pointes façon pierre taillée (facettes alternées assombries, centre serti
// bleu nuit), filet doré rehaussé d'un losange en pied — registre joaillerie
// de luxe, sans texte. Usage : ./Scripts/make-thenews-icon.swift
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

// Géométrie de la rosace : étoile régulière à 8 pointes (alternance rayon
// long / rayon court), centrée légèrement au-dessus du milieu du cadre pour
// équilibrer avec le filet en pied.
func starGeometry(size s: CGFloat) -> (center: NSPoint, outerRadius: CGFloat, innerRadius: CGFloat, points: Int) {
    (NSPoint(x: s / 2, y: s * 0.545), s * 0.30, s * 0.115, 8)
}

func starPath(size s: CGFloat) -> NSBezierPath {
    let geo = starGeometry(size: s)
    let path = NSBezierPath()
    for i in 0..<(geo.points * 2) {
        let r = i % 2 == 0 ? geo.outerRadius : geo.innerRadius
        let angle = CGFloat.pi / CGFloat(geo.points) * CGFloat(i) + .pi / 2
        let point = NSPoint(x: geo.center.x + cos(angle) * r, y: geo.center.y + sin(angle) * r)
        i == 0 ? path.move(to: point) : path.line(to: point)
    }
    path.close()
    return path
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

    // Rosace : dégradé or appliqué en clip direct sur le tracé de l'étoile.
    let geo = starGeometry(size: s)
    ctx.saveGState()
    starPath(size: s).addClip()
    let goldGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            CGColor(red: goldLight.r, green: goldLight.g, blue: goldLight.b, alpha: 1),
            CGColor(red: goldDark.r, green: goldDark.g, blue: goldDark.b, alpha: 1),
        ] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(goldGradient,
                           start: CGPoint(x: 0, y: geo.center.y + geo.outerRadius),
                           end: CGPoint(x: 0, y: geo.center.y - geo.outerRadius), options: [])
    ctx.restoreGState()

    // Facettes alternées assombries (effet pierre taillée), fondu multiply.
    ctx.saveGState()
    ctx.setBlendMode(.multiply)
    for i in 0..<geo.points where i % 2 == 1 {
        let angleOuter = CGFloat.pi / CGFloat(geo.points) * CGFloat(i * 2) + .pi / 2
        let angleInner = CGFloat.pi / CGFloat(geo.points) * CGFloat(i * 2 + 1) + .pi / 2
        let kite = NSBezierPath()
        kite.move(to: geo.center)
        kite.line(to: NSPoint(x: geo.center.x + cos(angleOuter) * geo.outerRadius,
                              y: geo.center.y + sin(angleOuter) * geo.outerRadius))
        kite.line(to: NSPoint(x: geo.center.x + cos(angleInner) * geo.innerRadius,
                              y: geo.center.y + sin(angleInner) * geo.innerRadius))
        kite.close()
        NSColor(calibratedRed: 0.47, green: 0.35, blue: 0.08, alpha: 0.35).setFill()
        kite.fill()
    }
    ctx.restoreGState()

    // Centre serti bleu nuit.
    NSColor(calibratedRed: 0.03, green: 0.05, blue: 0.11, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: geo.center.x - s * 0.05, y: geo.center.y - s * 0.05,
                               width: s * 0.10, height: s * 0.10)).fill()

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

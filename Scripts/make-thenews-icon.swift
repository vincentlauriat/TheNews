#!/usr/bin/env swift
// Génère le jeu d'icônes de TheNews dans AppIcon.appiconset.
// Design : carré arrondi, dégradé bleu nuit (héritage NewsWatch), monogramme serif
// blanc « TN » et bandeau saumon en pied (clin d'œil au papier des Echos) —
// symbolise l'agrégation multi-journaux. Usage : ./Scripts/make-thenews-icon.swift
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

func render(_ size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    let radius = s * 0.22
    let clip = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    clip.addClip()

    // Fond dégradé bleu nuit.
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.12, green: 0.20, blue: 0.42, alpha: 1),
        NSColor(calibratedRed: 0.06, green: 0.10, blue: 0.24, alpha: 1),
    ])!
    gradient.draw(in: rect, angle: -90)

    // Bandeau saumon en pied (Les Echos).
    let bandH = s * 0.14
    let band = NSRect(x: 0, y: 0, width: s, height: bandH)
    NSColor(calibratedRed: 0.98, green: 0.80, blue: 0.66, alpha: 1).setFill()
    band.fill()

    // Monogramme serif « TN ».
    let fontSize = s * 0.44
    let font = NSFont(name: "Georgia-Bold", size: fontSize)
        ?? NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .paragraphStyle: para,
    ]
    let text = "TN" as NSString
    let tsize = text.size(withAttributes: attrs)
    let ty = (s - tsize.height) / 2 + bandH * 0.35
    text.draw(at: NSPoint(x: (s - tsize.width) / 2, y: ty), withAttributes: attrs)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    let url = assets.appendingPathComponent("icon_\(size).png")
    try! render(size).write(to: url)
    print("wrote \(url.lastPathComponent)")
}
print("✅ icône TheNews générée")

#!/usr/bin/env swift
// Generates a neutral placeholder app icon set into the AppIcon.appiconset.
// A rounded blue-gradient square with the app's initial. Replace with your real
// artwork before shipping. Usage: ./Scripts/make-app-icon.swift [Letter]
import AppKit

let letter = CommandLine.arguments.count >= 2 ? String(CommandLine.arguments[1].prefix(1)) : "A"

// Resolve the appiconset next to this script (…/Scripts/../TheNews/Assets…).
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
    // Draw into a bitmap of EXACTLY `size`×`size` pixels. NSImage.lockFocus()
    // would render at the screen's backing scale (2× on Retina) and double every
    // icon, which iOS rejects ("did not have any applicable content").
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    let radius = s * 0.22
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.26, green: 0.55, blue: 0.98, alpha: 1),
        NSColor(calibratedRed: 0.13, green: 0.36, blue: 0.86, alpha: 1),
    ])!
    gradient.draw(in: path, angle: -90)

    let fontSize = s * 0.55
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: para,
    ]
    let text = letter.uppercased() as NSString
    let tsize = text.size(withAttributes: attrs)
    text.draw(at: NSPoint(x: (s - tsize.width) / 2, y: (s - tsize.height) / 2), withAttributes: attrs)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    let url = assets.appendingPathComponent("icon_\(size).png")
    try! render(size).write(to: url)
    print("wrote \(url.lastPathComponent)")
}
print("✅ placeholder icon set generated (letter: \(letter))")

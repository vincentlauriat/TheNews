#!/usr/bin/env swift
// Génère les assets « App Icon & Top Shelf Image » de TheNewsTV : couches
// Back/Middle/Front de l'App Icon (parallaxe tvOS), icône App Store à plat,
// et les deux bannières Top Shelf. Même design que l'icône principale (rosace
// à 8 pointes facettée sur fond bleu nuit, cf. make-thenews-icon.swift),
// redécoupé en couches. Usage : ./Scripts/make-thenewstv-icon.swift
import AppKit

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let root = scriptDir.deletingLastPathComponent()
let brand = root.appendingPathComponent("TheNewsTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets")
let fm = FileManager.default
guard fm.fileExists(atPath: brand.path) else {
    FileHandle.standardError.write(Data("could not locate \(brand.path)\n".utf8))
    exit(1)
}

let goldLight = (r: 0.97, g: 0.86, b: 0.58)
let goldDark = (r: 0.66, g: 0.48, b: 0.16)

// Géométrie de la rosace, identique à make-thenews-icon.swift, inscrite dans
// un carré de côté s.
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

// Fond dégradé bleu nuit, plein cadre (pas d'arrondi : le système gère la
// forme des icônes tvOS).
func drawBackground(ctx: CGContext, rect: CGRect) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    let bg = NSGradient(colors: [
        NSColor(calibratedRed: 0.11, green: 0.19, blue: 0.40, alpha: 1),
        NSColor(calibratedRed: 0.03, green: 0.05, blue: 0.11, alpha: 1),
    ])!
    bg.draw(in: rect, angle: -90)
    NSGraphicsContext.restoreGraphicsState()
}

// Halo satiné, taille relative à la hauteur du cadre — couche du milieu.
func drawGloss(ctx: CGContext, canvas: CGRect) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    let s = canvas.height
    let glossPath = NSBezierPath(ovalIn: NSRect(x: canvas.midX - s * 0.7, y: canvas.minY + s * 0.15, width: s * 1.4, height: s * 1.4))
    let gloss = NSGradient(colors: [
        NSColor(calibratedWhite: 1, alpha: 0.16),
        NSColor(calibratedWhite: 1, alpha: 0),
    ])!
    gloss.draw(in: glossPath, relativeCenterPosition: NSPoint(x: 0, y: 0.55))
    NSGraphicsContext.restoreGraphicsState()
}

// Rosace + filet doré/losange, inscrits dans un carré de côté
// `canvas.height * glyphScale`, centré dans `canvas` — couche du dessus.
func drawGlyph(ctx: CGContext, canvas: CGRect, glyphScale: CGFloat) {
    let s = canvas.height * glyphScale
    let originX = canvas.midX - s / 2
    let originY = canvas.midY - s / 2

    ctx.saveGState()
    ctx.translateBy(x: originX, y: originY)

    let geo = starGeometry(size: s)

    // Toutes les opérations AppKit (addClip/fill) ci-dessous ont besoin que
    // NSGraphicsContext.current pointe explicitement vers `ctx` — sans ce
    // repointage, addClip()/fill() ciblent le contexte AppKit courant (nil ou
    // périmé) et dessinent hors-clip ou pas du tout (bug constaté : la rosace
    // se retrouvait non découpée). Même pattern que le filet doré plus bas.
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

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

    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
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

    ctx.restoreGState()
}

func makeBitmap(width: Int, height: Int) -> (NSBitmapImageRep, CGContext) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    return (rep, ctx)
}

// Aplatit un rep RGBA en RGB opaque (sans canal alpha) via un CGContext bas
// niveau (kCGImageAlphaNoneSkipLast) — requis pour l'icône App Store et les
// bannières Top Shelf.
func flattenOpaque(_ rep: NSBitmapImageRep) -> Data {
    let cgImage = rep.cgImage!
    let width = cgImage.width, height = cgImage.height
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                         space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    let outRep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return outRep.representation(using: .png, properties: [:])!
}

func png(_ rep: NSBitmapImageRep) -> Data {
    return rep.representation(using: .png, properties: [:])!
}

// Couches transparentes (parallaxe) : back = fond seul, middle = halo seul,
// front = glyphe seul.
func renderBack(width: Int, height: Int) -> Data {
    let (rep, ctx) = makeBitmap(width: width, height: height)
    drawBackground(ctx: ctx, rect: CGRect(x: 0, y: 0, width: width, height: height))
    return png(rep)
}

func renderMiddle(width: Int, height: Int) -> Data {
    let (rep, ctx) = makeBitmap(width: width, height: height)
    drawGloss(ctx: ctx, canvas: CGRect(x: 0, y: 0, width: width, height: height))
    return png(rep)
}

func renderFront(width: Int, height: Int, glyphScale: CGFloat) -> Data {
    let (rep, ctx) = makeBitmap(width: width, height: height)
    drawGlyph(ctx: ctx, canvas: CGRect(x: 0, y: 0, width: width, height: height), glyphScale: glyphScale)
    return png(rep)
}

// Composite à plat, opaque (sans canal alpha) : App Store + Top Shelf.
func renderFlat(width: Int, height: Int, glyphScale: CGFloat) -> Data {
    let (rep, ctx) = makeBitmap(width: width, height: height)
    let rect = CGRect(x: 0, y: 0, width: width, height: height)
    drawBackground(ctx: ctx, rect: rect)
    drawGloss(ctx: ctx, canvas: rect)
    drawGlyph(ctx: ctx, canvas: rect, glyphScale: glyphScale)
    return flattenOpaque(rep)
}

func write(_ data: Data, to relativePath: String) {
    let url = brand.appendingPathComponent(relativePath)
    try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! data.write(to: url)
    print("wrote \(relativePath)")
}

// App Icon (parallaxe) : 400×240 @1x / 800×480 @2x, 3 couches.
for (w, h) in [(400, 240), (800, 480)] {
    write(renderBack(width: w, height: h), to: "App Icon.imagestack/Back.imagestacklayer/Content.imageset/icon-back-\(w)x\(h).png")
    write(renderMiddle(width: w, height: h), to: "App Icon.imagestack/Middle.imagestacklayer/Content.imageset/icon-middle-\(w)x\(h).png")
    write(renderFront(width: w, height: h, glyphScale: 0.86), to: "App Icon.imagestack/Front.imagestacklayer/Content.imageset/icon-front-\(w)x\(h).png")
}

// App Icon - App Store : 1280×768, à plat, opaque.
write(renderFlat(width: 1280, height: 768, glyphScale: 0.86), to: "App Icon - App Store.imageset/icon-appstore-1280x768.png")

// Top Shelf Image : 1920×720 @1x / 3840×1440 @2x — bannière, glyphe plus discret.
write(renderFlat(width: 1920, height: 720, glyphScale: 0.5), to: "Top Shelf Image.imageset/top-shelf-1920x720.png")
write(renderFlat(width: 3840, height: 1440, glyphScale: 0.5), to: "Top Shelf Image.imageset/top-shelf-3840x1440.png")

// Top Shelf Image Wide : 2320×720 @1x / 4640×1440 @2x.
write(renderFlat(width: 2320, height: 720, glyphScale: 0.5), to: "Top Shelf Image Wide.imageset/top-shelf-wide-2320x720.png")
write(renderFlat(width: 4640, height: 1440, glyphScale: 0.5), to: "Top Shelf Image Wide.imageset/top-shelf-wide-4640x1440.png")

print("✅ assets App Icon & Top Shelf tvOS générés")

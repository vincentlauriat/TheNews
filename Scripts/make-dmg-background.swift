#!/usr/bin/env swift
// Generates the DMG installer background (540×380 PNG): a subtle accent arrow
// pointing from the app icon toward the /Applications alias.
// Usage: ./Scripts/make-dmg-background.swift <output.png>
import AppKit

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: make-dmg-background.swift <output.png>\n".utf8))
    exit(1)
}
let outPath = args[1]

let W = 540.0, H = 380.0
let accent = NSColor(calibratedRed: 0.20, green: 0.48, blue: 0.96, alpha: 1.0) // neutral blue accent

let image = NSImage(size: NSSize(width: W, height: H))
image.lockFocus()

// Background
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: W, height: H).fill()

// Arrow shaft (icons sit at Finder y=200 from top → y≈180 from bottom here)
let y = H - 200.0
let x0 = 215.0, x1 = 325.0
let shaft = NSBezierPath()
shaft.lineWidth = 4
shaft.lineCapStyle = .round
shaft.move(to: NSPoint(x: x0, y: y))
shaft.line(to: NSPoint(x: x1, y: y))
accent.setStroke()
shaft.stroke()

// Arrow head (solid triangle)
let hs = 16.0
let head = NSBezierPath()
head.move(to: NSPoint(x: x1 + hs, y: y))
head.line(to: NSPoint(x: x1 - 2, y: y + hs * 0.7))
head.line(to: NSPoint(x: x1 - 2, y: y - hs * 0.7))
head.close()
accent.setFill()
head.fill()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("failed to render PNG\n".utf8))
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("background written: \(outPath)")

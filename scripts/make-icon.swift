#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let resources = root.appendingPathComponent("Resources", isDirectory: true)
try? FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func point(_ center: CGPoint, _ radius: CGFloat, _ degrees: CGFloat) -> CGPoint {
    let radians = degrees * .pi / 180
    return CGPoint(x: center.x + cos(radians) * radius, y: center.y + sin(radians) * radius)
}

func drawIcon(size: CGFloat) {
    let scale = size / 1024
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current?.imageInterpolation = .high
    NSGraphicsContext.current?.cgContext.scaleBy(x: scale, y: scale)

    let fieldRect = NSRect(x: 62, y: 62, width: 900, height: 900)
    let field = NSBezierPath(roundedRect: fieldRect, xRadius: 206, yRadius: 206)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.26)
    shadow.shadowBlurRadius = 34
    shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.set()
    color(0xF6EFE2).setFill()
    field.fill()

    NSGraphicsContext.saveGraphicsState()
    field.addClip()
    let boneGradient = NSGradient(colors: [
        color(0xFCF7ED),
        color(0xF3E9D9),
        color(0xE7DBC7)
    ])!
    boneGradient.draw(in: field, angle: -55)

    let glow = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.34),
        NSColor.clear
    ])!
    glow.draw(
        fromCenter: CGPoint(x: 330, y: 760),
        radius: 10,
        toCenter: CGPoint(x: 330, y: 760),
        radius: 470,
        options: []
    )
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    let innerRim = NSBezierPath(
        roundedRect: fieldRect.insetBy(dx: 14, dy: 14),
        xRadius: 194,
        yRadius: 194
    )
    color(0xDCC29B, alpha: 0.55).setStroke()
    innerRim.lineWidth = 2
    innerRim.stroke()
    NSGraphicsContext.restoreGraphicsState()

    let center = CGPoint(x: 512, y: 512)

    let dialShadow = NSShadow()
    dialShadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    dialShadow.shadowBlurRadius = 22
    dialShadow.shadowOffset = NSSize(width: 0, height: -8)
    dialShadow.set()

    let rimOuter = NSBezierPath(ovalIn: NSRect(
        x: center.x - 316,
        y: center.y - 316,
        width: 632,
        height: 632
    ))
    color(0xCFA97A).setFill()
    rimOuter.fill()

    let rimGradient = NSGradient(colors: [
        color(0xEAD7B4),
        color(0xC39A66),
        color(0xA97E4F)
    ])!
    rimGradient.draw(in: rimOuter, angle: -42)

    let face = NSBezierPath(ovalIn: NSRect(
        x: center.x - 282,
        y: center.y - 282,
        width: 564,
        height: 564
    ))
    let tomatoGradient = NSGradient(colors: [
        color(0xD6654F),
        color(0xC6533F),
        color(0xA53D2E)
    ])!
    tomatoGradient.draw(in: face, angle: -60)

    let faceInset = NSBezierPath(ovalIn: NSRect(
        x: center.x - 258,
        y: center.y - 258,
        width: 516,
        height: 516
    ))
    color(0xF6EFE2, alpha: 0.16).setStroke()
    faceInset.lineWidth = 2
    faceInset.stroke()

    for index in 0..<60 {
        let isMajor = index % 5 == 0
        let angle = CGFloat(index) * 6
        let outer = point(center, 246, angle)
        let inner = point(center, isMajor ? 218 : 230, angle)
        let tick = NSBezierPath()
        tick.move(to: inner)
        tick.line(to: outer)
        tick.lineCapStyle = .round
        tick.lineWidth = isMajor ? 7 : 3.4
        color(0xFFF4E4, alpha: isMajor ? 0.72 : 0.38).setStroke()
        tick.stroke()
    }

    let handShadow = NSShadow()
    handShadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    handShadow.shadowBlurRadius = 9
    handShadow.shadowOffset = NSSize(width: 0, height: -4)
    handShadow.set()

    let defaultIntervalMinutes: CGFloat = 25
    let handAngle = 90 - defaultIntervalMinutes / 60 * 360
    let hand = NSBezierPath()
    hand.move(to: center)
    hand.line(to: point(center, 196, handAngle))
    hand.lineCapStyle = .round
    hand.lineWidth = 27
    color(0xC9A16E).setStroke()
    hand.stroke()

    let pivotOuter = NSBezierPath(ovalIn: NSRect(
        x: center.x - 48,
        y: center.y - 48,
        width: 96,
        height: 96
    ))
    color(0xDCC29B).setFill()
    pivotOuter.fill()

    let pivotRing = NSBezierPath(ovalIn: NSRect(
        x: center.x - 37,
        y: center.y - 37,
        width: 74,
        height: 74
    ))
    color(0xB48A58).setFill()
    pivotRing.fill()

    let pivotCore = NSBezierPath(ovalIn: NSRect(
        x: center.x - 14,
        y: center.y - 14,
        width: 28,
        height: 28
    ))
    color(0x3B2E22).setFill()
    pivotCore.fill()

    let highlight = NSBezierPath(ovalIn: NSRect(
        x: center.x - 226,
        y: center.y + 54,
        width: 190,
        height: 104
    ))
    NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.15),
        NSColor.clear
    ])?.draw(in: highlight, angle: -74)

    NSGraphicsContext.restoreGraphicsState()
}

let baseSize = 1024
let baseRep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: baseSize,
    pixelsHigh: baseSize,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .calibratedRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
baseRep.size = NSSize(width: baseSize, height: baseSize)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: baseRep)
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: baseSize, height: baseSize).fill()
drawIcon(size: CGFloat(baseSize))
NSGraphicsContext.restoreGraphicsState()

let baseImage = NSImage(size: NSSize(width: baseSize, height: baseSize))
baseImage.addRepresentation(baseRep)

try baseRep.representation(using: .png, properties: [:])?.write(
    to: resources.appendingPathComponent("AppIcon-1024.png")
)

let iconset = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("Pomodoro.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, pixels) in variants {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: pixels, height: pixels).fill()
    baseImage.draw(
        in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
        from: NSRect(x: 0, y: 0, width: baseSize, height: baseSize),
        operation: .sourceOver,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])?.write(
        to: iconset.appendingPathComponent(name)
    )
}

let output = resources.appendingPathComponent("AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
let errorPipe = Pipe()
iconutil.standardError = errorPipe

try iconutil.run()
iconutil.waitUntilExit()

guard iconutil.terminationStatus == 0 else {
    let message = String(
        data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
    ) ?? "iconutil failed"
    FileHandle.standardError.write(Data(message.utf8))
    exit(1)
}

print("Wrote \(output.path)")

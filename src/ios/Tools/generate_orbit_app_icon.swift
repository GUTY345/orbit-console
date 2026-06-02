import AppKit
import CoreGraphics
import Foundation

struct IconSlot {
    let idiom: String
    let size: String
    let scale: String
    let pixels: Int
    let filename: String
}

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "src/ios/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let slots: [IconSlot] = [
    .init(idiom: "ipad", size: "20x20", scale: "1x", pixels: 20, filename: "OrbitIcon-20.png"),
    .init(idiom: "ipad", size: "20x20", scale: "2x", pixels: 40, filename: "OrbitIcon-20@2x.png"),
    .init(idiom: "ipad", size: "29x29", scale: "1x", pixels: 29, filename: "OrbitIcon-29.png"),
    .init(idiom: "ipad", size: "29x29", scale: "2x", pixels: 58, filename: "OrbitIcon-29@2x.png"),
    .init(idiom: "ipad", size: "40x40", scale: "1x", pixels: 40, filename: "OrbitIcon-40.png"),
    .init(idiom: "ipad", size: "40x40", scale: "2x", pixels: 80, filename: "OrbitIcon-40@2x.png"),
    .init(idiom: "ipad", size: "76x76", scale: "1x", pixels: 76, filename: "OrbitIcon-76.png"),
    .init(idiom: "ipad", size: "76x76", scale: "2x", pixels: 152, filename: "OrbitIcon-76@2x.png"),
    .init(idiom: "ipad", size: "83.5x83.5", scale: "2x", pixels: 167, filename: "OrbitIcon-83.5@2x.png"),
    .init(idiom: "ios-marketing", size: "1024x1024", scale: "1x", pixels: 1024, filename: "OrbitIcon-1024.png"),
]

func drawIcon(size: Int) throws -> NSBitmapImageRep {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0) else {
        throw NSError(domain: "OrbitIconGenerator", code: 2)
    }

    bitmap.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor(red: 0.0, green: 0.102, blue: 0.20, alpha: 1.0).setFill()
    rect.fill()

    let center = CGPoint(x: CGFloat(size) * 0.5, y: CGFloat(size) * 0.5)
    let radius = CGFloat(size) * 0.23
    let circleRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

    let orbitRect = CGRect(x: CGFloat(size) * 0.15, y: CGFloat(size) * 0.36,
                           width: CGFloat(size) * 0.70, height: CGFloat(size) * 0.28)
    let orbitPath = NSBezierPath(ovalIn: orbitRect)
    var transform = AffineTransform()
    transform.translate(x: center.x, y: center.y)
    transform.rotate(byDegrees: -45)
    transform.translate(x: -center.x, y: -center.y)
    orbitPath.transform(using: transform)
    orbitPath.lineWidth = max(5.0, CGFloat(size) * 0.035)
    NSColor(white: 0.88, alpha: 0.92).setStroke()
    orbitPath.stroke()

    let circlePath = NSBezierPath(ovalIn: circleRect)
    NSGraphicsContext.current?.saveGraphicsState()
    circlePath.addClip()
    let gradient = NSGradient(colors: [
        NSColor(white: 0.95, alpha: 1.0),
        NSColor(white: 0.58, alpha: 1.0),
        NSColor(white: 0.98, alpha: 1.0),
    ])!
    gradient.draw(in: circlePath, angle: -45)
    NSGraphicsContext.current?.restoreGraphicsState()

    NSColor(white: 1.0, alpha: 0.18).setFill()
    NSBezierPath(ovalIn: circleRect.insetBy(dx: radius * 0.38, dy: radius * 0.38)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "OrbitIconGenerator", code: 1)
    }
    try png.write(to: url, options: .atomic)
}

for slot in slots {
    try writePNG(drawIcon(size: slot.pixels), to: output.appendingPathComponent(slot.filename))
}

let images = slots.map { slot -> [String: String] in
    [
        "idiom": slot.idiom,
        "size": slot.size,
        "scale": slot.scale,
        "filename": slot.filename,
    ]
}
let contents: [String: Any] = [
    "images": images,
    "info": [
        "author": "xcode",
        "version": 1,
    ],
]
let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try data.write(to: output.appendingPathComponent("Contents.json"), options: .atomic)

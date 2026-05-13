import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDirectory = root
    .appendingPathComponent("Sources/SpotTerminal/Resources", isDirectory: true)
let iconsetDirectory = root
    .appendingPathComponent("dist/SpotTerminal.iconset", isDirectory: true)
let icnsURL = outputDirectory.appendingPathComponent("AppIcon.icns")

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: iconsetDirectory)
try FileManager.default.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

let iconSpecs: [(name: String, points: CGFloat, scale: CGFloat)] = [
    ("icon_16x16.png", 16, 1),
    ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1),
    ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1),
    ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1),
    ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1),
    ("icon_512x512@2x.png", 512, 2),
]

for spec in iconSpecs {
    let pixels = Int(spec.points * spec.scale)
    let image = drawIcon(size: CGFloat(pixels))
    let url = iconsetDirectory.appendingPathComponent(spec.name)
    try writePNG(image, to: url)
}

try writeICNS(
    chunks: [
        ("icp4", iconsetDirectory.appendingPathComponent("icon_16x16.png")),
        ("icp5", iconsetDirectory.appendingPathComponent("icon_32x32.png")),
        ("icp6", iconsetDirectory.appendingPathComponent("icon_32x32@2x.png")),
        ("ic07", iconsetDirectory.appendingPathComponent("icon_128x128.png")),
        ("ic08", iconsetDirectory.appendingPathComponent("icon_256x256.png")),
        ("ic09", iconsetDirectory.appendingPathComponent("icon_512x512.png")),
        ("ic10", iconsetDirectory.appendingPathComponent("icon_512x512@2x.png")),
    ],
    to: icnsURL
)

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    bitmap.size = image.size

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let radius = size * 0.205
    let shadowRect = rect.insetBy(dx: size * 0.075, dy: size * 0.055)
    let shadow = NSShadow()
    shadow.shadowBlurRadius = size * 0.06
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.018)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
    shadow.set()

    let shadowPath = NSBezierPath(roundedRect: shadowRect, xRadius: radius, yRadius: radius)
    NSColor.black.withAlphaComponent(0.28).setFill()
    shadowPath.fill()

    NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

    let baseRect = rect.insetBy(dx: size * 0.07, dy: size * 0.075)
    let basePath = NSBezierPath(roundedRect: baseRect, xRadius: radius, yRadius: radius)
    let baseGradient = NSGradient(colors: [
        NSColor(red: 0.70, green: 0.92, blue: 1.00, alpha: 1.0),
        NSColor(red: 0.22, green: 0.39, blue: 0.88, alpha: 1.0),
        NSColor(red: 0.08, green: 0.10, blue: 0.18, alpha: 1.0),
    ])
    baseGradient?.draw(in: basePath, angle: -42)

    let panel = NSBezierPath(
        roundedRect: baseRect.insetBy(dx: size * 0.105, dy: size * 0.18),
        xRadius: size * 0.095,
        yRadius: size * 0.095
    )
    NSColor.white.withAlphaComponent(0.24).setFill()
    panel.fill()
    NSColor.white.withAlphaComponent(0.36).setStroke()
    panel.lineWidth = max(1, size * 0.01)
    panel.stroke()

    let promptStroke = max(6, size * 0.051)
    let promptPath = NSBezierPath()
    promptPath.lineWidth = promptStroke
    promptPath.lineCapStyle = .round
    promptPath.lineJoinStyle = .round
    promptPath.move(to: NSPoint(x: size * 0.305, y: size * 0.575))
    promptPath.line(to: NSPoint(x: size * 0.405, y: size * 0.525))
    promptPath.line(to: NSPoint(x: size * 0.305, y: size * 0.475))
    NSColor(red: 0.78, green: 0.98, blue: 1.0, alpha: 0.96).setStroke()
    promptPath.stroke()

    let cursorRect = NSRect(x: size * 0.462, y: size * 0.485, width: size * 0.19, height: size * 0.036)
    let cursorPath = NSBezierPath(roundedRect: cursorRect, xRadius: promptStroke / 2, yRadius: promptStroke / 2)
    NSColor(red: 0.48, green: 1.0, blue: 0.72, alpha: 0.94).setFill()
    cursorPath.fill()

    let borderPath = NSBezierPath(roundedRect: baseRect.insetBy(dx: size * 0.006, dy: size * 0.006), xRadius: radius * 0.96, yRadius: radius * 0.96)
    NSColor.white.withAlphaComponent(0.18).setStroke()
    borderPath.lineWidth = max(1, size * 0.01)
    borderPath.stroke()

    NSGraphicsContext.restoreGraphicsState()
    image.addRepresentation(bitmap)
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "SpotTerminalIcon", code: 1)
    }
    try png.write(to: url, options: .atomic)
}

func writeICNS(chunks: [(type: String, url: URL)], to url: URL) throws {
    var body = Data()
    for chunk in chunks {
        let png = try Data(contentsOf: chunk.url)
        body.append(Data(chunk.type.utf8))
        body.appendUInt32BE(UInt32(png.count + 8))
        body.append(png)
    }

    var data = Data("icns".utf8)
    data.appendUInt32BE(UInt32(body.count + 8))
    data.append(body)
    try data.write(to: url, options: .atomic)
}

private extension Data {
    mutating func appendUInt32BE(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8(value & 0xff))
    }
}

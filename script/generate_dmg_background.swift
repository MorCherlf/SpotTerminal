import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "dist/dmg-background.png"
let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let size = NSSize(width: 660, height: 420)
let image = NSImage(size: size)
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size.width * 2),
    pixelsHigh: Int(size.height * 2),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
bitmap.size = size

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

let rect = NSRect(origin: .zero, size: size)
let background = NSGradient(colors: [
    NSColor(red: 0.96, green: 0.98, blue: 1.0, alpha: 1),
    NSColor(red: 0.88, green: 0.93, blue: 0.99, alpha: 1),
])
background?.draw(in: rect, angle: -35)

let cardRect = rect.insetBy(dx: 34, dy: 28)
let cardShadow = NSShadow()
cardShadow.shadowBlurRadius = 18
cardShadow.shadowOffset = NSSize(width: 0, height: -4)
cardShadow.shadowColor = NSColor.black.withAlphaComponent(0.11)
cardShadow.set()
let panel = NSBezierPath(roundedRect: cardRect, xRadius: 26, yRadius: 26)
NSColor.white.withAlphaComponent(0.82).setFill()
panel.fill()
NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
NSColor(red: 0.55, green: 0.62, blue: 0.72, alpha: 0.26).setStroke()
panel.lineWidth = 1
panel.stroke()

let arrowPath = NSBezierPath()
arrowPath.lineWidth = 7
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.move(to: NSPoint(x: 286, y: 206))
arrowPath.line(to: NSPoint(x: 374, y: 206))
arrowPath.move(to: NSPoint(x: 348, y: 232))
arrowPath.line(to: NSPoint(x: 378, y: 206))
arrowPath.line(to: NSPoint(x: 348, y: 180))
NSColor(red: 0.10, green: 0.48, blue: 0.90, alpha: 0.86).setStroke()
arrowPath.stroke()

NSGraphicsContext.restoreGraphicsState()
image.addRepresentation(bitmap)

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "SpotTerminalDMGBackground", code: 1)
}
try png.write(to: outputURL, options: .atomic)

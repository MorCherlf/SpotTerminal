import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDirectory = root.appendingPathComponent("docs/assets", isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let dark = NSColor(red: 0.05, green: 0.06, blue: 0.085, alpha: 1)
let ink = NSColor(red: 0.10, green: 0.13, blue: 0.18, alpha: 1)
let cyan = NSColor(red: 0.38, green: 0.86, blue: 1.00, alpha: 1)
let green = NSColor(red: 0.24, green: 0.95, blue: 0.63, alpha: 1)
let amber = NSColor(red: 1.00, green: 0.74, blue: 0.35, alpha: 1)
let purple = NSColor(red: 0.62, green: 0.56, blue: 1.00, alpha: 1)

try writePNG(drawHero(), to: outputDirectory.appendingPathComponent("spotterminal-hero.png"))
try writePNG(drawQuickPanel(), to: outputDirectory.appendingPathComponent("quick-panel.png"))
try writePNG(drawTerminalWindow(), to: outputDirectory.appendingPathComponent("terminal-window.png"))
try writePNG(drawSettings(), to: outputDirectory.appendingPathComponent("settings.png"))

func drawHero() -> NSImage {
    draw(size: NSSize(width: 1600, height: 900)) { rect in
        NSGradient(colors: [
            NSColor(red: 0.88, green: 0.95, blue: 1.00, alpha: 1),
            NSColor(red: 0.97, green: 0.99, blue: 0.93, alpha: 1),
            NSColor(red: 0.93, green: 0.91, blue: 1.00, alpha: 1),
        ])?.draw(in: rect, angle: -26)

        drawSoftCircle(center: NSPoint(x: 1280, y: 690), radius: 260, color: cyan.withAlphaComponent(0.16))
        drawSoftCircle(center: NSPoint(x: 220, y: 180), radius: 220, color: green.withAlphaComponent(0.12))

        let browser = NSRect(x: 170, y: 150, width: 1260, height: 620)
        drawWindow(rect: browser, title: "Spot Terminal", active: true)
        drawTerminalContent(in: browser.insetBy(dx: 34, dy: 64), large: true)

        let panel = NSRect(x: 435, y: 585, width: 730, height: 190)
        drawFloatingPanel(rect: panel)
        text("git switch release/v1.0", at: NSPoint(x: panel.minX + 42, y: panel.maxY - 72), size: 32, weight: .semibold, color: ink)
        drawPill("git status", x: panel.minX + 42, y: panel.minY + 44, color: cyan)
        drawPill("swift test", x: panel.minX + 180, y: panel.minY + 44, color: green)
        drawPill("docker ps", x: panel.minX + 328, y: panel.minY + 44, color: amber)

        text("SpotTerminal", at: NSPoint(x: 170, y: 805), size: 58, weight: .bold, color: ink)
        text("A fast native command panel that expands into a real macOS terminal.", at: NSPoint(x: 174, y: 764), size: 24, weight: .medium, color: NSColor(red: 0.28, green: 0.34, blue: 0.43, alpha: 1))
    }
}

func drawQuickPanel() -> NSImage {
    draw(size: NSSize(width: 1400, height: 820)) { rect in
        NSGradient(colors: [
            NSColor(red: 0.07, green: 0.09, blue: 0.13, alpha: 1),
            NSColor(red: 0.12, green: 0.14, blue: 0.20, alpha: 1),
        ])?.draw(in: rect, angle: -18)
        let panel = NSRect(x: 260, y: 330, width: 880, height: 270)
        drawFloatingPanel(rect: panel)
        text("kubectl get po", at: NSPoint(x: panel.minX + 46, y: panel.maxY - 78), size: 34, weight: .semibold, color: ink)
        drawDivider(x: panel.minX + 36, y: panel.maxY - 112, width: panel.width - 72)
        drawSuggestion("kubectl get pods", "Kubernetes resource", y: panel.maxY - 162, selected: true, panel: panel)
        drawSuggestion("kubectl get services", "Kubernetes resource", y: panel.maxY - 210, selected: false, panel: panel)
        drawSuggestion("kubectl get deployments", "Kubernetes resource", y: panel.maxY - 258, selected: false, panel: panel)
        text("Tab completes common commands; history stays out of the completion cycle.", at: NSPoint(x: 286, y: 250), size: 24, weight: .medium, color: .white.withAlphaComponent(0.78))
    }
}

func drawTerminalWindow() -> NSImage {
    draw(size: NSSize(width: 1400, height: 880)) { rect in
        NSGradient(colors: [
            NSColor(red: 0.91, green: 0.96, blue: 1.00, alpha: 1),
            NSColor(red: 0.98, green: 0.98, blue: 0.94, alpha: 1),
        ])?.draw(in: rect, angle: -24)
        let window = NSRect(x: 110, y: 110, width: 1180, height: 660)
        drawWindow(rect: window, title: "Spot Terminal", active: true)
        drawSidebar(in: NSRect(x: window.minX, y: window.minY, width: 230, height: window.height - 42))
        drawTerminalContent(in: NSRect(x: window.minX + 252, y: window.minY + 36, width: window.width - 286, height: window.height - 102), large: false)
        text("Tabs, split panes, themes, font zoom, archives, and expand-from-panel workflows.", at: NSPoint(x: 122, y: 54), size: 24, weight: .medium, color: NSColor(red: 0.26, green: 0.32, blue: 0.40, alpha: 1))
    }
}

func drawSettings() -> NSImage {
    draw(size: NSSize(width: 1400, height: 860)) { rect in
        NSColor(red: 0.94, green: 0.96, blue: 0.99, alpha: 1).setFill()
        rect.fill()
        let window = NSRect(x: 150, y: 105, width: 1100, height: 650)
        drawWindow(rect: window, title: "Settings", active: true)
        let sidebar = NSRect(x: window.minX, y: window.minY, width: 260, height: window.height - 42)
        drawSidebar(in: sidebar)
        let content = NSRect(x: window.minX + 300, y: window.minY + 78, width: 780, height: 500)
        text("General", at: NSPoint(x: content.minX, y: content.maxY), size: 34, weight: .bold, color: ink)
        drawSettingRow("Language", "English / 简体中文", y: content.maxY - 82, content: content)
        drawSettingRow("Quick Start Guide", "Open onboarding anytime", y: content.maxY - 162, content: content)
        drawSettingRow("Diagnostics", "Privacy-safe local logs only", y: content.maxY - 242, content: content)
        drawSettingRow("Updates", "Placeholder ready for future releases", y: content.maxY - 322, content: content)
    }
}

func draw(size: NSSize, body: (NSRect) -> Void) -> NSImage {
    let image = NSImage(size: size)
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
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
    body(NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    image.addRepresentation(bitmap)
    return image
}

func drawWindow(rect: NSRect, title: String, active: Bool) {
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 34
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.set()
    let path = NSBezierPath(roundedRect: rect, xRadius: 22, yRadius: 22)
    NSColor.white.withAlphaComponent(0.96).setFill()
    path.fill()
    NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
    NSColor.black.withAlphaComponent(0.08).setStroke()
    path.lineWidth = 1
    path.stroke()
    NSColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: rect.minX, y: rect.maxY - 48, width: rect.width, height: 48), xRadius: 22, yRadius: 22).fill()
    for (index, color) in [NSColor.systemRed, NSColor.systemYellow, NSColor.systemGreen].enumerated() {
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: rect.minX + 22 + CGFloat(index) * 24, y: rect.maxY - 30, width: 12, height: 12)).fill()
    }
    text(title, at: NSPoint(x: rect.midX - 54, y: rect.maxY - 31), size: 14, weight: .semibold, color: NSColor(red: 0.34, green: 0.38, blue: 0.46, alpha: 1))
}

func drawFloatingPanel(rect: NSRect) {
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 36
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
    shadow.set()
    let path = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
    NSColor.white.withAlphaComponent(0.92).setFill()
    path.fill()
    NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
    NSColor.white.withAlphaComponent(0.55).setStroke()
    path.lineWidth = 1
    path.stroke()
}

func drawTerminalContent(in rect: NSRect, large: Bool) {
    let terminal = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
    NSGradient(colors: [dark, NSColor(red: 0.015, green: 0.018, blue: 0.03, alpha: 1)])?.draw(in: terminal, angle: -35)
    let fontSize: CGFloat = large ? 23 : 18
    let x = rect.minX + 28
    var y = rect.maxY - 52
    let lines: [(String, NSColor)] = [
        ("morcherlf@mac project % swift test", green),
        ("Test run with 95 tests passed after 2.13 seconds.", .white.withAlphaComponent(0.86)),
        ("morcherlf@mac project % git status --short", green),
        (" M Sources/SpotTerminal/Core/Shell/PersistentShellSession.swift", cyan.withAlphaComponent(0.9)),
        (" M Sources/SpotTerminal/Features/Terminal/SwiftTermTerminalView.swift", cyan.withAlphaComponent(0.9)),
        ("morcherlf@mac project % _", green),
    ]
    for line in lines {
        text(line.0, at: NSPoint(x: x, y: y), size: fontSize, weight: .medium, color: line.1, mono: true)
        y -= fontSize + 18
    }
}

func drawSidebar(in rect: NSRect) {
    NSColor(red: 0.95, green: 0.96, blue: 0.985, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18).fill()
    let items = ["General", "Shortcuts", "Shell", "Updates", "Diagnostics"]
    for (index, item) in items.enumerated() {
        let y = rect.maxY - 84 - CGFloat(index) * 54
        if index == 0 {
            NSColor(red: 0.80, green: 0.92, blue: 1.0, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: rect.minX + 18, y: y - 12, width: rect.width - 36, height: 38), xRadius: 10, yRadius: 10).fill()
        }
        text(item, at: NSPoint(x: rect.minX + 34, y: y), size: 17, weight: .semibold, color: ink)
    }
}

func drawSuggestion(_ command: String, _ detail: String, y: CGFloat, selected: Bool, panel: NSRect) {
    if selected {
        NSColor(red: 0.82, green: 0.94, blue: 1.0, alpha: 0.8).setFill()
        NSBezierPath(roundedRect: NSRect(x: panel.minX + 28, y: y - 14, width: panel.width - 56, height: 40), xRadius: 11, yRadius: 11).fill()
    }
    text(command, at: NSPoint(x: panel.minX + 48, y: y), size: 20, weight: .semibold, color: ink, mono: true)
    text(detail, at: NSPoint(x: panel.maxX - 254, y: y + 1), size: 15, weight: .medium, color: NSColor(red: 0.42, green: 0.48, blue: 0.58, alpha: 1))
}

func drawSettingRow(_ title: String, _ value: String, y: CGFloat, content: NSRect) {
    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x: content.minX, y: y - 28, width: content.width, height: 58), xRadius: 12, yRadius: 12).fill()
    text(title, at: NSPoint(x: content.minX + 22, y: y), size: 18, weight: .semibold, color: ink)
    text(value, at: NSPoint(x: content.maxX - 330, y: y), size: 16, weight: .medium, color: NSColor(red: 0.42, green: 0.48, blue: 0.58, alpha: 1))
}

func drawPill(_ label: String, x: CGFloat, y: CGFloat, color: NSColor) {
    color.withAlphaComponent(0.18).setFill()
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: CGFloat(label.count * 10 + 36), height: 34), xRadius: 17, yRadius: 17).fill()
    text(label, at: NSPoint(x: x + 18, y: y + 8), size: 14, weight: .semibold, color: ink, mono: true)
}

func drawDivider(x: CGFloat, y: CGFloat, width: CGFloat) {
    NSColor.black.withAlphaComponent(0.09).setStroke()
    let path = NSBezierPath()
    path.move(to: NSPoint(x: x, y: y))
    path.line(to: NSPoint(x: x + width, y: y))
    path.lineWidth = 1
    path.stroke()
}

func drawSoftCircle(center: NSPoint, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
}

func text(_ string: String, at point: NSPoint, size: CGFloat, weight: NSFont.Weight, color: NSColor, mono: Bool = false) {
    let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
    string.draw(at: point, withAttributes: [
        .font: font,
        .foregroundColor: color,
    ])
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [.compressionFactor: 0.92]) else {
        throw NSError(domain: "SpotTerminalReadmeAssets", code: 1)
    }
    try png.write(to: url, options: .atomic)
}

import Cocoa

/// Renders the application icon: a graphite squircle with a green battery and a
/// lightning bolt. Used by the `--icon` mode to produce the .icns at package
/// time (the menu-bar glyph is drawn separately by `BatteryIcon`).
enum AppIcon {

    static func image(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        // Graphite squircle background.
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let radius = size * 0.2237
        let bg = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        let gradient = NSGradient(colors: [
            NSColor(srgbRed: 0.24, green: 0.24, blue: 0.26, alpha: 1),
            NSColor(srgbRed: 0.10, green: 0.10, blue: 0.11, alpha: 1),
        ])!
        gradient.draw(in: bg, angle: -90)

        // Battery body.
        let bw = size * 0.60, bh = size * 0.34
        let bodyRect = NSRect(x: (size - bw) / 2 - size * 0.012,
                              y: (size - bh) / 2, width: bw, height: bh)
        let line = size * 0.024
        let body = NSBezierPath(roundedRect: bodyRect.insetBy(dx: line / 2, dy: line / 2),
                                xRadius: bh * 0.28, yRadius: bh * 0.28)
        body.lineWidth = line
        NSColor.white.setStroke()
        body.stroke()

        // Terminal nub.
        let nubW = size * 0.024, nubH = bh * 0.42
        let nub = NSBezierPath(
            roundedRect: NSRect(x: bodyRect.maxX + size * 0.008,
                                y: bodyRect.midY - nubH / 2, width: nubW, height: nubH),
            xRadius: nubW * 0.4, yRadius: nubW * 0.4)
        NSColor.white.setFill()
        nub.fill()

        // Green charge fill.
        let inset = line * 1.5
        let inner = bodyRect.insetBy(dx: inset, dy: inset)
        let fillRect = NSRect(x: inner.minX, y: inner.minY,
                              width: inner.width * 0.74, height: inner.height)
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: bh * 0.16, yRadius: bh * 0.16)
        NSColor.systemGreen.setFill()
        fill.fill()

        // Lightning bolt.
        let cx = bodyRect.midX, cy = bodyRect.midY
        let h = bodyRect.height * 0.82, w = h * 0.52
        let bolt = NSBezierPath()
        bolt.move(to: NSPoint(x: cx + w * 0.15, y: cy + h * 0.5))
        bolt.line(to: NSPoint(x: cx - w * 0.5, y: cy - h * 0.05))
        bolt.line(to: NSPoint(x: cx - w * 0.02, y: cy - h * 0.05))
        bolt.line(to: NSPoint(x: cx - w * 0.15, y: cy - h * 0.5))
        bolt.line(to: NSPoint(x: cx + w * 0.5, y: cy + h * 0.05))
        bolt.line(to: NSPoint(x: cx + w * 0.02, y: cy + h * 0.05))
        bolt.close()
        NSColor.white.setFill()
        bolt.fill()

        image.unlockFocus()
        return image
    }
}

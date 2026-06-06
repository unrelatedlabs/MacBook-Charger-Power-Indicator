import Cocoa

/// Renders the application icon: a graphite squircle with a soft green
/// "charging" glow, a glossy white-outlined battery with a green gradient fill,
/// and a bright lightning bolt. Used by the `--icon` mode to produce the .icns
/// at package time.
enum AppIcon {

    static func image(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let ctx = NSGraphicsContext.current!

        // --- Background squircle with a graphite gradient ---
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let radius = size * 0.2237
        let bg = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        ctx.saveGraphicsState()
        bg.addClip()
        NSGradient(colors: [
            NSColor(srgbRed: 0.22, green: 0.23, blue: 0.25, alpha: 1),
            NSColor(srgbRed: 0.07, green: 0.08, blue: 0.09, alpha: 1),
        ])!.draw(in: rect, angle: -90)

        // Soft green charging glow behind the battery.
        NSGradient(colors: [
            NSColor.systemGreen.withAlphaComponent(0.55),
            NSColor.systemGreen.withAlphaComponent(0.0),
        ])!.draw(fromCenter: NSPoint(x: size * 0.5, y: size * 0.46),
                 radius: 0,
                 toCenter: NSPoint(x: size * 0.5, y: size * 0.46),
                 radius: size * 0.42,
                 options: [])

        // Subtle top gloss.
        NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.10),
            NSColor.white.withAlphaComponent(0.0),
        ])!.draw(in: NSRect(x: 0, y: size * 0.62, width: size, height: size * 0.38), angle: -90)
        ctx.restoreGraphicsState()

        // --- Battery body ---
        let bw = size * 0.60, bh = size * 0.34
        let bodyRect = NSRect(x: (size - bw) / 2 - size * 0.012,
                              y: (size - bh) / 2, width: bw, height: bh)
        let line = size * 0.026

        // Green gradient charge fill, clipped to a rounded rect.
        let inset = line * 1.6
        let inner = bodyRect.insetBy(dx: inset, dy: inset)
        let fillRect = NSRect(x: inner.minX, y: inner.minY,
                              width: inner.width * 0.76, height: inner.height)
        let fillPath = NSBezierPath(roundedRect: fillRect,
                                    xRadius: bh * 0.18, yRadius: bh * 0.18)
        ctx.saveGraphicsState()
        fillPath.addClip()
        NSGradient(colors: [
            NSColor(srgbRed: 0.46, green: 0.88, blue: 0.52, alpha: 1),
            NSColor(srgbRed: 0.18, green: 0.66, blue: 0.32, alpha: 1),
        ])!.draw(in: fillRect, angle: -90)
        ctx.restoreGraphicsState()

        // White rounded outline with a faint outer shadow for depth.
        let body = NSBezierPath(roundedRect: bodyRect.insetBy(dx: line / 2, dy: line / 2),
                                xRadius: bh * 0.3, yRadius: bh * 0.3)
        body.lineWidth = line
        ctx.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = size * 0.012
        shadow.shadowOffset = NSSize(width: 0, height: -size * 0.006)
        shadow.set()
        NSColor.white.setStroke()
        body.stroke()
        ctx.restoreGraphicsState()

        // Terminal nub.
        let nubW = size * 0.026, nubH = bh * 0.44
        let nub = NSBezierPath(
            roundedRect: NSRect(x: bodyRect.maxX + size * 0.008,
                                y: bodyRect.midY - nubH / 2, width: nubW, height: nubH),
            xRadius: nubW * 0.45, yRadius: nubW * 0.45)
        NSColor.white.setFill()
        nub.fill()

        // --- Lightning bolt with a soft glow ---
        let cx = bodyRect.midX, h = bodyRect.height * 0.86, w = h * 0.5
        let cy = bodyRect.midY
        let bolt = NSBezierPath()
        bolt.move(to: NSPoint(x: cx + w * 0.15, y: cy + h * 0.5))
        bolt.line(to: NSPoint(x: cx - w * 0.5, y: cy - h * 0.05))
        bolt.line(to: NSPoint(x: cx - w * 0.02, y: cy - h * 0.05))
        bolt.line(to: NSPoint(x: cx - w * 0.15, y: cy - h * 0.5))
        bolt.line(to: NSPoint(x: cx + w * 0.5, y: cy + h * 0.05))
        bolt.line(to: NSPoint(x: cx + w * 0.02, y: cy + h * 0.05))
        bolt.close()
        ctx.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = NSColor(srgbRed: 0.1, green: 0.4, blue: 0.15, alpha: 0.6)
        glow.shadowBlurRadius = size * 0.02
        glow.shadowOffset = .zero
        glow.set()
        NSColor.white.setFill()
        bolt.fill()
        ctx.restoreGraphicsState()

        image.unlockFocus()
        return image
    }
}

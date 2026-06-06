import Cocoa

/// Draws a 1:1 replica of the native macOS (Tahoe) menu-bar battery, entirely in
/// code (no bundled art, so nothing to license). A rounded body outline, a
/// terminal nub, a charge fill, and — while charging/plugged — a lightning bolt
/// knocked out of the fill (dark over the fill, traced light over the empty part)
/// exactly like the system glyph. Monochrome like the system's (white ink on a
/// dark bar, black on a light one); only goes red when critically low on battery.
/// The headline value (watts plugged, percent otherwise) sits to the left of the
/// glyph, where macOS shows its percentage.
///
/// Geometry is matched to the system battery measured at 20px/pt: body 23×11.65,
/// stroke ~1.0, bolt ≈ full body height with the normalized vertices below.
enum BatteryIcon {

    static func image(for s: PowerSnapshot, text: String, dark: Bool) -> NSImage {
        let bodyW: CGFloat = 23.0
        let bodyH: CGFloat = 11.8
        let stroke: CGFloat = 1.05
        let nubGap: CGFloat = 0.9
        let nubR: CGFloat = 2.0          // terminal is a half-disc: flat left, round right
        let textGap: CGFloat = 4.0
        let vPad: CGFloat = 4.2          // room for the bolt to overflow the body

        let ink = dark ? NSColor.white : NSColor.black
        // Colours sampled from the native menu-bar battery: outline ≈ ink@0.53
        // (gray 134/255 on black), fill ≈ ink@0.92 (gray 234/255).
        // Native border is #757575 — white @ 117/255 over the dark bar.
        let outline = ink.withAlphaComponent(0.459)
        let plugged = s.isPlugged || s.isCharging || s.isCharged
        let fillColor: NSColor
        if s.lowPowerMode {
            fillColor = NSColor(srgbRed: 1.0, green: 0xD6 / 255.0, blue: 0.0, alpha: 1.0) // #FFD600
        } else if s.isLow && !plugged {
            fillColor = .systemRed
        } else {
            fillColor = ink.withAlphaComponent(0.90)
        }
        let showBolt = plugged
        // Apple's own bolt glyph, recoloured to the ink colour (pre-tinted before
        // the main image is locked).
        let tintedBolt = showBolt ? boltSymbol.map { tinted($0, ink) } : nil

        // Headline value, to the left of the glyph.
        let font = NSFont.systemFont(ofSize: 12.5, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
        let hasText = !text.isEmpty
        let tSize = hasText ? (text as NSString).size(withAttributes: attrs) : .zero
        let textBlockW = hasText ? ceil(tSize.width) + textGap : 0

        let totalW = textBlockW + bodyW + nubGap + nubR + 1
        let size = NSSize(width: totalW, height: bodyH + vPad * 2)

        let image = NSImage(size: size)
        image.lockFocus()
        let ctx = NSGraphicsContext.current!

        if hasText {
            (text as NSString).draw(at: NSPoint(x: 0, y: (size.height - tSize.height) / 2 - 0.5),
                                    withAttributes: attrs)
        }

        let bodyRect = NSRect(x: textBlockW, y: (size.height - bodyH) / 2,
                              width: bodyW, height: bodyH)
        let radius = bodyH * 0.21

        // 1) Body outline.
        let body = NSBezierPath(roundedRect: bodyRect.insetBy(dx: stroke / 2, dy: stroke / 2),
                                xRadius: radius, yRadius: radius)
        body.lineWidth = stroke
        outline.setStroke()
        body.stroke()

        // 2) Charge fill.
        let interior = bodyRect.insetBy(dx: stroke + 0.9, dy: stroke + 0.9)
        let fillW = interior.width * CGFloat(s.fillFraction)
        if fillW > 0.5 {
            let fr = NSBezierPath(roundedRect: NSRect(x: interior.minX, y: interior.minY,
                                                      width: fillW, height: interior.height),
                                  xRadius: 1.4, yRadius: 1.4)
            fillColor.setFill()
            fr.fill()
        }

        // 3) Charging bolt: a light bolt with a thin dark "moat" around it, so it
        // reads over both the fill and the empty area — this is how the native
        // glyph draws it (NOT a dark knockout). The native bolt is big: it
        // overflows the body top and bottom and crosses the outline, so it is
        // NOT clipped to the body.
        if showBolt {
            ctx.saveGraphicsState()
            if let sym = boltSymbol, let tb = tintedBolt {
                // Apple's bolt.fill, sized by height and centred in the body.
                let bh = bodyH * 1.18          // symbol has internal padding
                let bw = bh * (sym.size.width / max(sym.size.height, 0.001)) * 1.12
                let rect = NSRect(x: bodyRect.midX - bw / 2, y: bodyRect.midY - bh / 2 + 0.4,
                                  width: bw, height: bh)
                // dark moat: dilate the bolt by a CONSTANT width by stamping it
                // offset around a small circle (a scale-up would make the moat
                // thicker at the tips — native's moat is uniform and thin).
                let moat: CGFloat = 0.55
                ctx.compositingOperation = .destinationOut
                let steps = 16
                for i in 0..<steps {
                    let a = CGFloat(i) / CGFloat(steps) * 2 * .pi
                    sym.draw(in: rect.offsetBy(dx: cos(a) * moat, dy: sin(a) * moat))
                }
                sym.draw(in: rect)
                // light bolt on top
                ctx.compositingOperation = .sourceOver
                tb.draw(in: rect)
            } else {
                // Fallback: code-drawn rounded bolt.
                let bolt = boltPath(centerX: bodyRect.midX, centerY: bodyRect.midY,
                                    height: bodyH * 1.15)
                ctx.compositingOperation = .destinationOut
                NSColor.black.setStroke(); NSColor.black.setFill()
                bolt.lineWidth = 1.7; bolt.stroke(); bolt.fill()
                ctx.compositingOperation = .sourceOver
                ink.setFill(); bolt.fill()
            }
            ctx.restoreGraphicsState()
        }

        // 4) Terminal nub — a half-disc (flat left edge, semicircular right) like
        // the native cap, not a rectangle.
        let nubX = bodyRect.maxX + nubGap
        let midY = bodyRect.midY
        let nub = NSBezierPath()
        nub.move(to: NSPoint(x: nubX, y: midY + nubR))
        nub.line(to: NSPoint(x: nubX, y: midY - nubR))
        nub.appendArc(withCenter: NSPoint(x: nubX, y: midY), radius: nubR,
                      startAngle: -90, endAngle: 90, clockwise: false)
        nub.close()
        outline.setFill()
        nub.fill()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    /// Apple's own filled lightning glyph — the exact native bolt.
    private static let boltSymbol: NSImage? = {
        let cfg = NSImage.SymbolConfiguration(pointSize: 64, weight: .regular)
        return NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Charging")?
            .withSymbolConfiguration(cfg)
    }()

    /// Recolour a black+alpha template image to `color`, preserving its alpha.
    private static func tinted(_ img: NSImage, _ color: NSColor) -> NSImage {
        let out = NSImage(size: img.size)
        out.lockFocus()
        img.draw(at: .zero, from: NSRect(origin: .zero, size: img.size),
                 operation: .sourceOver, fraction: 1)
        color.set()
        NSRect(origin: .zero, size: img.size).fill(using: .sourceAtop)
        out.unlockFocus()
        out.isTemplate = false
        return out
    }

    /// A lightning bolt centered at (cx, cy), `height` tall, matching the native
    /// battery bolt's silhouette (normalized vertices; y is image-up). The native
    /// bolt has rounded corners, so every vertex is filleted. (Fallback only.)
    private static func boltPath(centerX cx: CGFloat, centerY cy: CGFloat,
                                 height h: CGFloat) -> NSBezierPath {
        let w = h * 0.663
        // (nx 0…1 left→right, ny 0…1 top→bottom) → screen point
        func pt(_ nx: CGFloat, _ ny: CGFloat) -> NSPoint {
            NSPoint(x: cx + (nx - 0.5) * w, y: cy + (ny - 0.5) * h)
        }
        let pts = [pt(0.29, 0.00),   // top apex
                   pt(0.95, 0.50),   // right tip
                   pt(0.56, 0.60),   // inner
                   pt(0.72, 1.00),   // bottom apex
                   pt(0.05, 0.50),   // left tip
                   pt(0.42, 0.40)]   // inner
        return roundedPolygon(pts, radius: h * 0.13)
    }

    /// Build a closed path through `pts` with each corner rounded by `radius`
    /// (filleted with a quadratic curve, expressed as a cubic).
    private static func roundedPolygon(_ pts: [NSPoint], radius r: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let n = pts.count
        for i in 0..<n {
            let p0 = pts[(i + n - 1) % n]
            let p1 = pts[i]
            let p2 = pts[(i + 1) % n]
            let v1 = NSPoint(x: p0.x - p1.x, y: p0.y - p1.y)
            let v2 = NSPoint(x: p2.x - p1.x, y: p2.y - p1.y)
            let l1 = max(hypot(v1.x, v1.y), 0.0001)
            let l2 = max(hypot(v2.x, v2.y), 0.0001)
            let d = min(r, l1 / 2, l2 / 2)
            let a = NSPoint(x: p1.x + v1.x / l1 * d, y: p1.y + v1.y / l1 * d)
            let b = NSPoint(x: p1.x + v2.x / l2 * d, y: p1.y + v2.y / l2 * d)
            // quadratic (control p1) expressed as a cubic
            let c1 = NSPoint(x: a.x + 2.0 / 3.0 * (p1.x - a.x), y: a.y + 2.0 / 3.0 * (p1.y - a.y))
            let c2 = NSPoint(x: b.x + 2.0 / 3.0 * (p1.x - b.x), y: b.y + 2.0 / 3.0 * (p1.y - b.y))
            if i == 0 { path.move(to: a) } else { path.line(to: a) }
            path.curve(to: b, controlPoint1: c1, controlPoint2: c2)
        }
        path.close()
        return path
    }
}

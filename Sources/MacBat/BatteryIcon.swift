import Cocoa

/// Draws a compact battery glyph with the headline number rendered *inside* the
/// body (watts while plugged in, percentage otherwise). The ink color is chosen
/// explicitly from the menu bar's appearance (`dark`) because a baked NSImage
/// doesn't adapt on its own — white ink on a dark bar, black on a light one.
/// The shell fill is tinted by state: green when plugged/charging, red when low.
enum BatteryIcon {

    static func image(for s: PowerSnapshot, text: String, dark: Bool) -> NSImage {
        let bodyH: CGFloat = 16
        let nubW: CGFloat = 2.2
        let nubH: CGFloat = 7
        let lineW: CGFloat = 1.3
        let pad: CGFloat = 1.0          // breathing room so strokes aren't clipped
        let textInset: CGFloat = 3.5    // horizontal space around the number

        let ink = dark ? NSColor.white : NSColor.black

        let stateColor: NSColor
        if s.isCharging || s.isCharged || s.isPlugged {
            stateColor = NSColor.systemGreen
        } else if s.isLow {
            stateColor = NSColor.systemRed
        } else {
            stateColor = ink
        }

        // High-contrast number; measure it so the body grows to fit.
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .bold)
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: ink,
        ]
        let textSize = (text as NSString).size(withAttributes: textAttrs)

        let bodyW = max(24, ceil(textSize.width) + textInset * 2 + 1)
        let size = NSSize(width: bodyW + nubW + pad * 2 + 0.5, height: bodyH + pad * 2)

        let image = NSImage(size: size)
        image.lockFocus()

        let outline = ink.withAlphaComponent(0.65)

        // Battery body outline.
        let bodyRect = NSRect(x: pad, y: pad, width: bodyW, height: bodyH)
        let body = NSBezierPath(roundedRect: bodyRect, xRadius: 3.0, yRadius: 3.0)
        body.lineWidth = lineW
        outline.setStroke()
        body.stroke()

        // Terminal nub on the right.
        let nubRect = NSRect(x: bodyRect.maxX + 0.5,
                             y: pad + (bodyH - nubH) / 2,
                             width: nubW, height: nubH)
        let nub = NSBezierPath(roundedRect: nubRect, xRadius: 1.2, yRadius: 1.2)
        outline.setFill()
        nub.fill()

        // Fill bar showing charge level, tinted by state, behind the text.
        let inset: CGFloat = 1.8
        let innerMax = bodyRect.insetBy(dx: inset, dy: inset)
        let fillW = max(0, innerMax.width * CGFloat(s.fillFraction))
        if fillW > 0 {
            let fillRect = NSRect(x: innerMax.minX, y: innerMax.minY,
                                  width: fillW, height: innerMax.height)
            let fill = NSBezierPath(roundedRect: fillRect, xRadius: 1.4, yRadius: 1.4)
            stateColor.withAlphaComponent(0.45).setFill()
            fill.fill()
        }

        // The number, centered inside the body.
        let textOrigin = NSPoint(x: bodyRect.midX - textSize.width / 2,
                                 y: bodyRect.midY - textSize.height / 2 - 0.5)
        (text as NSString).draw(at: textOrigin, withAttributes: textAttrs)

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

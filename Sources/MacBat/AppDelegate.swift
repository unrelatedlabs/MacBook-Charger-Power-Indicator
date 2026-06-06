import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var appearanceObservation: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        migrateLegacyLoginAgent()
        handleLoginCLIFlags()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // Re-render immediately when the menu bar's light/dark appearance flips.
        appearanceObservation = statusItem.button?.observe(\.effectiveAppearance) {
            [weak self] _, _ in self?.refresh()
        }

        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    // MARK: - Status bar

    private func refresh() {
        let s = PowerInfo.read()
        guard let button = statusItem.button else { return }

        // Headline inside the glyph: charger power while plugged in, else charge %.
        let label: String
        if s.isPlugged && s.adapterPower >= 0.5 {
            label = "\(Int(s.adapterPower.rounded()))W"
        } else {
            label = "\(s.percent)%"
        }
        // The menu bar's own appearance decides the ink color (dark bar -> white).
        let dark = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        button.image = BatteryIcon.image(for: s, text: label, dark: dark)
        button.imagePosition = .imageOnly
        button.title = ""
    }

    // MARK: - Menu

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu(menu, snapshot: PowerInfo.read())
    }

    private func rebuildMenu(_ menu: NSMenu, snapshot s: PowerSnapshot) {
        menu.removeAllItems()

        // Header
        let stateText: String
        if s.isCharged { stateText = "Charged" }
        else if s.isCharging { stateText = "Charging" }
        else if s.isPlugged { stateText = "Plugged In" }
        else { stateText = "On Battery" }
        menu.addItem(header("\(s.percent)% — \(stateText)"))

        if s.isPlugged, s.adapterPower >= 0.5 {
            menu.addItem(row("Adapter power", Fmt.watts(s.adapterPower)))
        }
        if s.batteryPowerMagnitude >= 0.1 {
            let label = s.batteryIsCharging ? "Charging battery at" : "Battery draining at"
            menu.addItem(row(label, Fmt.watts(s.batteryPowerMagnitude)))
        }
        if s.batteryIsCharging, s.timeToFull > 0 {
            menu.addItem(row("Time to full", Fmt.duration(s.timeToFull)))
        } else if !s.isPlugged, s.timeToEmpty > 0 {
            menu.addItem(row("Time remaining", Fmt.duration(s.timeToEmpty)))
        }

        // Battery
        menu.addItem(.separator())
        menu.addItem(section("Battery"))
        if !s.condition.isEmpty { menu.addItem(row("Condition", s.condition)) }
        if s.healthPercent >= 0 { menu.addItem(row("Health", "\(s.healthPercent)%")) }
        if s.cycleCount >= 0 { menu.addItem(row("Cycle count", "\(s.cycleCount)")) }
        if s.maxCapacity > 0 && s.designCapacity > 0 {
            menu.addItem(row("Capacity", "\(s.maxCapacity) / \(s.designCapacity) mAh"))
        }
        if !s.temperature.isNaN {
            menu.addItem(row("Temperature", Fmt.temp(s.temperature)))
        }
        if s.voltage > 0 { menu.addItem(row("Voltage", Fmt.volts(s.voltage))) }
        if abs(s.amperage) > 0.001 {
            let sign = s.amperage >= 0 ? "+" : "−"
            menu.addItem(row("Current", "\(sign)\(Fmt.amps(abs(s.amperage)))"))
        }
        if !s.serial.isEmpty { menu.addItem(row("Serial", s.serial)) }

        // Power adapter
        if s.adapterConnected {
            menu.addItem(.separator())
            menu.addItem(section("Power Adapter"))
            if !s.adapterName.isEmpty { menu.addItem(row("Name", s.adapterName)) }
            if s.adapterWatts > 0 { menu.addItem(row("Wattage", "\(s.adapterWatts) W")) }
            if s.adapterVoltage > 0 || s.adapterCurrent > 0 {
                menu.addItem(row("Negotiated",
                    "\(Fmt.volts(s.adapterVoltage)) · \(Fmt.amps(s.adapterCurrent))"))
            }
            if !s.adapterManufacturer.isEmpty {
                menu.addItem(row("Manufacturer", s.adapterManufacturer))
            }
            if !s.adapterModel.isEmpty { menu.addItem(row("Model", s.adapterModel)) }
            if !s.adapterFamily.isEmpty { menu.addItem(row("Family", s.adapterFamily)) }
            if !s.adapterSerial.isEmpty { menu.addItem(row("Serial", s.adapterSerial)) }
            if !s.adapterFwVersion.isEmpty {
                menu.addItem(row("Firmware", s.adapterFwVersion))
            }
            if !s.adapterHwVersion.isEmpty {
                menu.addItem(row("Hardware", s.adapterHwVersion))
            }

            // USB-C Power-Delivery profiles (charger + cable capability).
            if !s.pdProfiles.isEmpty {
                menu.addItem(.separator())
                menu.addItem(section("USB-C Power Profiles"))
                for p in s.pdProfiles {
                    menu.addItem(row("\(Fmt.volts(p.voltage)) · \(Fmt.amps(p.current))",
                                     Fmt.watts(p.watts)))
                }
            }
        }

        // Footer
        menu.addItem(.separator())
        let login = NSMenuItem(title: "Start at Login",
                               action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(login)

        let quit = NSMenuItem(title: "Quit", action: #selector(quit),
                              keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Login item (SMAppService)

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("MacBat: login item toggle failed: \(error.localizedDescription)")
        }
    }

    /// One-time migration: earlier versions started at login via a LaunchAgent
    /// plist. Remove it (so we don't launch twice) and carry the intent over to
    /// SMAppService, which now owns the login-item state.
    private func migrateLegacyLoginAgent() {
        let plist = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/LaunchAgents/com.pkuhar.macbat.plist")
        guard FileManager.default.fileExists(atPath: plist) else { return }
        try? FileManager.default.removeItem(atPath: plist)
        if SMAppService.mainApp.status != .enabled {
            try? SMAppService.mainApp.register()
        }
    }

    /// Lets the installer script flip the login item via the app itself, since
    /// SMAppService has no command-line equivalent.
    private func handleLoginCLIFlags() {
        let args = CommandLine.arguments
        if args.contains("--enable-login") {
            try? SMAppService.mainApp.register()
        }
        if args.contains("--disable-login") {
            try? SMAppService.mainApp.unregister()
            NSApp.terminate(nil)
        }
    }

    // MARK: - Menu item builders
    //
    // Informational rows use a custom NSTextField view rather than a disabled
    // NSMenuItem: disabled items are dimmed by the system, whereas a label view
    // draws at full contrast and never shows the hover highlight.

    private func makeItem(_ view: NSView) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = view
        return item
    }

    private func labelView(_ attributed: NSAttributedString, height: CGFloat) -> NSView {
        let field = NSTextField(labelWithAttributedString: attributed)
        field.sizeToFit()
        let leftInset: CGFloat = 14, rightInset: CGFloat = 22
        let container = NSView(frame: NSRect(
            x: 0, y: 0, width: field.frame.width + leftInset + rightInset, height: height))
        field.setFrameOrigin(NSPoint(x: leftInset, y: (height - field.frame.height) / 2))
        container.addSubview(field)
        return container
    }

    private func header(_ text: String) -> NSMenuItem {
        let a = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.labelColor])
        return makeItem(labelView(a, height: 26))
    }

    private func section(_ text: String) -> NSMenuItem {
        let a = NSAttributedString(string: text.uppercased(), attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor.secondaryLabelColor])
        return makeItem(labelView(a, height: 22))
    }

    private func row(_ label: String, _ value: String) -> NSMenuItem {
        let text = NSMutableAttributedString(
            string: label + "   ",
            attributes: [.font: NSFont.systemFont(ofSize: 13),
                         .foregroundColor: NSColor.secondaryLabelColor])
        text.append(NSAttributedString(
            string: value,
            attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium),
                         .foregroundColor: NSColor.labelColor]))
        return makeItem(labelView(text, height: 20))
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Formatting

enum Fmt {
    static func watts(_ w: Double) -> String {
        w < 10 ? String(format: "%.1f W", w) : String(format: "%.0f W", w)
    }
    static func volts(_ v: Double) -> String { String(format: "%.2f V", v) }
    static func amps(_ a: Double) -> String { String(format: "%.2f A", a) }
    static func temp(_ c: Double) -> String { String(format: "%.1f °C", c) }
    static func duration(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

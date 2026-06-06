import Cocoa

// `--dump` prints the current power snapshot as plain text and exits. Handy for
// debugging the IOKit readings without the menu bar.
if CommandLine.arguments.contains("--dump") {
    let s = PowerInfo.read()
    print("""
    charge:        \(s.percent)%  (plugged=\(s.isPlugged) charging=\(s.isCharging) charged=\(s.isCharged))
    voltage:       \(s.voltage) V
    amperage:      \(s.amperage) A
    batteryWatts:  \(s.batteryWatts) W (charging=\(s.batteryIsCharging))
    adapterPower:  \(s.adapterPower) W
    timeToFull:    \(s.timeToFull) min   timeToEmpty: \(s.timeToEmpty) min
    cycleCount:    \(s.cycleCount)
    temperature:   \(s.temperature) °C
    capacity:      \(s.currentCapacityMah) / \(s.maxCapacity) / design \(s.designCapacity) mAh
    health:        \(s.healthPercent)%   condition: \(s.condition)
    serial:        \(s.serial)
    --- adapter (connected=\(s.adapterConnected)) ---
    name:          \(s.adapterName)
    watts:         \(s.adapterWatts) W
    negotiated:    \(s.adapterVoltage) V · \(s.adapterCurrent) A
    manufacturer:  \(s.adapterManufacturer)
    model:         \(s.adapterModel)   family: \(s.adapterFamily)
    serial:        \(s.adapterSerial)
    fw/hw:         \(s.adapterFwVersion) / \(s.adapterHwVersion)
    pdProfiles:    \(s.pdProfiles.map { "\($0.voltage)V/\($0.current)A" }.joined(separator: ", "))
    """)
    exit(0)
}

// `--render <text> <out.png>` draws the menu-bar icon to a PNG and exits, so the
// glyph can be inspected without the (possibly auto-hidden) menu bar.
if let i = CommandLine.arguments.firstIndex(of: "--render"),
   CommandLine.arguments.count > i + 2 {
    let text = CommandLine.arguments[i + 1]
    let out = CommandLine.arguments[i + 2]
    var s = PowerInfo.read()
    s.isPlugged = text.hasSuffix("W")   // tint preview to match the label kind
    let dark = CommandLine.arguments.contains("--dark")
    let image = BatteryIcon.image(for: s, text: text, dark: dark)
    if let tiff = image.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: out))
        print("wrote \(out) (\(Int(image.size.width))x\(Int(image.size.height)) pt)")
    }
    exit(0)
}

// `--icon <out.png>` renders the 1024px app icon and exits (used at package time).
if let i = CommandLine.arguments.firstIndex(of: "--icon"),
   CommandLine.arguments.count > i + 1 {
    let out = CommandLine.arguments[i + 1]
    let image = AppIcon.image(size: 1024)
    if let tiff = image.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: out))
        print("wrote \(out)")
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Agent app: live in the menu bar only, no Dock icon, no main window.
app.setActivationPolicy(.accessory)
app.run()

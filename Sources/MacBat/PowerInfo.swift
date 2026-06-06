import Foundation
import IOKit
import IOKit.ps

/// A single immutable snapshot of the system's power state, assembled from
/// IOPowerSources and the AppleSmartBattery IORegistry node.
struct PowerSnapshot {
    // Charge
    var percent: Int = 0            // 0...100
    var isCharging: Bool = false    // current is flowing into the battery
    var isCharged: Bool = false     // plugged in and full
    var isPlugged: Bool = false     // an external power source is attached
    var batteryPresent: Bool = true

    // Live electrical values
    var voltage: Double = 0         // volts
    var amperage: Double = 0        // amps, signed (+ into pack, - out of pack)
    var batteryWatts: Double = 0    // signed V * A: + charging, - discharging

    // Time estimates (minutes, -1 == calculating / unknown)
    var timeToFull: Int = -1
    var timeToEmpty: Int = -1

    // Battery health
    var cycleCount: Int = -1
    var temperature: Double = .nan  // °C
    var designCapacity: Int = -1    // mAh
    var maxCapacity: Int = -1       // mAh (current full-charge capacity)
    var currentCapacityMah: Int = -1
    var healthPercent: Int = -1     // maxCapacity / designCapacity
    var condition: String = ""      // e.g. "Normal", "Service Recommended"
    var serial: String = ""

    // Power adapter
    var adapterConnected: Bool = false
    var adapterName: String = ""
    var adapterManufacturer: String = ""
    var adapterWatts: Int = -1       // rated / negotiated max
    var adapterVoltage: Double = 0   // negotiated, volts
    var adapterCurrent: Double = 0   // negotiated max, amps
    var adapterSerial: String = ""
    var adapterModel: String = ""
    var adapterHwVersion: String = ""
    var adapterFwVersion: String = ""
    var adapterFamily: String = ""
    var adapterDescription: String = ""

    /// USB-C Power-Delivery profiles the charger/cable pair advertises.
    var pdProfiles: [PDProfile] = []

    var isLow: Bool { percent <= 20 && !isPlugged }
    var fillFraction: Double { max(0, min(1, Double(percent) / 100.0)) }

    /// True only when current is actually flowing into the pack.
    var batteryIsCharging: Bool { amperage > 0.02 }
    /// Magnitude of power moving through the pack, regardless of direction.
    var batteryPowerMagnitude: Double { abs(batteryWatts) }

    /// The charger's delivered power, in watts — the headline number while
    /// plugged in. Prefers the rated `Watts`, then the negotiated V·A point.
    var adapterPower: Double {
        if adapterWatts > 0 { return Double(adapterWatts) }
        let negotiated = adapterVoltage * adapterCurrent
        return negotiated > 0 ? negotiated : 0
    }
}

struct PDProfile {
    var voltage: Double  // volts
    var current: Double  // amps
    var watts: Double { voltage * current }
}

enum PowerInfo {

    static func read() -> PowerSnapshot {
        var s = PowerSnapshot()
        readPowerSources(into: &s)
        readSmartBattery(into: &s)
        readAdapter(into: &s)
        return s
    }

    // MARK: - IOPowerSources (charge %, state, time estimates)

    private static func readPowerSources(into s: inout PowerSnapshot) {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue()
                    as? [String: Any] else { continue }

            if let cur = desc[kIOPSCurrentCapacityKey] as? Int,
               let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 {
                s.percent = Int((Double(cur) / Double(max) * 100).rounded())
            }
            if let charging = desc[kIOPSIsChargingKey] as? Bool { s.isCharging = charging }
            if let charged = desc[kIOPSIsChargedKey] as? Bool { s.isCharged = charged }
            if let present = desc[kIOPSIsPresentKey] as? Bool { s.batteryPresent = present }
            if let state = desc[kIOPSPowerSourceStateKey] as? String {
                s.isPlugged = (state == kIOPSACPowerValue)
            }
            if let condition = desc[kIOPSBatteryHealthKey] as? String, !condition.isEmpty {
                s.condition = condition
            }
            if let t = desc[kIOPSTimeToFullChargeKey] as? Int { s.timeToFull = t }
            if let t = desc[kIOPSTimeToEmptyKey] as? Int { s.timeToEmpty = t }
        }
    }

    // MARK: - AppleSmartBattery IORegistry (volts, amps, cycles, temp, health)

    private static func readSmartBattery(into s: inout PowerSnapshot) {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        var unmanaged: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0)
                == KERN_SUCCESS,
              let props = unmanaged?.takeRetainedValue() as? [String: Any]
        else { return }

        if let installed = props["BatteryInstalled"] as? Bool { s.batteryPresent = installed }
        if let ext = props["ExternalConnected"] as? Bool { s.isPlugged = ext }
        if let charging = props["IsCharging"] as? Bool { s.isCharging = charging }
        if let full = props["FullyCharged"] as? Bool { s.isCharged = full }

        if let mv = props["Voltage"] as? Int { s.voltage = Double(mv) / 1000.0 }
        // Amperage is signed mA; InstantAmperage is the more responsive reading.
        var ma = props["Amperage"] as? Int ?? 0
        if ma == 0, let inst = props["InstantAmperage"] as? Int { ma = inst }
        s.amperage = Double(ma) / 1000.0
        s.batteryWatts = s.voltage * s.amperage

        if let cycles = props["CycleCount"] as? Int { s.cycleCount = cycles }
        if let temp = props["Temperature"] as? Int { s.temperature = Double(temp) / 100.0 }
        if let serial = props["Serial"] as? String { s.serial = serial }

        // Capacities. On Apple Silicon the "raw" keys hold the real mAh values.
        let design = props["DesignCapacity"] as? Int ?? -1
        let rawMax = props["AppleRawMaxCapacity"] as? Int
        let rawCur = props["AppleRawCurrentCapacity"] as? Int
        s.designCapacity = design
        s.maxCapacity = rawMax ?? (props["MaxCapacity"] as? Int ?? -1)
        s.currentCapacityMah = rawCur ?? (props["CurrentCapacity"] as? Int ?? -1)
        if let rawMax, design > 0 {
            s.healthPercent = Int((Double(rawMax) / Double(design) * 100).rounded())
        }

        if s.condition.isEmpty {
            if let pf = props["PermanentFailureStatus"] as? Int {
                s.condition = pf == 0 ? "Normal" : "Service Recommended"
            }
        }

        // The richest adapter info lives under AdapterDetails on this node.
        if let ad = props["AdapterDetails"] as? [String: Any] {
            applyAdapterDetails(ad, into: &s)
        }
    }

    // MARK: - Power adapter details

    private static func readAdapter(into s: inout PowerSnapshot) {
        // Fall back to the public adapter API if AdapterDetails wasn't populated.
        if !s.adapterConnected,
           let ad = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue()
            as? [String: Any] {
            applyAdapterDetails(ad, into: &s)
        }
    }

    private static func applyAdapterDetails(_ ad: [String: Any], into s: inout PowerSnapshot) {
        s.adapterConnected = true
        if let w = ad["Watts"] as? Int { s.adapterWatts = w }
        if let mv = ad["AdapterVoltage"] as? Int ?? ad["Voltage"] as? Int {
            s.adapterVoltage = Double(mv) / 1000.0
        }
        if let ma = ad["Current"] as? Int { s.adapterCurrent = Double(ma) / 1000.0 }
        if let n = ad["Name"] as? String { s.adapterName = n }
        if let m = ad["Manufacturer"] as? String { s.adapterManufacturer = m }
        if let sn = ad["SerialString"] as? String ?? ad["SerialNumber"] as? String {
            s.adapterSerial = sn
        }
        if let model = ad["Model"] as? String { s.adapterModel = model }
        if let hw = ad["HwVersion"] as? String { s.adapterHwVersion = hw }
        if let fw = ad["FwVersion"] as? String { s.adapterFwVersion = fw }
        if let desc = ad["Description"] as? String { s.adapterDescription = desc }
        if let fam = ad["FamilyCode"] as? Int { s.adapterFamily = familyName(fam) }

        // USB-C Power-Delivery menu: voltage/current pairs the charger advertises.
        if let menu = ad["UsbHvcMenu"] as? [[String: Any]] {
            for entry in menu {
                guard let mv = entry["MaxVoltage"] as? Int,
                      let ma = entry["MaxCurrent"] as? Int else { continue }
                s.pdProfiles.append(PDProfile(voltage: Double(mv) / 1000.0,
                                              current: Double(ma) / 1000.0))
            }
            s.pdProfiles.sort { $0.watts < $1.watts }
        }
    }

    private static func familyName(_ code: Int) -> String {
        // Common Apple adapter family codes; unknown ones fall through to hex.
        switch code {
        case 0xe0004000...0xe0004FFF: return "USB-C Power Delivery"
        case 0x00000003: return "MagSafe"
        case 0x00000004: return "MagSafe 2"
        case 0x0000ff00: return "USB-C"
        default: return String(format: "0x%08x", code)
        }
    }
}

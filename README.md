# MacBat

A tiny macOS menu-bar app that shows your battery level like the system
indicator — but when a charger is plugged in it shows the **charging power**,
and the dropdown reveals full details about the battery, the power adapter, and
the USB-C power-delivery profiles the charger/cable negotiate.

## What it shows

**Menu bar**
- On battery: the classic battery glyph + `NN%` (fill bar, red when ≤20%).
- Plugged in: green fill + lightning bolt + the adapter's delivered wattage,
  e.g. `96 W`.

**Dropdown**
- **State** — charge %, Charging / Charged / Plugged In / On Battery, adapter
  power, live battery charge/discharge wattage, time to full / time remaining.
- **Battery** — condition, health %, cycle count, capacity (current / design
  mAh), temperature, voltage, signed current, serial.
- **Power Adapter** — name, wattage, negotiated V·A, manufacturer, model,
  family, serial, firmware/hardware version.
- **USB-C Power Profiles** — every voltage/current pair the charger advertises,
  with computed watts.

All values come from IOKit (`IOPowerSources` + the `AppleSmartBattery`
IORegistry node + `AdapterDetails`). Nothing leaves your machine.

## Build & run

```sh
./build-app.sh          # builds build/MacBat.app (ad-hoc signed)
open build/MacBat.app   # launches it into the menu bar
```

Requires the Xcode command-line tools (Swift 5.9+) and macOS 13+.

To run it automatically at login, add `build/MacBat.app` under
**System Settings → General → Login Items**.

## Distribute

```sh
./package.sh
```

Produces, in `dist/`:
- `MacBat.app` — a **universal** (Apple Silicon + Intel) build with a generated
  icon, ad-hoc code-signed.
- `MacBat.dmg` — drag-to-Applications disk image.
- `MacBat.zip` — zipped app.

> **Not notarized.** There's no paid Developer ID certificate on this machine,
> so Gatekeeper will quarantine the app on other Macs. First launch on another
> machine: right-click the app → **Open** → **Open**, or run
> `xattr -dr com.apple.quarantine /Applications/MacBat.app`.
> To distribute without that step you'd need an Apple Developer Program
> membership (Developer ID signing + notarization).

## Debugging

```sh
swift build -c release
"$(swift build -c release --show-bin-path)/MacBat" --dump
```

`--dump` prints the current power snapshot as plain text and exits — useful for
checking the raw IOKit readings without the menu bar.

## Notes

- It's an agent app (`LSUIElement`), so there's no Dock icon or window.
- Charging direction is derived from the battery's signed amperage: on an
  underpowered charger the pack can still drain, and MacBat reports
  "Battery draining at N W" honestly rather than faking a charge.
- Some fields (adapter name/serial, cable info) are only populated by certain
  chargers; empty fields are simply omitted from the menu.
```

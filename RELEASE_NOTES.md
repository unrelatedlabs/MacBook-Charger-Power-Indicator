# MacBat v1.0.0

A tiny macOS menu-bar app that shows your battery — and, when a charger is
plugged in, the **charging power in watts**.

## Highlights
- 🔋 Battery percentage shown inside a compact battery glyph.
- ⚡ Plugged in? The glyph turns green and shows the adapter's **wattage** (e.g. `86W`).
- 📋 Dropdown with full detail:
  - **Battery** — condition, health, cycle count, capacity, temperature, voltage, current.
  - **Power Adapter** — name, wattage, negotiated voltage/current, manufacturer, model, serial, firmware.
  - **USB-C Power Profiles** — the voltage/current levels the charger advertises.
- 🚀 **Start at Login** toggle (SMAppService) right in the menu.
- 🖥️ Universal binary — Apple Silicon + Intel. Reads everything locally via IOKit; nothing leaves your Mac.

## Install
1. Download `MacBat.dmg`, open it, drag **MacBat** to Applications.
2. First launch: right-click **MacBat → Open → Open** (the app isn't notarized).
3. Enable **Start at Login** from its menu-bar dropdown if you want it always on.

Requires macOS 13 (Ventura) or later.

> Not notarized (no Developer ID certificate). Gatekeeper will ask once on first
> launch; use right-click → Open, or run
> `xattr -dr com.apple.quarantine /Applications/MacBat.app`.

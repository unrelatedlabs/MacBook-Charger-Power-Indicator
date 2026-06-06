# MacBat

A tiny macOS menu-bar app that shows your battery — and, when a charger is
plugged in, the **charging power in watts**.

## Demo

<p align="center">
  <img src="media/menubar.gif" width="300" alt="Menu-bar readout switching to charging wattage"><br><br>
  <img src="media/dropdown.gif" width="240" alt="Dropdown with battery, adapter, and USB-C power details">
</p>

## What it does

- **On battery:** a battery icon with the charge **percentage** inside it.
- **Plugged in:** the icon turns green and shows the adapter's **wattage**
  (e.g. `86W`) instead of the percentage.
- **Click it** for a dropdown with the details:
  - **Battery** — condition, health, cycle count, capacity, temperature,
    voltage, current.
  - **Power Adapter** — name, wattage, negotiated voltage/current,
    manufacturer, model, serial, firmware.
  - **USB-C Power Profiles** — the voltage/current levels the charger supports.

It reads everything locally from macOS (IOKit). Nothing is sent anywhere.

## Run it

```sh
./build-app.sh         # build MacBat.app
open build/MacBat.app  # launch it into the menu bar
```

To start it automatically at login:

```sh
./install-login-item.sh
```

It runs as a background app — no Dock icon, no window, just the menu-bar item.
Quit it from its own dropdown (**Quit MacBat**).

## Build a shareable copy

```sh
./package.sh   # creates dist/MacBat.dmg and dist/MacBat.zip
```

## License

MIT — © 2026 Peter Kuhar ([@pkuhar](https://github.com/pkuhar)). See [LICENSE](LICENSE).

# Build & Development Setup

This guide walks you through building the watch face from source, running it in the Connect IQ simulator, and sideloading it onto a real device.

## Prerequisites

### 1. Connect IQ SDK

Download and install from [developer.garmin.com/connect-iq/sdk/](https://developer.garmin.com/connect-iq/sdk/). The instructions below assume SDK **8.4.0** or newer, installed to the default location on macOS:

```
~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-*/
```

After install, open the **SDK Manager** app once and download at least one device profile (e.g. `fenix847mm` or `fenix6s`).

### 2. Java 17

The SDK toolchain requires Java 17 (newer versions will not work).

```bash
brew install openjdk@17
sudo ln -sfn "$(brew --prefix)/opt/openjdk@17/libexec/openjdk.jdk" \
  /Library/Java/JavaVirtualMachines/openjdk-17.jdk
```

Verify: `java -version` should report `17.x`.

### 3. Generate your own signing key

**Never commit a signing key.** The repo's `.gitignore` excludes `developer_key.der`, but you still need to generate your own:

```bash
# Generate raw RSA key, then convert to PKCS8 DER (the format monkeyc expects)
openssl genrsa -out developer_key_raw.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER \
  -in developer_key_raw.pem -out developer_key.der -nocrypt
rm developer_key_raw.pem
```

Leave `developer_key.der` in the repo root — the build scripts look for it there.

## Build + run in the simulator

The recommended workflow is `preview.sh`, which builds, pushes to a running simulator, and captures a screenshot:

```bash
# Launch the simulator once per session (from the SDK):
SDK_PATH="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc"
"$SDK_PATH/bin/connectiq" &

# Build + push + screenshot:
./preview.sh                  # default: fenix847mm
./preview.sh fenix6s          # test the MIP layout
```

The screenshot is saved to `screenshots/latest.png`.

> **Tip:** The simulator commonly crashes on the *first* `monkeydo` push after launch. Just run `./preview.sh` again — the second push works.

### Manual build (no simulator)

```bash
SDK_PATH="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc"
"$SDK_PATH/bin/monkeyc" \
  -d fenix847mm \
  -f monkey.jungle \
  -o watchface-f8.prg \
  -y developer_key.der
```

## Sideload to a real device

1. Build a `.prg` for your exact device as above.
2. Connect the watch via USB (it mounts as `GARMIN`).
3. Copy the `.prg` to `GARMIN/APPS/`.
4. Safely eject the watch. On the device, go to **Settings → Watch Face** and pick "OLED Weather".

## Publishing to the Connect IQ Store

If you want to publish your own fork to the Store:

1. **Regenerate the app UUID** in `manifest.xml` — the current value is a placeholder and the Store rejects duplicates. Any UUID generator works (`uuidgen` on macOS).
2. Build a `.iq` bundle: `"$SDK_PATH/bin/monkeyc" -e -f monkey.jungle -o watchface.iq -y developer_key.der`.
3. Upload at [apps.garmin.com](https://apps.garmin.com/en-US/developer/dashboard).

## Project layout

```
garmin_watch_face/
├── manifest.xml           # App metadata, supported devices, permissions
├── monkey.jungle          # Build config, device-specific resource paths
├── preview.sh             # Build + simulator + screenshot helper
├── simulation-data.json   # Mock sensor/weather data for the simulator
├── source/
│   ├── WatchFaceApp.mc        # App entry + background service hook
│   ├── WatchFaceView.mc       # All rendering (weather, time, rings, AOD)
│   ├── WatchFaceDelegate.mc   # Sleep/wake transitions
│   ├── WeatherDataManager.mc  # Cache + Garmin API fallback
│   ├── WeatherService.mc      # Background fetch from Open-Meteo
│   ├── Theme.mc               # Colors, layout constants, presets
│   └── Settings.mc            # Settings cache + typed getters
├── resources/
│   ├── strings/strings.xml
│   ├── settings/settings.xml
│   ├── properties.xml
│   └── drawables/
├── resources-fenix847mm/   # AMOLED-specific overrides (empty stub)
└── resources-fenix6s/      # MIP-specific overrides (empty stub)
```

## Debug flags

`source/WatchFaceView.mc` has a `DEBUG_SIMULATOR` constant. The Garmin simulator doesn't populate `ActivityMonitor` from `simulation-data.json`, so set this to `true` temporarily to feed in mock step/floor/HR/Body-Battery values when testing layout:

```monkeyc
private const DEBUG_SIMULATOR = false;  // ALWAYS false when committing
private const DEBUG_STEPS = 6700;       // 67% of goal
private const DEBUG_STEP_GOAL = 10000;
// ... etc
```

**Flip it back to `false` before committing.** The `preview.sh` screenshot + `CLAUDE.md` crop protocol is the recommended way to iterate on layout changes.

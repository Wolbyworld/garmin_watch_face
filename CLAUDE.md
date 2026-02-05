# Garmin Weather Watch Face

## Project Goal
Build a Connect IQ watch face that supports both **Garmin Fenix 8 47mm AMOLED (454x454 pixels)** and **Fenix 6S MIP (240x240 pixels)**. The design recreates the "Rain & Clouds" style weather watch face, optimized for each display type.

## Reference Images
The PNG/JPEG files in this folder show the original "Rain & Clouds" watch face that was designed for older MIP (280x280) displays. It looks ugly on the high-res AMOLED. The goal is to preserve all the same data elements but with a modern OLED-optimized design.

## Data Elements to Display
1. **Location + temperature** (top, centered)
2. **Weather chart** (main feature, upper-middle area):
   - Day/night gradient band (navy/dark blue transitions)
   - Cloud cover (semi-transparent white/gray shapes, opacity = density)
   - Temperature curve (smooth polyline in warm amber, gradient fill below)
   - Precipitation bars (thin vertical bars in cool cyan, height = intensity)
   - Wind (subtle tick marks or encoding)
   - Hour markers (small dim gray numbers)
   - Day labels + separators (WE, TH, FR...)
   - "Now" indicator (bright vertical line at current time)
3. **Date** (weekday, day, month, ISO week number)
4. **Time** (large digits, seconds as small superscript, ~30% of display height)
5. **Step goal fill effect** on time digits (filled portion = % of step goal achieved)
6. **Heart rate** (current BPM with heart icon)
7. **Steps / distance**
8. **Data field** (configurable: elevation, floors, calories, etc.)
9. **Move bar** (inactivity indicator, muted red dots)
10. **Battery** (top-right, small and dim)

## Design Requirements
- **True black background** (#000000) everywhere -- pixels off for battery savings
- **Themeable**: All colors, fonts, and spacing in a Theme module/dictionary so themes can be swapped easily. Start with a dark theme.
- **Refined typography**: Clean sans-serif fonts, no chunky pixel bitmaps
- **Smooth weather chart**: Polylines and filled polygons using Dc primitives. At 454x454 density, line segments look smooth enough.
- **Restrained color palette** against black (see theme below)
- **Visual hierarchy**: Time largest/brightest, weather chart mid-prominence, stats small/subdued

## Default Theme (Dark)
| Role | Color | Hex |
|---|---|---|
| Background | True black | #000000 |
| Time digits | Bright white | #FFFFFF |
| Primary text (date, location) | Warm gray | #B0B0B0 |
| Secondary text (labels, stats) | Dim gray | #707070 |
| Temperature curve | Warm amber | #FFB347 |
| Precipitation | Cool cyan | #4DD0E1 |
| Cloud cover | Translucent white | #FFFFFF @ 30-60% opacity |
| Night sky | Deep navy | #0A1628 |
| Day sky | Dark slate blue | #1A3050 |
| Heart rate icon | Soft red | #E57373 |
| Move bar | Muted red | #C62828 @ 60% |
| Step goal fill | Accent teal | #26A69A |
| Week number badge | Accent orange | #FF8A65 |

## AOD (Always-On Display)
- Minimal: time only (thin outline font), date, battery
- Keep total luminance under 10% (Garmin requirement)
- Mostly gesture-wake usage, so AOD is low priority but should exist

## Technical Stack
- **Language**: Monkey C (Garmin Connect IQ)
- **Target API level**: 3.4.0 (for Fenix 6S compatibility)
- **Target devices**:
  - Fenix 8 AMOLED: `fenix847mm`, `fenix8solar47mm`, `fenix851mm`, `fenix8solar51mm`
  - Fenix 6S MIP: `fenix6s`, `fenix6spro`
  - Also: `venu2`, `venu2s`, `venu3`, `venu3s`, `epix2pro47mm`, `epix2pro51mm`
- **Weather data**: Primary: Open-Meteo API (via background service). Fallback: Garmin Weather API
- **Location**: Uses last GPS position from activities (updates when you run/bike/hike with GPS)
- **Build system**: monkey.jungle file

## Architecture Notes
- **WatchFaceApp.mc**: App entry point, provides `getServiceDelegate()` for background weather service
- **WatchFaceView.mc**: Main view - all rendering (weather chart, time, stats, rings, AOD)
- **WatchFaceDelegate.mc**: Handles power mode transitions (sleep/wake for AOD)
- **WeatherService.mc**: Background service that fetches from Open-Meteo API every 30 min
- **WeatherDataManager.mc**: Module that caches weather data, tries external first then Garmin API
- **Theme.mc**: Module holding colors, layout constants, and theme presets (Dark, Warm, Cool, HighContrast)
- **Settings.mc**: Central settings cache with typed getters for all 22 configurable options

## Key CIQ APIs to Use
- `WatchUi.WatchFace` / `WatchUi.WatchFaceDelegate`
- `Dc` graphics: `drawLine()`, `fillPolygon()`, `drawText()`, `setColor()`, `fillRectangle()`
- `Weather.getCurrentConditions()`, `Weather.getHourlyForecast()`
- `ActivityMonitor.getInfo()` -- steps, step goal, move bar level
- `Activity.getActivityInfo()` -- heart rate, elevation
- `System.getDeviceSettings()` -- battery, clock format
- `System.getClockTime()` -- current time

## Status
- Design approved by user
- **Working implementation** - all major features functional and tested on real device
- Custom mini-digit renderer (8x10 pixels) and mini-letter renderer (9x11 pixels) for tiny text
- Day labels: 2-character abbreviations (MO, TU, WE, TH, FR, SA, SU) using custom mini-letters
- Organic cloud shapes using overlapping circles
- Activity rings with Apple-style overflow effect and cycling center data
- Two secondary timezones: São Paulo (UTC-3) and San Francisco (UTC-8)
- **External Weather API (Open-Meteo)** ✅ Working on real device!
  - Fetches 4 days of data every 30 minutes via background service (UI shows 96h)
  - Uses last GPS position from activities (updates when you run/bike)
  - Falls back to default location (Pozuelo de Alarcón) after device reset
  - Falls back to Garmin API if external data unavailable
  - Red warning cloud shown when using default location (no GPS data)
- **Time fill** - Uses same step progress as activity rings (no scaling, direct 1:1 match)
- **Fenix 6S MIP Support** ✅ Added
  - Simplified layout optimized for 240x240 display
  - No activity rings (too small for MIP)
  - Centered world clocks at bottom
  - HR + battery row at very bottom
  - Simple single-circle clouds (no alpha blending on MIP)
  - MIP 64-color palette mapping

## Learnings from Development (January 2026)

### SDK Setup
- **SDK Location**: `~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-X.X.X-YYYY-MM-DD-xxxxx/`
- **Java 17 required**: Install via `brew install openjdk@17` then symlink to `/Library/Java/JavaVirtualMachines/`
- **Signing key**: Must be DER format (not PEM). Generate with:
  ```bash
  openssl genrsa -out developer_key_raw.pem 4096
  openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key_raw.pem -out developer_key.der -nocrypt
  ```

### Build, Preview & Iterate

**Primary workflow — use `preview.sh` for visual iteration:**
```bash
# Prerequisite: simulator must be running (launch once per session)
SDK_PATH="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc"
"$SDK_PATH/bin/connectiq" &

# Build + push to simulator + capture screenshot (one command)
./preview.sh                  # default: fenix847mm
./preview.sh fenix847mm       # explicit device

# Screenshot saved to screenshots/latest.png (overwritten each time)
# Claude reads screenshots/latest.png to SEE the watch face
```

**The iteration loop:**
1. Edit source code
2. Run `./preview.sh` (~5 seconds)
3. Read `screenshots/latest.png` for a full overview
4. **ALWAYS crop-zoom** the area you changed — the full thumbnail is too small to judge pixel alignment
5. Read the cropped image to verify, fix issues, repeat

**Crop-zoom protocol (`sips`):**

The full screenshot is **1562×2090 px** (simulator window capture of the fenix847mm). The watch dial is centered within it. Use `sips -c` to crop specific zones:

```bash
# Syntax: sips -c <height> <width> --cropOffset <y> <x> <input> -o <output>
#   height/width = size of the crop rectangle
#   y/x = top-left corner of the crop (from top-left of image)

# Named zones (copy-paste ready):
sips -c 100 500 --cropOffset 560 530 screenshots/latest.png -o screenshots/detail.png  # HEADER (icon + temp + location)
sips -c 350 850 --cropOffset 530 350 screenshots/latest.png -o screenshots/detail.png  # CHART (weather chart + day labels)
sips -c 150 600 --cropOffset 810 480 screenshots/latest.png -o screenshots/detail.png  # DATE (date line + week badge)
sips -c 300 700 --cropOffset 890 420 screenshots/latest.png -o screenshots/detail.png  # TIME (time digits + seconds/AM-PM)
sips -c 350 800 --cropOffset 1130 370 screenshots/latest.png -o screenshots/detail.png # BOTTOM (rings + world clocks + icons)
```

Visual map of crop zones on the 1562×2090 screenshot:
```
y=530  ┌─ HEADER ──────────┐  (100×500 @ 560,530)
y=530  ┌─── CHART ─────────────┐  (350×850 @ 530,350)
y=810  │  ┌─ DATE ──────┐      │  (150×600 @ 810,480)
y=890  │  ┌─ TIME ──────────┐  │  (300×700 @ 890,420)
y=1130 └──┌─ BOTTOM ────────────┐  (350×800 @ 1130,370)
```

**Rules:**
- NEVER declare a UI change "looks good" from the full thumbnail alone
- After cropping, Read the `screenshots/detail.png` file to actually see it
- If the crop misses your target, adjust offsets and re-crop — don't guess

**Multi-value testing for activity-dependent UI:**

When changes affect step fill, rings, or any activity-based display, test at multiple levels by editing `DEBUG_STEPS` / `DEBUG_FLOORS` / etc. constants in WatchFaceView.mc:

```monkeyc
// Set DEBUG_SIMULATOR = true, then test each set (build + crop-verify each):
// Set 1: Low    → DEBUG_STEPS=3000  (30%)  GOAL=10000, FLOORS=2, HR=55, BB=30
// Set 2: Mid    → DEBUG_STEPS=6700  (67%)  GOAL=10000, FLOORS=5, HR=82, BB=54
// Set 3: High   → DEBUG_STEPS=8900  (89%)  GOAL=10000, FLOORS=8, HR=95, BB=85
// Set 4: Over   → DEBUG_STEPS=13500 (135%) GOAL=10000, FLOORS=14, HR=68, BB=72
// IMPORTANT: Set DEBUG_SIMULATOR = false before committing!
```

At each level, crop the TIME zone and BOTTOM zone, then visually compare that the time fill percentage matches the ring fill percentage.

**Manual build (without preview):**
```bash
SDK_PATH="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc"
"$SDK_PATH/bin/monkeyc" -d fenix847mm -f monkey.jungle -o watchface.prg -y developer_key.der
"$SDK_PATH/bin/monkeydo" watchface.prg fenix847mm
```

**Note:** The simulator crashes on first `monkeydo` push after launch. Second push works. The `preview.sh` script runs monkeydo in background — if the screenshot shows an empty sim, just run it again.

### Monkey C Language Gotchas
1. **Type annotations** - Generally avoid, except for HTTP callbacks (SDK 8.4.0+ requires them):
   ```monkeyc
   // Regular functions - no type annotations needed:
   function draw(dc) {}

   // HTTP callbacks - REQUIRE type annotations in SDK 8.4.0+:
   function handleResponse(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
       // Must use typed signature for makeWebRequest callbacks
   }
   ```

2. **Permissions**: Use `Background` permission (not `Weather`) for weather API access:
   ```xml
   <iq:uses-permission id="Background"/>
   ```

3. **AOD detection**: Don't use `requiresBurnInProtection` - it's always true on AMOLED. Track sleep state with callbacks:
   ```monkeyc
   private var _isAwake = true;
   function onEnterSleep() { _isAwake = false; WatchUi.requestUpdate(); }
   function onExitSleep() { _isAwake = true; WatchUi.requestUpdate(); }
   ```

4. **Dynamic layout**: Don't hardcode 454x454. Use `dc.getWidth()`/`dc.getHeight()` and calculate proportionally:
   ```monkeyc
   function initLayout(dc) {
       screenWidth = dc.getWidth();
       screenHeight = dc.getHeight();
   }
   function getCenter() { return screenWidth / 2; }
   function getTimeY() { return (screenHeight * 0.66).toNumber(); }
   ```

5. **Weather API**:
   - `Weather.getHourlyForecast()` returns array of hourly forecasts (up to 72 hours = 3 days)
   - `Weather.getCurrentConditions()` returns current weather
   - Each hourly entry has: `temperature`, `windSpeed`, `precipitationChance`, `forecastTime`, etc.
   - Returns `null` if no weather data available - always check!

6. **Number conversions**: Use `.toFloat()` and `.toNumber()` explicitly for arithmetic

### External Weather API (Open-Meteo)

**How it works:**
1. Background service (`WeatherService.mc`) runs every 30 minutes
2. Gets last GPS position via `Position.getInfo()` (cached from previous activities)
3. Fetches weather from Open-Meteo API (free, no API key needed)
4. Stores data in `Application.Storage`
5. `WeatherDataManager.mc` reads from storage on next screen refresh
6. Falls back to Garmin Weather API if no external data available

**GPS Location Flow:**
```
You go for a run with GPS → Watch caches position → Background service uses it
                                                            ↓
Travel to new city → Old position still cached → Weather shows old location
                                                            ↓
Go for a run in new city → Position updates → Weather now shows new location
```

**Permissions required:**
```xml
<iq:uses-permission id="Background"/>      <!-- Background service -->
<iq:uses-permission id="Communications"/>  <!-- HTTP requests -->
<iq:uses-permission id="Positioning"/>     <!-- Read GPS position -->
```

**Open-Meteo API endpoint:**
```
https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&hourly=temperature_2m,precipitation_probability,cloudcover,windspeed_10m&forecast_days=4&timezone=auto
```
Note: We request 4 days even though UI shows 72h, to ensure full coverage regardless of current time of day.

### Custom Mini-Digit and Mini-Letter Renderers
**Problem**: `FONT_XTINY` is the smallest Garmin font but still too large for some UI elements (temp boxes on chart, HR in ring center, day labels).

**Solution**: Custom pixel-based renderers using `fillRectangle()`:
- `drawMiniDigit()` - 8x10 pixel digits (0-9) for numbers
- `drawMiniLetter()` - 9x11 pixel letters (M, T, W, F, S, U, O, H, R, A, E, -) for day labels and "--" placeholder
- `drawMiniNumber()` - Wrapper for multi-digit numbers (supports negative)
- `drawMiniText()` - Wrapper for multi-letter text, centered

```monkeyc
// Draw two-letter day labels centered at position
drawMiniText(dc, centerX, y, "TU", color);

// Draw numbers (HR, steps, temps)
drawMiniNumber(dc, centerX, centerY, 68, color);
```

### Organic Cloud Rendering
**Problem**: Rectangle clouds look blocky and ugly.

**Solution**: Use overlapping `fillCircle()` calls to create puffy cloud shapes:
```monkeyc
// Draw puffy cloud with multiple overlapping circles
dc.fillCircle(x + 4, baseY, 4);      // left puff
dc.fillCircle(x + 10, baseY, 5);     // center (larger)
dc.fillCircle(x + 17, baseY, 4);     // right puff
if (cloudCoverage > 50) {
    dc.fillCircle(x + 7, baseY - 3, 3);   // top-left puff
    dc.fillCircle(x + 13, baseY - 3, 3);  // top-right puff
}
```
- Opacity scales with cloud coverage percentage
- More/larger circles for heavier cloud cover

### UI Layout Tips
- **Header spacing**: Use at least 20px between stacked text lines to avoid overlap
- **Ring center text**: Mini-digits work well for HR display in activity rings
- **Week badge**: Height matches font height for vertical alignment with date text
- **Day labels**: Two-letter abbreviations (MO, TU, WE, TH, FR, SA, SU) using 9x11 mini-letters
- **Secondary timezones**: Two timezones (SAO + SFO) stacked vertically with label on left, time on right
- **Icon spacing**: 18px vertical spacing works well for 9x10 pixel icons

### Round Display Layout Considerations
The 454x454 display is circular, so elements near the edges get clipped. Key learnings:

1. **Horizontal text on same line**: When placing label + value side by side (e.g., "SAO 07:14"), use 50-65px gap between them. `FONT_XTINY` text is wider than expected - a 3-letter label like "SAO" takes ~30px.

2. **Vertical stacking for multiple items**: When showing multiple data points (like two timezones), stack vertically with 40px total spread. Each row: label left-justified, time right of label with large gap.

3. **Edge cutoff at corners**: At Y positions far from center (like ringsY ± 30), the horizontal safe area shrinks. Test elements near edges - if text gets cut, move the whole block toward center.

4. **Positioning formula for bottom-right area** (timezones):
   ```monkeyc
   var tzX = center + 80;           // Base X position
   var labelX = tzX - 80;           // Labels far left
   var timeX = tzX - 15;            // Times left of edge
   var tzY1 = ringsY - 30;          // First row (higher)
   var tzY2 = ringsY + 10;          // Second row (lower)
   ```

5. **Heart icon with HR**: HR number displays alone in ring center; heart icon appears in the icon column (below steps/stairs/body battery icons). Shows "--" when no HR data available.

### Activity Rings Design

**Ring Sizes** (optimized for 454px display):
- Outer radius: 48px, Middle: 38px, Inner: 28px
- Stroke width: 6px
- Position: `center - 85` horizontally (moved left to avoid right edge clipping)

**Apple-Style Overflow Effect** (when progress > 100%):
The key insight is that Apple doesn't use arrows - just visual layering:
```monkeyc
// 1. Base ring at 50% brightness (shows it's "underneath")
dc.setColor(Theme.dimColor(color, 0.5), Graphics.COLOR_TRANSPARENT);
dc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, 90, -270);

// 2. Black shadow offset by 3px (creates depth/floating effect)
dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
dc.drawArc(x + 3, y + 3, radius, ...);

// 3. Bright overflow arc at 125% brightness (clearly "on top")
dc.setColor(Theme.brightenColor(color, 1.25), Graphics.COLOR_TRANSPARENT);
dc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, 90, 90 - overflowDeg);

// 4. Rounded end caps (slightly larger at tip to emphasize "head")
dc.fillCircle(tipX, tipY, (stroke / 2) + 1);
```

**Cycling Center Data** (rotates every 5 seconds):
```monkeyc
var cycleIndex = (clockTime.sec / 5) % 4;
// 0=Steps (teal), 1=HR (red), 2=Floors (yellow), 3=Body Battery (blue)
```
- Each value displays in its matching ring color
- 4 small indicator dots below show which metric is active (bright dot = current)

**Theme.brightenColor()** - Added to Theme.mc for overflow effect:
```monkeyc
function brightenColor(color, factor) {
    var r = ((color >> 16) & 0xFF) * factor;
    // ... clamp to 255 max
    return (r.toNumber() << 16) | (g.toNumber() << 8) | b.toNumber();
}
```

### Project Structure (Simplified)
```
garmin_watch_face/
├── manifest.xml
├── monkey.jungle
├── developer_key.der
├── preview.sh               # Build + push + screenshot (./preview.sh fenix847mm)
├── simulation-data.json     # Mock weather data for simulator
├── screenshots/             # Auto-generated simulator screenshots (gitignored)
├── CLAUDE.md
├── TODO.md
├── source/
│   ├── WatchFaceApp.mc      # App entry point + getServiceDelegate()
│   ├── WatchFaceView.mc     # All rendering (weather, time, stats, rings)
│   ├── WatchFaceDelegate.mc # Sleep/wake handling
│   ├── WeatherDataManager.mc # Weather data cache + Garmin API fallback
│   ├── WeatherService.mc    # Background service for Open-Meteo API
│   ├── Theme.mc             # Colors, layout constants, and theming
│   └── Settings.mc          # Settings cache with typed getters
└── resources/
    ├── strings/strings.xml  # UI strings (~100 strings)
    ├── settings/settings.xml # Settings UI (5 groups, 22 settings)
    ├── properties.xml       # Default property values
    ├── drawables/drawables.xml
    └── drawables/launcher_icon.png
```

### Remaining TODOs
- ~~Connect real Weather API~~ ✅ Done (WeatherDataManager.mc + WeatherService.mc)
- ~~External Weather API~~ ✅ Done (Open-Meteo via background service)
- ~~Time fill visual fix~~ ✅ Done (1.5x scale factor)
- ~~Read actual Body Battery~~ ✅ Done (SensorHistory.getBodyBatteryHistory)
- ~~Read actual HR~~ ✅ Done (Activity.getActivityInfo + ActivityMonitor.getHeartRateHistory)
- ~~Add battery indicator~~ ✅ Done (top-right corner)
- ~~GPS-based location~~ ✅ Done (uses last GPS position from activities)
- ~~Test external weather API on real device~~ ✅ Working!
- ~~Implement settings screen~~ ✅ Done (22 settings across 6 categories)
- ~~HR not showing in ring center~~ ✅ Fixed - added bounds validation for `centerData` setting, HR number in center with heart icon in icon column
- ~~Activity rings too small~~ ✅ Fixed - larger rings (48/38/28), Apple-style overflow effect, cycling center data every 5 seconds

### Settings System

**22 Configurable Settings in 5 Groups:**

1. **Time & Date**:
   - Clock format (12h/24h/System)
   - Show seconds (on/off)
   - Date format (3 options)
   - Show week number (on/off)

2. **World Clocks**:
   - World clock count (0/1/2)
   - Timezone 1 (25 cities)
   - Timezone 2 (25 cities)

3. **Weather Chart**:
   - Show weather chart (on/off)
   - Temperature curve (on/off)
   - Precipitation (on/off)
   - Clouds (on/off)
   - Wind (on/off)
   - Temperature unit (C/F)
   - Forecast range (48h/72h)

4. **Activity Rings**:
   - Ring layout (All 3/2 Rings/Off)
   - Outer ring data (Steps/Floors/Body Battery/HR/Off)
   - Middle ring data
   - Inner ring data
   - Show ring icons (on/off)
   - Note: Center data now auto-cycles through all 4 metrics every 5 seconds

5. **Appearance**:
   - Theme (Dark/Warm/Cool/High Contrast)
   - Accent color (Teal/Orange/Blue/Purple/Red)
   - Time color (White/Warm White/Cool White)
   - Battery display (Always/<50%/<20%/Off)

**City List (25 cities for world clocks):**
NYC, LAX, CHI, DEN, SAO, MEX, LON, PAR, BER, MAD, ROM, AMS, MOS, DUB, MUM, SIN, HKG, TYO, SEL, SYD, AKL, HNL, ANC, TOR, VAN

### Fenix 6S MIP Layout (Simplified)

The Fenix 6S uses a 240x240 MIP display with only 64 colors (no alpha blending). The layout is simplified:

```
┌─────────────────────────┐
│     18° • Pozuelo      │  ← Header: temp + location (smaller)
│                         │
│  ▓▓▓ Weather Chart ▓▓▓  │  ← Weather chart (simplified, ~40px height)
│  MO   TU   WE   TH      │
│                         │
│     tue 15 jan [W03]    │  ← Date with week badge
│                         │
│        12:34            │  ← Time (main focus)
│          :56 PM         │  ← Seconds + AM/PM
│                         │
│     SAO 07:14           │  ← World clocks (CENTERED)
│     SFO 04:14           │
│      ♥ 68  🔋 85%       │  ← HR + Battery (bottom row)
└─────────────────────────┘
```

**Removed for MIP:**
- Activity rings (too small at 240px)
- Apple-style overflow effect
- Ring center cycling data
- Ring icons
- Organic multi-circle clouds (replaced with simple circles)

**MIP 64-Color Palette:**
Colors are quantized to 6 levels per channel: `0x00`, `0x55`, `0xAA`, `0xFF`

### Build Commands

```bash
# Preferred: use preview.sh for visual iteration (see "Build, Preview & Iterate" above)
./preview.sh fenix847mm

# Manual build (for sideloading to real device)
SDK_PATH="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc"
"$SDK_PATH/bin/monkeyc" -d fenix847mm -f monkey.jungle -o watchface-f8.prg -y developer_key.der
```

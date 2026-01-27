# Garmin OLED Weather Watch Face

## Project Goal
Build a Connect IQ watch face for **Garmin Fenix 8 47mm AMOLED (454x454 pixels)** that recreates the "Rain & Clouds" style weather watch face but redesigned for OLED displays.

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
- **Target API level**: 5.0+ (for AMOLED luminance-based burn-in heuristics)
- **Target device**: fenix8 47mm AMOLED (device ID: `fenix847mm` or similar -- verify in CIQ SDK)
- **Weather data**: Primary: Open-Meteo API (via background service). Fallback: Garmin Weather API
- **Location**: Uses last GPS position from activities (updates when you run/bike/hike with GPS)
- **Build system**: monkey.jungle file

## Architecture Notes
- **WatchFaceApp.mc**: App entry point, provides `getServiceDelegate()` for background weather service
- **WatchFaceView.mc**: Main view - all rendering (weather chart, time, stats, rings, AOD)
- **WatchFaceDelegate.mc**: Handles power mode transitions (sleep/wake for AOD)
- **WeatherService.mc**: Background service that fetches from Open-Meteo API every 30 min
- **WeatherDataManager.mc**: Module that caches weather data, tries external first then Garmin API
- **Theme.mc**: Module holding all color constants and spacing values
- Settings via CIQ properties for: units (C/F, km/mi), 12/24h, data field selection, theme selection

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
- Activity rings with HR (+ heart icon) in center, steps below
- Two secondary timezones: São Paulo (UTC-3) and San Francisco (UTC-8)
- **External Weather API (Open-Meteo)** ✅ Working on real device!
  - Fetches 4 days of data every 30 minutes via background service (UI shows 72h)
  - Uses last GPS position from activities (updates when you run/bike)
  - Falls back to Garmin API if no GPS position or external data unavailable
- **Time fill visual fix** - Scaled by 1.5x so visual fill matches perceived completion

## Learnings from Development (January 2026)

### SDK Setup
- **SDK Location**: `~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-X.X.X-YYYY-MM-DD-xxxxx/`
- **Java 17 required**: Install via `brew install openjdk@17` then symlink to `/Library/Java/JavaVirtualMachines/`
- **Signing key**: Must be DER format (not PEM). Generate with:
  ```bash
  openssl genrsa -out developer_key_raw.pem 4096
  openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key_raw.pem -out developer_key.der -nocrypt
  ```

### Build & Run Commands
```bash
SDK_PATH="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc"
"$SDK_PATH/bin/monkeyc" -d fenix847mm -f monkey.jungle -o watchface.prg -y developer_key.der
"$SDK_PATH/bin/monkeydo" watchface.prg fenix847mm
```

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
- `drawMiniLetter()` - 9x11 pixel letters (M, T, W, F, S, U, O, H, R, A, E) for day labels
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

5. **Heart icon with HR**: Use compact 6x5 pixel heart icon. Position heart to left of HR number, adjust based on digit count (2 vs 3 digits for HR ≥100) to keep centered in ring.

### Project Structure (Simplified)
```
garmin_watch_face/
├── manifest.xml
├── monkey.jungle
├── developer_key.der
├── simulation-data.json     # Mock weather data for simulator
├── CLAUDE.md
├── TODO.md
├── source/
│   ├── WatchFaceApp.mc      # App entry point + getServiceDelegate()
│   ├── WatchFaceView.mc     # All rendering (weather, time, stats, rings)
│   ├── WatchFaceDelegate.mc # Sleep/wake handling
│   ├── WeatherDataManager.mc # Weather data cache + Garmin API fallback
│   ├── WeatherService.mc    # Background service for Open-Meteo API
│   └── Theme.mc             # Colors and layout constants
└── resources/
    ├── strings.xml
    ├── settings.xml
    ├── properties.xml
    ├── drawables.xml
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
- Implement settings screen (ring data sources, timezone, theme)

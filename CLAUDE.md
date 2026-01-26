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
- **Weather data**: Use `Garmin.Weather.getHourlyForecast()` and `Garmin.Weather.getCurrentConditions()` from the built-in CIQ Weather API
- **Build system**: monkey.jungle file

## Architecture Notes
- **Theme.mc**: Module holding all color constants and spacing values as a dictionary/object. Easy to swap.
- **WeatherChart.mc**: Class responsible for drawing the multi-layer weather forecast chart on a Dc context. This is the most complex component.
- **WatchFaceView.mc**: Main view extending WatchUi.WatchFace, orchestrates layout and calls sub-renderers.
- **WatchFaceDelegate.mc**: Handles power mode transitions (sleep/wake for AOD).
- **DataFields.mc**: Renders the bottom stats area (HR, steps, data field, move bar).
- **TimeRenderer.mc**: Draws time digits with the step-goal fill effect.
- Settings via CIQ properties for: units (C/F, km/mi), 12/24h, data field selection, theme selection.

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
- Implementation not yet started
- Need to research exact CIQ project scaffolding, device IDs, and API signatures before writing code

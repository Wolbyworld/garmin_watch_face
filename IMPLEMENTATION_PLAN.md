# 10X OLED Watch Face Implementation Plan

## Current Design Analysis (What's Wrong)

After analyzing the reference images of the "Rain & Clouds" watch face, here are the key problems that make it look dated on AMOLED:

### Visual Problems

| Problem | Impact | Root Cause |
|---------|--------|------------|
| **Bright blue background** | Battery drain, retina fatigue, cheap look | MIP displays don't save power with black |
| **Pixelated bitmap fonts** | Chunky, low-res appearance | 280x280 MIP required bold chunky fonts |
| **Hatched/dithered textures** | Noisy, busy, dated | MIP used dithering for "gradient" simulation |
| **Precipitation as pixel noise** | Confusing, hard to parse | Limited color depth workaround |
| **Day/night as solid color bands** | Abrupt transitions, no elegance | MIP can't do smooth gradients |
| **Everything same visual weight** | No hierarchy, overwhelming | Cramming data into limited space |
| **Dense hour markers** | Cluttered chart | Needed for low-res legibility |
| **Gray cloud hatching** | Looks like noise/static | MIP simulation of transparency |

### Data Density (Keep This - It's Good)
The information architecture is actually excellent:
- Weather chart with multi-dimensional data (temp, precip, clouds, wind, day/night)
- Glanceable time with seconds
- Step goal progress feedback
- Key health metrics (HR, steps, distance)
- Configurable data field
- Move bar for inactivity

**Goal**: Keep ALL the data, transform the PRESENTATION.

---

## 10X Design Vision

### Core Principles

1. **OLED-Native Aesthetics**
   - True black (#000000) background everywhere
   - Pixels OFF = battery savings + infinite contrast
   - Floating elements on void

2. **Refined Visual Hierarchy**
   ```
   Layer 1 (Dominant):   TIME - largest, brightest, 30% of screen
   Layer 2 (Primary):    Weather Chart - mid-prominence, rich detail
   Layer 3 (Supporting): Date, Location - warm gray, readable
   Layer 4 (Ambient):    Stats, Battery - dim, peripheral vision
   ```

3. **Smooth, Anti-Aliased Rendering**
   - At 454x454, polylines look smooth
   - Use `fillPolygon()` for gradient-like fills
   - Layer transparency via color blending

4. **Restrained Color Palette**
   - Warm amber for temperature (life, warmth)
   - Cool cyan for water/precipitation (fresh, cool)
   - Soft grays for text hierarchy
   - Deep navy/slate for night/day sky bands
   - Accent colors only for highlights

5. **Purposeful Animation Opportunities**
   - "Now" indicator pulse
   - Step fill animation on wake
   - Smooth second tick

---

## Detailed Component Specifications

### 1. Weather Chart (The Hero Element)

**Dimensions**: Full width (454px), ~140px height, positioned upper-middle

**Layers (bottom to top)**:

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 0: BLACK BACKGROUND                                    │
├─────────────────────────────────────────────────────────────┤
│ Layer 1: DAY/NIGHT GRADIENT BAND                            │
│   • Navy (#0A1628) for night hours                          │
│   • Dark slate (#1A3050) for day hours                      │
│   • Smooth vertical gradient transitions at dawn/dusk       │
│   • Height: full chart height                               │
├─────────────────────────────────────────────────────────────┤
│ Layer 2: CLOUD COVER                                        │
│   • Semi-transparent white shapes                           │
│   • Opacity 30-60% based on cloud density                   │
│   • Organic curved shapes using polygon fills               │
│   • Positioned at top portion of chart                      │
├─────────────────────────────────────────────────────────────┤
│ Layer 3: TEMPERATURE CURVE                                  │
│   • Warm amber (#FFB347) polyline, 2px stroke               │
│   • Smooth curve through hourly data points                 │
│   • Gradient fill below curve (amber @ 40% → black)         │
│   • Temperature labels at local min/max only                │
├─────────────────────────────────────────────────────────────┤
│ Layer 4: PRECIPITATION BARS                                 │
│   • Cool cyan (#4DD0E1) vertical bars                       │
│   • Bar height = precipitation intensity (0-100%)           │
│   • 3px wide, 2px gaps between hours                        │
│   • Positioned from bottom of chart                         │
├─────────────────────────────────────────────────────────────┤
│ Layer 5: WIND INDICATORS (subtle)                           │
│   • Tiny tick marks below temperature curve                 │
│   • Tick length/angle encodes wind speed/direction          │
│   • Very dim gray (#404040)                                 │
├─────────────────────────────────────────────────────────────┤
│ Layer 6: TIME MARKERS                                       │
│   • Hour numbers every 6 hours (6, 12, 18, 0)               │
│   • Dim gray (#505050), tiny font                           │
│   • Day separators as thin vertical lines                   │
│   • Day labels (WE, TH, FR) at bottom                       │
├─────────────────────────────────────────────────────────────┤
│ Layer 7: "NOW" INDICATOR                                    │
│   • Bright white vertical line at current hour              │
│   • Small triangle pointer at top                           │
│   • Subtle glow effect (2px gradient)                       │
└─────────────────────────────────────────────────────────────┘
```

**Rendering Technique**:
```
For each layer:
  1. Calculate pixel positions from hourly data
  2. Build polygon/polyline point arrays
  3. Use Dc.setColor() with appropriate color
  4. Dc.fillPolygon() for filled areas
  5. Dc.drawLine() sequences for curves
```

### 2. Time Display

**Design**:
```
┌──────────────────────────────┐
│                              │
│         1:28                 │  ← Main digits: 120pt equivalent
│              AM              │  ← AM/PM: 24pt, superscript right
│               19             │  ← Seconds: 32pt, subscript right
│                              │
└──────────────────────────────┘
```

**Step Goal Fill Effect**:
- Calculate `fillPercent = currentSteps / stepGoal`
- Draw time digits twice:
  1. Full digits in dim gray (#404040) - "unfilled" state
  2. Clip rectangle from bottom up to `fillPercent * digitHeight`
  3. Draw digits again in bright teal (#26A69A) - "filled" state
- Creates "filling up" visual as you walk

**Font Requirements**:
- Clean sans-serif (Roboto Condensed feel)
- Use Connect IQ vector fonts if available (API 5.0+)
- Fallback to large bitmap font optimized for AMOLED

### 3. Date Display

**Format**: `wed 1 may` + week badge `[7]`

**Layout**:
```
wed 1 may  ⬛7
           └── Week number in orange badge
```

**Styling**:
- Lowercase weekday (modern feel)
- Warm gray (#B0B0B0)
- Week badge: Orange (#FF8A65) rounded rect with white number

### 4. Location + Temperature (Header)

**Layout**:
```
┌─────────────────────────────────────────┐
│  ⚡ 18° Olathe                    ⬚ 85% │
│  └─ temp    └─ location           └─ battery
└─────────────────────────────────────────┘
```

**Styling**:
- Temperature in bright white
- Location in warm gray, truncated with ellipsis if needed
- Battery: tiny icon + %, dim gray, top-right corner

### 5. Stats Row (Bottom)

**Layout**:
```
┌─────────────────────────────────────────┐
│  ♥ 142  •  7,696 steps  •  ↑ 32m        │
│  └─ HR     └─ steps/distance  └─ data field
└─────────────────────────────────────────┘
```

**Move Bar**:
- 5 small dots above stats row
- Fill with muted red (#C62828 @ 60%) based on inactivity level
- Normally hidden (black) when activity is good

### 6. Always-On Display (AOD)

**Requirements**:
- Total luminance < 10% of pixels
- Burn-in prevention via slight position shift

**Elements shown**:
- Time in outline font (1-2px stroke, no fill)
- Date (small, dim)
- Battery percentage
- NO weather chart (too bright)

---

## Technical Architecture

### File Structure
```
garmin_watch_face/
├── source/
│   ├── WeatherWatchFaceApp.mc      # App entry point
│   ├── WatchFaceView.mc            # Main view orchestration
│   ├── WatchFaceDelegate.mc        # Power/AOD handling
│   ├── Theme.mc                    # Colors, fonts, spacing
│   ├── WeatherChart.mc             # Weather visualization
│   ├── TimeRenderer.mc             # Time with step fill
│   ├── DataFields.mc               # Stats rendering
│   └── Utils.mc                    # Helper functions
├── resources/
│   ├── layouts/
│   │   └── layout.xml              # (minimal, mostly code-drawn)
│   ├── drawables/
│   │   └── launcher_icon.png       # App icon
│   ├── fonts/
│   │   └── (custom fonts if needed)
│   ├── strings/
│   │   └── strings.xml             # Localized strings
│   └── settings/
│       └── settings.xml            # User settings definitions
├── resources-eng/
│   └── strings/
│       └── strings.xml
├── manifest.xml                    # App manifest
├── monkey.jungle                   # Build configuration
└── CLAUDE.md                       # Design spec
```

### Key Classes

**Theme.mc**:
```monkey-c
module Theme {
    // Colors
    const BG = 0x000000;
    const TIME_PRIMARY = 0xFFFFFF;
    const TIME_FILL = 0x26A69A;
    const TEXT_PRIMARY = 0xB0B0B0;
    const TEXT_SECONDARY = 0x707070;
    const TEMP_CURVE = 0xFFB347;
    const PRECIPITATION = 0x4DD0E1;
    const NIGHT_SKY = 0x0A1628;
    const DAY_SKY = 0x1A3050;
    const HR_ICON = 0xE57373;
    const MOVE_BAR = 0xC62828;
    const WEEK_BADGE = 0xFF8A65;

    // Layout constants (454x454 screen)
    const SCREEN_SIZE = 454;
    const HEADER_Y = 30;
    const CHART_Y = 70;
    const CHART_HEIGHT = 140;
    const DATE_Y = 220;
    const TIME_Y = 250;
    const TIME_HEIGHT = 120;
    const STATS_Y = 400;
}
```

**WeatherChart.mc** (core render loop):
```monkey-c
class WeatherChart {
    function draw(dc, forecast, currentHour) {
        drawDayNightBand(dc, forecast);
        drawCloudCover(dc, forecast);
        drawTemperatureCurve(dc, forecast);
        drawPrecipitationBars(dc, forecast);
        drawWindIndicators(dc, forecast);
        drawTimeMarkers(dc, forecast, currentHour);
        drawNowIndicator(dc, currentHour);
    }
}
```

### API Usage

**Weather Data**:
```monkey-c
var conditions = Weather.getCurrentConditions();
var hourly = Weather.getHourlyForecast();
// hourly is array of HourlyForecast objects:
// - forecastTime (Moment)
// - temperature (Number, Celsius)
// - precipitationChance (Number, 0-100)
// - cloudCover (Number, 0-100)
// - windSpeed (Number)
// - condition (enum)
```

**Activity Data**:
```monkey-c
var activityInfo = ActivityMonitor.getInfo();
// - steps (Number)
// - stepGoal (Number)
// - moveBarLevel (Number, 0-5)

var heartRate = Activity.getActivityInfo().currentHeartRate;
```

**System Data**:
```monkey-c
var clockTime = System.getClockTime();
var settings = System.getDeviceSettings();
// - is24Hour (Boolean)
// - batteryPercentage (Number)
```

---

## Implementation Phases

### Phase 1: Scaffold & Theme (Foundation)
1. Create Connect IQ project structure
2. Set up manifest.xml for fenix847mm
3. Implement Theme.mc with all constants
4. Create minimal WatchFaceView that shows time
5. Verify builds and runs in simulator

### Phase 2: Time Display with Step Fill
1. Implement TimeRenderer.mc
2. Large time digits rendering
3. Seconds as superscript
4. AM/PM indicator (12h mode)
5. Step goal fill effect
6. Test with simulated step data

### Phase 3: Weather Chart (Core Feature)
1. Implement WeatherChart.mc structure
2. Day/night gradient band
3. Temperature curve with fill
4. Precipitation bars
5. Cloud cover shapes
6. Hour markers and day labels
7. "Now" indicator
8. Test with simulated weather data

### Phase 4: Data Fields & Stats
1. Implement DataFields.mc
2. Heart rate display with icon
3. Steps / distance display
4. Configurable data field
5. Move bar indicator
6. Battery display

### Phase 5: Integration & Polish
1. Wire up real Weather API
2. Wire up real Activity data
3. Add error handling for missing data
4. Implement date display with week badge
5. Location/temperature header

### Phase 6: AOD & Settings
1. Implement WatchFaceDelegate for power modes
2. Create AOD rendering path
3. Add settings.xml for user preferences
4. Theme selection support
5. Unit preferences (C/F, km/mi)

### Phase 7: Testing & Optimization
1. Test on device simulator
2. Memory profiling
3. Battery impact testing
4. Edge case handling
5. Final visual polish

---

## 10X Improvement Summary

| Aspect | Before (MIP) | After (OLED 10X) |
|--------|--------------|------------------|
| Background | Bright blue | True black, pixels off |
| Typography | Chunky bitmap | Clean anti-aliased sans |
| Weather chart | Pixelated, hatched | Smooth gradients, clean curves |
| Color palette | Saturated, noisy | Restrained, purposeful |
| Visual hierarchy | Everything equal | Clear layering |
| Temp curve | Jagged line | Smooth polyline with gradient fill |
| Precipitation | Pixel noise | Clean cyan bars |
| Clouds | Gray hatching | Semi-transparent shapes |
| Day/night | Solid bands | Smooth gradient transitions |
| Time display | Standard digits | Fill effect tied to step goal |
| Battery life | Poor (bright BG) | Excellent (black BG) |
| AOD support | None | Minimal outline mode |

---

## Next Steps

Ready to begin implementation. Starting with Phase 1: Project scaffold and Theme module.

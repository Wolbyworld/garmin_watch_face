# Garmin Connect IQ Implementation Plan

## Overview
Implement the OLED weather watch face for **Garmin Fenix 8 47mm AMOLED (454x454)** using Monkey C and Connect IQ SDK.

---

## Phase 1: Project Setup

### 1.1 Create Project Structure
```
garmin_watch_face/
├── source/
│   ├── WatchFaceApp.mc          # Application entry point
│   ├── WatchFaceView.mc         # Main view (orchestrates rendering)
│   ├── WatchFaceDelegate.mc     # Power mode transitions (AOD)
│   ├── Theme.mc                 # Color constants & theming
│   ├── WeatherChart.mc          # Weather chart renderer
│   ├── TimeRenderer.mc          # Time with step-fill effect
│   ├── StatsRings.mc            # Concentric activity rings
│   ├── DateRenderer.mc          # Date & week number badge
│   └── HeaderRenderer.mc        # Location, temp, battery, timezone
├── resources/
│   ├── strings.xml              # Localized strings
│   ├── settings.xml             # User-configurable settings
│   ├── drawables.xml            # Drawable resources
│   └── layouts/
│       └── layout.xml           # Layout definitions
├── manifest.xml                 # App manifest (device, permissions)
└── monkey.jungle                # Build configuration
```

### 1.2 manifest.xml Configuration
```xml
<iq:manifest version="3">
    <iq:application id="weather-oled-face" type="watchface">
        <iq:products>
            <iq:product id="fenix8solar47mm"/>
            <iq:product id="fenix847mm"/>
        </iq:products>
        <iq:permissions>
            <iq:uses-permission id="Weather"/>
            <iq:uses-permission id="SensorHistory"/>
        </iq:permissions>
        <iq:languages>
            <iq:language>eng</iq:language>
        </iq:languages>
    </iq:application>
</iq:manifest>
```

### 1.3 Required APIs
- `Toybox.Weather` - Weather forecasts
- `Toybox.ActivityMonitor` - Steps, floors, move bar
- `Toybox.Activity` - Heart rate
- `Toybox.System` - Battery, clock format, device settings
- `Toybox.Graphics` - All drawing primitives

---

## Phase 2: Theme System

### 2.1 Theme.mc
```monkeyc
module Theme {
    // Screen constants
    const SCREEN_SIZE = 454;
    const CENTER = 227;
    const SAFE_MARGIN = 40;

    // Layout positions (from prototype)
    const HEADER_Y = 32;
    const CHART_Y = 50;
    const CHART_HEIGHT = 115;
    const DATE_Y = 195;
    const TIME_Y = 300;
    const RINGS_Y = 368;

    // Dark theme colors
    const BG = 0x000000;
    const TIME_PRIMARY = 0xFFFFFF;
    const TIME_UNFILLED = 0x252525;
    const TIME_FILL = 0x26A69A;
    const TEXT_PRIMARY = 0xB0B0B0;
    const TEXT_SECONDARY = 0x707070;
    const TEXT_DIM = 0x454545;
    const TEMP_CURVE = 0xFFB347;
    const PRECIPITATION = 0x4DD0E1;
    const WIND_SPEED = 0xEF5350;
    const CLOUD_COLOR = 0xFFFFFF;
    const NIGHT_SKY = 0x0A1628;
    const DAY_SKY = 0x1E4D6B;
    const HR_RING = 0xE57373;
    const STEPS_RING = 0x26A69A;
    const FLOORS_RING = 0x81C784;
    const WEEK_BADGE = 0xFF8A65;
}
```

---

## Phase 3: Core Components

### 3.1 WatchFaceView.mc (Main Orchestrator)
```monkeyc
class WatchFaceView extends WatchUi.WatchFace {
    private var weatherChart;
    private var timeRenderer;
    private var statsRings;

    function initialize() {
        WatchFace.initialize();
        weatherChart = new WeatherChart();
        timeRenderer = new TimeRenderer();
        statsRings = new StatsRings();
    }

    function onUpdate(dc) {
        // Clear with true black
        dc.setColor(Theme.BG, Theme.BG);
        dc.clear();

        // Draw components in order
        drawHeader(dc);
        weatherChart.draw(dc);
        drawDate(dc);
        timeRenderer.draw(dc);
        statsRings.draw(dc);
    }
}
```

### 3.2 WeatherChart.mc (Most Complex Component)

**Layers to implement:**
1. Day/night gradient band
2. Cloud cover (soft circles with alpha)
3. Temperature curve (Catmull-Rom smoothing)
4. Wind speed line
5. Precipitation bars
6. Time markers & day separators
7. "Now" indicator

**Key implementation notes:**
- Use `dc.fillPolygon()` for temperature fill area
- Use `dc.drawLine()` segments for curves (CIQ doesn't have bezier)
- Approximate smooth curves with 5-point interpolation per segment
- Cloud opacity via multiple overlapping circles with varying alpha
- Cache weather data to avoid API calls on every frame

```monkeyc
class WeatherChart {
    private var cachedForecast = null;
    private var lastFetchTime = 0;

    function draw(dc) {
        updateWeatherCache();

        var chartX = Theme.SAFE_MARGIN + 5;
        var chartWidth = Theme.SCREEN_SIZE - (Theme.SAFE_MARGIN * 2) - 10;

        drawDayNightBand(dc, chartX, chartWidth);
        drawClouds(dc, chartX, chartWidth);
        drawTemperatureCurve(dc, chartX, chartWidth);
        drawWindLine(dc, chartX, chartWidth);
        drawPrecipitation(dc, chartX, chartWidth);
        drawTimeMarkers(dc, chartX, chartWidth);
        drawNowIndicator(dc, chartX);
    }

    private function catmullRom(p0, p1, p2, p3, t) {
        var t2 = t * t;
        var t3 = t2 * t;
        return 0.5 * (
            (2 * p1) +
            (-p0 + p2) * t +
            (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
            (-p0 + 3 * p1 - 3 * p2 + p3) * t3
        );
    }
}
```

### 3.3 TimeRenderer.mc (Step-Fill Effect)

**Implementation approach:**
1. Draw time text twice with clipping regions
2. Top clip: unfilled color (dark gray)
3. Bottom clip: filled color (teal) based on step progress

```monkeyc
class TimeRenderer {
    function draw(dc) {
        var clockTime = System.getClockTime();
        var activityInfo = ActivityMonitor.getInfo();

        var hours = clockTime.hour;
        var minutes = clockTime.min;
        var stepProgress = activityInfo.steps.toFloat() / activityInfo.stepGoal;

        // Format time string
        var timeStr = hours + ":" + minutes.format("%02d");

        var digitHeight = 76;
        var fillHeight = (digitHeight * stepProgress).toNumber();
        var baseY = Theme.TIME_Y;

        // Draw unfilled portion (top)
        dc.setClip(0, baseY - digitHeight, Theme.SCREEN_SIZE, digitHeight - fillHeight);
        dc.setColor(Theme.TIME_UNFILLED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER, baseY, Graphics.FONT_NUMBER_THAI_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.clearClip();

        // Draw filled portion (bottom)
        dc.setClip(0, baseY - fillHeight, Theme.SCREEN_SIZE, fillHeight);
        dc.setColor(Theme.TIME_FILL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER, baseY, Graphics.FONT_NUMBER_THAI_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.clearClip();
    }
}
```

### 3.4 StatsRings.mc (Concentric Activity Rings)

```monkeyc
class StatsRings {
    function draw(dc) {
        var activityInfo = ActivityMonitor.getInfo();
        var hrIterator = ActivityMonitor.getHeartRateHistory(1, true);
        var hr = hrIterator.next().heartRate;

        var stepsProgress = activityInfo.steps.toFloat() / activityInfo.stepGoal;
        var floorsProgress = activityInfo.floorsClimbed.toFloat() / activityInfo.floorsClimbedGoal;
        var hrProgress = (hr - 50).toFloat() / 130;

        // Draw concentric rings
        drawRing(dc, Theme.CENTER, Theme.RINGS_Y, 32, 6, stepsProgress, Theme.STEPS_RING);
        drawRing(dc, Theme.CENTER, Theme.RINGS_Y, 24, 6, hrProgress, Theme.HR_RING);
        drawRing(dc, Theme.CENTER, Theme.RINGS_Y, 16, 6, floorsProgress, Theme.FLOORS_RING);

        // Draw stats labels below
        drawStatsLabels(dc, activityInfo.steps, hr, activityInfo.floorsClimbed);
    }

    private function drawRing(dc, x, y, radius, stroke, progress, color) {
        // Background ring (dim)
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(stroke);
        // Draw arc from -90deg, progress * 360deg
        drawArc(dc, x, y, radius, -90, progress * 360);
    }

    private function drawArc(dc, x, y, radius, startDeg, sweepDeg) {
        // CIQ uses drawArc(x, y, r, attr, startDeg, endDeg)
        dc.drawArc(x, y, radius, Graphics.ARC_COUNTER_CLOCKWISE,
                   startDeg, startDeg + sweepDeg);
    }
}
```

---

## Phase 4: AOD (Always-On Display)

### 4.1 WatchFaceDelegate.mc
```monkeyc
class WatchFaceDelegate extends WatchUi.WatchFaceDelegate {
    function onPowerBudgetExceeded(info) {
        // Reduce update rate or simplify rendering
    }
}
```

### 4.2 AOD Mode Rendering
- Time only (thin outline font)
- Date (small, dim)
- Battery percentage
- No weather chart, no rings
- Target: <10% screen luminance

```monkeyc
function onUpdate(dc) {
    if (System.getDeviceSettings().isInSleepMode) {
        drawAOD(dc);
    } else {
        drawFullFace(dc);
    }
}

function drawAOD(dc) {
    dc.setColor(Theme.BG, Theme.BG);
    dc.clear();

    // Time only - dim white
    dc.setColor(0x606060, Graphics.COLOR_TRANSPARENT);
    dc.drawText(Theme.CENTER, Theme.CENTER, Graphics.FONT_NUMBER_MILD,
                getTimeString(), Graphics.TEXT_JUSTIFY_CENTER);
}
```

---

## Phase 5: Settings & Configuration

### 5.1 settings.xml
```xml
<settings>
    <setting propertyKey="@Properties.tempUnit" title="@Strings.tempUnit">
        <settingConfig type="list">
            <listEntry value="0">@Strings.celsius</listEntry>
            <listEntry value="1">@Strings.fahrenheit</listEntry>
        </settingConfig>
    </setting>
    <setting propertyKey="@Properties.clockFormat" title="@Strings.clockFormat">
        <settingConfig type="list">
            <listEntry value="0">@Strings.format12h</listEntry>
            <listEntry value="1">@Strings.format24h</listEntry>
        </settingConfig>
    </setting>
    <setting propertyKey="@Properties.secondTimezone" title="@Strings.secondTz">
        <settingConfig type="numeric" min="-12" max="12"/>
    </setting>
    <setting propertyKey="@Properties.theme" title="@Strings.theme">
        <settingConfig type="list">
            <listEntry value="0">@Strings.themeDark</listEntry>
            <listEntry value="1">@Strings.themeWarm</listEntry>
            <listEntry value="2">@Strings.themeCool</listEntry>
        </settingConfig>
    </setting>
</settings>
```

---

## Phase 6: Implementation Order

### Step 1: Scaffolding (Day 1)
- [ ] Create project structure
- [ ] Set up manifest.xml with correct device IDs
- [ ] Configure monkey.jungle build file
- [ ] Implement Theme.mc with all constants
- [ ] Create basic WatchFaceView that draws black background

### Step 2: Time Display (Day 2)
- [ ] Implement TimeRenderer with step-fill effect
- [ ] Test clipping approach on simulator
- [ ] Add AM/PM and seconds display
- [ ] Verify centering matches prototype

### Step 3: Date & Header (Day 2)
- [ ] Implement DateRenderer with week badge
- [ ] Implement HeaderRenderer (location, battery, timezone)
- [ ] Verify safe zone compliance

### Step 4: Stats Rings (Day 3)
- [ ] Implement StatsRings with concentric design
- [ ] Connect to ActivityMonitor for real data
- [ ] Add stats labels below rings
- [ ] Test with various progress values

### Step 5: Weather Chart (Days 4-6)
- [ ] Implement day/night gradient band
- [ ] Add precipitation bars
- [ ] Implement temperature curve with smoothing
- [ ] Add wind speed line
- [ ] Implement cloud rendering
- [ ] Add time markers and day separators
- [ ] Add "now" indicator
- [ ] Cache weather data efficiently

### Step 6: Polish & AOD (Day 7)
- [ ] Implement AOD mode
- [ ] Add settings/configuration
- [ ] Performance optimization
- [ ] Test on actual device
- [ ] Memory profiling

---

## Technical Challenges & Solutions

### Challenge 1: Smooth Curves
**Problem:** CIQ has no bezier curves
**Solution:** Catmull-Rom spline with line segments (5 points per data point)

### Challenge 2: Semi-transparent Clouds
**Problem:** Limited alpha support in CIQ
**Solution:** Use `dc.setColor()` with alpha-blended colors, draw multiple overlapping circles

### Challenge 3: Step-Fill Text Effect
**Problem:** No native text masking
**Solution:** Draw text twice with `dc.setClip()` regions

### Challenge 4: Weather Data Caching
**Problem:** API calls are expensive
**Solution:** Cache forecast, refresh every 30 minutes

### Challenge 5: Arc Drawing for Rings
**Problem:** Need progress arcs from top (-90 degrees)
**Solution:** Use `dc.drawArc()` with calculated start/end angles

---

## Testing Checklist

- [ ] Verify on Fenix 8 simulator
- [ ] Test with 0%, 50%, 100% step progress
- [ ] Test 12h and 24h clock formats
- [ ] Test with no weather data available
- [ ] Test AOD luminance compliance
- [ ] Memory usage < 100KB
- [ ] Battery impact assessment
- [ ] Test all theme variations

---

## Files to Create

| File | Purpose | Complexity |
|------|---------|------------|
| `manifest.xml` | App config | Low |
| `monkey.jungle` | Build config | Low |
| `Theme.mc` | Constants | Low |
| `WatchFaceApp.mc` | Entry point | Low |
| `WatchFaceView.mc` | Main view | Medium |
| `WatchFaceDelegate.mc` | AOD handling | Low |
| `TimeRenderer.mc` | Time + step fill | Medium |
| `DateRenderer.mc` | Date + week badge | Low |
| `HeaderRenderer.mc` | Top bar | Low |
| `StatsRings.mc` | Activity rings | Medium |
| `WeatherChart.mc` | Weather viz | **High** |
| `settings.xml` | User settings | Low |
| `strings.xml` | Localization | Low |

---

## Next Steps

1. **Verify SDK setup** - Ensure Connect IQ SDK 7.x is installed
2. **Create project** - Use `connectiq` CLI or VS Code extension
3. **Start with Theme.mc** - Get constants from prototype
4. **Build incrementally** - Test each component in simulator before moving on

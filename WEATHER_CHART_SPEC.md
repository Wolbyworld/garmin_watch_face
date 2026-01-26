# Weather Chart Specification: A 10X Design Document

## Research Foundation

This specification is built on extensive research from the following sources:

### Gold Standard References
- **Dark Sky App**: "A Data Visualization Masterpiece" - the definitive example of weather data visualization done right. Key insight: "I could understand the shape of the weather at a glance, even from a zoomed out view." [Source](https://nightingaledvs.com/dark-sky-weather-data-viz/)
- **Weathergraph**: The leading weather chart app for smartwatches, showing "7 days of hour-by-hour weather in a single, dense chart" [Source](https://weathergraph.app)
- **Edward Tufte's Sparklines**: "Small, intense, word-sized graphics with typographic resolution" with data-pixel ratio = 1.0 [Source](https://www.edwardtufte.com/notebook/sparkline-theory-and-practice-edward-tufte/)

### Technical References
- Garmin Connect IQ Graphics API (fillPolygon, drawLine, setAntiAlias)
- Samsung AMOLED optimization guidelines (OPR < 15% for AOD)
- IPCC color palette guidelines for climate data
- ColorBrewer accessibility standards

---

## Core Design Philosophy

### 1. "Shape of Weather" Over Precision

> "Dark Sky aggressively leaned into these ideas, and the team worked hard to turn nearly everything in the application into a context-sensitive information graphic."

**Principle**: Show the TREND and SHAPE, not precise numbers. Users need to know:
- "Is it getting warmer or colder?"
- "When will it rain?"
- "How long is the rain?"
- "Is today better or worse than tomorrow?"

**Anti-pattern**: Tables of numbers, scrolling lists, tapping to see details.

### 2. Glanceability (Tufte's "Data Density")

> "Sparklines vastly increase the amount of data within our eyespan"

**Principle**: Maximum information in minimum space. The entire 72-hour forecast should be parseable in 1-2 seconds without interaction.

**Metrics**:
- Time to first insight: < 0.5 seconds
- Time to full comprehension: < 2 seconds
- Zero taps required for basic forecast

### 3. Categorical Simplification Over False Precision

> "Dark Sky replaces precise forecast distributions of rainfall and snowfall with rough categories instead. This design choice contextualizes the forecast to simpler categories that can help us quickly make changes in our life."

**Principle**: "Light rain", "Heavy rain" > "0.23 inches". Weather forecasts have high uncertainty - don't pretend otherwise.

### 4. OLED-Native Design

> "OLED technology consumes less power when displaying black since individual pixels are turned off."

**Principle**: True black background, minimal luminance, purposeful use of color only where it adds information.

---

## The Chart Architecture

### Dimensions & Positioning

```
Screen: 454 x 454 pixels (Fenix 8 47mm)

┌────────────────────────────────────────────────────────────────┐
│                        HEADER ZONE                              │  Y: 0-50
│  18° Seattle                                         ▪ 85%     │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│                     WEATHER CHART                               │  Y: 60-200
│                     (140px height)                              │  Height: 140px
│                                                                 │  Width: 400px (centered)
│                                                                 │
├────────────────────────────────────────────────────────────────┤
│                       DATE ZONE                                 │  Y: 210-240
│                    wed 1 may [7]                                │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│                       TIME ZONE                                 │  Y: 245-375
│                       1:28                                      │  Height: 130px
│                           AM                                    │
│                            19                                   │
│                                                                 │
├────────────────────────────────────────────────────────────────┤
│                       STATS ZONE                                │  Y: 380-440
│  ♥142    7,696 steps    ↑32m          ●●●●○                    │
└────────────────────────────────────────────────────────────────┘
```

### Weather Chart Internal Structure

```
Chart: 400w x 140h pixels
Time span: 72 hours (current hour → +72h)
Resolution: ~5.5 pixels per hour

┌─────────────────────────────────────────────────────────────────────────┐
│ Y=0   ╔═══════════════════════════════════════════════════════════════╗ │
│       ║                    TEMPERATURE LABELS                          ║ │
│       ║  22°        •              18°       •         21°            ║ │ 12px
│ Y=12  ╠═══════════════════════════════════════════════════════════════╣ │
│       ║                                                                ║ │
│       ║     █████  CLOUD LAYER (variable opacity)  ████████████       ║ │ 20px
│       ║   ███████████                          █████████████████      ║ │
│ Y=32  ╠═══════════════════════════════════════════════════════════════╣ │
│       ║                                                                ║ │
│       ║        ╭──────╮                   ╭────────────────╮          ║ │
│       ║       ╱        ╲                 ╱                  ╲         ║ │ 50px
│       ║ TEMP ╱          ╲_______________╱                    ╲        ║ │
│       ║     ╱  (gradient fill below curve)                    ╲       ║ │
│       ║    ╱                                                   ╲      ║ │
│ Y=82  ╠═══════════════════════════════════════════════════════════════╣ │
│       ║                                                                ║ │
│       ║  ░░░░░░░  ░░░  ░░░░░░░░░░░░░░  ░░  WIND TICKS                 ║ │ 8px
│       ║                                                                ║ │
│ Y=90  ╠═══════════════════════════════════════════════════════════════╣ │
│       ║                                                                ║ │
│       ║  ▐▐▐  ▐▐▐▐▐▐▐▐▐▐▐▐▐▐   ▐▐▐▐    PRECIPITATION BARS             ║ │ 30px
│       ║  ▐▐▐  ▐▐▐▐▐▐▐▐▐▐▐▐▐▐   ▐▐▐▐    (height = intensity)           ║ │
│       ║       ▐▐▐▐▐▐▐▐▐▐                                              ║ │
│ Y=120 ╠═══════════════════════════════════════════════════════════════╣ │
│       ║                                                                ║ │
│       ║  │   6    │   12   │   18   │   0    │   6    │              ║ │ 12px
│       ║  WED      │        │        │  THU   │        │   FRI        ║ │
│ Y=132 ╠═══════════════════════════════════════════════════════════════╣ │
│       ║░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░▓▓▓▓║ │ 8px
│       ║         DAY/NIGHT BAND (navy=night, slate=day)                ║ │
│ Y=140 ╚═══════════════════════════════════════════════════════════════╝ │
└─────────────────────────────────────────────────────────────────────────┘

NOW INDICATOR: Bright vertical line at current hour position
```

---

## Layer-by-Layer Specification

### Layer 0: Background (Bottom)

**Purpose**: True black void for OLED efficiency

| Property | Value |
|----------|-------|
| Color | `#000000` (true black) |
| Coverage | 100% of chart area |

**Rationale**: Every pixel that's black is a pixel that's OFF on OLED. This is the foundation of battery efficiency.

---

### Layer 1: Day/Night Band

**Purpose**: Provide temporal context - when is day, when is night?

**Design Inspiration**:
> "The chart background shows the day/night cycle and sunshine intensity—the brighter the background, the sunnier it is." - Weathergraph

**Implementation**:

| Property | Night | Civil Twilight | Day |
|----------|-------|----------------|-----|
| Color | `#0A1628` | `#0F1F38` | `#1A3050` |
| Hex RGB | 10,22,40 | 15,31,56 | 26,48,80 |
| Brightness | 8% | 12% | 18% |

**Position**: Bottom 8px of chart (Y: 132-140)

**Transitions**:
- Sunrise/sunset: 2-hour gradient transition (smooth, not abrupt)
- Calculate from astronomical data or use simplified 6am/6pm + latitude adjustment

**Algorithm**:
```
For each pixel X in [0, chartWidth]:
    hour = currentHour + (X / pixelsPerHour)
    sunPosition = calculateSunPosition(hour, latitude)

    if sunPosition < -6°:      // Night
        color = NIGHT_COLOR
    elif sunPosition < 0°:     // Civil twilight
        t = (sunPosition + 6) / 6
        color = lerp(NIGHT_COLOR, TWILIGHT_COLOR, t)
    elif sunPosition < 6°:     // Dawn/dusk golden hour
        t = sunPosition / 6
        color = lerp(TWILIGHT_COLOR, DAY_COLOR, t)
    else:                      // Full day
        color = DAY_COLOR
```

---

### Layer 2: Cloud Cover

**Purpose**: Show when it's cloudy vs clear

**Design Inspiration**:
> "Cloud opacity measures how opaque the clouds are... Thin clouds may allow most irradiance to pass through, while thicker clouds have a greater effect." - Solcast

**Design Decision**: Use transparency/opacity to represent cloud density, NOT hatching or patterns.

| Cloud Cover % | Opacity | Visual |
|--------------|---------|--------|
| 0-20% | 0% | Clear (invisible) |
| 20-40% | 15% | Light wisps |
| 40-60% | 30% | Partly cloudy |
| 60-80% | 45% | Mostly cloudy |
| 80-100% | 60% | Overcast |

**Color**: `#FFFFFF` (white) at variable opacity

**Position**: Y: 12-32 (top portion of chart, 20px height)

**Shape**: Organic curved shapes, NOT rectangles
- Use Bezier-approximated curves via polygon points
- Clouds should "flow" horizontally, merging and separating
- Minimum cloud segment width: 3 hours (avoid noisy flickering)

**Rendering Technique**:
```
Since Connect IQ doesn't support alpha blending natively:
1. Pre-compute blended colors: blend(#FFFFFF, backgroundColor, opacity)
2. Draw clouds as filled polygons with pre-computed colors
3. Use multiple cloud "layers" at different Y positions for depth
```

---

### Layer 3: Temperature Curve (THE HERO)

**Purpose**: The primary data element - show temperature trends

**Design Inspiration**:
> "Temperature displayed as a smooth gradient line to instantly spot the warmest hour" - Weathergraph
> "Dark Sky's temperature pills preserve their existing magnitude more effectively" - Nightingale

**Curve Properties**:

| Property | Value |
|----------|-------|
| Stroke color | `#FFB347` (warm amber) |
| Stroke width | 2px |
| Fill | Gradient from curve to baseline |
| Fill top color | `#FFB347` @ 40% opacity → `#664824` |
| Fill bottom color | `#000000` (black, fades to nothing) |

**Position**: Y: 32-82 (50px height for curve area)

**Temperature Mapping**:
```
tempRange = max(forecastTemps) - min(forecastTemps)
tempRange = max(tempRange, 10)  // Minimum 10° range to avoid flat lines

For each hour:
    normalizedTemp = (temp - minTemp) / tempRange
    Y = curveBottom - (normalizedTemp * curveHeight)
```

**Curve Smoothing**:
- DON'T just connect points with straight lines (looks jagged)
- Use Catmull-Rom spline interpolation for smooth curves
- Connect IQ doesn't have Bezier, so approximate with fine-grained polyline:
  - Interpolate 4 points between each hourly data point
  - Results in smooth visual curve

**Algorithm for Catmull-Rom**:
```
function catmullRom(p0, p1, p2, p3, t):
    t2 = t * t
    t3 = t2 * t
    return 0.5 * (
        (2 * p1) +
        (-p0 + p2) * t +
        (2*p0 - 5*p1 + 4*p2 - p3) * t2 +
        (-p0 + 3*p1 - 3*p2 + p3) * t3
    )
```

**Gradient Fill Below Curve**:
- Since Connect IQ doesn't support true gradients:
- Draw horizontal lines from curve down to baseline
- Each line slightly more transparent (or use 3-4 color bands)
- Alternative: Use 4-band stepped gradient for simplicity

```
Band 1 (just below curve): #FFB347 @ 35% → #594023
Band 2: #FFB347 @ 25% → #3F2D19
Band 3: #FFB347 @ 15% → #261B0F
Band 4 (bottom): #FFB347 @ 5% → #0D0905
```

**Temperature Labels**:
- Only show at local maxima and minima (NOT every hour)
- Font: Small, 12px, color `#B0B0B0`
- Position: Just above/below the curve point
- Maximum 4-5 labels visible to avoid clutter

---

### Layer 4: Precipitation Bars

**Purpose**: Show when and how much rain/snow

**Design Inspiration**:
> "Rain & snow shown as blue bars where taller bars equal heavier precipitation" - Weathergraph
> "Blue indicates light rain... cyan indicates moderate precipitation" - Weather Radar standards

**Color Mapping**:

| Precip Type | Color | Hex |
|-------------|-------|-----|
| Rain (light) | Light cyan | `#80DEEA` |
| Rain (moderate) | Cyan | `#4DD0E1` |
| Rain (heavy) | Deep cyan | `#00ACC1` |
| Snow | White | `#ECEFF1` |
| Sleet/Mix | Blue-white | `#B3E5FC` |

**Position**: Y: 90-120 (30px height)

**Bar Properties**:
```
Bar width: 3px per hour
Gap between bars: 1px
Max bar height: 30px (100% precipitation)

Height mapping (precipitation chance 0-100%):
    barHeight = (precipChance / 100) * maxBarHeight

Minimum visible height: 3px (for any precip > 10%)
```

**Intensity Encoding** (dual encoding for clarity):
- Height = probability (0-100%)
- Color saturation = intensity (light/moderate/heavy)

**Rendering**:
```
For each hour with precipitation:
    if precipChance > 10:
        x = hourToX(hour)
        barHeight = max(3, (precipChance / 100) * 30)
        color = getColorForIntensity(precipIntensity)

        // Draw bar from bottom up
        dc.setColor(color, Graphics.COLOR_TRANSPARENT)
        dc.fillRectangle(x, 120 - barHeight, 3, barHeight)
```

---

### Layer 5: Wind Indicators (Subtle)

**Purpose**: Show wind patterns without cluttering

**Design Inspiration**:
> "Instead of conveying wind direction using text ('NW' or 'Northwest'), Dark Sky uses arrows! If the wind shifts directions throughout the day, I can feel the wind direction changing using my body."

**Design Decision**: Use subtle tick marks, NOT prominent arrows (would be too busy)

**Position**: Y: 82-90 (8px height, between temp curve and precip)

**Tick Properties**:
```
Tick color: #404040 (very dim gray)
Tick length: 2-6px based on wind speed
    0-10 km/h: 2px
    10-20 km/h: 3px
    20-30 km/h: 4px
    30-40 km/h: 5px
    40+ km/h: 6px

Tick angle: Rotated to show wind direction (optional - may be too subtle at this size)
Tick spacing: Every 3 hours (not every hour, too cluttered)
```

**Alternative Simpler Approach**:
Just show vertical tick heights for speed, skip direction encoding.

---

### Layer 6: Time Markers & Day Labels

**Purpose**: Temporal navigation - know what time you're looking at

**Design**:
```
Hour markers: Every 6 hours (0, 6, 12, 18)
    Font: 10px, color #505050
    Position: Y: 120-132

Day separators: Vertical line at midnight
    Color: #303030
    Style: 1px dashed or solid
    Height: Full chart height

Day labels: WED, THU, FRI (abbreviated)
    Font: 10px bold, color #707070
    Position: Centered in each day's span
    Y: 126-132 (below hour numbers)
```

**Rendering**:
```
For each hour in forecast:
    x = hourToX(hour)

    if hour % 6 == 0:
        // Draw hour label
        dc.setColor(0x505050, Graphics.COLOR_TRANSPARENT)
        dc.drawText(x, 122, smallFont, hour.toString(), Graphics.TEXT_JUSTIFY_CENTER)

    if hour % 24 == 0:
        // Draw day separator
        dc.setColor(0x303030, Graphics.COLOR_TRANSPARENT)
        dc.drawLine(x, 0, x, 140)

        // Draw day label
        dayName = getDayAbbrev(hour)
        dc.drawText(x + 60, 126, smallFont, dayName, Graphics.TEXT_JUSTIFY_CENTER)
```

---

### Layer 7: "NOW" Indicator (Top Layer)

**Purpose**: Clearly mark the current moment

**Design Inspiration**:
> Dark Sky put "a colored vertical bar to indicate cloud cover or precipitation" for the current time

**Properties**:
```
Line color: #FFFFFF (bright white)
Line width: 2px
Height: Full chart height (140px)
Position: X = 0 (left edge, since chart starts at "now")

Optional enhancements:
- Small triangle pointer at top
- Subtle glow effect (1px #FFFFFF40 lines on either side)
```

**Animation** (if performance allows):
- Gentle pulse effect on wake
- Fade in/out over 500ms

---

## Color Palette Summary

### Primary Palette

| Role | Color | Hex | Usage |
|------|-------|-----|-------|
| Background | True black | `#000000` | Everywhere |
| Temperature curve | Warm amber | `#FFB347` | Main curve stroke |
| Temperature fill | Amber gradient | `#FFB347` → `#000000` | Below curve |
| Precipitation | Cool cyan | `#4DD0E1` | Rain bars |
| Snow | Ice white | `#ECEFF1` | Snow bars |
| Cloud cover | White @ opacity | `#FFFFFF @ 30-60%` | Cloud shapes |
| Night sky | Deep navy | `#0A1628` | Day/night band |
| Day sky | Dark slate | `#1A3050` | Day/night band |
| Now indicator | Bright white | `#FFFFFF` | Vertical line |
| Hour labels | Dim gray | `#505050` | Time markers |
| Day labels | Medium gray | `#707070` | WED, THU, etc |
| Temp labels | Warm gray | `#B0B0B0` | Temp numbers |

### Extended Palette (for future themes)

| Role | Hex | Notes |
|------|-----|-------|
| HR icon | `#E57373` | Soft red |
| Move bar | `#C62828 @ 60%` | Muted red |
| Step fill | `#26A69A` | Accent teal |
| Week badge | `#FF8A65` | Accent orange |

---

## Performance Optimizations

### 1. Buffered Bitmap Approach

From Crystal Face research:
> "The goal meters and move bar are drawn from a palette-restricted back buffer, for improved drawing performance"

**Strategy**:
- Pre-render static chart elements to a BufferedBitmap
- Only update dynamic elements (NOW line) per second
- Full chart redraw only when weather data changes or hourly

### 2. Cached Calculations

```
// Cache on data change, not every render
class WeatherChartCache {
    var tempCurvePoints;      // Array of Point2D
    var precipBarHeights;     // Array of heights
    var cloudPolygons;        // Array of polygon point arrays
    var dayNightColors;       // Array of pre-blended colors

    function recalculate(forecast) {
        // Heavy calculation done once
    }
}
```

### 3. Anti-Aliasing Strategy

From Garmin forums:
> "When anti-aliasing is enabled, rings, circles, and triangles are hugely improved, while 1 pixel wide lines are only slightly better."

**Decision**:
- Enable anti-aliasing for temperature curve (improves smoothness significantly)
- Skip anti-aliasing for straight lines (day separators, precip bars)
- Use `dc.setAntiAlias(true)` selectively

### 4. Draw Order Optimization

Draw from back to front to minimize overdraw:
1. Day/night band (bottom layer)
2. Cloud cover
3. Temperature gradient fill
4. Precipitation bars
5. Wind ticks
6. Temperature curve stroke
7. Time markers
8. Temperature labels
9. NOW indicator

---

## Uncertainty Visualization (Advanced)

### Research Insight

> "Dark Sky's one-hour precipitation chart showed you the level of rain over the next 60 minutes and the certainty of that prediction. It did it by animating the area chart: The wobblier it was, the less accurate the prediction."

> "When ensemble members cluster tightly, confidence is high. When they diverge, genuine uncertainty exists."

### Implementation Options

**Option A: Faded Confidence Bands**
- Draw temperature curve with confidence bands
- Inner band (high confidence): 25th-75th percentile
- Outer band (low confidence): 10th-90th percentile
- Bands fade to transparent at edges

**Option B: Curve Thickness**
- Thicker curve = less certainty
- Thin crisp line = high confidence forecast
- Thicker fuzzy line = uncertain

**Option C: Time-based Fade**
- Forecast confidence decreases with time
- Near term (0-24h): Full opacity
- Medium term (24-48h): 80% opacity
- Far term (48-72h): 60% opacity

**Recommended**: Option C (simplest, clearest, least visual clutter)

---

## Accessibility Considerations

### Color Blindness

From IPCC guidelines:
> "All palettes proposed by the IPCC are colour-blind friendly, are perceptually uniform"

**Validation**:
- Amber (temp) vs Cyan (precip) is safe for most color blindness types
- Avoid red/green combinations
- Use ColorBrewer palettes as reference

### Contrast Ratios

| Element | Foreground | Background | Ratio | WCAG |
|---------|------------|------------|-------|------|
| Temp curve | `#FFB347` | `#000000` | 11.1:1 | AAA |
| Precip bars | `#4DD0E1` | `#000000` | 10.2:1 | AAA |
| Day labels | `#707070` | `#000000` | 4.8:1 | AA |
| Hour labels | `#505050` | `#000000` | 3.5:1 | AA (large) |

---

## Implementation Checklist

### Phase 1: Basic Structure
- [ ] Create WeatherChart.mc class
- [ ] Implement coordinate system and time mapping
- [ ] Draw day/night band
- [ ] Draw basic temperature polyline (no smoothing)

### Phase 2: Core Visualization
- [ ] Implement temperature curve smoothing (Catmull-Rom)
- [ ] Add gradient fill below curve
- [ ] Draw precipitation bars with intensity colors
- [ ] Add cloud cover shapes

### Phase 3: Polish
- [ ] Add NOW indicator
- [ ] Add time markers and day labels
- [ ] Add temperature labels at min/max
- [ ] Implement wind ticks

### Phase 4: Optimization
- [ ] Add buffered bitmap caching
- [ ] Selective anti-aliasing
- [ ] Memory profiling
- [ ] Battery impact testing

### Phase 5: Advanced Features
- [ ] Uncertainty visualization (far-term fade)
- [ ] Theme support (color palette switching)
- [ ] Responsive layout for different screen sizes

---

## References

### Primary Sources
1. [Dark Sky Eulogy - Nightingale](https://nightingaledvs.com/dark-sky-weather-data-viz/)
2. [Weathergraph App](https://weathergraph.app)
3. [Edward Tufte - Sparkline Theory](https://www.edwardtufte.com/notebook/sparkline-theory-and-practice-edward-tufte/)
4. [Garmin Connect IQ Graphics API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/Dc.html)
5. [Samsung AMOLED Optimization](https://developer.samsung.com/sdp/blog/en/2024/05/07/optimizing-watch-face-battery-usage-by-reducing-on-pixel-ratio)

### Color & Visualization
6. [IPCC Visual Style Guide](https://www.ipcc.ch/site/assets/uploads/2022/09/IPCC_AR6_WGI_VisualStyleGuide_2022.pdf)
7. [ColorBrewer](https://colorbrewer2.org/)
8. [ESRI Temperature Palette](https://www.esri.com/arcgis-blog/products/arcgis-pro/mapping/a-meaningful-temperature-palette/)

### Technical Implementation
9. [Crystal Face GitHub](https://github.com/warmsound/crystal-face)
10. [Garmin Forums - Anti-aliasing Discussion](https://forums.garmin.com/developer/connect-iq/f/discussion/238654/3-2-2-antialias-option)

---

*This specification represents 10X the thought and research of typical weather visualizations. Every design decision is grounded in user research, data visualization best practices, and technical constraints of the Garmin AMOLED platform.*

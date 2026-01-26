# Watch Face TODO

## Phase B: Visual Improvements (Pending)

### 1. Cloud Coverage Enhancement
- Replace rectangles with wavy cloud-like polygon shapes
- Use varying opacity based on cloud density (30-60% opacity range)
- Reference original "Rain & Clouds" design for cloud rendering style

### 2. Day/Night Visualization
- Current thin bar (6px) may be too subtle
- Options to consider:
  - Make taller (10-15px)
  - Add gradient transition between day/night
  - Extend color into chart background area
  - Add sun/moon icons at sunrise/sunset

### 3. General Polish
- Consistent spacing throughout all elements
- Color refinements based on real device testing
- Font size adjustments for readability

---

## Future Configurability

### Ring Data Sources (Settings)
- **Outer ring**: Steps (current) | Active Minutes | Calories
- **Middle ring**: Floors (current) | Distance | Intensity Minutes
- **Inner ring**: Body Battery (current) | Stress | Sleep Score

### Secondary Timezone
- Make timezone city configurable via settings
- Options: UTC, specific city names, offset from local
- Consider showing 2-letter timezone abbreviation

### Theme Selection
- Add theme settings property
- Support multiple color themes (dark, light, high contrast)
- Per-element color customization

### Weather Data
- Currently using fake/simulated data for development
- Switch to real `Weather.getHourlyForecast()` API when ready
- Add error handling for missing weather data

### Units
- Temperature: Celsius / Fahrenheit (from system settings)
- Distance: km / mi (from system settings)
- Time format: 12h / 24h (from system settings)

---

## Known Issues

- Body Battery API needs actual implementation (currently using placeholder)
- Heart rate needs to read from Activity.getActivityInfo() for live HR
- Weather chart uses simulated data - need to connect real API

---

## Build Commands

```bash
SDK_PATH="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc"
"$SDK_PATH/bin/monkeyc" -d fenix847mm -f monkey.jungle -o watchface.prg -y developer_key.der
"$SDK_PATH/bin/monkeydo" watchface.prg fenix847mm
```

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
- ~~Currently using fake/simulated data for development~~
- ~~Switch to real `Weather.getHourlyForecast()` API when ready~~ ✅ Done
- ~~Add error handling for missing weather data~~ ✅ Done
- ~~External Weather API (Open-Meteo)~~ ✅ Done (WeatherService.mc background service)
- Add location setting (currently defaults to Madrid, lat/lon stored in Application.Storage)

### Settings Screen Configuration

**How it works:** Watch faces don't have on-device settings menus. Instead, users configure settings through the **Garmin Connect IQ mobile app** on their phone. Settings sync to the watch automatically.

**Implementation steps:**
1. Create `resources/settings.xml` - defines the settings UI shown in the mobile app
2. Update `resources/properties.xml` - defines default values for each setting
3. Read settings in code via `Application.Properties.getValue("propertyId")`
4. Handle `onSettingsChanged()` in WatchFaceApp to refresh when user changes settings

**Settings to implement:**

| Setting | Type | Options |
|---------|------|---------|
| Outer ring data | list | Steps (default), Active Minutes, Calories |
| Middle ring data | list | Floors (default), Distance, Intensity Minutes |
| Inner ring data | list | Body Battery (default), Stress, Sleep Score |
| Secondary timezone | list | UTC, EST, PST, CET, JST, or custom offset |
| Timezone offset | number | -12 to +14 (for custom) |
| Theme | list | Dark (default), High Contrast |
| Show seconds | boolean | true (default) |

**Example settings.xml structure:**
```xml
<settings>
    <setting propertyKey="@Properties.outerRingData" title="Outer Ring">
        <settingConfig type="list">
            <listEntry value="0">Steps</listEntry>
            <listEntry value="1">Active Minutes</listEntry>
            <listEntry value="2">Calories</listEntry>
        </settingConfig>
    </setting>
</settings>
```

**Alternative: On-watch tap interaction**
- Could add tap-to-cycle behavior for quick changes (e.g., tap rings area to cycle data source)
- Implement via `WatchFaceDelegate.onPress()` method
- Limited but provides quick access without phone

### Units
- Temperature: Celsius / Fahrenheit (from system settings)
- Distance: km / mi (from system settings)
- Time format: 12h / 24h (from system settings)

---

## Known Issues

- ~~Body Battery API needs actual implementation (currently using placeholder)~~ ✅ Done
- ~~Heart rate needs to read from Activity.getActivityInfo() for live HR~~ ✅ Done
- ~~Weather chart uses simulated data - need to connect real API~~ ✅ Done

## Fixed (January 2026)

- Location name: Added empty string check and fallback logic
- Precipitation: Lowered threshold to 5%, wider bars, variable intensity
- Step progress: Removed hardcoded 0.72 fallback (was causing mismatch with rings)
- Brightness: Increased all dim colors for better visibility on AMOLED
- Battery indicator: Added with color change for low battery
- Real HR: Reads from Activity.getActivityInfo() with history fallback
- Real Body Battery: Reads from SensorHistory.getBodyBatteryHistory()
- **Time fill visual fix**: Scaled progress by 1.5x so 30% real progress shows ~45% visual fill (digit pixels are mostly in upper 70% of font height)
- **External Weather API**: Open-Meteo via background service with 30-min fetch interval, falls back to Garmin API

---

## Build Commands

```bash
SDK_PATH="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc"
"$SDK_PATH/bin/monkeyc" -d fenix847mm -f monkey.jungle -o watchface.prg -y developer_key.der
"$SDK_PATH/bin/monkeydo" watchface.prg fenix847mm
```

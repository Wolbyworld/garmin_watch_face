using Toybox.Weather;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Math;
using Toybox.Application;
using Toybox.Background;

// WeatherDataManager: Fetches and caches weather data from external API (Open-Meteo)
// Falls back to Garmin Weather API if external data unavailable
// Provides 96-hour (4 days) forecast arrays for the weather chart
module WeatherDataManager {

    // Cached data arrays (96 hours)
    var temps = null;
    var hours = null;
    var precips = null;
    var clouds = null;
    var winds = null;

    // Temperature range for chart normalization
    var minTemp = 0.0;
    var maxTemp = 20.0;

    // Daily extremes for temperature boxes
    var dayHighs = null;
    var dayLows = null;
    var dayHighIdx = null;
    var dayLowIdx = null;

    // Current conditions
    var currentTemp = null;
    var locationName = "Unknown";
    var weatherSource = "garmin";  // "garmin" or "open-meteo"

    // Cache management
    var lastFetchTime = null;
    const CACHE_DURATION = 900;  // 15 minutes in seconds
    const EXT_CACHE_DURATION = 1800;  // 30 minutes for external data

    // Default values when API unavailable
    const DEFAULT_TEMP = 18.0;
    const DEFAULT_CLOUD = 30;
    const DEFAULT_PRECIP = 0;
    const DEFAULT_WIND = 5.0;

    // Check cache and refresh if needed
    function refreshIfNeeded() {
        var now = Time.now().value();

        // Check if cache is still valid
        if (lastFetchTime != null && temps != null) {
            var elapsed = now - lastFetchTime;
            if (elapsed < CACHE_DURATION) {
                return;  // Cache still valid
            }
        }

        // Register background temporal event for external weather fetch (every 30 min)
        registerBackgroundEvent();

        // Fetch fresh data (tries external first, then Garmin)
        fetchWeatherData();
        lastFetchTime = now;
    }

    // Register background temporal event for weather fetching
    function registerBackgroundEvent() {
        // Check if background is supported
        if (Toybox has :Background) {
            var lastTime = Background.getLastTemporalEventTime();
            var now = Time.now();

            // Register if never run or if > 25 min since last run
            if (lastTime == null || now.subtract(lastTime).value() > 1500) {
                // Schedule to run in 5 minutes, then every 30 min
                var runTime = now.add(new Time.Duration(300));
                Background.registerForTemporalEvent(runTime);
            }
        }
    }

    // Fetch all weather data - tries external API first, falls back to Garmin
    function fetchWeatherData() {
        // Initialize arrays
        temps = new [96];
        hours = new [96];
        precips = new [96];
        clouds = new [96];
        winds = new [96];

        dayHighs = new [4];
        dayLows = new [4];
        dayHighIdx = new [4];
        dayLowIdx = new [4];

        for (var d = 0; d < 4; d++) {
            dayHighs[d] = -100.0;
            dayLows[d] = 100.0;
            dayHighIdx[d] = 0;
            dayLowIdx[d] = 0;
        }

        minTemp = 100.0;
        maxTemp = -100.0;

        // Get current time info
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var currentHour = now.hour;

        // Fetch current conditions for location name and current temp (always from Garmin)
        fetchCurrentConditions();

        // Try external data first (from background service)
        var usedExternal = tryExternalWeatherData(currentHour);

        if (!usedExternal) {
            // Fall back to Garmin API
            fetchGarminWeatherData(currentHour);
        }

        // Ensure valid temperature range for chart normalization
        if (maxTemp <= minTemp) { maxTemp = minTemp + 10.0; }
        var tempRange = maxTemp - minTemp;
        if (tempRange < 8.0) {
            // Expand range symmetrically
            var mid = (maxTemp + minTemp) / 2.0;
            minTemp = mid - 5.0;
            maxTemp = mid + 5.0;
        }
    }

    // Try to use external weather data from Application.Storage
    // Returns true if external data was used, false otherwise
    function tryExternalWeatherData(currentHour) {
        // Check if external data exists and is fresh
        var extFetchTime = Application.Storage.getValue("ext_fetch_time");
        if (extFetchTime == null) {
            return false;
        }

        var now = Time.now().value();
        var age = now - extFetchTime;

        // External data expires after 12 hours (stale forecast is still useful)
        if (age > 43200) {
            return false;
        }

        // Read external data arrays
        var extTemps = Application.Storage.getValue("ext_temps");
        var extPrecips = Application.Storage.getValue("ext_precips");
        var extClouds = Application.Storage.getValue("ext_clouds");
        var extWinds = Application.Storage.getValue("ext_winds");

        // Validate we have temperature data at minimum
        if (extTemps == null || extTemps.size() < 24) {
            return false;
        }

        weatherSource = "open-meteo";

        // Get the hour offset to align external data with current time
        // External data starts at 00:00 of fetch day
        var fetchInfo = Gregorian.info(new Time.Moment(extFetchTime), Time.FORMAT_SHORT);
        var fetchHour = fetchInfo.hour;

        // Calculate starting index in external data
        // If fetched at 10:00, and now is 14:00 same day, offset is 4
        var hoursElapsed = (now - extFetchTime) / 3600;
        var startIdx = fetchHour + hoursElapsed;
        if (startIdx < 0) { startIdx = 0; }

        var extSize = extTemps.size();

        for (var i = 0; i < 96; i++) {
            var hour = (currentHour + i) % 24;
            hours[i] = hour;

            var extIdx = startIdx + i;
            if (extIdx < extSize && extIdx >= 0) {
                temps[i] = safeFloat(extTemps[extIdx], DEFAULT_TEMP);
                precips[i] = (extPrecips != null && extIdx < extPrecips.size())
                    ? safeNumber(extPrecips[extIdx], DEFAULT_PRECIP) : DEFAULT_PRECIP;
                clouds[i] = (extClouds != null && extIdx < extClouds.size())
                    ? safeNumber(extClouds[extIdx], DEFAULT_CLOUD) : DEFAULT_CLOUD;
                winds[i] = (extWinds != null && extIdx < extWinds.size())
                    ? safeFloat(extWinds[extIdx], DEFAULT_WIND) : DEFAULT_WIND;
            } else {
                // Extrapolate from last known value
                fillWithDefaults(i, currentHour);
            }

            // Track temperature range
            if (temps[i] < minTemp) { minTemp = temps[i]; }
            if (temps[i] > maxTemp) { maxTemp = temps[i]; }

            // Track daily extremes
            var dayIndex = (currentHour + i) / 24;
            if (dayIndex < 4) {
                if (temps[i] > dayHighs[dayIndex]) {
                    dayHighs[dayIndex] = temps[i];
                    dayHighIdx[dayIndex] = i;
                }
                if (temps[i] < dayLows[dayIndex]) {
                    dayLows[dayIndex] = temps[i];
                    dayLowIdx[dayIndex] = i;
                }
            }
        }

        return true;
    }

    // Fetch weather data from Garmin API
    function fetchGarminWeatherData(currentHour) {
        weatherSource = "garmin";

        var forecast = Weather.getHourlyForecast();

        if (forecast != null && forecast.size() > 0) {
            // Fill arrays from API data
            var forecastSize = forecast.size();

            for (var i = 0; i < 96; i++) {
                var hour = (currentHour + i) % 24;
                hours[i] = hour;

                if (i < forecastSize) {
                    var entry = forecast[i];
                    temps[i] = safeFloat(entry.temperature, DEFAULT_TEMP);
                    precips[i] = safeNumber(entry.precipitationChance, DEFAULT_PRECIP);
                    winds[i] = safeFloat(entry.windSpeed, DEFAULT_WIND);

                    // cloudCover available in API 5.1.0+, may be null in 5.0.0
                    if (entry has :cloudCover && entry.cloudCover != null) {
                        clouds[i] = entry.cloudCover;
                    } else {
                        clouds[i] = DEFAULT_CLOUD;
                    }
                } else {
                    // Extrapolate from last known value
                    fillWithDefaults(i, currentHour);
                }

                // Track temperature range
                if (temps[i] < minTemp) { minTemp = temps[i]; }
                if (temps[i] > maxTemp) { maxTemp = temps[i]; }

                // Track daily extremes
                var dayIndex = (currentHour + i) / 24;
                if (dayIndex < 4) {
                    if (temps[i] > dayHighs[dayIndex]) {
                        dayHighs[dayIndex] = temps[i];
                        dayHighIdx[dayIndex] = i;
                    }
                    if (temps[i] < dayLows[dayIndex]) {
                        dayLows[dayIndex] = temps[i];
                        dayLowIdx[dayIndex] = i;
                    }
                }
            }
        } else {
            // No forecast data - generate time-based defaults
            generateDefaultData(currentHour);
        }
    }

    // Convert condition code to readable text
    function getConditionText(condition) {
        if (condition == Weather.CONDITION_CLEAR) { return "Clear"; }
        if (condition == Weather.CONDITION_PARTLY_CLOUDY) { return "Pt Cloudy"; }
        if (condition == Weather.CONDITION_MOSTLY_CLOUDY) { return "Cloudy"; }
        if (condition == Weather.CONDITION_RAIN) { return "Rain"; }
        if (condition == Weather.CONDITION_LIGHT_RAIN) { return "Lt Rain"; }
        if (condition == Weather.CONDITION_HEAVY_RAIN) { return "Hvy Rain"; }
        if (condition == Weather.CONDITION_SNOW) { return "Snow"; }
        if (condition == Weather.CONDITION_LIGHT_SNOW) { return "Lt Snow"; }
        if (condition == Weather.CONDITION_HEAVY_SNOW) { return "Hvy Snow"; }
        if (condition == Weather.CONDITION_THUNDERSTORMS) { return "Storms"; }
        if (condition == Weather.CONDITION_FOG) { return "Fog"; }
        if (condition == Weather.CONDITION_HAZY) { return "Hazy"; }
        if (condition == Weather.CONDITION_WINDY) { return "Windy"; }
        if (condition == Weather.CONDITION_CLOUDY) { return "Cloudy"; }
        return "Weather";  // Generic fallback
    }

    // Fetch current conditions for location and current temp
    function fetchCurrentConditions() {
        var conditions = Weather.getCurrentConditions();
        if (conditions == null) {
            locationName = "No Weather";
            return;
        }

        if (conditions.temperature != null) {
            currentTemp = conditions.temperature;
        }

        // Try to get location name from various sources
        locationName = "Unknown";

        // Try observationLocationName first (may be deprecated but often works)
        if (conditions has :observationLocationName && conditions.observationLocationName != null) {
            var obsLoc = conditions.observationLocationName;
            if (obsLoc.length() > 0) {
                locationName = obsLoc;
            }
        }

        // If still unknown, show current condition as fallback (more useful than "Weather OK")
        if (locationName.equals("Unknown") && conditions has :condition && conditions.condition != null) {
            locationName = getConditionText(conditions.condition);
        }

        // Truncate if too long
        if (locationName.length() > 12) {
            locationName = locationName.substring(0, 12);
        }
    }

    // Fill array slot with extrapolated/default values
    function fillWithDefaults(idx, currentHour) {
        var hour = (currentHour + idx) % 24;
        hours[idx] = hour;

        // Use last known temp or time-based default
        if (idx > 0 && temps[idx-1] != null) {
            // Slight variation from previous value
            var hourFloat = (hour - 6).toFloat();
            var diurnal = Math.sin(hourFloat * 3.14159 / 12.0) * 2.0;
            temps[idx] = temps[idx-1] + diurnal * 0.1;
        } else {
            // Time-of-day based default
            var hourFloat = (hour - 6).toFloat();
            var tempVariation = Math.sin(hourFloat * 3.14159 / 12.0) * 8.0;
            temps[idx] = DEFAULT_TEMP + tempVariation;
        }

        precips[idx] = DEFAULT_PRECIP;
        clouds[idx] = DEFAULT_CLOUD;
        winds[idx] = DEFAULT_WIND;
    }

    // Generate complete default data when no API data available
    function generateDefaultData(currentHour) {
        for (var i = 0; i < 96; i++) {
            var hour = (currentHour + i) % 24;
            hours[i] = hour;

            // Diurnal temperature variation (warmer midday, cooler night)
            var hourFloat = (hour - 6).toFloat();
            var tempVariation = Math.sin(hourFloat * 3.14159 / 12.0) * 9.0;
            temps[i] = DEFAULT_TEMP + tempVariation;

            precips[i] = DEFAULT_PRECIP;
            clouds[i] = DEFAULT_CLOUD;
            winds[i] = DEFAULT_WIND;

            // Track temperature range
            if (temps[i] < minTemp) { minTemp = temps[i]; }
            if (temps[i] > maxTemp) { maxTemp = temps[i]; }

            // Track daily extremes
            var dayIndex = (currentHour + i) / 24;
            if (dayIndex < 4) {
                if (temps[i] > dayHighs[dayIndex]) {
                    dayHighs[dayIndex] = temps[i];
                    dayHighIdx[dayIndex] = i;
                }
                if (temps[i] < dayLows[dayIndex]) {
                    dayLows[dayIndex] = temps[i];
                    dayLowIdx[dayIndex] = i;
                }
            }
        }
    }

    // Safe float extraction with default
    function safeFloat(value, defaultVal) {
        if (value == null) {
            return defaultVal;
        }
        return value.toFloat();
    }

    // Safe number extraction with default
    function safeNumber(value, defaultVal) {
        if (value == null) {
            return defaultVal;
        }
        return value.toNumber();
    }

    // Get temperature range for chart normalization
    function getTempRange() {
        return maxTemp - minTemp;
    }
}

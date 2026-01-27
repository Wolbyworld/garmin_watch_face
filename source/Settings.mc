using Toybox.Application;
using Toybox.System;

// Central settings cache with typed getters
// All settings are cached and refreshed on demand
module Settings {
    // Cached values - Time & Date
    var _clockFormat = 2;       // 0=12h, 1=24h, 2=System
    var _showSeconds = true;
    var _dateFormat = 0;        // 0=Wed 15 Jan, 1=15 Jan Wed, 2=Jan 15
    var _showWeekNumber = true;

    // World Clocks
    var _worldClockCount = 2;   // 0=Off, 1=One, 2=Two
    var _timezone1 = 4;         // Index into city array (SAO)
    var _timezone2 = 1;         // Index into city array (LAX)

    // Weather Chart
    var _showWeatherChart = true;
    var _showTemperature = true;
    var _showPrecipitation = true;
    var _showClouds = true;
    var _showWind = true;
    var _temperatureUnit = 0;   // 0=Celsius, 1=Fahrenheit
    var _forecastHours = 1;     // 0=48h, 1=72h

    // Activity Rings
    var _ringLayout = 0;        // 0=All 3, 1=2 Rings, 2=Off
    var _outerRing = 0;         // 0=Steps, 1=Floors, 2=BodyBatt, 3=HR, 4=Off
    var _middleRing = 1;
    var _innerRing = 2;
    var _centerData = 1;        // 0=Steps, 1=HR, 2=Off
    var _showRingIcons = true;

    // Appearance
    var _theme = 0;             // 0=Dark, 1=Warm, 2=Cool, 3=HighContrast
    var _accentColor = 0;       // 0=Teal, 1=Orange, 2=Blue, 3=Purple, 4=Red
    var _timeColor = 0;         // 0=White, 1=WarmWhite, 2=CoolWhite
    var _showBattery = 0;       // 0=Always, 1=<50%, 2=<20%, 3=Off

    var _cacheValid = false;

    // City data for timezones (25 cities)
    const CITY_NAMES = ["NYC", "LAX", "CHI", "DEN", "SAO", "MEX", "LON", "PAR",
                        "BER", "MAD", "ROM", "AMS", "MOS", "DUB", "MUM", "SIN",
                        "HKG", "TYO", "SEL", "SYD", "AKL", "HNL", "ANC", "TOR", "VAN"];

    const CITY_OFFSETS = [-5, -8, -6, -7, -3, -6, 0, 1, 1, 1, 1, 1, 3, 4, 5,
                          8, 8, 9, 9, 10, 12, -10, -9, -5, -8];

    // Refresh all settings from properties storage
    function refresh() {
        var app = Application.getApp();

        // Time & Date
        _clockFormat = getNumberProperty(app, "clockFormat", 2);
        _showSeconds = getBoolProperty(app, "showSeconds", true);
        _dateFormat = getNumberProperty(app, "dateFormat", 0);
        _showWeekNumber = getBoolProperty(app, "showWeekNumber", true);

        // World Clocks
        _worldClockCount = getNumberProperty(app, "worldClockCount", 2);
        _timezone1 = getNumberProperty(app, "timezone1", 4);
        _timezone2 = getNumberProperty(app, "timezone2", 1);

        // Weather Chart
        _showWeatherChart = getBoolProperty(app, "showWeatherChart", true);
        _showTemperature = getBoolProperty(app, "showTemperature", true);
        _showPrecipitation = getBoolProperty(app, "showPrecipitation", true);
        _showClouds = getBoolProperty(app, "showClouds", true);
        _showWind = getBoolProperty(app, "showWind", true);
        _temperatureUnit = getNumberProperty(app, "temperatureUnit", 0);
        _forecastHours = getNumberProperty(app, "forecastHours", 1);

        // Activity Rings
        _ringLayout = getNumberProperty(app, "ringLayout", 0);
        _outerRing = getNumberProperty(app, "outerRing", 0);
        _middleRing = getNumberProperty(app, "middleRing", 1);
        _innerRing = getNumberProperty(app, "innerRing", 2);
        _centerData = getNumberProperty(app, "centerData", 1);
        _showRingIcons = getBoolProperty(app, "showRingIcons", true);

        // Appearance
        _theme = getNumberProperty(app, "theme", 0);
        _accentColor = getNumberProperty(app, "accentColor", 0);
        _timeColor = getNumberProperty(app, "timeColor", 0);
        _showBattery = getNumberProperty(app, "showBattery", 0);

        _cacheValid = true;
    }

    function invalidateCache() {
        _cacheValid = false;
    }

    // Helper to safely get number property
    function getNumberProperty(app, key, defaultVal) {
        var val = app.getProperty(key);
        if (val != null) {
            return val;
        }
        return defaultVal;
    }

    // Helper to safely get boolean property
    function getBoolProperty(app, key, defaultVal) {
        var val = app.getProperty(key);
        if (val != null) {
            return val;
        }
        return defaultVal;
    }

    // Ensure cache is valid before returning values
    function ensureCache() {
        if (!_cacheValid) {
            refresh();
        }
    }

    // === Time & Date Getters ===

    // Returns effective clock format: true = 24h, false = 12h
    function is24Hour() {
        ensureCache();
        if (_clockFormat == 2) {
            return System.getDeviceSettings().is24Hour;
        }
        return _clockFormat == 1;
    }

    function isShowSeconds() {
        ensureCache();
        return _showSeconds;
    }

    function getDateFormat() {
        ensureCache();
        return _dateFormat;
    }

    function isShowWeekNumber() {
        ensureCache();
        return _showWeekNumber;
    }

    // === World Clock Getters ===

    function getWorldClockCount() {
        ensureCache();
        return _worldClockCount;
    }

    function getTimezone1Index() {
        ensureCache();
        return _timezone1;
    }

    function getTimezone2Index() {
        ensureCache();
        return _timezone2;
    }

    function getTimezone1Name() {
        ensureCache();
        return CITY_NAMES[_timezone1];
    }

    function getTimezone2Name() {
        ensureCache();
        return CITY_NAMES[_timezone2];
    }

    function getTimezone1Offset() {
        ensureCache();
        return CITY_OFFSETS[_timezone1];
    }

    function getTimezone2Offset() {
        ensureCache();
        return CITY_OFFSETS[_timezone2];
    }

    // === Weather Chart Getters ===

    function isShowWeatherChart() {
        ensureCache();
        return _showWeatherChart;
    }

    function isShowTemperature() {
        ensureCache();
        return _showTemperature;
    }

    function isShowPrecipitation() {
        ensureCache();
        return _showPrecipitation;
    }

    function isShowClouds() {
        ensureCache();
        return _showClouds;
    }

    function isShowWind() {
        ensureCache();
        return _showWind;
    }

    function getTemperatureUnit() {
        ensureCache();
        return _temperatureUnit;
    }

    function isCelsius() {
        ensureCache();
        return _temperatureUnit == 0;
    }

    function getForecastHours() {
        ensureCache();
        return _forecastHours == 0 ? 48 : 72;
    }

    // Convert celsius to display temperature based on user setting
    function getDisplayTemp(celsius) {
        ensureCache();
        if (_temperatureUnit == 1) {
            // Fahrenheit
            return ((celsius.toFloat() * 9.0 / 5.0) + 32.0).toNumber();
        }
        return celsius;
    }

    // === Activity Rings Getters ===

    function getRingLayout() {
        ensureCache();
        return _ringLayout;
    }

    function getOuterRing() {
        ensureCache();
        return _outerRing;
    }

    function getMiddleRing() {
        ensureCache();
        return _middleRing;
    }

    function getInnerRing() {
        ensureCache();
        return _innerRing;
    }

    function getCenterData() {
        ensureCache();
        return _centerData;
    }

    function isShowRingIcons() {
        ensureCache();
        return _showRingIcons;
    }

    // === Appearance Getters ===

    function getTheme() {
        ensureCache();
        return _theme;
    }

    function getAccentColor() {
        ensureCache();
        return _accentColor;
    }

    function getTimeColor() {
        ensureCache();
        return _timeColor;
    }

    function getShowBattery() {
        ensureCache();
        return _showBattery;
    }

    // Check if battery should be displayed based on current level and setting
    function shouldShowBattery(batteryLevel) {
        ensureCache();
        if (_showBattery == 3) { return false; }  // Off
        if (_showBattery == 1 && batteryLevel >= 50) { return false; }
        if (_showBattery == 2 && batteryLevel >= 20) { return false; }
        return true;
    }
}

using Toybox.Application;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;

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
    var _timezone2 = 1;         // Index into city array (SFO)

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
    var _showRingIcons = true;

    // Appearance
    var _theme = 0;             // 0=Dark, 1=Warm, 2=Cool, 3=HighContrast
    var _accentColor = 0;       // 0=Teal, 1=Orange, 2=Blue, 3=Purple, 4=Red
    var _timeColor = 0;         // 0=White, 1=WarmWhite, 2=CoolWhite
    var _showBattery = 0;       // 0=Always, 1=<50%, 2=<20%, 3=Off
    var _timeFont = 0;          // 0=Bold, 1=Medium, 2=Light

    var _cacheValid = false;

    // World-clock results are stable during a normal minute update. Cache the
    // effective cities and offsets so each renderer does not repeat DST work.
    var _timezoneCacheValid = false;
    var _timezoneCacheYear = -1;
    var _timezoneCacheMonth = -1;
    var _timezoneCacheDay = -1;
    var _timezoneCacheHour = -1;
    var _timezoneCacheLocalOffsetMinutes = 0;
    var _effectiveTimezone1 = 0;
    var _effectiveTimezone2 = 0;
    var _timezone1OffsetMinutes = 0;
    var _timezone2OffsetMinutes = 0;

    // City data for timezones (25 cities)
    const CITY_NAMES = ["NYC", "SFO", "CHI", "DEN", "SAO", "MEX", "LON", "PAR",
                        "BER", "MAD", "ROM", "AMS", "MOS", "DUB", "MUM", "SIN",
                        "HKG", "TYO", "SEL", "SYD", "AKL", "HNL", "ANC", "TOR", "VAN"];

    const CITY_STANDARD_OFFSETS_MINUTES = [-300, -480, -360, -420, -180, -360, 0, 60,
                                           60, 60, 60, 60, 180, 240, 330, 480,
                                           480, 540, 540, 600, 720, -600, -540, -300, -480];

    // Fallback city when configured timezone matches local timezone
    // MAD (Madrid) index = 9
    const FALLBACK_CITY_INDEX = 9;

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
        _showRingIcons = getBoolProperty(app, "showRingIcons", true);

        // Appearance
        _theme = getNumberProperty(app, "theme", 0);
        _accentColor = getNumberProperty(app, "accentColor", 0);
        _timeColor = getNumberProperty(app, "timeColor", 0);
        _showBattery = getNumberProperty(app, "showBattery", 0);
        _timeFont = getNumberProperty(app, "timeFont", 0);

        _cacheValid = true;
        _timezoneCacheValid = false;
    }

    function invalidateCache() {
        _cacheValid = false;
        _timezoneCacheValid = false;
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

    // Get local timezone offset in minutes (for smart substitution)
    function getLocalOffsetMinutes() {
        var clockTime = System.getClockTime();
        return (clockTime.timeZoneOffset / 60).toNumber();
    }

    // Backward-compatible hour offset helper.
    function getLocalOffset() {
        return getLocalOffsetMinutes() / 60;
    }

    function normalizeTimezoneIndex(index) {
        if (index < 0 || index >= CITY_NAMES.size()) {
            return FALLBACK_CITY_INDEX;  // Return MAD
        }
        return index;
    }

    function getCityOffsetMinutes(index) {
        index = normalizeTimezoneIndex(index);
        var offset = CITY_STANDARD_OFFSETS_MINUTES[index];

        if (usesUSDst(index) && isUSDstActive()) {
            offset += 60;
        } else if (usesEuropeDst(index) && isEuropeDstActive()) {
            offset += 60;
        } else if (index == 19 && isSydneyDstActive()) {
            offset += 60;
        } else if (index == 20 && isAucklandDstActive()) {
            offset += 60;
        }

        return offset;
    }

    function usesUSDst(index) {
        return index == 0 || index == 1 || index == 2 || index == 3 ||
            index == 22 || index == 23 || index == 24;
    }

    function usesEuropeDst(index) {
        return index == 6 || index == 7 || index == 8 || index == 9 ||
            index == 10 || index == 11;
    }

    function isUSDstActive() {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return isDateInRange(now.month, now.day,
            3, secondSundayOfMonth(now.year, 3),
            11, firstSundayOfMonth(now.year, 11));
    }

    function isEuropeDstActive() {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return isDateInRange(now.month, now.day,
            3, lastSundayOfMonth(now.year, 3),
            10, lastSundayOfMonth(now.year, 10));
    }

    function isSydneyDstActive() {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return isDateInRange(now.month, now.day,
            10, firstSundayOfMonth(now.year, 10),
            4, firstSundayOfMonth(now.year, 4));
    }

    function isAucklandDstActive() {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return isDateInRange(now.month, now.day,
            9, lastSundayOfMonth(now.year, 9),
            4, firstSundayOfMonth(now.year, 4));
    }

    function isDateInRange(month, day, startMonth, startDay, endMonth, endDay) {
        if (startMonth < endMonth) {
            return (month > startMonth || (month == startMonth && day >= startDay)) &&
                (month < endMonth || (month == endMonth && day < endDay));
        }

        return (month > startMonth || (month == startMonth && day >= startDay)) ||
            (month < endMonth || (month == endMonth && day < endDay));
    }

    function firstSundayOfMonth(year, month) {
        var dow = dayOfWeekForDate(year, month, 1);
        return ((8 - dow) % 7) + 1;
    }

    function secondSundayOfMonth(year, month) {
        return firstSundayOfMonth(year, month) + 7;
    }

    function lastSundayOfMonth(year, month) {
        var lastDay = daysInMonth(year, month);
        var dow = dayOfWeekForDate(year, month, lastDay);
        return lastDay - ((dow - 1) % 7);
    }

    function dayOfWeekForDate(year, month, day) {
        var moment = Gregorian.moment({:year => year, :month => month, :day => day});
        return Gregorian.info(moment, Time.FORMAT_SHORT).day_of_week;
    }

    function daysInMonth(year, month) {
        if (month == 2) {
            return isLeapYear(year) ? 29 : 28;
        }
        if (month == 4 || month == 6 || month == 9 || month == 11) {
            return 30;
        }
        return 31;
    }

    function isLeapYear(year) {
        return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    }

    function isLocalTimezone(index) {
        return getCityOffsetMinutes(index) == getLocalOffsetMinutes();
    }

    function isLocalMadridTimezone() {
        return isLocalTimezone(FALLBACK_CITY_INDEX);
    }

    function isConfiguredMadridTimezone() {
        return normalizeTimezoneIndex(_timezone1) == FALLBACK_CITY_INDEX ||
            normalizeTimezoneIndex(_timezone2) == FALLBACK_CITY_INDEX;
    }

    function isConfiguredLocalTimezone() {
        return isLocalTimezone(_timezone1) || isLocalTimezone(_timezone2);
    }

    // Smart substitution: if a configured clock is local, show Madrid instead.
    // If away from Madrid and neither configured clock is local, keep Madrid visible in slot 1.
    function getEffectiveTimezoneIndex(configuredIndex) {
        return getEffectiveTimezoneIndexForSlot(configuredIndex, false);
    }

    function getEffectiveTimezone1Index() {
        return getEffectiveTimezoneIndexForSlot(_timezone1, true);
    }

    function getEffectiveTimezone2Index() {
        return getEffectiveTimezoneIndexForSlot(_timezone2, false);
    }

    function getEffectiveTimezoneIndexForSlot(configuredIndex, isFirstSlot) {
        configuredIndex = normalizeTimezoneIndex(configuredIndex);

        if (configuredIndex != FALLBACK_CITY_INDEX && isLocalTimezone(configuredIndex)) {
            return FALLBACK_CITY_INDEX;
        }

        if (isFirstSlot && !isLocalMadridTimezone() &&
            !isConfiguredLocalTimezone() && !isConfiguredMadridTimezone()) {
            return FALLBACK_CITY_INDEX;
        }

        return configuredIndex;
    }

    function refreshTimezoneCache() {
        ensureCache();

        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var localOffsetMinutes = getLocalOffsetMinutes();
        if (_timezoneCacheValid &&
            _timezoneCacheYear == now.year &&
            _timezoneCacheMonth == now.month &&
            _timezoneCacheDay == now.day &&
            _timezoneCacheHour == now.hour &&
            _timezoneCacheLocalOffsetMinutes == localOffsetMinutes) {
            return;
        }

        _effectiveTimezone1 = getEffectiveTimezone1Index();
        _effectiveTimezone2 = getEffectiveTimezone2Index();
        _timezone1OffsetMinutes = getCityOffsetMinutes(_effectiveTimezone1);
        _timezone2OffsetMinutes = getCityOffsetMinutes(_effectiveTimezone2);

        _timezoneCacheYear = now.year;
        _timezoneCacheMonth = now.month;
        _timezoneCacheDay = now.day;
        _timezoneCacheHour = now.hour;
        _timezoneCacheLocalOffsetMinutes = localOffsetMinutes;
        _timezoneCacheValid = true;
    }

    function ensureTimezoneCache() {
        if (!_timezoneCacheValid) {
            refreshTimezoneCache();
        }
    }

    function getCachedLocalOffsetMinutes() {
        ensureTimezoneCache();
        return _timezoneCacheLocalOffsetMinutes;
    }

    function getTimezone1Name() {
        ensureTimezoneCache();
        return CITY_NAMES[_effectiveTimezone1];
    }

    function getTimezone2Name() {
        ensureTimezoneCache();
        return CITY_NAMES[_effectiveTimezone2];
    }

    function getTimezone1OffsetMinutes() {
        ensureTimezoneCache();
        return _timezone1OffsetMinutes;
    }

    function getTimezone2OffsetMinutes() {
        ensureTimezoneCache();
        return _timezone2OffsetMinutes;
    }

    function getTimezone1Offset() {
        ensureCache();
        return getTimezone1OffsetMinutes() / 60;
    }

    function getTimezone2Offset() {
        ensureCache();
        return getTimezone2OffsetMinutes() / 60;
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

    function getTimeFont() {
        ensureCache();
        return _timeFont;
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

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Weather;
using Toybox.ActivityMonitor;
using Toybox.Activity;
using Toybox.Time;
using Toybox.Time.Gregorian;

// Main watch face view - orchestrates all rendering components
class WatchFaceView extends WatchUi.WatchFace {

    // Component renderers
    private var _weatherChart as WeatherChart?;
    private var _timeRenderer as TimeRenderer?;
    private var _statsRings as StatsRings?;

    // Cached data
    private var _lastWeatherUpdate as Number = 0;
    private var _cachedForecast as Array?;

    function initialize() {
        WatchFace.initialize();
    }

    // Called when the view is loaded
    function onLayout(dc as Dc) as Void {
        // Initialize renderers
        _weatherChart = new WeatherChart();
        _timeRenderer = new TimeRenderer();
        _statsRings = new StatsRings();
    }

    // Called when the view becomes visible
    function onShow() as Void {
        // Refresh weather data when view appears
        updateWeatherData();
    }

    // Main render function - called every minute (or second if configured)
    function onUpdate(dc as Dc) as Void {
        var deviceSettings = System.getDeviceSettings();

        // Clear with true black for OLED
        dc.setColor(Theme.BG, Theme.BG);
        dc.clear();

        // Check if in sleep/AOD mode
        if (deviceSettings has :requiresBurnInProtection && deviceSettings.requiresBurnInProtection) {
            drawAOD(dc);
            return;
        }

        // Full watch face rendering
        drawHeader(dc);

        if (_weatherChart != null) {
            _weatherChart.draw(dc, _cachedForecast);
        }

        drawDate(dc);

        if (_timeRenderer != null) {
            _timeRenderer.draw(dc);
        }

        if (_statsRings != null) {
            _statsRings.draw(dc);
        }
    }

    // Called when entering sleep mode
    function onEnterSleep() as Void {
        WatchUi.requestUpdate();
    }

    // Called when exiting sleep mode
    function onExitSleep() as Void {
        WatchUi.requestUpdate();
    }

    // === HEADER RENDERING ===
    private function drawHeader(dc as Dc) as Void {
        var y = Theme.HEADER_Y;

        // Get current conditions for temperature and location
        var conditions = Weather.getCurrentConditions();
        var tempStr = "--°";
        var locationStr = "";

        if (conditions != null) {
            if (conditions.temperature != null) {
                var temp = conditions.temperature;
                // Convert to user's preferred unit if needed
                tempStr = temp.format("%d") + "°";
            }
            if (conditions.observationLocationName != null) {
                locationStr = conditions.observationLocationName;
                // Truncate if too long
                if (locationStr.length() > 12) {
                    locationStr = locationStr.substring(0, 12);
                }
            }
        }

        // Temperature + Location (centered)
        dc.setColor(Theme.TIME_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER, y, Graphics.FONT_TINY, tempStr + " " + locationStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Second timezone (left side)
        var clockTime = System.getClockTime();
        var tzOffset = getSecondTimezoneOffset();
        var tz2Hour = (clockTime.hour + tzOffset + 24) % 24;
        var tz2Str = getTz2Name() + " " + tz2Hour.format("%d") + ":" + clockTime.min.format("%02d");

        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.SAFE_ZONE_START + 20, y, Graphics.FONT_XTINY, tz2Str, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Battery (right side)
        var battery = System.getSystemStats().battery;
        var battStr = battery.format("%d") + "%";
        dc.drawText(Theme.SAFE_ZONE_END - 20, y, Graphics.FONT_XTINY, battStr, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // === DATE RENDERING ===
    private function drawDate(dc as Dc) as Void {
        var y = Theme.DATE_Y;
        var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);

        // Format: "mon 27 jan"
        var dayNames = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
        var monthNames = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];

        var dayName = dayNames[now.day_of_week - 1];
        var dateStr = dayName + " " + now.day.format("%d") + " " + monthNames[now.month - 1];

        // Calculate week number
        var weekNum = getISOWeekNumber(now);

        // Draw date text
        dc.setColor(Theme.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        var dateWidth = dc.getTextWidthInPixels(dateStr, Graphics.FONT_TINY);

        // Week badge dimensions
        var badgeWidth = 22;
        var badgeHeight = 15;
        var badgeGap = 8;

        // Center the date + badge together
        var totalWidth = dateWidth + badgeGap + badgeWidth;
        var startX = Theme.CENTER - (totalWidth / 2);

        dc.drawText(startX, y, Graphics.FONT_TINY, dateStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Week badge (orange rounded rect)
        var badgeX = startX + dateWidth + badgeGap;
        var badgeY = y - (badgeHeight / 2);

        dc.setColor(Theme.WEEK_BADGE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(badgeX, badgeY, badgeWidth, badgeHeight, 3);

        // Week number text
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(badgeX + badgeWidth/2, y, Graphics.FONT_XTINY, weekNum.format("%d"), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // === AOD (Always-On Display) ===
    private function drawAOD(dc as Dc) as Void {
        // Minimal display for burn-in protection
        // Time only - dim
        var clockTime = System.getClockTime();
        var hour = clockTime.hour;
        var min = clockTime.min;

        // 12-hour format
        if (!System.getDeviceSettings().is24Hour && hour > 12) {
            hour = hour - 12;
        }
        if (hour == 0) {
            hour = 12;
        }

        var timeStr = hour.format("%d") + ":" + min.format("%02d");

        dc.setColor(Theme.AOD_TIME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER, Theme.CENTER, Graphics.FONT_NUMBER_MILD, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Date - smaller, dimmer
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dateStr = now.month.format("%d") + "/" + now.day.format("%d");
        dc.setColor(Theme.AOD_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER, Theme.CENTER + 50, Graphics.FONT_XTINY, dateStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // === WEATHER DATA ===
    private function updateWeatherData() as Void {
        var now = Time.now().value();
        // Update every 30 minutes
        if (now - _lastWeatherUpdate > 1800) {
            _cachedForecast = Weather.getHourlyForecast();
            _lastWeatherUpdate = now;
        }
    }

    // === HELPER FUNCTIONS ===
    private function getISOWeekNumber(date as Gregorian.Info) as Number {
        // Simplified ISO week calculation
        var dayOfYear = date.day_of_week;  // This is approximate
        // For proper ISO week, you'd need more complex calculation
        // Using simplified version for now
        var jan1 = Gregorian.moment({:year => date.year, :month => 1, :day => 1});
        var diff = Time.now().subtract(jan1);
        var dayOfYearActual = (diff.value() / 86400).toNumber() + 1;
        return ((dayOfYearActual - date.day_of_week + 10) / 7).toNumber();
    }

    private function getSecondTimezoneOffset() as Number {
        // Get from settings, default to 0
        var offset = Application.Properties.getValue("secondTimezoneOffset");
        if (offset != null) {
            return offset as Number;
        }
        return 0;
    }

    private function getTz2Name() as String {
        var name = Application.Properties.getValue("secondTimezoneName");
        if (name != null) {
            return name as String;
        }
        return "TZ2";
    }
}

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Weather;
using Toybox.ActivityMonitor;
using Toybox.Activity;
using Toybox.SensorHistory;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Math;
using Toybox.Application;

class WatchFaceView extends WatchUi.WatchFace {

    private var _isAwake = true;

    // SIMULATOR DEBUG MODE: Set to true for testing in simulator, false for release
    // The Garmin simulator does NOT populate ActivityMonitor data from simulation-data.json
    private const DEBUG_SIMULATOR = false;
    private const DEBUG_STEPS = 6700;      // 67% of goal
    private const DEBUG_STEP_GOAL = 10000;
    private const DEBUG_FLOORS = 8;        // 80% of goal
    private const DEBUG_FLOOR_GOAL = 10;
    private const DEBUG_BODY_BATTERY = 54;
    private const DEBUG_HR = 82;
    private const DEBUG_MOVE_BAR = 3;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc) {
        Theme.initLayout(dc);
    }

    function onShow() {
    }

    function onUpdate(dc) {
        Theme.initLayout(dc);

        // Apply theme from settings
        Theme.applyTheme(Settings.getTheme(), Settings.getAccentColor(), Settings.getTimeColor());

        dc.setColor(Theme.BG, Theme.BG);
        dc.clear();

        if (!_isAwake) {
            drawAOD(dc);
            return;
        }

        // Refresh weather data if cache is stale
        WeatherDataManager.refreshIfNeeded();

        drawBattery(dc);
        drawHeader(dc);
        if (Settings.isShowWeatherChart()) {
            drawWeatherChart(dc);
        }
        drawDate(dc);
        drawTime(dc);
        drawStats(dc);
        drawMoveBar(dc);
    }

    function onEnterSleep() {
        _isAwake = false;
        WatchUi.requestUpdate();
    }

    function onExitSleep() {
        _isAwake = true;
        WatchUi.requestUpdate();
    }

    private function drawBattery(dc) {
        // On MIP displays, battery is shown in the stats row at bottom
        if (Theme.isMIPDisplay) {
            return;
        }

        var stats = System.getSystemStats();
        var battery = stats.battery.toNumber();

        // Check if we should show battery based on settings
        if (!Settings.shouldShowBattery(battery)) {
            return;
        }

        // Position: top-right corner
        var x = Theme.screenWidth - 38;
        var y = 12;

        // Battery icon dimensions
        var w = 22;
        var h = 10;
        var tipW = 2;
        var tipH = 4;

        // Color based on level
        var color = Theme.TEXT_DIM;
        if (battery <= 20) {
            color = 0xE57373;  // Red when low
        } else if (battery <= 40) {
            color = 0xFFB347;  // Amber when medium-low
        }

        // Battery outline
        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, w, h);

        // Battery tip (positive terminal)
        dc.fillRectangle(x + w, y + (h - tipH) / 2, tipW, tipH);

        // Fill level
        var fillW = ((w - 2) * battery / 100).toNumber();
        if (fillW > 0) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + 1, y + 1, fillW, h - 2);
        }

        // Percentage text (small, to the left of icon)
        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x - 4, y + h/2, Graphics.FONT_XTINY, battery.format("%d"), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawHeader(dc) {
        var center = Theme.getCenter();

        // Use cached data from WeatherDataManager
        var temp = WeatherDataManager.currentTemp;
        var tempStr = temp != null
            ? Settings.getDisplayTemp(temp).format("%d") + "°"
            : "18°";
        var locationStr = WeatherDataManager.locationName;
        var condition = WeatherDataManager.currentCondition;

        // Check if using default location (no GPS data)
        var usingDefault = Application.Storage.getValue("using_default_location");

        // Check if location is a real place name (not a condition text fallback)
        var hasRealLocation = !locationStr.equals("Unknown") && !locationStr.equals("No Weather");
        // If location matches a condition text, it's a fallback - don't show separator
        if (locationStr.equals("Clear") || locationStr.equals("Pt Cloudy") ||
            locationStr.equals("Cloudy") || locationStr.equals("Rain") ||
            locationStr.equals("Lt Rain") || locationStr.equals("Hvy Rain") ||
            locationStr.equals("Snow") || locationStr.equals("Lt Snow") ||
            locationStr.equals("Hvy Snow") || locationStr.equals("Storms") ||
            locationStr.equals("Fog") || locationStr.equals("Hazy") ||
            locationStr.equals("Windy") || locationStr.equals("Weather")) {
            hasRealLocation = false;
        }

        if (Theme.isMIPDisplay) {
            // MIP: no icon, single line "15° · Location" at Y=12
            var headerY = 12;
            var headerStr = tempStr;
            if (hasRealLocation) {
                headerStr = tempStr + " · " + locationStr;
            }
            dc.setColor(Theme.getColor(Theme.TIME_PRIMARY), Graphics.COLOR_TRANSPARENT);
            dc.drawText(center, headerY, Graphics.FONT_XTINY, headerStr, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            // AMOLED: [icon] 15° · Pozuelo at Y=14
            var headerY = 14;
            var headerStr;
            if (hasRealLocation) {
                headerStr = tempStr + " · " + locationStr;
            } else {
                headerStr = tempStr;
            }

            // Calculate total width for centering with icon
            var textWidth = dc.getTextWidthInPixels(headerStr, Graphics.FONT_XTINY);
            var iconWidth = 16;
            var iconGap = 4;
            var totalWidth = iconWidth + iconGap + textWidth;
            var startX = center - (totalWidth / 2);

            // Draw weather icon — vertically centered with text
            var textH = dc.getFontHeight(Graphics.FONT_XTINY);
            var iconH = 12;
            var iconY = headerY + (textH - iconH) / 2;
            drawWeatherIcon(dc, startX, iconY, condition);

            // Draw text
            dc.setColor(Theme.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(startX + iconWidth + iconGap, headerY, Graphics.FONT_XTINY, headerStr, Graphics.TEXT_JUSTIFY_LEFT);

            // Show red warning cloud if using default location
            if (usingDefault == true) {
                var warningX = startX + totalWidth + 8;
                drawWarningCloud(dc, warningX, headerY + 4);
            }
        }
    }

    // Draw a small red cloud to indicate default location is being used
    private function drawWarningCloud(dc, x, y) {
        var color = 0xE57373;  // Soft red (same as low battery)
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        // Small puffy cloud shape (12px wide, 8px tall)
        dc.fillCircle(x, y, 4);       // center
        dc.fillCircle(x - 5, y + 1, 3); // left
        dc.fillCircle(x + 5, y + 1, 3); // right
        dc.fillCircle(x - 2, y - 2, 2); // top-left
        dc.fillCircle(x + 2, y - 2, 2); // top-right
    }

    // Draw weather icon based on condition code (~14x12 pixel art)
    private function drawWeatherIcon(dc, x, y, condition) {
        if (condition == null) {
            drawIconCloud(dc, x, y);
            return;
        }
        if (condition == Weather.CONDITION_CLEAR) {
            drawIconSun(dc, x, y);
        } else if (condition == Weather.CONDITION_PARTLY_CLOUDY) {
            drawIconPartlyCloudy(dc, x, y);
        } else if (condition == Weather.CONDITION_MOSTLY_CLOUDY || condition == Weather.CONDITION_CLOUDY) {
            drawIconCloud(dc, x, y);
        } else if (condition == Weather.CONDITION_RAIN || condition == Weather.CONDITION_LIGHT_RAIN) {
            drawIconRain(dc, x, y);
        } else if (condition == Weather.CONDITION_HEAVY_RAIN) {
            drawIconHeavyRain(dc, x, y);
        } else if (condition == Weather.CONDITION_SNOW || condition == Weather.CONDITION_LIGHT_SNOW || condition == Weather.CONDITION_HEAVY_SNOW) {
            drawIconSnow(dc, x, y);
        } else if (condition == Weather.CONDITION_THUNDERSTORMS) {
            drawIconThunder(dc, x, y);
        } else if (condition == Weather.CONDITION_FOG || condition == Weather.CONDITION_HAZY) {
            drawIconFog(dc, x, y);
        } else if (condition == Weather.CONDITION_WINDY) {
            drawIconWind(dc, x, y);
        } else {
            drawIconCloud(dc, x, y);
        }
    }

    // Sun icon: circle with rays
    private function drawIconSun(dc, x, y) {
        var cx = x + 7;
        var cy = y + 5;
        dc.setColor(Theme.TEMP_CURVE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 4);
        // Rays
        dc.fillRectangle(cx - 1, cy - 7, 2, 2);  // top
        dc.fillRectangle(cx - 1, cy + 5, 2, 2);   // bottom
        dc.fillRectangle(cx - 7, cy - 1, 2, 2);   // left
        dc.fillRectangle(cx + 5, cy - 1, 2, 2);   // right
    }

    // Partly cloudy: small sun + cloud overlay
    private function drawIconPartlyCloudy(dc, x, y) {
        // Sun peeking from behind
        dc.setColor(Theme.TEMP_CURVE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + 10, y + 2, 3);
        // Cloud in front
        dc.setColor(0xB0B0B0, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + 4, y + 7, 3);
        dc.fillCircle(x + 8, y + 6, 4);
        dc.fillCircle(x + 12, y + 7, 3);
    }

    // Cloud icon
    private function drawIconCloud(dc, x, y) {
        dc.setColor(0x909090, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + 4, y + 7, 3);
        dc.fillCircle(x + 8, y + 5, 4);
        dc.fillCircle(x + 12, y + 7, 3);
    }

    // Rain icon: cloud + drops
    private function drawIconRain(dc, x, y) {
        dc.setColor(0x808080, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + 4, y + 4, 3);
        dc.fillCircle(x + 8, y + 3, 4);
        dc.fillCircle(x + 12, y + 4, 3);
        // Rain drops
        dc.setColor(Theme.PRECIPITATION, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + 5, y + 9, 1, 3);
        dc.fillRectangle(x + 9, y + 9, 1, 3);
    }

    // Heavy rain icon: cloud + more drops
    private function drawIconHeavyRain(dc, x, y) {
        dc.setColor(0x707070, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + 4, y + 4, 3);
        dc.fillCircle(x + 8, y + 3, 4);
        dc.fillCircle(x + 12, y + 4, 3);
        // Heavy rain drops
        dc.setColor(Theme.PRECIPITATION, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + 4, y + 9, 1, 3);
        dc.fillRectangle(x + 7, y + 9, 1, 3);
        dc.fillRectangle(x + 10, y + 9, 1, 3);
    }

    // Snow icon: cloud + snowflakes (dots)
    private function drawIconSnow(dc, x, y) {
        dc.setColor(0x808080, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + 4, y + 4, 3);
        dc.fillCircle(x + 8, y + 3, 4);
        dc.fillCircle(x + 12, y + 4, 3);
        // Snowflakes
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + 5, y + 10, 1);
        dc.fillCircle(x + 9, y + 10, 1);
        dc.fillCircle(x + 7, y + 12, 1);
    }

    // Thunder icon: cloud + bolt
    private function drawIconThunder(dc, x, y) {
        dc.setColor(0x606060, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + 4, y + 4, 3);
        dc.fillCircle(x + 8, y + 3, 4);
        dc.fillCircle(x + 12, y + 4, 3);
        // Lightning bolt
        dc.setColor(Theme.TEMP_CURVE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + 8, y + 8, 2, 2);
        dc.fillRectangle(x + 7, y + 10, 2, 2);
        dc.fillRectangle(x + 9, y + 10, 1, 1);
    }

    // Fog icon: horizontal lines
    private function drawIconFog(dc, x, y) {
        dc.setColor(0x808080, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + 2, y + 2, 10, 1);
        dc.fillRectangle(x + 1, y + 5, 12, 1);
        dc.fillRectangle(x + 3, y + 8, 8, 1);
        dc.fillRectangle(x + 1, y + 11, 10, 1);
    }

    // Wind icon: wavy lines
    private function drawIconWind(dc, x, y) {
        dc.setColor(0x909090, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + 1, y + 3, 10, 1);
        dc.fillRectangle(x + 11, y + 2, 2, 1);
        dc.fillRectangle(x + 2, y + 6, 8, 1);
        dc.fillRectangle(x + 10, y + 5, 2, 1);
        dc.fillRectangle(x + 1, y + 9, 10, 1);
        dc.fillRectangle(x + 11, y + 8, 2, 1);
    }

    private function drawWeatherChart(dc) {
        // Chart dimensions - scale for MIP displays
        var chartX = Theme.isMIPDisplay ? 20 : 45;
        var chartY = Theme.isMIPDisplay ? 50 : 34;
        var chartWidth = Theme.screenWidth - (Theme.isMIPDisplay ? 40 : 90);
        var chartHeight = Theme.isMIPDisplay ? Theme.getChartHeightMIP() : 115;

        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var currentHour = now.hour;
        var dayOfWeek = now.day_of_week;

        // Use cached weather data from WeatherDataManager
        var temps = WeatherDataManager.temps;
        var hours = WeatherDataManager.hours;
        var precips = WeatherDataManager.precips;
        var clouds = WeatherDataManager.clouds;
        var winds = WeatherDataManager.winds;
        var minTemp = WeatherDataManager.minTemp;
        var maxTemp = WeatherDataManager.maxTemp;
        var dayHighs = WeatherDataManager.dayHighs;
        var dayLows = WeatherDataManager.dayLows;
        var dayHighIdx = WeatherDataManager.dayHighIdx;
        var dayLowIdx = WeatherDataManager.dayLowIdx;

        // Safety check - if data not yet loaded, skip rendering
        if (temps == null || hours == null) {
            return;
        }

        var tempRange = WeatherDataManager.getTempRange();
        var forecastHours = Settings.getForecastHours();

        // Day/night band at bottom of chart area
        var bandY = chartY + chartHeight - 5;
        var bandHeight = 6;
        for (var i = 0; i < chartWidth; i += 2) {
            var idx = (i * forecastHours / chartWidth);
            if (idx >= forecastHours) { idx = forecastHours - 1; }
            if (idx >= 96) { idx = 95; }
            dc.setColor(Theme.getSkyColor(hours[idx]), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(chartX + i, bandY, 2, bandHeight);
        }

        // Clouds at top - organic shapes using overlapping circles
        if (Settings.isShowClouds()) {
            for (var i = 0; i < forecastHours && i < 96; i += 3) {
                var c = clouds[i];
                if (c > 35) {
                    var x = chartX + (i * chartWidth / forecastHours);

                    // MIP displays: use solid gray (no alpha blending)
                    // AMOLED: use opacity-based dimming
                    var cloudColor;
                    if (Theme.isMIPDisplay) {
                        // MIP: use palette-safe grays based on coverage
                        if (c > 70) {
                            cloudColor = 0xAAAAAA;  // Light gray for heavy clouds
                        } else if (c > 50) {
                            cloudColor = 0x555555;  // Medium gray
                        } else {
                            cloudColor = 0x555555;  // Dim gray for light clouds
                        }
                    } else {
                        var opacity = (c - 35).toFloat() / 65.0;
                        cloudColor = Theme.dimColor(Theme.CLOUD_COLOR, opacity * 0.35);
                    }
                    dc.setColor(cloudColor, Graphics.COLOR_TRANSPARENT);

                    // Draw cloud shape - simplified for MIP
                    var baseY = chartY + 6;

                    if (Theme.isMIPDisplay) {
                        // MIP: simple single circles
                        var radius = c > 60 ? 3 : 2;
                        dc.fillCircle(x + 5, baseY, radius);
                    } else {
                        // AMOLED: organic puffy clouds
                        // Main body - row of circles
                        dc.fillCircle(x + 4, baseY, 4);
                        dc.fillCircle(x + 10, baseY, 5);
                        dc.fillCircle(x + 17, baseY, 4);

                        // Top puffs - slightly higher
                        if (c > 50) {
                            dc.fillCircle(x + 7, baseY - 3, 3);
                            dc.fillCircle(x + 13, baseY - 3, 3);
                        }

                        // Extra puffs for very cloudy
                        if (c > 70) {
                            dc.fillCircle(x + 10, baseY - 5, 2);
                        }
                    }
                }
            }
        }

        // Temperature curve
        if (Settings.isShowTemperature()) {
            var tempYStart = chartY + 10;
            var tempHeight = chartHeight - 25;

            dc.setColor(Theme.TEMP_CURVE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);

            var prevX = -1;
            var prevTempY = -1;

            for (var i = 0; i < forecastHours && i < 96; i++) {
                var x = chartX + (i * chartWidth / forecastHours);
                var norm = (temps[i] - minTemp) / tempRange;
                if (norm < 0.0) { norm = 0.0; }
                if (norm > 1.0) { norm = 1.0; }
                var y = tempYStart + tempHeight - (norm * tempHeight);

                if (prevX >= 0) {
                    dc.drawLine(prevX, prevTempY, x, y.toNumber());
                }
                prevX = x;
                prevTempY = y.toNumber();
            }
            dc.setPenWidth(1);
        }

        // Wind line (subtle but visible)
        if (Settings.isShowWind()) {
            var tempYStart = chartY + 10;
            var tempHeight = chartHeight - 25;

            dc.setColor(Theme.dimColor(Theme.WIND_SPEED, 0.5), Graphics.COLOR_TRANSPARENT);
            var prevX = -1;
            var prevWindY = -1;

            for (var i = 0; i < forecastHours && i < 96; i++) {
                var x = chartX + (i * chartWidth / forecastHours);
                var norm = winds[i] / 20.0;
                if (norm > 1.0) { norm = 1.0; }
                var y = tempYStart + 2 + (tempHeight - 4) - (norm * (tempHeight - 4));

                if (prevX >= 0) {
                    dc.drawLine(prevX, prevWindY, x, y.toNumber());
                }
                prevX = x;
                prevWindY = y.toNumber();
            }
        }

        // Precipitation bars - draw from bottom of chart, upward
        if (Settings.isShowPrecipitation()) {
            var precipBaseY = chartY + chartHeight - 12;

            for (var i = 0; i < forecastHours && i < 96; i++) {
                var precipChance = precips[i];
                if (precipChance > 5) {
                    var x = chartX + (i * chartWidth / forecastHours);
                    var h = (2 + (precipChance - 5).toFloat() * 18.0 / 95.0).toNumber();
                    if (h > 20) { h = 20; }

                    var intensity = 0.4 + (precipChance / 100.0) * 0.6;
                    dc.setColor(Theme.dimColor(Theme.PRECIPITATION, intensity), Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, precipBaseY - h, 3, h);
                }
            }
        }

        // Day separators (dotted lines at midnight)
        var days = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];
        var dayLabelY = chartY + chartHeight + 3;

        for (var i = 6; i < forecastHours && i < 96; i += 6) {
            var hour = (currentHour + i) % 24;
            var x = chartX + (i * chartWidth / forecastHours);

            if (hour == 0) {
                dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
                for (var dy = chartY + 4; dy < chartY + chartHeight - 8; dy += 3) {
                    dc.fillRectangle(x, dy, 1, 1);
                }
            }
        }

        // Day labels BELOW the chart
        // Show label when ANY part of day is visible, centered on visible portion
        var hoursUntilMidnight = (24 - currentHour) % 24;
        if (hoursUntilMidnight == 0) { hoursUntilMidnight = 24; }

        var dayLabelColor = Theme.TEXT_DIM;

        // Today's label (always visible, from hour 0 to hoursUntilMidnight)
        var todayCenter = hoursUntilMidnight / 2;
        var todayX = chartX + (todayCenter * chartWidth / forecastHours);
        var todayIdx = (dayOfWeek - 1);
        if (todayIdx < 0) { todayIdx = 6; }
        drawMiniText(dc, todayX, dayLabelY, days[todayIdx], dayLabelColor);

        // Tomorrow's label (day +1)
        var day1Start = hoursUntilMidnight;
        var day1End = day1Start + 24;
        if (day1End > forecastHours) { day1End = forecastHours; }
        if (day1Start < forecastHours) {
            var day1Center = (day1Start + day1End) / 2;
            var day1X = chartX + (day1Center * chartWidth / forecastHours);
            var day1Idx = (dayOfWeek) % 7;
            drawMiniText(dc, day1X, dayLabelY, days[day1Idx], dayLabelColor);
        }

        // Day +2 label
        var day2Start = hoursUntilMidnight + 24;
        var day2End = day2Start + 24;
        if (day2End > forecastHours) { day2End = forecastHours; }
        if (day2Start < forecastHours) {
            var day2Center = (day2Start + day2End) / 2;
            var day2X = chartX + (day2Center * chartWidth / forecastHours);
            var day2Idx = (dayOfWeek + 1) % 7;
            drawMiniText(dc, day2X, dayLabelY, days[day2Idx], dayLabelColor);
        }

        // Day +3 label
        var day3Start = hoursUntilMidnight + 48;
        var day3End = day3Start + 24;
        if (day3End > forecastHours) { day3End = forecastHours; }
        if (day3Start < forecastHours) {
            var day3Center = (day3Start + day3End) / 2;
            var day3X = chartX + (day3Center * chartWidth / forecastHours);
            var day3Idx = (dayOfWeek + 2) % 7;
            drawMiniText(dc, day3X, dayLabelY, days[day3Idx], dayLabelColor);
        }

        // Temperature boxes (high/low for each visible day) - using mini-digits
        if (Settings.isShowTemperature()) {
            var tempYStart = chartY + 10;
            var tempHeight = chartHeight - 25;
            var boxH = 10;
            var boxW = 16;
            var boxR = 2;

            for (var d = 0; d < 3; d++) {
                if (dayHighs[d] > -100.0) {
                    var hiIdx = dayHighIdx[d];
                    if (hiIdx < forecastHours) {
                        var hiX = chartX + (hiIdx * chartWidth / forecastHours);
                        var hiNorm = (dayHighs[d] - minTemp) / tempRange;
                        if (hiNorm < 0.0) { hiNorm = 0.0; }
                        if (hiNorm > 1.0) { hiNorm = 1.0; }
                        var hiY = tempYStart + tempHeight - (hiNorm * tempHeight);
                        var hiBoxY = hiY.toNumber() - 11;

                        dc.setColor(Theme.dimColor(Theme.TEMP_CURVE, 0.25), Graphics.COLOR_TRANSPARENT);
                        dc.fillRoundedRectangle(hiX - boxW/2, hiBoxY, boxW, boxH, boxR);

                        var displayHi = Settings.getDisplayTemp(dayHighs[d].toNumber());
                        drawMiniNumber(dc, hiX, hiBoxY + 5, displayHi, Theme.TEMP_CURVE);
                    }
                }

                if (dayLows[d] < 100.0 && d > 0) {
                    var loIdx = dayLowIdx[d];
                    if (loIdx < forecastHours) {
                        var loX = chartX + (loIdx * chartWidth / forecastHours);
                        var loNorm = (dayLows[d] - minTemp) / tempRange;
                        if (loNorm < 0.0) { loNorm = 0.0; }
                        if (loNorm > 1.0) { loNorm = 1.0; }
                        var loY = tempYStart + tempHeight - (loNorm * tempHeight);
                        var loBoxY = loY.toNumber() + 3;

                        dc.setColor(Theme.dimColor(Theme.TEMP_CURVE, 0.15), Graphics.COLOR_TRANSPARENT);
                        dc.fillRoundedRectangle(loX - boxW/2, loBoxY, boxW, boxH, boxR);

                        var displayLo = Settings.getDisplayTemp(dayLows[d].toNumber());
                        drawMiniNumber(dc, loX, loBoxY + 5, displayLo, Theme.dimColor(Theme.TEMP_CURVE, 0.7));
                    }
                }
            }
        }
    }

    private function drawDate(dc) {
        var y = Theme.isMIPDisplay ? (Theme.screenHeight * 0.40).toNumber() : 166;
        var center = Theme.getCenter();
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        var dayNames = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
        var monthNames = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];

        // Format date based on setting
        var dateFormat = Settings.getDateFormat();
        var dateStr;
        if (dateFormat == 0) {
            // Wed 15 Jan
            dateStr = dayNames[now.day_of_week - 1] + " " + now.day + " " + monthNames[now.month - 1];
        } else if (dateFormat == 1) {
            // 15 Jan Wed
            dateStr = now.day + " " + monthNames[now.month - 1] + " " + dayNames[now.day_of_week - 1];
        } else {
            // Jan 15
            dateStr = monthNames[now.month - 1] + " " + now.day;
        }

        var showWeekNum = Settings.isShowWeekNumber();
        var weekNum = 0;
        if (showWeekNum) {
            var startOfYear = Gregorian.moment({:year => now.year, :month => 1, :day => 1});
            var dayOfYear = ((Time.now().value() - startOfYear.value()) / 86400).toNumber() + 1;
            var startDow = Gregorian.info(startOfYear, Time.FORMAT_SHORT).day_of_week;
            weekNum = ((dayOfYear + startDow - 2) / 7).toNumber() + 1;
        }

        if (showWeekNum) {
            var dateWidth = dc.getTextWidthInPixels(dateStr, Graphics.FONT_XTINY);
            var badgeWidth = 24;
            var badgeGap = 6;
            var totalWidth = dateWidth + badgeGap + badgeWidth;
            var startX = center - (totalWidth / 2);

            dc.setColor(Theme.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(startX, y, Graphics.FONT_XTINY, dateStr, Graphics.TEXT_JUSTIFY_LEFT);

            var fontH = dc.getFontHeight(Graphics.FONT_XTINY);
            var badgeH = fontH;
            var badgeX = startX + dateWidth + badgeGap;
            var badgeY = y;

            dc.setColor(Theme.WEEK_BADGE, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(badgeX, badgeY, badgeWidth, badgeH, 4);

            dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
            dc.drawText(badgeX + badgeWidth / 2, badgeY + badgeH / 2, Graphics.FONT_XTINY, weekNum.format("%d"), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(Theme.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(center, y, Graphics.FONT_XTINY, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawTime(dc) {
        var clockTime = System.getClockTime();
        var center = Theme.getCenter();
        var baseY = Theme.isMIPDisplay ? (Theme.screenHeight * 0.56).toNumber() : 255;

        var hour = clockTime.hour;
        var min = clockTime.min;
        var isPM = hour >= 12;

        // Use settings for clock format
        var is24h = Settings.is24Hour();

        if (!is24h) {
            if (hour > 12) { hour = hour - 12; }
            if (hour == 0) { hour = 12; }
        }

        var timeStr = hour.format("%d") + ":" + min.format("%02d");

        // Shift time left so the combined block (time + seconds/AM) looks centered
        var timeCenter = Theme.isMIPDisplay ? center : center - 15;

        // Use the same step progress calculation as activity rings for consistency
        var activityData = getActivityDataRaw();
        var stepProgress = activityData[:stepsProgress];
        // Cap at 1.0 for visual fill (we don't show overflow in time digits)
        if (stepProgress > 1.0) { stepProgress = 1.0; }

        // Font selection based on display type and user setting
        var timeFont;
        if (Theme.isMIPDisplay) {
            timeFont = Graphics.FONT_NUMBER_MEDIUM;
        } else {
            var fontSetting = Settings.getTimeFont();
            if (fontSetting == 1) { timeFont = Graphics.FONT_NUMBER_MEDIUM; }
            else if (fontSetting == 2) { timeFont = Graphics.FONT_NUMBER_MILD; }
            else { timeFont = Graphics.FONT_NUMBER_HOT; }
        }
        var fontHeight = dc.getFontHeight(timeFont);

        var textTop = baseY - (fontHeight / 2);
        var textBottom = baseY + (fontHeight / 2);

        // Fill grows from bottom of text cell upward using full fontHeight
        var fillHeight = (fontHeight * stepProgress).toNumber();
        var fillY = textBottom - fillHeight;

        // Unfilled portion (above fill line)
        if (fillY > textTop) {
            dc.setClip(0, textTop, Theme.screenWidth, fillY - textTop);
            dc.setColor(Theme.TIME_UNFILLED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(timeCenter, baseY, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.clearClip();
        }

        // Filled portion (fill line to bottom)
        if (fillHeight > 0) {
            dc.setClip(0, fillY, Theme.screenWidth, fillHeight);
            dc.setColor(Theme.TIME_FILL, Graphics.COLOR_TRANSPARENT);
            dc.drawText(timeCenter, baseY, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.clearClip();
        }

        // Seconds and AM/PM — bottom-aligned to the right of the time digits
        var showSec = Settings.isShowSeconds();
        if (showSec || !is24h) {
            var subText = "";
            if (showSec) { subText = ":" + clockTime.sec.format("%02d"); }
            if (!is24h) {
                if (subText.length() > 0) { subText = subText + " "; }
                subText = subText + (isPM ? "PM" : "AM");
            }
            var subFont = Graphics.FONT_XTINY;
            var timeWidth = dc.getTextWidthInPixels(timeStr, timeFont);
            var rightX = timeCenter + (timeWidth / 2) + 4;
            // Exact baseline alignment using font ascent metrics
            var timeBaseline = baseY - (fontHeight / 2) + dc.getFontAscent(timeFont);
            var subBaseline = dc.getFontAscent(subFont);
            var subY = timeBaseline - subBaseline;
            dc.setColor(Theme.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rightX, subY, subFont, subText, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    private function drawStats(dc) {
        var center = Theme.getCenter();

        if (Theme.isMIPDisplay) {
            // MIP layout: simplified - no activity rings, centered world clocks + HR/battery row
            drawStatsMIP(dc, center);
        } else {
            // AMOLED layout: rings on left, world clocks on right
            var ringLayout = Settings.getRingLayout();

            // === LEFT SIDE: Activity Rings ===
            if (ringLayout != 2) {  // Not "Off"
                drawActivityRings(dc, center);
            }

            // === RIGHT SIDE: World Clocks ===
            var worldClockCount = Settings.getWorldClockCount();
            if (worldClockCount > 0) {
                drawWorldClocks(dc, center, worldClockCount);
            }
        }
    }

    // Simplified stats layout for MIP displays (Fenix 6S)
    private function drawStatsMIP(dc, center) {
        var clockTime = System.getClockTime();

        // World clocks - CENTERED at bottom
        var worldClockCount = Settings.getWorldClockCount();
        if (worldClockCount > 0) {
            var baseY = Theme.getWorldClocksY();
            var localOffset = clockTime.timeZoneOffset / 3600;

            if (worldClockCount >= 1) {
                var tz1Name = Settings.getTimezone1Name();
                var tz1Offset = Settings.getTimezone1Offset();
                var tz1Hour = (clockTime.hour - localOffset + tz1Offset + 48) % 24;
                var tz1Min = clockTime.min;
                var tzY1 = worldClockCount >= 2 ? baseY - 12 : baseY;

                var tz1Str = tz1Name + " " + tz1Hour.format("%02d") + ":" + tz1Min.format("%02d");
                dc.setColor(Theme.getColor(Theme.TEXT_SECONDARY), Graphics.COLOR_TRANSPARENT);
                dc.drawText(center, tzY1, Graphics.FONT_XTINY, tz1Str, Graphics.TEXT_JUSTIFY_CENTER);
            }

            if (worldClockCount >= 2) {
                var tz2Name = Settings.getTimezone2Name();
                var tz2Offset = Settings.getTimezone2Offset();
                var tz2Hour = (clockTime.hour - localOffset + tz2Offset + 48) % 24;
                var tz2Min = clockTime.min;
                var tzY2 = baseY + 12;

                var tz2Str = tz2Name + " " + tz2Hour.format("%02d") + ":" + tz2Min.format("%02d");
                dc.setColor(Theme.getColor(Theme.TEXT_SECONDARY), Graphics.COLOR_TRANSPARENT);
                dc.drawText(center, tzY2, Graphics.FONT_XTINY, tz2Str, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        // HR + Battery row at very bottom
        var statsY = Theme.getStatsRowY();
        var currentHR = 0;

        // Get Heart Rate
        var activityInfo = Activity.getActivityInfo();
        if (activityInfo != null && activityInfo.currentHeartRate != null) {
            currentHR = activityInfo.currentHeartRate;
        } else {
            if (Toybox has :ActivityMonitor) {
                var hrIterator = ActivityMonitor.getHeartRateHistory(1, true);
                if (hrIterator != null) {
                    var hrSample = hrIterator.next();
                    if (hrSample != null && hrSample.heartRate != null && hrSample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                        currentHR = hrSample.heartRate;
                    }
                }
            }
        }

        // Draw heart icon + HR on left side of center
        var hrStr = currentHR > 0 ? currentHR.format("%d") : "--";
        dc.setColor(Theme.getColor(Theme.HR_RING), Graphics.COLOR_TRANSPARENT);
        drawHeartIconSmall(dc, center - 45, statsY - 3);
        dc.drawText(center - 32, statsY, Graphics.FONT_XTINY, hrStr, Graphics.TEXT_JUSTIFY_LEFT);

        // Battery on right side of center
        var stats = System.getSystemStats();
        var battery = stats.battery.toNumber();
        var batteryColor = Theme.TEXT_DIM;
        if (battery <= 20) {
            batteryColor = 0xE57373;
        } else if (battery <= 40) {
            batteryColor = 0xFFB347;
        }
        dc.setColor(Theme.getColor(batteryColor), Graphics.COLOR_TRANSPARENT);
        drawBatteryIconSmall(dc, center + 18, statsY - 4);
        dc.drawText(center + 32, statsY, Graphics.FONT_XTINY, battery.format("%d") + "%", Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Small heart icon for MIP stats row (5x4 pixels)
    private function drawHeartIconSmall(dc, x, y) {
        dc.fillRectangle(x, y, 2, 1);
        dc.fillRectangle(x+3, y, 2, 1);
        dc.fillRectangle(x, y+1, 5, 1);
        dc.fillRectangle(x+1, y+2, 3, 1);
        dc.fillRectangle(x+2, y+3, 1, 1);
    }

    // Small battery icon for MIP stats row (10x6 pixels)
    private function drawBatteryIconSmall(dc, x, y) {
        dc.drawRectangle(x, y, 8, 5);
        dc.fillRectangle(x+8, y+1, 2, 3);
    }

    private function drawActivityRings(dc, center) {
        var ringsX = center - 85;
        var ringsY = 370;
        var stroke = 6;
        var outerR = 48;
        var middleR = 38;
        var innerR = 28;

        var ringLayout = Settings.getRingLayout();

        // Get all activity data (without capping at 1.0 for overflow display)
        var activityData = getActivityDataRaw();
        var currentSteps = activityData[:steps];
        var stepsProgress = activityData[:stepsProgress];
        var currentFloors = activityData[:floors];
        var floorsProgress = activityData[:floorsProgress];
        var bodyBattery = activityData[:bodyBattery];
        var bodyBatteryProgress = activityData[:bodyBatteryProgress];
        var currentHR = activityData[:hr];
        var hrProgress = activityData[:hrProgress];

        // Get configured data sources
        var outerType = Settings.getOuterRing();
        var middleType = Settings.getMiddleRing();
        var innerType = Settings.getInnerRing();

        // Draw outer ring
        if (outerType != 4) {
            var outerData = getRingData(outerType, stepsProgress, floorsProgress, bodyBatteryProgress, hrProgress);
            drawRingWithOverflow(dc, ringsX, ringsY, outerR, stroke, outerData[:progress], Theme.getRingColor(outerType));
        }

        // Draw middle ring (only if layout is "All 3")
        if (ringLayout == 0 && middleType != 4) {
            var middleData = getRingData(middleType, stepsProgress, floorsProgress, bodyBatteryProgress, hrProgress);
            drawRingWithOverflow(dc, ringsX, ringsY, middleR, stroke, middleData[:progress], Theme.getRingColor(middleType));
        }

        // Draw inner ring (only if layout is "All 3")
        if (ringLayout == 0 && innerType != 4) {
            var innerData = getRingData(innerType, stepsProgress, floorsProgress, bodyBatteryProgress, hrProgress);
            drawRingWithOverflow(dc, ringsX, ringsY, innerR, stroke, innerData[:progress], Theme.getRingColor(innerType));
        }

        // Icons to the right of rings
        if (Settings.isShowRingIcons()) {
            var iconX = ringsX + outerR + 12;
            var iconSpacing = 20;

            if (outerType != 4) {
                drawRingIcon(dc, iconX, ringsY - iconSpacing - 5, outerType);
            }
            if (ringLayout == 0 && middleType != 4) {
                drawRingIcon(dc, iconX, ringsY - 5, middleType);
            }
            if (ringLayout == 0 && innerType != 4) {
                drawRingIcon(dc, iconX, ringsY + iconSpacing - 5, innerType);
            }
        }

        // Cycling center data - rotates every 5 seconds through all 4 metrics
        var clockTime = System.getClockTime();
        var cycleIndex = (clockTime.sec / 5) % 4;  // 0=Steps, 1=HR, 2=Floors, 3=BodyBattery

        var centerValue = 0;
        var centerColor = Theme.STEPS_RING;
        var showDash = false;

        if (cycleIndex == 0) {
            // Steps
            centerValue = currentSteps;
            centerColor = Theme.STEPS_RING;
        } else if (cycleIndex == 1) {
            // Heart Rate
            centerValue = currentHR;
            centerColor = Theme.HR_RING;
            if (currentHR <= 0) { showDash = true; }
        } else if (cycleIndex == 2) {
            // Floors
            centerValue = currentFloors;
            centerColor = Theme.FLOORS_RING;
        } else {
            // Body Battery
            centerValue = bodyBattery;
            centerColor = Theme.BODY_BATTERY_RING;
        }

        if (showDash) {
            drawMiniText(dc, ringsX, ringsY, "--", centerColor);
        } else {
            drawMiniNumber(dc, ringsX, ringsY, centerValue, centerColor);
        }

        // Small indicator dot below center showing which metric is displayed
        drawCycleIndicator(dc, ringsX, ringsY + 18, cycleIndex);
    }

    // Draw 4 small dots indicating which metric is currently shown
    private function drawCycleIndicator(dc, centerX, y, activeIndex) {
        var dotSpacing = 8;
        var startX = centerX - (dotSpacing * 1.5).toNumber();
        var colors = [Theme.STEPS_RING, Theme.HR_RING, Theme.FLOORS_RING, Theme.BODY_BATTERY_RING];

        for (var i = 0; i < 4; i++) {
            var dotX = startX + (i * dotSpacing);
            if (i == activeIndex) {
                dc.setColor(colors[i], Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(dotX, y, 3);
            } else {
                dc.setColor(Theme.dimColor(colors[i], 0.3), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(dotX, y, 2);
            }
        }
    }

    // Get activity data without capping progress at 1.0 (for overflow display)
    private function getActivityDataRaw() {
        var currentSteps = 0;
        var stepsProgress = 0.0;
        var currentFloors = 0;
        var floorsProgress = 0.0;
        var bodyBattery = 0;
        var bodyBatteryProgress = 0.0;
        var currentHR = 0;
        var hrProgress = 0.0;

        if (DEBUG_SIMULATOR) {
            currentSteps = DEBUG_STEPS;
            stepsProgress = DEBUG_STEPS.toFloat() / DEBUG_STEP_GOAL.toFloat();
            // Don't cap - allow overflow

            currentFloors = DEBUG_FLOORS;
            floorsProgress = DEBUG_FLOORS.toFloat() / DEBUG_FLOOR_GOAL.toFloat();
            // Don't cap - allow overflow

            bodyBattery = DEBUG_BODY_BATTERY;
            bodyBatteryProgress = bodyBattery / 100.0;

            currentHR = DEBUG_HR;
            hrProgress = (currentHR - 40).toFloat() / 160.0;
            if (hrProgress < 0.0) { hrProgress = 0.0; }
        } else {
            // Get Heart Rate
            var activityInfo = Activity.getActivityInfo();
            if (activityInfo != null && activityInfo.currentHeartRate != null) {
                currentHR = activityInfo.currentHeartRate;
            } else {
                var hrIterator = ActivityMonitor.getHeartRateHistory(1, true);
                if (hrIterator != null) {
                    var hrSample = hrIterator.next();
                    if (hrSample != null && hrSample.heartRate != null && hrSample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                        currentHR = hrSample.heartRate;
                    }
                }
            }
            hrProgress = (currentHR - 40).toFloat() / 160.0;
            if (hrProgress < 0.0) { hrProgress = 0.0; }

            // Get Body Battery
            if (Toybox has :SensorHistory && SensorHistory has :getBodyBatteryHistory) {
                var bbIterator = SensorHistory.getBodyBatteryHistory({:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST});
                if (bbIterator != null) {
                    var bbSample = bbIterator.next();
                    if (bbSample != null && bbSample.data != null) {
                        bodyBattery = bbSample.data.toNumber();
                        bodyBatteryProgress = bodyBattery / 100.0;
                    }
                }
            }

            var actInfo = ActivityMonitor.getInfo();
            if (actInfo != null) {
                if (actInfo.steps != null) {
                    currentSteps = actInfo.steps;
                }
                if (actInfo.stepGoal != null && actInfo.stepGoal > 0) {
                    stepsProgress = currentSteps.toFloat() / actInfo.stepGoal.toFloat();
                    // Don't cap - allow overflow
                }

                if (actInfo.floorsClimbed != null) {
                    currentFloors = actInfo.floorsClimbed;
                }
                var floorGoal = 10;
                if (actInfo.floorsClimbedGoal != null && actInfo.floorsClimbedGoal > 0) {
                    floorGoal = actInfo.floorsClimbedGoal;
                }
                floorsProgress = currentFloors.toFloat() / floorGoal.toFloat();
                // Don't cap - allow overflow
            }
        }

        return {
            :steps => currentSteps,
            :stepsProgress => stepsProgress,
            :floors => currentFloors,
            :floorsProgress => floorsProgress,
            :bodyBattery => bodyBattery,
            :bodyBatteryProgress => bodyBatteryProgress,
            :hr => currentHR,
            :hrProgress => hrProgress
        };
    }

    private function getRingData(dataType, stepsProgress, floorsProgress, bodyBatteryProgress, hrProgress) {
        switch (dataType) {
            case 0: return { :progress => stepsProgress };
            case 1: return { :progress => floorsProgress };
            case 2: return { :progress => bodyBatteryProgress };
            case 3: return { :progress => hrProgress };
            default: return { :progress => 0.0 };
        }
    }

    private function drawRingIcon(dc, x, y, dataType) {
        var color = Theme.getRingColor(dataType);
        switch (dataType) {
            case 0: drawStepsIcon(dc, x, y, color); break;
            case 1: drawStairsIcon(dc, x, y, color); break;
            case 2: drawBodyBatteryIcon(dc, x, y, color); break;
            case 3: drawHeartIcon(dc, x, y, color); break;
        }
    }

    private function drawWorldClocks(dc, center, count) {
        var ringsY = 370;
        var tzX = center + 80;
        var clockTime = System.getClockTime();
        var localOffset = clockTime.timeZoneOffset / 3600;

        var labelX = tzX - 80;
        var timeX = tzX - 15;

        if (count >= 1) {
            var tz1Name = Settings.getTimezone1Name();
            var tz1Offset = Settings.getTimezone1Offset();
            var tz1Hour = (clockTime.hour - localOffset + tz1Offset + 48) % 24;
            var tz1Min = clockTime.min;

            var tzY1 = count >= 2 ? ringsY - 41 : ringsY - 21;

            dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(labelX, tzY1, Graphics.FONT_XTINY, tz1Name, Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(Theme.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(timeX, tzY1, Graphics.FONT_XTINY, tz1Hour.format("%02d") + ":" + tz1Min.format("%02d"), Graphics.TEXT_JUSTIFY_LEFT);
        }

        if (count >= 2) {
            var tz2Name = Settings.getTimezone2Name();
            var tz2Offset = Settings.getTimezone2Offset();
            var tz2Hour = (clockTime.hour - localOffset + tz2Offset + 48) % 24;
            var tz2Min = clockTime.min;

            var tzY2 = ringsY - 1;

            dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(labelX, tzY2, Graphics.FONT_XTINY, tz2Name, Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(Theme.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(timeX, tzY2, Graphics.FONT_XTINY, tz2Hour.format("%02d") + ":" + tz2Min.format("%02d"), Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // Mini-digit renderer: draws 8x10 pixel digits
    private function drawMiniDigit(dc, x, y, digit, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (digit == 0) {
            dc.fillRectangle(x+1, y, 6, 1);
            dc.fillRectangle(x+1, y+9, 6, 1);
            dc.fillRectangle(x, y+1, 1, 8);
            dc.fillRectangle(x+7, y+1, 1, 8);
        } else if (digit == 1) {
            dc.fillRectangle(x+4, y, 1, 10);
            dc.fillRectangle(x+3, y+1, 1, 1);
        } else if (digit == 2) {
            dc.fillRectangle(x, y, 8, 1);
            dc.fillRectangle(x+7, y+1, 1, 3);
            dc.fillRectangle(x+1, y+4, 6, 1);
            dc.fillRectangle(x, y+5, 1, 4);
            dc.fillRectangle(x, y+9, 8, 1);
        } else if (digit == 3) {
            dc.fillRectangle(x, y, 8, 1);
            dc.fillRectangle(x+7, y+1, 1, 8);
            dc.fillRectangle(x+1, y+4, 6, 1);
            dc.fillRectangle(x, y+9, 8, 1);
        } else if (digit == 4) {
            dc.fillRectangle(x, y, 1, 5);
            dc.fillRectangle(x, y+4, 8, 1);
            dc.fillRectangle(x+7, y, 1, 10);
        } else if (digit == 5) {
            dc.fillRectangle(x, y, 8, 1);
            dc.fillRectangle(x, y+1, 1, 3);
            dc.fillRectangle(x, y+4, 8, 1);
            dc.fillRectangle(x+7, y+5, 1, 4);
            dc.fillRectangle(x, y+9, 8, 1);
        } else if (digit == 6) {
            dc.fillRectangle(x+1, y, 7, 1);
            dc.fillRectangle(x, y+1, 1, 8);
            dc.fillRectangle(x+1, y+4, 7, 1);
            dc.fillRectangle(x+7, y+5, 1, 4);
            dc.fillRectangle(x+1, y+9, 6, 1);
        } else if (digit == 7) {
            dc.fillRectangle(x, y, 8, 1);
            dc.fillRectangle(x+7, y+1, 1, 9);
        } else if (digit == 8) {
            dc.fillRectangle(x+1, y, 6, 1);
            dc.fillRectangle(x+1, y+4, 6, 1);
            dc.fillRectangle(x+1, y+9, 6, 1);
            dc.fillRectangle(x, y+1, 1, 8);
            dc.fillRectangle(x+7, y+1, 1, 8);
        } else if (digit == 9) {
            dc.fillRectangle(x+1, y, 6, 1);
            dc.fillRectangle(x, y+1, 1, 3);
            dc.fillRectangle(x+1, y+4, 7, 1);
            dc.fillRectangle(x+7, y+1, 1, 8);
            dc.fillRectangle(x, y+9, 7, 1);
        }
    }

    private function drawMiniNumber(dc, centerX, centerY, number, color) {
        var isNegative = number < 0;
        if (isNegative) { number = -number; }

        var str = number.format("%d");
        var len = str.length();
        var digitWidth = 9;
        var minusWidth = isNegative ? 7 : 0;
        var totalWidth = minusWidth + len * digitWidth - 1;
        var startX = centerX - totalWidth / 2;
        var startY = centerY - 5;

        if (isNegative) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(startX, startY + 4, 6, 1);
            startX = startX + minusWidth;
        }

        for (var i = 0; i < len; i++) {
            var ch = str.substring(i, i+1);
            var digit = ch.toNumber();
            drawMiniDigit(dc, startX + i * digitWidth, startY, digit, color);
        }
    }

    private function drawMiniLetter(dc, x, y, letter, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (letter.equals("M")) {
            dc.fillRectangle(x, y, 1, 11);
            dc.fillRectangle(x+8, y, 1, 11);
            dc.fillRectangle(x+1, y+1, 1, 2);
            dc.fillRectangle(x+7, y+1, 1, 2);
            dc.fillRectangle(x+2, y+2, 2, 1);
            dc.fillRectangle(x+5, y+2, 2, 1);
            dc.fillRectangle(x+3, y+3, 3, 1);
        } else if (letter.equals("T")) {
            dc.fillRectangle(x, y, 9, 1);
            dc.fillRectangle(x+4, y+1, 1, 10);
        } else if (letter.equals("W")) {
            dc.fillRectangle(x, y, 1, 11);
            dc.fillRectangle(x+8, y, 1, 11);
            dc.fillRectangle(x+4, y+5, 1, 5);
            dc.fillRectangle(x+1, y+9, 3, 1);
            dc.fillRectangle(x+5, y+9, 3, 1);
        } else if (letter.equals("F")) {
            dc.fillRectangle(x, y, 9, 1);
            dc.fillRectangle(x, y+1, 1, 10);
            dc.fillRectangle(x+1, y+5, 5, 1);
        } else if (letter.equals("S")) {
            dc.fillRectangle(x+1, y, 7, 1);
            dc.fillRectangle(x, y+1, 1, 4);
            dc.fillRectangle(x+1, y+5, 7, 1);
            dc.fillRectangle(x+8, y+6, 1, 4);
            dc.fillRectangle(x+1, y+10, 7, 1);
        } else if (letter.equals("U")) {
            dc.fillRectangle(x, y, 1, 10);
            dc.fillRectangle(x+8, y, 1, 10);
            dc.fillRectangle(x+1, y+10, 7, 1);
        } else if (letter.equals("O")) {
            dc.fillRectangle(x+1, y, 7, 1);
            dc.fillRectangle(x, y+1, 1, 9);
            dc.fillRectangle(x+8, y+1, 1, 9);
            dc.fillRectangle(x+1, y+10, 7, 1);
        } else if (letter.equals("H")) {
            dc.fillRectangle(x, y, 1, 11);
            dc.fillRectangle(x+8, y, 1, 11);
            dc.fillRectangle(x+1, y+5, 7, 1);
        } else if (letter.equals("R")) {
            dc.fillRectangle(x, y, 1, 11);
            dc.fillRectangle(x+1, y, 7, 1);
            dc.fillRectangle(x+8, y+1, 1, 4);
            dc.fillRectangle(x+1, y+5, 7, 1);
            dc.fillRectangle(x+5, y+6, 1, 2);
            dc.fillRectangle(x+6, y+8, 1, 1);
            dc.fillRectangle(x+7, y+9, 2, 2);
        } else if (letter.equals("A")) {
            dc.fillRectangle(x+3, y, 3, 1);
            dc.fillRectangle(x+1, y+1, 2, 1);
            dc.fillRectangle(x+6, y+1, 2, 1);
            dc.fillRectangle(x, y+2, 1, 9);
            dc.fillRectangle(x+8, y+2, 1, 9);
            dc.fillRectangle(x+1, y+5, 7, 1);
        } else if (letter.equals("E")) {
            dc.fillRectangle(x, y, 9, 1);
            dc.fillRectangle(x, y+1, 1, 9);
            dc.fillRectangle(x+1, y+5, 5, 1);
            dc.fillRectangle(x, y+10, 9, 1);
        } else if (letter.equals("-")) {
            dc.fillRectangle(x+2, y+5, 5, 1);  // Horizontal dash centered vertically
        }
    }

    private function drawMiniText(dc, centerX, y, text, color) {
        var len = text.length();
        var letterWidth = 10;
        var totalWidth = len * letterWidth - 1;
        var startX = centerX - totalWidth / 2;

        for (var i = 0; i < len; i++) {
            var letter = text.substring(i, i+1);
            drawMiniLetter(dc, startX + i * letterWidth, y, letter, color);
        }
    }

    private function drawStepsIcon(dc, x, y, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y+2, 2, 5);
        dc.fillRectangle(x+2, y+3, 1, 3);
        dc.fillRectangle(x, y, 2, 1);
        dc.fillRectangle(x+5, y+5, 2, 5);
        dc.fillRectangle(x+4, y+6, 1, 3);
        dc.fillRectangle(x+5, y+3, 2, 1);
    }

    private function drawStairsIcon(dc, x, y, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y+8, 3, 2);
        dc.fillRectangle(x+3, y+5, 3, 2);
        dc.fillRectangle(x+6, y+2, 3, 2);
        dc.fillRectangle(x+3, y+7, 1, 3);
        dc.fillRectangle(x+6, y+4, 1, 3);
    }

    private function drawBodyBatteryIcon(dc, x, y, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y+1, 8, 1);
        dc.fillRectangle(x, y+9, 8, 1);
        dc.fillRectangle(x, y+2, 1, 7);
        dc.fillRectangle(x+7, y+2, 1, 7);
        dc.fillRectangle(x+3, y, 3, 1);
        dc.fillRectangle(x+2, y+3, 4, 5);
    }

    private function drawHeartIcon(dc, x, y, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, 2, 2);
        dc.fillRectangle(x+4, y, 2, 2);
        dc.fillRectangle(x+2, y+1, 2, 1);
        dc.fillRectangle(x, y+2, 6, 1);
        dc.fillRectangle(x+1, y+3, 4, 1);
        dc.fillRectangle(x+2, y+4, 2, 1);
    }

    // Draw ring with Apple-style overflow indicator when progress > 100%
    private function drawRingWithOverflow(dc, x, y, radius, stroke, progress, color) {
        dc.setPenWidth(stroke);

        // Background ring (very dim)
        dc.setColor(Theme.dimColor(color, 0.15), Graphics.COLOR_TRANSPARENT);
        dc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, 90, -270);

        if (progress <= 0.01) {
            dc.setPenWidth(1);
            return;
        }

        if (progress <= 1.0) {
            // Normal progress: draw the arc with rounded caps
            var sweepDeg = (progress * 360).toNumber();
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, 90, 90 - sweepDeg);

            // Rounded start cap at 12 o'clock
            var startX = x;
            var startY = y - radius;
            dc.fillCircle(startX, startY, stroke / 2);

            // Rounded end cap at the tip
            var tipAngle = (90 - sweepDeg) * Math.PI / 180.0;
            var tipX = x + (radius * Math.cos(tipAngle)).toNumber();
            var tipY = y - (radius * Math.sin(tipAngle)).toNumber();
            dc.fillCircle(tipX, tipY, stroke / 2);
        } else {
            // OVERFLOW - Apple-style pure layering (no arrows)

            // 1. Base ring: completed 100%, dimmed to show it's "underneath"
            dc.setColor(Theme.dimColor(color, 0.5), Graphics.COLOR_TRANSPARENT);
            dc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, 90, -270);

            // 2. Calculate overflow (capped at 100% extra for visual)
            var overflow = progress - 1.0;
            if (overflow > 1.0) { overflow = 1.0; }
            var overflowDeg = (overflow * 360).toNumber();
            if (overflowDeg < 8) { overflowDeg = 8; }

            // 3. Shadow layer - offset down-right, creates floating effect
            dc.setPenWidth(stroke);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(x + 3, y + 3, radius, Graphics.ARC_CLOCKWISE, 90, 90 - overflowDeg);
            // Shadow end cap
            var shadowTipAngle = (90 - overflowDeg) * Math.PI / 180.0;
            var shadowTipX = (x + 3) + (radius * Math.cos(shadowTipAngle)).toNumber();
            var shadowTipY = (y + 3) - (radius * Math.sin(shadowTipAngle)).toNumber();
            dc.fillCircle(shadowTipX, shadowTipY, stroke / 2);
            // Shadow start cap
            dc.fillCircle(x + 3, y + 3 - radius, stroke / 2);

            // 4. Bright overflow arc - full brightness, "on top"
            var overflowColor = Theme.brightenColor(color, 1.25);
            dc.setColor(overflowColor, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, 90, 90 - overflowDeg);

            // 5. Rounded start cap at 12 o'clock
            dc.fillCircle(x, y - radius, stroke / 2);

            // 6. Rounded end cap - slightly larger to emphasize the "head"
            var tipAngle = (90 - overflowDeg) * Math.PI / 180.0;
            var tipX = x + (radius * Math.cos(tipAngle)).toNumber();
            var tipY = y - (radius * Math.sin(tipAngle)).toNumber();
            dc.fillCircle(tipX, tipY, (stroke / 2) + 1);
        }

        dc.setPenWidth(1);
    }

    private function drawMoveBar(dc) {
        if (Theme.isMIPDisplay) { return; }

        var moveBarLevel = 0;
        if (DEBUG_SIMULATOR) {
            moveBarLevel = DEBUG_MOVE_BAR;
        } else {
            var actInfo = ActivityMonitor.getInfo();
            if (actInfo != null && actInfo.moveBarLevel != null) {
                moveBarLevel = actInfo.moveBarLevel;
            }
        }

        if (moveBarLevel <= 0) { return; }

        var center = Theme.getCenter();
        var radius = center - 2;
        var halfSpread = moveBarLevel * 36;

        dc.setPenWidth(3);
        dc.setColor(0xC62828, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(center, center, radius, Graphics.ARC_CLOCKWISE,
            270 + halfSpread, 270 - halfSpread);
        dc.setPenWidth(1);
    }

    private function drawAOD(dc) {
        var center = Theme.getCenter();
        var clockTime = System.getClockTime();
        var hour = clockTime.hour;
        var min = clockTime.min;

        var is24h = Settings.is24Hour();
        if (!is24h) {
            if (hour > 12) { hour = hour - 12; }
            if (hour == 0) { hour = 12; }
        }

        dc.setColor(Theme.AOD_TIME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, Theme.screenHeight / 2, Graphics.FONT_NUMBER_MILD,
            hour.format("%d") + ":" + min.format("%02d"),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dayNames = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
        dc.setColor(Theme.AOD_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, Theme.screenHeight / 2 + 45, Graphics.FONT_XTINY,
            dayNames[now.day_of_week - 1] + " " + now.day,
            Graphics.TEXT_JUSTIFY_CENTER);

        if (Settings.shouldShowBattery(System.getSystemStats().battery.toNumber())) {
            var battery = System.getSystemStats().battery.toNumber();
            dc.drawText(Theme.screenWidth - 20, 15, Graphics.FONT_XTINY,
                battery.format("%d") + "%",
                Graphics.TEXT_JUSTIFY_RIGHT);
        }
    }
}

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

class WatchFaceView extends WatchUi.WatchFace {

    private var _isAwake = true;

    // SIMULATOR DEBUG MODE: Set to true for testing in simulator, false for release
    // The Garmin simulator does NOT populate ActivityMonitor data from simulation-data.json
    private const DEBUG_SIMULATOR = false;
    private const DEBUG_STEPS = 2108;
    private const DEBUG_STEP_GOAL = 7000;
    private const DEBUG_FLOORS = 3;
    private const DEBUG_FLOOR_GOAL = 10;
    private const DEBUG_BODY_BATTERY = 72;
    private const DEBUG_HR = 68;

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
        drawWeatherChart(dc);
        drawDate(dc);
        drawTime(dc);
        drawStats(dc);
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
        var stats = System.getSystemStats();
        var battery = stats.battery.toNumber();

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
        // Header - centered single column: temp on top, city below
        var y = 8;  // Moved up
        var center = Theme.getCenter();

        // Use cached data from WeatherDataManager
        var tempStr = WeatherDataManager.currentTemp != null
            ? WeatherDataManager.currentTemp.format("%d") + "°"
            : "18°";
        var locationStr = WeatherDataManager.locationName;

        // Temperature on line 1 (centered, brighter)
        dc.setColor(Theme.TIME_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 7, Graphics.FONT_XTINY, tempStr, Graphics.TEXT_JUSTIFY_CENTER);

        // City on line 2 (centered, dimmer)
        dc.setColor(Theme.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 30, Graphics.FONT_XTINY, locationStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawWeatherChart(dc) {
        // Chart dimensions
        var chartX = 45;
        var chartY = 70;
        var chartWidth = Theme.screenWidth - 90;
        var chartHeight = 80;  // Reduced to make room for day labels below

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

        // Day/night band at bottom of chart area
        var bandY = chartY + chartHeight - 5;
        var bandHeight = 6;
        for (var i = 0; i < chartWidth; i += 2) {
            var idx = (i * 72 / chartWidth);
            if (idx >= 72) { idx = 71; }
            dc.setColor(Theme.getSkyColor(hours[idx]), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(chartX + i, bandY, 2, bandHeight);
        }

        // Clouds at top - organic shapes using overlapping circles
        for (var i = 0; i < 72; i += 3) {
            var c = clouds[i];
            if (c > 35) {
                var x = chartX + (i * chartWidth / 72);
                var opacity = (c - 35).toFloat() / 65.0;
                var cloudColor = Theme.dimColor(Theme.CLOUD_COLOR, opacity * 0.35);
                dc.setColor(cloudColor, Graphics.COLOR_TRANSPARENT);

                // Draw puffy cloud shape with multiple overlapping circles
                var baseY = chartY + 6;
                var cloudWidth = 18 + (c / 10);  // Wider clouds for higher coverage

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

        // Temperature curve
        var tempYStart = chartY + 10;
        var tempHeight = chartHeight - 25;

        dc.setColor(Theme.TEMP_CURVE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);

        var prevX = -1;
        var prevTempY = -1;

        for (var i = 0; i < 72; i++) {
            var x = chartX + (i * chartWidth / 72);
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

        // Wind line (subtle but visible)
        dc.setColor(Theme.dimColor(Theme.WIND_SPEED, 0.5), Graphics.COLOR_TRANSPARENT);
        prevX = -1;
        var prevWindY = -1;

        for (var i = 0; i < 72; i++) {
            var x = chartX + (i * chartWidth / 72);
            var norm = winds[i] / 20.0;  // Lower ceiling for typical wind speeds 5-15 km/h
            if (norm > 1.0) { norm = 1.0; }
            var y = tempYStart + 2 + (tempHeight - 4) - (norm * (tempHeight - 4));

            if (prevX >= 0) {
                dc.drawLine(prevX, prevWindY, x, y.toNumber());
            }
            prevX = x;
            prevWindY = y.toNumber();
        }

        // Precipitation bars - draw from bottom of chart, upward
        var precipBaseY = chartY + chartHeight - 12;  // Above the day/night band

        for (var i = 0; i < 72; i++) {
            var precipChance = precips[i];
            if (precipChance > 5) {  // Lower threshold from 15% to 5%
                var x = chartX + (i * chartWidth / 72);
                // Scale height: 5% = 2px, 100% = 20px
                // FIXED: Use float division to avoid integer truncation (18/95=0)
                var h = (2 + (precipChance - 5).toFloat() * 18.0 / 95.0).toNumber();
                if (h > 20) { h = 20; }

                // Color intensity based on chance
                var intensity = 0.4 + (precipChance / 100.0) * 0.6;
                dc.setColor(Theme.dimColor(Theme.PRECIPITATION, intensity), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, precipBaseY - h, 3, h);  // 3px bars to fit 72 hours
            }
        }

        // Day separators (dotted lines at midnight)
        var days = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];  // Two-letter abbreviations
        var dayLabelY = chartY + chartHeight + 3;  // Below chart with spacing

        for (var i = 6; i < 72; i += 6) {
            var hour = (currentHour + i) % 24;
            var x = chartX + (i * chartWidth / 72);

            if (hour == 0) {
                // Dotted vertical line
                dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
                for (var dy = chartY + 4; dy < chartY + chartHeight - 8; dy += 3) {
                    dc.fillRectangle(x, dy, 1, 1);
                }
            }
        }

        // Day labels BELOW the chart - using mini letters, brighter than before
        // Position labels at center of each day's span
        var hoursUntilMidnight = (24 - currentHour) % 24;
        if (hoursUntilMidnight == 0) { hoursUntilMidnight = 24; }

        var dayLabelColor = Theme.TEXT_DIM;  // Brighter than before (was dimColor 0.6)

        // Today's label - center of remaining hours
        var todayCenter = hoursUntilMidnight / 2;
        var todayX = chartX + (todayCenter * chartWidth / 72);
        var todayIdx = (dayOfWeek - 1);
        if (todayIdx < 0) { todayIdx = 6; }
        drawMiniText(dc, todayX, dayLabelY, days[todayIdx], dayLabelColor);

        // Tomorrow's label (day +1)
        var day1Start = hoursUntilMidnight;
        var day1Center = day1Start + 12;
        if (day1Center < 72) {
            var day1X = chartX + (day1Center * chartWidth / 72);
            var day1Idx = (dayOfWeek) % 7;
            drawMiniText(dc, day1X, dayLabelY, days[day1Idx], dayLabelColor);
        }

        // Day +2 label
        var day2Start = hoursUntilMidnight + 24;
        var day2Center = day2Start + 12;
        if (day2Center < 72) {
            var day2X = chartX + (day2Center * chartWidth / 72);
            var day2Idx = (dayOfWeek + 1) % 7;
            drawMiniText(dc, day2X, dayLabelY, days[day2Idx], dayLabelColor);
        }

        // Day +3 label (Thursday if today is Monday)
        var day3Start = hoursUntilMidnight + 48;
        var day3Center = day3Start + 12;
        if (day3Center < 72) {
            var day3X = chartX + (day3Center * chartWidth / 72);
            var day3Idx = (dayOfWeek + 2) % 7;
            drawMiniText(dc, day3X, dayLabelY, days[day3Idx], dayLabelColor);
        }

        // Temperature boxes (high/low for each visible day) - using mini-digits
        var boxH = 10;
        var boxW = 16;
        var boxR = 2;  // Corner radius

        for (var d = 0; d < 3; d++) {
            if (dayHighs[d] > -100.0) {
                // Draw high temp box
                var hiIdx = dayHighIdx[d];
                var hiX = chartX + (hiIdx * chartWidth / 72);
                var hiNorm = (dayHighs[d] - minTemp) / tempRange;
                if (hiNorm < 0.0) { hiNorm = 0.0; }
                if (hiNorm > 1.0) { hiNorm = 1.0; }
                var hiY = tempYStart + tempHeight - (hiNorm * tempHeight);
                var hiBoxY = hiY.toNumber() - 11;

                // Background box
                dc.setColor(Theme.dimColor(Theme.TEMP_CURVE, 0.25), Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(hiX - boxW/2, hiBoxY, boxW, boxH, boxR);

                // Mini number
                drawMiniNumber(dc, hiX, hiBoxY + 5, dayHighs[d].toNumber(), Theme.TEMP_CURVE);
            }

            if (dayLows[d] < 100.0 && d > 0) {  // Skip today's low if partial day
                // Draw low temp box
                var loIdx = dayLowIdx[d];
                var loX = chartX + (loIdx * chartWidth / 72);
                var loNorm = (dayLows[d] - minTemp) / tempRange;
                if (loNorm < 0.0) { loNorm = 0.0; }
                if (loNorm > 1.0) { loNorm = 1.0; }
                var loY = tempYStart + tempHeight - (loNorm * tempHeight);
                var loBoxY = loY.toNumber() + 3;

                // Background box (dimmer)
                dc.setColor(Theme.dimColor(Theme.TEMP_CURVE, 0.15), Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(loX - boxW/2, loBoxY, boxW, boxH, boxR);

                // Mini number (dimmer)
                drawMiniNumber(dc, loX, loBoxY + 5, dayLows[d].toNumber(), Theme.dimColor(Theme.TEMP_CURVE, 0.7));
            }
        }

        // NOW indicator removed - was too prominent
    }

    private function drawDate(dc) {
        // Date row - moved down
        var y = 172;
        var center = Theme.getCenter();
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        var dayNames = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
        var monthNames = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];

        var dateStr = dayNames[now.day_of_week - 1] + " " + now.day + " " + monthNames[now.month - 1];

        var startOfYear = Gregorian.moment({:year => now.year, :month => 1, :day => 1});
        var dayOfYear = ((Time.now().value() - startOfYear.value()) / 86400).toNumber() + 1;
        var startDow = Gregorian.info(startOfYear, Time.FORMAT_SHORT).day_of_week;
        var weekNum = ((dayOfYear + startDow - 2) / 7).toNumber() + 1;

        var dateWidth = dc.getTextWidthInPixels(dateStr, Graphics.FONT_XTINY);
        var badgeWidth = 24;  // Wider to cover number
        var badgeGap = 6;
        var totalWidth = dateWidth + badgeGap + badgeWidth;
        var startX = center - (totalWidth / 2);

        dc.setColor(Theme.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, y, Graphics.FONT_XTINY, dateStr, Graphics.TEXT_JUSTIFY_LEFT);

        var fontH = dc.getFontHeight(Graphics.FONT_XTINY);
        var badgeH = fontH;  // Match font height exactly
        var badgeX = startX + dateWidth + badgeGap;
        var badgeY = y;  // Align with text baseline

        dc.setColor(Theme.WEEK_BADGE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(badgeX, badgeY, badgeWidth, badgeH, 4);

        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(badgeX + badgeWidth / 2, badgeY + badgeH / 2, Graphics.FONT_XTINY, weekNum.format("%d"), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawTime(dc) {
        // Time display with step goal fill effect
        var clockTime = System.getClockTime();
        var deviceSettings = System.getDeviceSettings();
        var center = Theme.getCenter();
        var baseY = 268;

        var hour = clockTime.hour;
        var min = clockTime.min;
        var isPM = hour >= 12;

        if (!deviceSettings.is24Hour) {
            if (hour > 12) { hour = hour - 12; }
            if (hour == 0) { hour = 12; }
        }

        var timeStr = hour.format("%d") + ":" + min.format("%02d");

        var stepProgress = 0.0;
        if (DEBUG_SIMULATOR) {
            // Use debug values for simulator testing
            stepProgress = DEBUG_STEPS.toFloat() / DEBUG_STEP_GOAL.toFloat();
        } else {
            var actInfo = ActivityMonitor.getInfo();
            if (actInfo != null && actInfo.steps != null && actInfo.stepGoal != null && actInfo.stepGoal > 0) {
                stepProgress = actInfo.steps.toFloat() / actInfo.stepGoal.toFloat();
            }
        }
        if (stepProgress > 1.0) { stepProgress = 1.0; }

        var timeFont = Graphics.FONT_NUMBER_HOT;
        var fontHeight = dc.getFontHeight(timeFont);

        var textTop = baseY - (fontHeight / 2);
        var textBottom = baseY + (fontHeight / 2);
        // Scale progress by 1.5x so visual fill matches perceived completion
        // (digit pixels are mostly in upper 70% of font height, so 30% real = ~5% visible)
        var scaledProgress = stepProgress * 1.5;
        if (scaledProgress > 1.0) { scaledProgress = 1.0; }
        var fillPixels = (fontHeight * scaledProgress).toNumber();
        var fillY = textBottom - fillPixels;

        if (fontHeight > fillPixels) {
            dc.setClip(0, textTop, Theme.screenWidth, fontHeight - fillPixels);
            dc.setColor(Theme.TIME_UNFILLED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(center, baseY, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.clearClip();
        }

        if (fillPixels > 0) {
            dc.setClip(0, fillY, Theme.screenWidth, fillPixels);
            dc.setColor(Theme.TIME_FILL, Graphics.COLOR_TRANSPARENT);
            dc.drawText(center, baseY, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.clearClip();
        }

        // PM/AM and seconds - stacked vertically to the right of time with proper spacing
        var timeWidth = dc.getTextWidthInPixels(timeStr, timeFont);
        var rightX = center + (timeWidth / 2) + 8;

        // Seconds on top (larger, brighter) - moved higher
        dc.setColor(Theme.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightX, baseY - 24, Graphics.FONT_TINY, clockTime.sec.format("%02d"), Graphics.TEXT_JUSTIFY_LEFT);

        // AM/PM below seconds (smaller, dimmer) - moved lower
        if (!deviceSettings.is24Hour) {
            dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rightX, baseY + 16, Graphics.FONT_XTINY, isPM ? "PM" : "AM", Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    private function drawStats(dc) {
        // New layout: Rings on LEFT with HR in center, Secondary Timezone on RIGHT
        var center = Theme.getCenter();

        // === LEFT SIDE: Activity Rings with HR in center ===
        var ringsX = center - 70;
        var ringsY = 370;
        var stroke = 4;
        var outerR = 34;   // Steps (outer)
        var middleR = 26;  // Floors (middle)
        var innerR = 18;   // Body Battery (inner)

        var currentSteps = 0;
        var stepsProgress = 0.0;
        var currentFloors = 0;
        var floorsProgress = 0.0;
        var bodyBattery = 0;
        var bodyBatteryProgress = 0.0;
        var currentHR = 0;

        if (DEBUG_SIMULATOR) {
            // Use debug values for simulator testing
            currentSteps = DEBUG_STEPS;
            stepsProgress = DEBUG_STEPS.toFloat() / DEBUG_STEP_GOAL.toFloat();
            if (stepsProgress > 1.0) { stepsProgress = 1.0; }

            currentFloors = DEBUG_FLOORS;
            floorsProgress = DEBUG_FLOORS.toFloat() / DEBUG_FLOOR_GOAL.toFloat();
            if (floorsProgress > 1.0) { floorsProgress = 1.0; }

            bodyBattery = DEBUG_BODY_BATTERY;
            bodyBatteryProgress = bodyBattery / 100.0;

            currentHR = DEBUG_HR;
        } else {
            // Get Heart Rate from Activity (live during workout) or ActivityMonitor (resting)
            var activityInfo = Activity.getActivityInfo();
            if (activityInfo != null && activityInfo.currentHeartRate != null) {
                currentHR = activityInfo.currentHeartRate;
            } else {
                // Try to get latest HR from history
                var hrIterator = ActivityMonitor.getHeartRateHistory(1, true);
                if (hrIterator != null) {
                    var hrSample = hrIterator.next();
                    if (hrSample != null && hrSample.heartRate != null && hrSample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                        currentHR = hrSample.heartRate;
                    }
                }
            }

            // Get Body Battery from SensorHistory
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
                // Steps
                if (actInfo.steps != null) {
                    currentSteps = actInfo.steps;
                }
                if (actInfo.stepGoal != null && actInfo.stepGoal > 0) {
                    stepsProgress = currentSteps.toFloat() / actInfo.stepGoal.toFloat();
                    if (stepsProgress > 1.0) { stepsProgress = 1.0; }
                }

                // Floors - default goal to 10 if not set
                if (actInfo.floorsClimbed != null) {
                    currentFloors = actInfo.floorsClimbed;
                }
                var floorGoal = 10;  // Default goal
                if (actInfo.floorsClimbedGoal != null && actInfo.floorsClimbedGoal > 0) {
                    floorGoal = actInfo.floorsClimbedGoal;
                }
                floorsProgress = currentFloors.toFloat() / floorGoal.toFloat();
                if (floorsProgress > 1.0) { floorsProgress = 1.0; }
            }
        }

        // Draw rings: Steps (outer), Floors (middle), Body Battery (inner)
        drawRing(dc, ringsX, ringsY, outerR, stroke, stepsProgress, Theme.STEPS_RING);
        drawRing(dc, ringsX, ringsY, middleR, stroke, floorsProgress, Theme.FLOORS_RING);
        drawRing(dc, ringsX, ringsY, innerR, stroke, bodyBatteryProgress, Theme.BODY_BATTERY_RING);

        // Icons to the right of rings (vertically stacked, matching ring order)
        var iconX = ringsX + outerR + 10;  // Right of outer ring with gap
        var iconSpacing = 14;              // Vertical spacing between icons
        drawStepsIcon(dc, iconX, ringsY - iconSpacing - 5, Theme.STEPS_RING);
        drawStairsIcon(dc, iconX, ringsY - 5, Theme.FLOORS_RING);
        drawBodyBatteryIcon(dc, iconX, ringsY + iconSpacing - 5, Theme.BODY_BATTERY_RING);

        // Tiny HR in center of rings - using mini-digits (no heart icon)
        drawMiniNumber(dc, ringsX, ringsY, currentHR, Theme.HR_RING);

        // Steps count below rings - show full number with more gap
        drawMiniNumber(dc, ringsX, ringsY + outerR + 14, currentSteps, Theme.STEPS_RING);

        // === RIGHT SIDE: Secondary Timezone (São Paulo, UTC-3) ===
        var tzX = center + 75;
        var tzY = ringsY - 12;

        // Calculate São Paulo time (BRT = UTC-3)
        var clockTime = System.getClockTime();
        var localOffset = clockTime.timeZoneOffset / 3600;  // Local offset in hours
        var spOffset = -3;  // São Paulo is UTC-3
        var spHour = (clockTime.hour - localOffset + spOffset + 48) % 24;
        var spMin = clockTime.min;

        // Time with normal smallest font
        dc.setColor(Theme.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tzX, tzY, Graphics.FONT_XTINY, spHour.format("%02d") + ":" + spMin.format("%02d"), Graphics.TEXT_JUSTIFY_CENTER);

        // Label below with more spacing
        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tzX, tzY + 26, Graphics.FONT_XTINY, "SAO", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Mini-digit renderer: draws 8x10 pixel digits
    private function drawMiniDigit(dc, x, y, digit, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        // Each digit is 8px wide, 10px tall
        if (digit == 0) {
            dc.fillRectangle(x+1, y, 6, 1);    // top
            dc.fillRectangle(x+1, y+9, 6, 1);  // bottom
            dc.fillRectangle(x, y+1, 1, 8);    // left
            dc.fillRectangle(x+7, y+1, 1, 8);  // right
        } else if (digit == 1) {
            dc.fillRectangle(x+4, y, 1, 10);   // center vertical
            dc.fillRectangle(x+3, y+1, 1, 1);  // top left tick
        } else if (digit == 2) {
            dc.fillRectangle(x, y, 8, 1);      // top
            dc.fillRectangle(x+7, y+1, 1, 3);  // right upper
            dc.fillRectangle(x+1, y+4, 6, 1);  // middle
            dc.fillRectangle(x, y+5, 1, 4);    // left lower
            dc.fillRectangle(x, y+9, 8, 1);    // bottom
        } else if (digit == 3) {
            dc.fillRectangle(x, y, 8, 1);      // top
            dc.fillRectangle(x+7, y+1, 1, 8);  // right
            dc.fillRectangle(x+1, y+4, 6, 1);  // middle
            dc.fillRectangle(x, y+9, 8, 1);    // bottom
        } else if (digit == 4) {
            dc.fillRectangle(x, y, 1, 5);      // left upper
            dc.fillRectangle(x, y+4, 8, 1);    // middle
            dc.fillRectangle(x+7, y, 1, 10);   // right
        } else if (digit == 5) {
            dc.fillRectangle(x, y, 8, 1);      // top
            dc.fillRectangle(x, y+1, 1, 3);    // left upper
            dc.fillRectangle(x, y+4, 8, 1);    // middle
            dc.fillRectangle(x+7, y+5, 1, 4);  // right lower
            dc.fillRectangle(x, y+9, 8, 1);    // bottom
        } else if (digit == 6) {
            dc.fillRectangle(x+1, y, 7, 1);    // top
            dc.fillRectangle(x, y+1, 1, 8);    // left
            dc.fillRectangle(x+1, y+4, 7, 1);  // middle
            dc.fillRectangle(x+7, y+5, 1, 4);  // right lower
            dc.fillRectangle(x+1, y+9, 6, 1);  // bottom
        } else if (digit == 7) {
            dc.fillRectangle(x, y, 8, 1);      // top
            dc.fillRectangle(x+7, y+1, 1, 9);  // right
        } else if (digit == 8) {
            dc.fillRectangle(x+1, y, 6, 1);    // top
            dc.fillRectangle(x+1, y+4, 6, 1);  // middle
            dc.fillRectangle(x+1, y+9, 6, 1);  // bottom
            dc.fillRectangle(x, y+1, 1, 8);    // left
            dc.fillRectangle(x+7, y+1, 1, 8);  // right
        } else if (digit == 9) {
            dc.fillRectangle(x+1, y, 6, 1);    // top
            dc.fillRectangle(x, y+1, 1, 3);    // left upper
            dc.fillRectangle(x+1, y+4, 7, 1);  // middle
            dc.fillRectangle(x+7, y+1, 1, 8);  // right
            dc.fillRectangle(x, y+9, 7, 1);    // bottom
        }
    }

    // Draw a mini number (multiple digits) centered at x,y - supports negative
    private function drawMiniNumber(dc, centerX, centerY, number, color) {
        var isNegative = number < 0;
        if (isNegative) { number = -number; }

        var str = number.format("%d");
        var len = str.length();
        var digitWidth = 9;  // 8px digit + 1px gap
        var minusWidth = isNegative ? 7 : 0;  // 6px minus + 1px gap
        var totalWidth = minusWidth + len * digitWidth - 1;
        var startX = centerX - totalWidth / 2;
        var startY = centerY - 5;  // Center vertically (10px tall / 2)

        // Draw minus sign if negative
        if (isNegative) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(startX, startY + 4, 6, 1);  // Horizontal minus
            startX = startX + minusWidth;
        }

        for (var i = 0; i < len; i++) {
            var ch = str.substring(i, i+1);
            var digit = ch.toNumber();
            drawMiniDigit(dc, startX + i * digitWidth, startY, digit, color);
        }
    }

    // Draw mini letter for day labels (9x11 pixels - 1 point bigger than before)
    private function drawMiniLetter(dc, x, y, letter, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        // 9x11 pixel letters
        if (letter.equals("M")) {
            dc.fillRectangle(x, y, 1, 11);     // left
            dc.fillRectangle(x+8, y, 1, 11);   // right
            dc.fillRectangle(x+1, y+1, 1, 2);  // left inner
            dc.fillRectangle(x+7, y+1, 1, 2);  // right inner
            dc.fillRectangle(x+2, y+2, 2, 1);  // left diagonal
            dc.fillRectangle(x+5, y+2, 2, 1);  // right diagonal
            dc.fillRectangle(x+3, y+3, 3, 1);  // center
        } else if (letter.equals("T")) {
            dc.fillRectangle(x, y, 9, 1);      // top
            dc.fillRectangle(x+4, y+1, 1, 10); // center (1px wide like other letters)
        } else if (letter.equals("W")) {
            dc.fillRectangle(x, y, 1, 11);     // left
            dc.fillRectangle(x+8, y, 1, 11);   // right
            dc.fillRectangle(x+4, y+5, 1, 5);  // center
            dc.fillRectangle(x+1, y+9, 3, 1);  // left inner
            dc.fillRectangle(x+5, y+9, 3, 1);  // right inner
        } else if (letter.equals("F")) {
            dc.fillRectangle(x, y, 9, 1);      // top
            dc.fillRectangle(x, y+1, 1, 10);   // left
            dc.fillRectangle(x+1, y+5, 5, 1);  // middle
        } else if (letter.equals("S")) {
            dc.fillRectangle(x+1, y, 7, 1);    // top
            dc.fillRectangle(x, y+1, 1, 4);    // left upper
            dc.fillRectangle(x+1, y+5, 7, 1);  // middle
            dc.fillRectangle(x+8, y+6, 1, 4);  // right lower
            dc.fillRectangle(x+1, y+10, 7, 1); // bottom
        } else if (letter.equals("U")) {
            dc.fillRectangle(x, y, 1, 10);     // left
            dc.fillRectangle(x+8, y, 1, 10);   // right
            dc.fillRectangle(x+1, y+10, 7, 1); // bottom
        } else if (letter.equals("O")) {
            dc.fillRectangle(x+1, y, 7, 1);    // top
            dc.fillRectangle(x, y+1, 1, 9);    // left
            dc.fillRectangle(x+8, y+1, 1, 9);  // right
            dc.fillRectangle(x+1, y+10, 7, 1); // bottom
        } else if (letter.equals("H")) {
            dc.fillRectangle(x, y, 1, 11);     // left
            dc.fillRectangle(x+8, y, 1, 11);   // right
            dc.fillRectangle(x+1, y+5, 7, 1);  // middle
        } else if (letter.equals("R")) {
            dc.fillRectangle(x, y, 1, 11);     // left
            dc.fillRectangle(x+1, y, 7, 1);    // top
            dc.fillRectangle(x+8, y+1, 1, 4);  // right upper
            dc.fillRectangle(x+1, y+5, 7, 1);  // middle
            dc.fillRectangle(x+5, y+6, 1, 2);  // diagonal upper
            dc.fillRectangle(x+6, y+8, 1, 1);  // diagonal mid
            dc.fillRectangle(x+7, y+9, 2, 2);  // diagonal lower
        } else if (letter.equals("A")) {
            dc.fillRectangle(x+3, y, 3, 1);    // top
            dc.fillRectangle(x+1, y+1, 2, 1);  // left upper
            dc.fillRectangle(x+6, y+1, 2, 1);  // right upper
            dc.fillRectangle(x, y+2, 1, 9);    // left
            dc.fillRectangle(x+8, y+2, 1, 9);  // right
            dc.fillRectangle(x+1, y+5, 7, 1);  // middle
        } else if (letter.equals("E")) {
            dc.fillRectangle(x, y, 9, 1);      // top
            dc.fillRectangle(x, y+1, 1, 9);    // left
            dc.fillRectangle(x+1, y+5, 5, 1);  // middle
            dc.fillRectangle(x, y+10, 9, 1);   // bottom
        }
    }

    // Draw mini text (multiple letters) centered at x,y
    private function drawMiniText(dc, centerX, y, text, color) {
        var len = text.length();
        var letterWidth = 10;  // 9px letter + 1px gap
        var totalWidth = len * letterWidth - 1;
        var startX = centerX - totalWidth / 2;

        for (var i = 0; i < len; i++) {
            var letter = text.substring(i, i+1);
            drawMiniLetter(dc, startX + i * letterWidth, y, letter, color);
        }
    }

    // Draw footprint icon for steps (9x10 pixels)
    private function drawStepsIcon(dc, x, y, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        // Left foot
        dc.fillRectangle(x, y+2, 2, 5);      // sole
        dc.fillRectangle(x+2, y+3, 1, 3);    // arch
        dc.fillRectangle(x, y, 2, 1);        // toe
        // Right foot (offset down and right)
        dc.fillRectangle(x+5, y+5, 2, 5);    // sole
        dc.fillRectangle(x+4, y+6, 1, 3);    // arch
        dc.fillRectangle(x+5, y+3, 2, 1);    // toe
    }

    // Draw stairs icon (9x10 pixels)
    private function drawStairsIcon(dc, x, y, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        // Three steps going up-right
        dc.fillRectangle(x, y+8, 3, 2);      // bottom step
        dc.fillRectangle(x+3, y+5, 3, 2);    // middle step
        dc.fillRectangle(x+6, y+2, 3, 2);    // top step
        // Risers (vertical parts)
        dc.fillRectangle(x+3, y+7, 1, 3);    // bottom riser
        dc.fillRectangle(x+6, y+4, 1, 3);    // middle riser
    }

    // Draw battery icon for body battery (9x10 pixels)
    private function drawBodyBatteryIcon(dc, x, y, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        // Battery outline
        dc.fillRectangle(x, y+1, 8, 1);      // top
        dc.fillRectangle(x, y+9, 8, 1);      // bottom
        dc.fillRectangle(x, y+2, 1, 7);      // left
        dc.fillRectangle(x+7, y+2, 1, 7);    // right
        // Positive terminal (bump on top)
        dc.fillRectangle(x+3, y, 3, 1);
        // Fill inside (shows it's charged)
        dc.fillRectangle(x+2, y+3, 4, 5);
    }

    private function drawRing(dc, x, y, radius, stroke, progress, color) {
        dc.setPenWidth(stroke);

        // Background ring - brightened from 0.25 to 0.35
        dc.setColor(Theme.dimColor(color, 0.35), Graphics.COLOR_TRANSPARENT);
        dc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, 90, -270);

        // Progress arc
        if (progress > 0.01) {
            var sweepDeg = (progress * 360).toNumber();
            if (sweepDeg > 360) { sweepDeg = 360; }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, 90, 90 - sweepDeg);
        }

        dc.setPenWidth(1);
    }

    private function drawAOD(dc) {
        var center = Theme.getCenter();
        var clockTime = System.getClockTime();
        var hour = clockTime.hour;
        var min = clockTime.min;

        if (!System.getDeviceSettings().is24Hour) {
            if (hour > 12) { hour = hour - 12; }
            if (hour == 0) { hour = 12; }
        }

        // Time (center)
        dc.setColor(Theme.AOD_TIME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, Theme.screenHeight / 2, Graphics.FONT_NUMBER_MILD,
            hour.format("%d") + ":" + min.format("%02d"),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Date (below time)
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dayNames = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
        dc.setColor(Theme.AOD_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, Theme.screenHeight / 2 + 45, Graphics.FONT_XTINY,
            dayNames[now.day_of_week - 1] + " " + now.day,
            Graphics.TEXT_JUSTIFY_CENTER);

        // Battery (top right, minimal)
        var battery = System.getSystemStats().battery.toNumber();
        dc.drawText(Theme.screenWidth - 20, 15, Graphics.FONT_XTINY,
            battery.format("%d") + "%",
            Graphics.TEXT_JUSTIFY_RIGHT);
    }
}

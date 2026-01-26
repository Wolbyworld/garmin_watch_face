using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Weather;
using Toybox.ActivityMonitor;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Math;

class WatchFaceView extends WatchUi.WatchFace {

    private var _isAwake = true;

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

    private function drawHeader(dc) {
        // Header - centered single column: temp on top, city below
        var y = 8;  // Moved up
        var center = Theme.getCenter();

        var tempStr = "18°";
        var locationStr = "Seattle";

        var conditions = Weather.getCurrentConditions();
        if (conditions != null) {
            if (conditions.temperature != null) {
                tempStr = conditions.temperature.format("%d") + "°";
            }
            if (conditions.observationLocationName != null) {
                locationStr = conditions.observationLocationName;
                if (locationStr.length() > 12) {
                    locationStr = locationStr.substring(0, 12);
                }
            }
        }

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

        // Generate fake weather data
        var seed = 54321;
        var temps = new [72];
        var hours = new [72];
        var precips = new [72];
        var clouds = new [72];
        var winds = new [72];

        var minTemp = 100.0;
        var maxTemp = -100.0;

        // Track daily highs/lows for temperature boxes
        var dayHighs = new [3];
        var dayLows = new [3];
        var dayHighIdx = new [3];
        var dayLowIdx = new [3];
        for (var d = 0; d < 3; d++) {
            dayHighs[d] = -100.0;
            dayLows[d] = 100.0;
            dayHighIdx[d] = 0;
            dayLowIdx[d] = 0;
        }

        for (var i = 0; i < 72; i++) {
            seed = ((seed * 9301 + 49297) % 233280);
            var rand = seed.toFloat() / 233280.0;

            var hour = (currentHour + i) % 24;
            hours[i] = hour;

            var hourFloat = (hour - 6).toFloat();
            var tempVariation = Math.sin(hourFloat * 3.14159 / 12.0) * 9.0;
            var temp = 18.0 + tempVariation + (rand - 0.5) * 2.0;
            temps[i] = temp;

            if (temp < minTemp) { minTemp = temp; }
            if (temp > maxTemp) { maxTemp = temp; }

            // Track daily extremes
            var dayIndex = (currentHour + i) / 24;
            if (dayIndex < 3) {
                if (temp > dayHighs[dayIndex]) {
                    dayHighs[dayIndex] = temp;
                    dayHighIdx[dayIndex] = i;
                }
                if (temp < dayLows[dayIndex]) {
                    dayLows[dayIndex] = temp;
                    dayLowIdx[dayIndex] = i;
                }
            }

            if ((i > 10 && i < 20) || (i > 42 && i < 52)) {
                precips[i] = (40 + rand * 40).toNumber();
            } else {
                precips[i] = 0;
            }

            if (precips[i] > 0) {
                clouds[i] = (75 + rand * 25).toNumber();
            } else if ((i > 5 && i < 15) || (i > 35 && i < 45)) {
                clouds[i] = (45 + rand * 35).toNumber();
            } else {
                clouds[i] = (10 + rand * 25).toNumber();
            }

            winds[i] = 10.0 + Math.sin(i.toFloat() * 0.25) * 7.0 + (rand - 0.5) * 5.0;
        }

        if (maxTemp <= minTemp) { maxTemp = minTemp + 10.0; }
        var tempRange = maxTemp - minTemp;
        if (tempRange < 8.0) { tempRange = 10.0; }

        // Day/night band at bottom of chart area
        var bandY = chartY + chartHeight - 5;
        var bandHeight = 6;
        for (var i = 0; i < chartWidth; i += 2) {
            var idx = (i * 72 / chartWidth);
            if (idx >= 72) { idx = 71; }
            dc.setColor(Theme.getSkyColor(hours[idx]), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(chartX + i, bandY, 2, bandHeight);
        }

        // Clouds at top (simple rectangles for now)
        for (var i = 0; i < 72; i += 5) {
            var c = clouds[i];
            if (c > 40) {
                var x = chartX + (i * chartWidth / 72);
                var opacity = (c - 40).toFloat() / 60.0;
                dc.setColor(Theme.dimColor(Theme.CLOUD_COLOR, opacity * 0.3), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, chartY, 20, 12);
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

        // Wind line (subtle)
        dc.setColor(Theme.dimColor(Theme.WIND_SPEED, 0.4), Graphics.COLOR_TRANSPARENT);
        prevX = -1;
        var prevWindY = -1;

        for (var i = 0; i < 72; i++) {
            var x = chartX + (i * chartWidth / 72);
            var norm = winds[i] / 30.0;
            if (norm > 1.0) { norm = 1.0; }
            var y = tempYStart + 2 + (tempHeight - 4) - (norm * (tempHeight - 4));

            if (prevX >= 0) {
                dc.drawLine(prevX, prevWindY, x, y.toNumber());
            }
            prevX = x;
            prevWindY = y.toNumber();
        }

        // Precipitation bars
        dc.setColor(Theme.PRECIPITATION, Graphics.COLOR_TRANSPARENT);
        var precipBaseY = chartY + chartHeight - 8;

        for (var i = 0; i < 72; i += 2) {
            if (precips[i] > 15) {
                var x = chartX + (i * chartWidth / 72);
                var h = (precips[i] * 14 / 100);
                if (h < 2) { h = 2; }
                dc.fillRectangle(x, precipBaseY - h, 3, h);
            }
        }

        // Day separators (dotted lines at midnight)
        var days = ["S", "M", "T", "W", "T", "F", "S"];  // Single letters
        var dayLabelY = chartY + chartHeight + 1;  // Closer to chart

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

        // Day labels BELOW the chart - using mini letters, very dim
        // Position labels at center of each day's span
        var hoursUntilMidnight = (24 - currentHour) % 24;
        if (hoursUntilMidnight == 0) { hoursUntilMidnight = 24; }

        var dimLabelColor = Theme.dimColor(Theme.TEXT_DIM, 0.6);

        // Today's label - center of remaining hours
        var todayCenter = hoursUntilMidnight / 2;
        var todayX = chartX + (todayCenter * chartWidth / 72);
        var todayIdx = (dayOfWeek - 1);
        if (todayIdx < 0) { todayIdx = 6; }
        drawMiniLetter(dc, todayX - 2, dayLabelY, days[todayIdx], dimLabelColor);

        // Tomorrow's label (day +1)
        var day1Start = hoursUntilMidnight;
        var day1Center = day1Start + 12;
        if (day1Center < 72) {
            var day1X = chartX + (day1Center * chartWidth / 72);
            var day1Idx = (dayOfWeek) % 7;
            drawMiniLetter(dc, day1X - 2, dayLabelY, days[day1Idx], dimLabelColor);
        }

        // Day +2 label
        var day2Start = hoursUntilMidnight + 24;
        var day2Center = day2Start + 12;
        if (day2Center < 72) {
            var day2X = chartX + (day2Center * chartWidth / 72);
            var day2Idx = (dayOfWeek + 1) % 7;
            drawMiniLetter(dc, day2X - 2, dayLabelY, days[day2Idx], dimLabelColor);
        }

        // Day +3 label (Thursday if today is Monday)
        var day3Start = hoursUntilMidnight + 48;
        var day3Center = day3Start + 12;
        if (day3Center < 72) {
            var day3X = chartX + (day3Center * chartWidth / 72);
            var day3Idx = (dayOfWeek + 2) % 7;
            drawMiniLetter(dc, day3X - 2, dayLabelY, days[day3Idx], dimLabelColor);
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
        var badgeH = 18;  // Taller to cover number
        var badgeX = startX + dateWidth + badgeGap;
        var badgeY = y + (fontH - badgeH) / 2;

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

        var stepProgress = 0.72;
        var actInfo = ActivityMonitor.getInfo();
        if (actInfo != null && actInfo.steps != null && actInfo.stepGoal != null) {
            if (actInfo.stepGoal > 0 && actInfo.steps > 0) {
                stepProgress = actInfo.steps.toFloat() / actInfo.stepGoal.toFloat();
                if (stepProgress > 1.0) { stepProgress = 1.0; }
            }
        }

        var timeFont = Graphics.FONT_NUMBER_HOT;
        var fontHeight = dc.getFontHeight(timeFont);

        var textTop = baseY - (fontHeight / 2);
        var textBottom = baseY + (fontHeight / 2);
        var fillPixels = (fontHeight * stepProgress).toNumber();
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
        var outerR = 32;   // Steps (outer)
        var middleR = 24;  // Floors (middle)
        var innerR = 16;   // Body Battery (inner)

        var currentSteps = 7700;
        var stepsProgress = 0.77;
        var currentFloors = 32;
        var floorsProgress = 0.80;
        var bodyBattery = 65;
        var bodyBatteryProgress = 0.65;
        var currentHR = 72;

        var actInfo = ActivityMonitor.getInfo();
        if (actInfo != null) {
            if (actInfo.steps != null && actInfo.steps > 0) {
                currentSteps = actInfo.steps;
                if (actInfo.stepGoal != null && actInfo.stepGoal > 0) {
                    stepsProgress = currentSteps.toFloat() / actInfo.stepGoal.toFloat();
                    if (stepsProgress > 1.0) { stepsProgress = 1.0; }
                }
            }
            if (actInfo.floorsClimbed != null && actInfo.floorsClimbed > 0) {
                currentFloors = actInfo.floorsClimbed;
                if (actInfo.floorsClimbedGoal != null && actInfo.floorsClimbedGoal > 0) {
                    floorsProgress = currentFloors.toFloat() / actInfo.floorsClimbedGoal.toFloat();
                    if (floorsProgress > 1.0) { floorsProgress = 1.0; }
                }
            }
        }

        // Draw rings: Steps (outer), Floors (middle), Body Battery (inner)
        drawRing(dc, ringsX, ringsY, outerR, stroke, stepsProgress, Theme.STEPS_RING);
        drawRing(dc, ringsX, ringsY, middleR, stroke, floorsProgress, Theme.FLOORS_RING);
        drawRing(dc, ringsX, ringsY, innerR, stroke, bodyBatteryProgress, Theme.BODY_BATTERY_RING);

        // Tiny HR in center of rings - using mini-digits (no heart icon)
        drawMiniNumber(dc, ringsX, ringsY, currentHR, Theme.HR_RING);

        // Steps count below rings - show full number with more gap
        drawMiniNumber(dc, ringsX, ringsY + outerR + 14, currentSteps, Theme.STEPS_RING);

        // === RIGHT SIDE: Secondary Timezone ===
        var tzX = center + 75;
        var tzY = ringsY - 12;

        // Calculate UTC time (or configurable secondary timezone)
        var clockTime = System.getClockTime();
        var utcOffset = clockTime.timeZoneOffset / 3600;
        var utcHour = (clockTime.hour - utcOffset + 24) % 24;
        var utcMin = clockTime.min;

        // Time with normal smallest font
        dc.setColor(Theme.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tzX, tzY, Graphics.FONT_XTINY, utcHour.format("%02d") + ":" + utcMin.format("%02d"), Graphics.TEXT_JUSTIFY_CENTER);

        // UTC label below with more spacing
        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tzX, tzY + 26, Graphics.FONT_XTINY, "UTC", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Mini-digit renderer: draws 6x8 pixel digits
    private function drawMiniDigit(dc, x, y, digit, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        // Each digit is 6px wide, 8px tall
        if (digit == 0) {
            dc.fillRectangle(x+1, y, 4, 1);    // top
            dc.fillRectangle(x+1, y+7, 4, 1);  // bottom
            dc.fillRectangle(x, y+1, 1, 6);    // left
            dc.fillRectangle(x+5, y+1, 1, 6);  // right
        } else if (digit == 1) {
            dc.fillRectangle(x+3, y, 1, 8);    // center vertical
            dc.fillRectangle(x+2, y+1, 1, 1);  // top left tick
        } else if (digit == 2) {
            dc.fillRectangle(x, y, 6, 1);      // top
            dc.fillRectangle(x+5, y+1, 1, 2);  // right upper
            dc.fillRectangle(x+1, y+3, 4, 1);  // middle
            dc.fillRectangle(x, y+4, 1, 3);    // left lower
            dc.fillRectangle(x, y+7, 6, 1);    // bottom
        } else if (digit == 3) {
            dc.fillRectangle(x, y, 6, 1);      // top
            dc.fillRectangle(x+5, y+1, 1, 6);  // right
            dc.fillRectangle(x+1, y+3, 4, 1);  // middle
            dc.fillRectangle(x, y+7, 6, 1);    // bottom
        } else if (digit == 4) {
            dc.fillRectangle(x, y, 1, 4);      // left upper
            dc.fillRectangle(x, y+3, 6, 1);    // middle
            dc.fillRectangle(x+5, y, 1, 8);    // right
        } else if (digit == 5) {
            dc.fillRectangle(x, y, 6, 1);      // top
            dc.fillRectangle(x, y+1, 1, 2);    // left upper
            dc.fillRectangle(x, y+3, 6, 1);    // middle
            dc.fillRectangle(x+5, y+4, 1, 3);  // right lower
            dc.fillRectangle(x, y+7, 6, 1);    // bottom
        } else if (digit == 6) {
            dc.fillRectangle(x+1, y, 5, 1);    // top
            dc.fillRectangle(x, y+1, 1, 6);    // left
            dc.fillRectangle(x+1, y+3, 5, 1);  // middle
            dc.fillRectangle(x+5, y+4, 1, 3);  // right lower
            dc.fillRectangle(x+1, y+7, 4, 1);  // bottom
        } else if (digit == 7) {
            dc.fillRectangle(x, y, 6, 1);      // top
            dc.fillRectangle(x+5, y+1, 1, 7);  // right
        } else if (digit == 8) {
            dc.fillRectangle(x+1, y, 4, 1);    // top
            dc.fillRectangle(x+1, y+3, 4, 1);  // middle
            dc.fillRectangle(x+1, y+7, 4, 1);  // bottom
            dc.fillRectangle(x, y+1, 1, 6);    // left
            dc.fillRectangle(x+5, y+1, 1, 6);  // right
        } else if (digit == 9) {
            dc.fillRectangle(x+1, y, 4, 1);    // top
            dc.fillRectangle(x, y+1, 1, 2);    // left upper
            dc.fillRectangle(x+1, y+3, 5, 1);  // middle
            dc.fillRectangle(x+5, y+1, 1, 6);  // right
            dc.fillRectangle(x, y+7, 5, 1);    // bottom
        }
    }

    // Draw a mini number (multiple digits) centered at x,y - supports negative
    private function drawMiniNumber(dc, centerX, centerY, number, color) {
        var isNegative = number < 0;
        if (isNegative) { number = -number; }

        var str = number.format("%d");
        var len = str.length();
        var digitWidth = 7;  // 6px digit + 1px gap
        var minusWidth = isNegative ? 5 : 0;  // 4px minus + 1px gap
        var totalWidth = minusWidth + len * digitWidth - 1;
        var startX = centerX - totalWidth / 2;
        var startY = centerY - 4;  // Center vertically (8px tall / 2)

        // Draw minus sign if negative
        if (isNegative) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(startX, startY + 3, 4, 1);  // Horizontal minus
            startX = startX + minusWidth;
        }

        for (var i = 0; i < len; i++) {
            var ch = str.substring(i, i+1);
            var digit = ch.toNumber();
            drawMiniDigit(dc, startX + i * digitWidth, startY, digit, color);
        }
    }

    // Draw mini letter for day labels (6x8 pixels)
    private function drawMiniLetter(dc, x, y, letter, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        // 6x8 pixel letters
        if (letter.equals("M")) {
            dc.fillRectangle(x, y, 1, 8);      // left
            dc.fillRectangle(x+5, y, 1, 8);    // right
            dc.fillRectangle(x+1, y+1, 1, 2);  // left inner
            dc.fillRectangle(x+4, y+1, 1, 2);  // right inner
            dc.fillRectangle(x+2, y+2, 2, 1);  // center
        } else if (letter.equals("T")) {
            dc.fillRectangle(x, y, 6, 1);      // top
            dc.fillRectangle(x+2, y+1, 2, 7);  // center
        } else if (letter.equals("W")) {
            dc.fillRectangle(x, y, 1, 8);      // left
            dc.fillRectangle(x+5, y, 1, 8);    // right
            dc.fillRectangle(x+2, y+5, 2, 2);  // center
            dc.fillRectangle(x+1, y+6, 1, 1);  // left inner
            dc.fillRectangle(x+4, y+6, 1, 1);  // right inner
        } else if (letter.equals("F")) {
            dc.fillRectangle(x, y, 6, 1);      // top
            dc.fillRectangle(x, y+1, 1, 7);    // left
            dc.fillRectangle(x+1, y+3, 4, 1);  // middle
        } else if (letter.equals("S")) {
            dc.fillRectangle(x+1, y, 5, 1);    // top
            dc.fillRectangle(x, y+1, 1, 2);    // left upper
            dc.fillRectangle(x+1, y+3, 4, 1);  // middle
            dc.fillRectangle(x+5, y+4, 1, 3);  // right lower
            dc.fillRectangle(x, y+7, 5, 1);    // bottom
        } else if (letter.equals("U")) {
            dc.fillRectangle(x, y, 1, 7);      // left
            dc.fillRectangle(x+5, y, 1, 7);    // right
            dc.fillRectangle(x+1, y+7, 4, 1);  // bottom
        } else if (letter.equals("C")) {
            dc.fillRectangle(x+1, y, 5, 1);    // top
            dc.fillRectangle(x, y+1, 1, 6);    // left
            dc.fillRectangle(x+1, y+7, 5, 1);  // bottom
        }
    }

    private function drawRing(dc, x, y, radius, stroke, progress, color) {
        dc.setPenWidth(stroke);

        dc.setColor(Theme.dimColor(color, 0.25), Graphics.COLOR_TRANSPARENT);
        dc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, 90, -270);

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

        dc.setColor(Theme.AOD_TIME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, Theme.screenHeight / 2, Graphics.FONT_NUMBER_MILD,
            hour.format("%d") + ":" + min.format("%02d"),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

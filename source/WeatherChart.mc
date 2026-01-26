using Toybox.Graphics;
using Toybox.Weather;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;

// Renders the weather forecast chart with multiple layers:
// 1. Day/night gradient band
// 2. Cloud cover (soft circles)
// 3. Temperature curve (smoothed)
// 4. Wind speed line
// 5. Precipitation bars
// 6. Time markers
// 7. "Now" indicator
class WeatherChart {

    // Chart bounds
    private var _chartX as Number;
    private var _chartY as Number;
    private var _chartWidth as Number;
    private var _chartHeight as Number;

    // Cached temperature range for scaling
    private var _minTemp as Float = 0.0;
    private var _maxTemp as Float = 30.0;
    private var _maxWind as Float = 25.0;

    function initialize() {
        _chartX = Theme.SAFE_ZONE_START + 5;
        _chartY = Theme.CHART_Y;
        _chartWidth = Theme.CHART_WIDTH;
        _chartHeight = Theme.CHART_HEIGHT;
    }

    function draw(dc as Dc, forecast as Array?) as Void {
        if (forecast == null || forecast.size() == 0) {
            drawNoDataMessage(dc);
            return;
        }

        // Calculate temperature range for scaling
        calculateRanges(forecast);

        // Draw layers in order (back to front)
        drawDayNightBand(dc, forecast);
        drawClouds(dc, forecast);
        drawTemperatureCurve(dc, forecast);
        drawWindLine(dc, forecast);
        drawPrecipitation(dc, forecast);
        drawTimeMarkers(dc, forecast);
        drawNowIndicator(dc);
    }

    // Calculate min/max ranges for scaling
    private function calculateRanges(forecast as Array) as Void {
        _minTemp = 100.0;
        _maxTemp = -100.0;
        _maxWind = 0.0;

        var count = forecast.size() > 72 ? 72 : forecast.size();
        for (var i = 0; i < count; i++) {
            var hourly = forecast[i] as Weather.HourlyForecast;
            if (hourly != null) {
                if (hourly.temperature != null) {
                    var temp = hourly.temperature.toFloat();
                    if (temp < _minTemp) { _minTemp = temp; }
                    if (temp > _maxTemp) { _maxTemp = temp; }
                }
                if (hourly.windSpeed != null) {
                    var wind = hourly.windSpeed.toFloat();
                    if (wind > _maxWind) { _maxWind = wind; }
                }
            }
        }

        // Ensure minimum range
        if (_maxTemp - _minTemp < 10) {
            _maxTemp = _minTemp + 10;
        }
        if (_maxWind < 25) {
            _maxWind = 25.0;
        }
    }

    // Layer 1: Day/night gradient band at bottom of chart
    private function drawDayNightBand(dc as Dc, forecast as Array) as Void {
        var bandY = _chartY + _chartHeight - 6;
        var bandHeight = 6;
        var count = forecast.size() > 72 ? 72 : forecast.size();

        for (var i = 0; i < _chartWidth; i++) {
            var dataIndex = (i * count / _chartWidth).toNumber();
            if (dataIndex >= count) { dataIndex = count - 1; }

            var hourly = forecast[dataIndex] as Weather.HourlyForecast;
            var hour = 12;  // default to noon if no time

            if (hourly != null && hourly.forecastTime != null) {
                var info = Gregorian.info(hourly.forecastTime, Time.FORMAT_SHORT);
                hour = info.hour;
            }

            // Calculate day/night intensity
            var color = Theme.getSkyColor(hour);
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(_chartX + i, bandY, _chartX + i, bandY + bandHeight);
        }
    }

    // Layer 2: Cloud cover as soft circles
    private function drawClouds(dc as Dc, forecast as Array) as Void {
        var cloudY = _chartY + 8;
        var count = forecast.size() > 72 ? 72 : forecast.size();

        // Find cloud segments (consecutive hours with >40% clouds)
        var inSegment = false;
        var segmentStart = 0;
        var maxCloudCover = 0;

        for (var i = 0; i <= count; i++) {
            var cloudCover = 0;
            if (i < count) {
                var hourly = forecast[i] as Weather.HourlyForecast;
                if (hourly != null && hourly.cloudCover != null) {
                    cloudCover = hourly.cloudCover;
                }
            }

            if (cloudCover > 40 && !inSegment) {
                // Start new segment
                inSegment = true;
                segmentStart = i;
                maxCloudCover = cloudCover;
            } else if (cloudCover > 40 && inSegment) {
                // Continue segment
                if (cloudCover > maxCloudCover) {
                    maxCloudCover = cloudCover;
                }
            } else if ((cloudCover <= 40 || i == count) && inSegment) {
                // End segment - draw cloud
                inSegment = false;
                drawCloudSegment(dc, segmentStart, i, maxCloudCover, cloudY, count);
            }
        }
    }

    // Draw a cloud segment as overlapping circles
    private function drawCloudSegment(dc as Dc, startIdx as Number, endIdx as Number, cloudCover as Number, cloudY as Number, totalCount as Number) as Void {
        var startX = _chartX + (startIdx * _chartWidth / totalCount);
        var endX = _chartX + (endIdx * _chartWidth / totalCount);
        var segmentWidth = endX - startX;

        if (segmentWidth < 10) { return; }

        // Calculate opacity based on cloud cover (40-100% -> 20-50% alpha)
        var alpha = ((cloudCover - 40) * 0.5 / 60 + 0.2);

        // Draw multiple circles
        var numCircles = (segmentWidth / 15).toNumber();
        if (numCircles < 3) { numCircles = 3; }

        // Deterministic "random" positions based on startIdx
        var seed = startIdx * 127;

        for (var j = 0; j < numCircles; j++) {
            seed = (seed * 9301 + 49297) % 233280;
            var rand1 = seed.toFloat() / 233280.0;
            seed = (seed * 9301 + 49297) % 233280;
            var rand2 = seed.toFloat() / 233280.0;

            var cx = startX + (j.toFloat() / (numCircles - 1).toFloat()) * segmentWidth + (rand1 - 0.5) * 15;
            var cy = cloudY + (rand2 - 0.5) * 6;
            var radius = 6 + rand1 * 8;

            // Draw circle with alpha (use dimmed white)
            var cloudColor = Theme.dimColor(Theme.CLOUD_COLOR, alpha);
            dc.setColor(cloudColor, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx.toNumber(), cy.toNumber(), radius.toNumber());
        }
    }

    // Layer 3: Temperature curve with smoothing
    private function drawTemperatureCurve(dc as Dc, forecast as Array) as Void {
        var tempY = _chartY + 22;
        var tempHeight = 45;
        var count = forecast.size() > 72 ? 72 : forecast.size();
        var tempRange = _maxTemp - _minTemp;

        // Build points array
        var points = new [count];
        for (var i = 0; i < count; i++) {
            var hourly = forecast[i] as Weather.HourlyForecast;
            var temp = (_minTemp + _maxTemp) / 2;  // default to middle
            if (hourly != null && hourly.temperature != null) {
                temp = hourly.temperature.toFloat();
            }

            var x = _chartX + (i * _chartWidth / count);
            var normalizedTemp = (temp - _minTemp) / tempRange;
            var y = tempY + tempHeight - (normalizedTemp * tempHeight);
            points[i] = [x, y];
        }

        // Draw filled area under curve
        dc.setColor(Theme.dimColor(Theme.TEMP_CURVE, 0.15), Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < count - 1; i++) {
            var x1 = points[i][0];
            var y1 = points[i][1];
            var x2 = points[i + 1][0];
            var y2 = points[i + 1][1];
            var baseY = tempY + tempHeight;

            // Draw vertical fill lines
            for (var x = x1; x <= x2; x++) {
                var t = (x2 > x1) ? (x - x1).toFloat() / (x2 - x1).toFloat() : 0;
                var y = y1 + (y2 - y1) * t;
                dc.drawLine(x, y.toNumber(), x, baseY);
            }
        }

        // Draw temperature line with smoothing
        dc.setColor(Theme.TEMP_CURVE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);

        for (var i = 0; i < count - 1; i++) {
            // Catmull-Rom interpolation for smoothing
            var p0 = points[i > 0 ? i - 1 : 0];
            var p1 = points[i];
            var p2 = points[i + 1];
            var p3 = points[i < count - 2 ? i + 2 : count - 1];

            // Draw 5 segments between each point
            var prevX = p1[0];
            var prevY = p1[1];
            for (var t = 0.2; t <= 1.0; t += 0.2) {
                var x = catmullRom(p0[0], p1[0], p2[0], p3[0], t);
                var y = catmullRom(p0[1], p1[1], p2[1], p3[1], t);
                dc.drawLine(prevX, prevY.toNumber(), x.toNumber(), y.toNumber());
                prevX = x.toNumber();
                prevY = y.toNumber();
            }
        }
        dc.setPenWidth(1);

        // Draw temperature labels at peaks/valleys
        drawTempLabels(dc, points, count, tempRange);
    }

    // Catmull-Rom spline interpolation
    private function catmullRom(p0 as Float, p1 as Float, p2 as Float, p3 as Float, t as Float) as Float {
        var t2 = t * t;
        var t3 = t2 * t;
        return 0.5 * (
            (2 * p1) +
            (-p0 + p2) * t +
            (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
            (-p0 + 3 * p1 - 3 * p2 + p3) * t3
        );
    }

    // Draw temperature labels at peaks and valleys
    private function drawTempLabels(dc as Dc, points as Array, count as Number, tempRange as Float) as Void {
        dc.setColor(Theme.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        var lastLabelX = -50;

        for (var i = 2; i < count - 2; i++) {
            var prev = points[i - 1][1];
            var curr = points[i][1];
            var next = points[i + 1][1];

            // Check if this is a peak or valley
            if ((curr < prev && curr < next) || (curr > prev && curr > next)) {
                var x = points[i][0];
                if (x - lastLabelX > 50) {
                    // Calculate actual temperature from Y position
                    var normalizedTemp = 1.0 - (curr - (_chartY + 22)).toFloat() / 45.0;
                    var temp = _minTemp + normalizedTemp * tempRange;

                    dc.drawText(x, curr.toNumber() - 8, Graphics.FONT_XTINY, temp.format("%d") + "°", Graphics.TEXT_JUSTIFY_CENTER);
                    lastLabelX = x;
                }
            }
        }
    }

    // Layer 4: Wind speed line
    private function drawWindLine(dc as Dc, forecast as Array) as Void {
        var windY = _chartY + 28;
        var windHeight = 35;
        var count = forecast.size() > 72 ? 72 : forecast.size();

        dc.setColor(Theme.dimColor(Theme.WIND_SPEED, 0.6), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);

        var prevX = -1;
        var prevY = -1;

        for (var i = 0; i < count; i++) {
            var hourly = forecast[i] as Weather.HourlyForecast;
            var wind = 0.0;
            if (hourly != null && hourly.windSpeed != null) {
                wind = hourly.windSpeed.toFloat();
            }

            var x = _chartX + (i * _chartWidth / count);
            var normalizedWind = wind / _maxWind;
            var y = windY + windHeight - (normalizedWind * windHeight);

            if (prevX >= 0) {
                dc.drawLine(prevX, prevY, x, y.toNumber());
            }
            prevX = x;
            prevY = y.toNumber();
        }
    }

    // Layer 5: Precipitation bars
    private function drawPrecipitation(dc as Dc, forecast as Array) as Void {
        var precipY = _chartY + _chartHeight - 35;
        var precipMaxHeight = 25;
        var count = forecast.size() > 72 ? 72 : forecast.size();

        dc.setColor(Theme.PRECIPITATION, Graphics.COLOR_TRANSPARENT);

        for (var i = 0; i < count; i++) {
            var hourly = forecast[i] as Weather.HourlyForecast;
            var precip = 0;
            if (hourly != null && hourly.precipitationChance != null) {
                precip = hourly.precipitationChance;
            }

            if (precip > 10) {
                var x = _chartX + (i * _chartWidth / count);
                var barHeight = (precip.toFloat() / 100.0 * precipMaxHeight).toNumber();
                dc.fillRectangle(x, precipY + precipMaxHeight - barHeight, 3, barHeight);
            }
        }
    }

    // Layer 6: Time markers and day separators
    private function drawTimeMarkers(dc as Dc, forecast as Array) as Void {
        var count = forecast.size() > 72 ? 72 : forecast.size();
        var dayNames = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];

        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);

        for (var i = 0; i < count; i += 6) {
            var hourly = forecast[i] as Weather.HourlyForecast;
            var hour = 0;
            var dayOfWeek = 0;

            if (hourly != null && hourly.forecastTime != null) {
                var info = Gregorian.info(hourly.forecastTime, Time.FORMAT_SHORT);
                hour = info.hour;
                dayOfWeek = info.day_of_week - 1;  // 0-indexed
            }

            var x = _chartX + (i * _chartWidth / count);
            var markerY = _chartY + _chartHeight - 1;

            if (hour == 0 && i > 0) {
                // Day separator - dashed line
                dc.setPenWidth(1);
                for (var dy = _chartY + 3; dy < _chartY + _chartHeight - 10; dy += 4) {
                    dc.drawLine(x, dy, x, dy + 2);
                }

                // Day name
                dc.setColor(Theme.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(x, markerY, Graphics.FONT_XTINY, dayNames[dayOfWeek], Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
            } else if (i > 0) {
                // Hour marker
                dc.drawText(x, markerY, Graphics.FONT_XTINY, hour.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    // Layer 7: "Now" indicator
    private function drawNowIndicator(dc as Dc) as Void {
        dc.setColor(Theme.NOW_LINE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(_chartX, _chartY, _chartX, _chartY + _chartHeight);
        dc.setPenWidth(1);

        // Triangle at top
        dc.fillPolygon([
            [_chartX, _chartY],
            [_chartX - 4, _chartY - 5],
            [_chartX + 4, _chartY - 5]
        ]);
    }

    // Show message when no weather data
    private function drawNoDataMessage(dc as Dc) as Void {
        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER, _chartY + _chartHeight / 2, Graphics.FONT_TINY,
            "Weather data unavailable", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

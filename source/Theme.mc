using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;

module Theme {
    // Colors - brightened for better visibility
    const BG = 0x000000;
    const TIME_PRIMARY = 0xFFFFFF;
    const TIME_UNFILLED = 0x606060;  // Brightened more for visibility
    const TIME_FILL = 0x26A69A;
    const TEXT_PRIMARY = 0xC8C8C8;   // Brightened from 0xB0B0B0
    const TEXT_SECONDARY = 0x909090; // Brightened from 0x707070
    const TEXT_DIM = 0x606060;       // Brightened from 0x454545
    const TEMP_CURVE = 0xFFB347;
    const PRECIPITATION = 0x4DD0E1;
    const WIND_SPEED = 0xEF5350;
    const CLOUD_COLOR = 0xFFFFFF;
    const NIGHT_SKY = 0x0D1E30;      // Slightly brightened
    const DAY_SKY = 0x2A5F80;
    const HR_RING = 0xE57373;
    const STEPS_RING = 0x26A69A;
    const FLOORS_RING = 0xFFD54F;  // Gold/yellow for better distinction
    const BODY_BATTERY_RING = 0x42A5F5;  // Brighter blue for body battery
    const WEEK_BADGE = 0xFF8A65;
    const NOW_LINE = 0xFFFFFF;
    const AOD_TIME = 0x707070;  // Brightened for readability
    const AOD_TEXT = 0x505050;  // Brightened for readability

    // Dynamic layout - call these with dc to get positions
    var screenWidth = 454;
    var screenHeight = 454;
    var isInitialized = false;

    function initLayout(dc) {
        if (!isInitialized) {
            screenWidth = dc.getWidth();
            screenHeight = dc.getHeight();
            isInitialized = true;
        }
    }

    function getCenter() {
        return screenWidth / 2;
    }

    function getSafeMargin() {
        return (screenWidth * 0.088).toNumber(); // ~40px on 454
    }

    function getHeaderY() {
        return (screenHeight * 0.07).toNumber(); // ~32px on 454
    }

    function getChartY() {
        return (screenHeight * 0.11).toNumber(); // ~50px on 454
    }

    function getChartHeight() {
        return (screenHeight * 0.25).toNumber(); // ~115px on 454
    }

    function getChartWidth() {
        return screenWidth - (getSafeMargin() * 2) - 10;
    }

    function getDateY() {
        return (screenHeight * 0.43).toNumber(); // ~195px on 454
    }

    function getTimeY() {
        return (screenHeight * 0.66).toNumber(); // ~300px on 454
    }

    function getRingsY() {
        return (screenHeight * 0.81).toNumber(); // ~368px on 454
    }

    function getRingOuterRadius() {
        return (screenWidth * 0.07).toNumber(); // ~32px on 454
    }

    function getRingMiddleRadius() {
        return (screenWidth * 0.053).toNumber(); // ~24px on 454
    }

    function getRingInnerRadius() {
        return (screenWidth * 0.035).toNumber(); // ~16px on 454
    }

    function getRingStroke() {
        return (screenWidth * 0.013).toNumber(); // ~6px on 454
    }

    function getSkyColor(hour) {
        var intensity = 0.0;
        if (hour >= 6 && hour < 20) {
            var dayProgress = (hour - 6).toFloat() / 14.0;
            intensity = Math.sin(dayProgress * Math.PI);
        }
        return lerpColor(NIGHT_SKY, DAY_SKY, intensity);
    }

    function lerpColor(c1, c2, t) {
        var r1 = (c1 >> 16) & 0xFF;
        var g1 = (c1 >> 8) & 0xFF;
        var b1 = c1 & 0xFF;
        var r2 = (c2 >> 16) & 0xFF;
        var g2 = (c2 >> 8) & 0xFF;
        var b2 = c2 & 0xFF;
        var r = (r1 + (r2 - r1) * t).toNumber();
        var g = (g1 + (g2 - g1) * t).toNumber();
        var b = (b1 + (b2 - b1) * t).toNumber();
        return (r << 16) | (g << 8) | b;
    }

    function dimColor(color, factor) {
        var r = ((color >> 16) & 0xFF) * factor;
        var g = ((color >> 8) & 0xFF) * factor;
        var b = (color & 0xFF) * factor;
        return (r.toNumber() << 16) | (g.toNumber() << 8) | b.toNumber();
    }
}

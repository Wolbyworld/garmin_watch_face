using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;

module Theme {
    // Mutable theme colors - can be changed by applyTheme()
    var BG = 0x000000;
    var TIME_PRIMARY = 0xFFFFFF;
    var TIME_UNFILLED = 0x606060;
    var TIME_FILL = 0x26A69A;
    var TEXT_PRIMARY = 0xC8C8C8;
    var TEXT_SECONDARY = 0x909090;
    var TEXT_DIM = 0x606060;
    var TEMP_CURVE = 0xFFB347;
    var PRECIPITATION = 0x4DD0E1;
    var WIND_SPEED = 0xEF5350;
    var CLOUD_COLOR = 0xFFFFFF;
    var NIGHT_SKY = 0x0D1E30;
    var DAY_SKY = 0x2A5F80;
    var HR_RING = 0xE57373;
    var STEPS_RING = 0x26A69A;
    var FLOORS_RING = 0xFFD54F;
    var BODY_BATTERY_RING = 0x42A5F5;
    var WEEK_BADGE = 0xFF8A65;
    var NOW_LINE = 0xFFFFFF;
    var AOD_TIME = 0x707070;
    var AOD_TEXT = 0x505050;

    // Theme presets: [Dark, Warm, Cool, HighContrast]
    // Each array has 4 values for the 4 themes
    const THEME_TIME_PRIMARY = [0xFFFFFF, 0xFFF8E1, 0xE3F2FD, 0xFFFFFF];
    const THEME_TEXT_PRIMARY = [0xC8C8C8, 0xD7CCC8, 0xB0BEC5, 0xFFFFFF];
    const THEME_TEXT_SECONDARY = [0x909090, 0xA1887F, 0x78909C, 0xCCCCCC];
    const THEME_TEXT_DIM = [0x606060, 0x6D4C41, 0x546E7A, 0x999999];
    const THEME_TEMP_CURVE = [0xFFB347, 0xFFCC80, 0x81D4FA, 0xFF5722];
    const THEME_PRECIPITATION = [0x4DD0E1, 0x80CBC4, 0x4FC3F7, 0x00BCD4];
    const THEME_WIND_SPEED = [0xEF5350, 0xFFAB91, 0x90CAF9, 0xFF5252];
    const THEME_NIGHT_SKY = [0x0D1E30, 0x1A1410, 0x0D1B2A, 0x000000];
    const THEME_DAY_SKY = [0x2A5F80, 0x4E342E, 0x1E3A5F, 0x333333];
    const THEME_WEEK_BADGE = [0xFF8A65, 0xFFAB91, 0x64B5F6, 0xFF6D00];

    // Accent colors: [Teal, Orange, Blue, Purple, Red]
    const ACCENT_COLORS = [0x26A69A, 0xFF8A65, 0x42A5F5, 0xAB47BC, 0xEF5350];

    // Time colors: [White, WarmWhite, CoolWhite]
    const TIME_COLORS = [0xFFFFFF, 0xFFF8E1, 0xE3F2FD];

    // Dynamic layout - call these with dc to get positions
    var screenWidth = 454;
    var screenHeight = 454;
    var isInitialized = false;

    // MIP display detection (Fenix 6S is 240x240, AMOLED are 390+)
    var isMIPDisplay = false;

    function initLayout(dc) {
        if (!isInitialized) {
            screenWidth = dc.getWidth();
            screenHeight = dc.getHeight();
            // MIP displays are 240x240 or 260x260, AMOLED are 390+ pixels
            isMIPDisplay = (screenWidth < 300);
            isInitialized = true;
        }
    }

    // Map a 24-bit color to nearest MIP 64-color palette color
    // MIP displays only support 6 levels per channel: 0x00, 0x55, 0xAA, 0xFF
    function mapToMIPPalette(color) {
        var r = (color >> 16) & 0xFF;
        var g = (color >> 8) & 0xFF;
        var b = color & 0xFF;

        // Quantize each channel to nearest of: 0x00, 0x55, 0xAA, 0xFF
        r = quantizeChannel(r);
        g = quantizeChannel(g);
        b = quantizeChannel(b);

        return (r << 16) | (g << 8) | b;
    }

    // Quantize a single channel (0-255) to MIP palette level
    function quantizeChannel(value) {
        // Thresholds: 0-42 -> 0x00, 43-127 -> 0x55, 128-212 -> 0xAA, 213-255 -> 0xFF
        if (value < 43) { return 0x00; }
        if (value < 128) { return 0x55; }
        if (value < 213) { return 0xAA; }
        return 0xFF;
    }

    // Get a color, mapped to MIP palette if on MIP display
    function getColor(color) {
        if (isMIPDisplay) {
            return mapToMIPPalette(color);
        }
        return color;
    }

    // Dim color for MIP - returns palette-safe dimmed color
    function dimColorMIP(color, factor) {
        var dimmed = dimColor(color, factor);
        return mapToMIPPalette(dimmed);
    }

    // Apply theme based on settings
    // themeIdx: 0=Dark, 1=Warm, 2=Cool, 3=HighContrast
    // accentIdx: 0=Teal, 1=Orange, 2=Blue, 3=Purple, 4=Red
    // timeIdx: 0=White, 1=WarmWhite, 2=CoolWhite
    function applyTheme(themeIdx, accentIdx, timeIdx) {
        // Validate indices
        if (themeIdx < 0 || themeIdx > 3) { themeIdx = 0; }
        if (accentIdx < 0 || accentIdx > 4) { accentIdx = 0; }
        if (timeIdx < 0 || timeIdx > 2) { timeIdx = 0; }

        // Apply theme colors
        TIME_PRIMARY = TIME_COLORS[timeIdx];
        TEXT_PRIMARY = THEME_TEXT_PRIMARY[themeIdx];
        TEXT_SECONDARY = THEME_TEXT_SECONDARY[themeIdx];
        TEXT_DIM = THEME_TEXT_DIM[themeIdx];
        TEMP_CURVE = THEME_TEMP_CURVE[themeIdx];
        PRECIPITATION = THEME_PRECIPITATION[themeIdx];
        WIND_SPEED = THEME_WIND_SPEED[themeIdx];
        NIGHT_SKY = THEME_NIGHT_SKY[themeIdx];
        DAY_SKY = THEME_DAY_SKY[themeIdx];
        WEEK_BADGE = THEME_WEEK_BADGE[themeIdx];

        // Apply accent color for time fill and steps ring
        TIME_FILL = ACCENT_COLORS[accentIdx];
        STEPS_RING = ACCENT_COLORS[accentIdx];

        // TIME_UNFILLED should be a dim version of TIME_PRIMARY
        TIME_UNFILLED = dimColor(TIME_PRIMARY, 0.35);

        // AOD colors are always conservative
        AOD_TIME = dimColor(TIME_PRIMARY, 0.45);
        AOD_TEXT = dimColor(TEXT_PRIMARY, 0.35);
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

    // MIP-specific layout helpers
    function getWorldClocksY() {
        if (isMIPDisplay) {
            // Centered at bottom for MIP
            return (screenHeight * 0.82).toNumber();
        }
        return getRingsY();  // Same as rings Y on AMOLED
    }

    function getStatsRowY() {
        // Bottom row for HR + battery on MIP
        return (screenHeight * 0.92).toNumber();
    }

    function getChartHeightMIP() {
        // Smaller chart for MIP display
        return (screenHeight * 0.17).toNumber();  // ~40px on 240
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

    // Brighten a color (factor > 1.0 makes it brighter, capped at 255)
    function brightenColor(color, factor) {
        var r = ((color >> 16) & 0xFF) * factor;
        var g = ((color >> 8) & 0xFF) * factor;
        var b = (color & 0xFF) * factor;
        if (r > 255) { r = 255; }
        if (g > 255) { g = 255; }
        if (b > 255) { b = 255; }
        return (r.toNumber() << 16) | (g.toNumber() << 8) | b.toNumber();
    }

    // Get ring color for a data type
    // dataType: 0=Steps, 1=Floors, 2=BodyBatt, 3=HR
    function getRingColor(dataType) {
        switch (dataType) {
            case 0: return STEPS_RING;
            case 1: return FLOORS_RING;
            case 2: return BODY_BATTERY_RING;
            case 3: return HR_RING;
            default: return STEPS_RING;
        }
    }
}

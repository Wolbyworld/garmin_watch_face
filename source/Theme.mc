using Toybox.Graphics;

// Theme module containing all colors, positions, and layout constants
// Extracted from the HTML prototype for pixel-perfect implementation
module Theme {
    // === SCREEN CONSTANTS ===
    const SCREEN_SIZE = 454;
    const CENTER = 227;
    const SAFE_MARGIN = 40;
    const SAFE_ZONE_START = 40;
    const SAFE_ZONE_END = 414;
    const SAFE_WIDTH = 374;

    // === LAYOUT POSITIONS (Y coordinates) ===
    const HEADER_Y = 32;
    const CHART_Y = 50;
    const CHART_HEIGHT = 115;
    const CHART_WIDTH = 364;  // SAFE_WIDTH - 10
    const DATE_Y = 195;
    const TIME_Y = 300;
    const RINGS_Y = 368;
    const STATS_Y = 415;  // ringsY + outerRadius + 15

    // === RING DIMENSIONS ===
    const RING_OUTER_RADIUS = 32;
    const RING_MIDDLE_RADIUS = 24;
    const RING_INNER_RADIUS = 16;
    const RING_STROKE = 6;

    // === DARK THEME COLORS ===
    // Background
    const BG = 0x000000;

    // Time colors
    const TIME_PRIMARY = 0xFFFFFF;
    const TIME_UNFILLED = 0x252525;
    const TIME_FILL = 0x26A69A;

    // Text colors
    const TEXT_PRIMARY = 0xB0B0B0;
    const TEXT_SECONDARY = 0x707070;
    const TEXT_DIM = 0x454545;

    // Weather chart colors
    const TEMP_CURVE = 0xFFB347;
    const TEMP_FILL_ALPHA = 0x26FFB347;  // 15% opacity amber
    const PRECIPITATION = 0x4DD0E1;
    const WIND_SPEED = 0xEF5350;
    const CLOUD_COLOR = 0xFFFFFF;
    const NIGHT_SKY = 0x0A1628;
    const DAY_SKY = 0x1E4D6B;

    // Stats ring colors
    const HR_RING = 0xE57373;
    const STEPS_RING = 0x26A69A;
    const FLOORS_RING = 0x81C784;
    const RING_BG_ALPHA = 0.15;

    // Accent colors
    const WEEK_BADGE = 0xFF8A65;
    const NOW_LINE = 0xFFFFFF;
    const MOVE_BAR = 0xC62828;
    const MOVE_BAR_EMPTY = 0x1A1A1A;

    // === AOD COLORS (dimmer for burn-in protection) ===
    const AOD_TIME = 0x606060;
    const AOD_TEXT = 0x404040;

    // === HELPER FUNCTIONS ===

    // Get interpolated color between day and night based on hour
    function getSkyColor(hour as Number) as Number {
        var intensity = 0.0;
        if (hour >= 6 && hour < 20) {
            var dayProgress = (hour - 6).toFloat() / 14.0;
            intensity = Math.sin(dayProgress * Math.PI);
        }
        return lerpColor(NIGHT_SKY, DAY_SKY, intensity);
    }

    // Linear interpolation between two colors
    function lerpColor(c1 as Number, c2 as Number, t as Float) as Number {
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

    // Create a dimmed version of a color (for ring backgrounds)
    function dimColor(color as Number, factor as Float) as Number {
        var r = ((color >> 16) & 0xFF) * factor;
        var g = ((color >> 8) & 0xFF) * factor;
        var b = (color & 0xFF) * factor;
        return (r.toNumber() << 16) | (g.toNumber() << 8) | b.toNumber();
    }
}

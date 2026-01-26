using Toybox.Graphics;
using Toybox.System;
using Toybox.ActivityMonitor;

// Renders time with step-goal fill effect
// The time digits fill from bottom to top based on step progress
class TimeRenderer {

    function initialize() {
    }

    function draw(dc as Dc) as Void {
        var clockTime = System.getClockTime();
        var deviceSettings = System.getDeviceSettings();

        // Get step progress
        var activityInfo = ActivityMonitor.getInfo();
        var stepProgress = 0.0;
        if (activityInfo.stepGoal != null && activityInfo.stepGoal > 0 && activityInfo.steps != null) {
            stepProgress = activityInfo.steps.toFloat() / activityInfo.stepGoal.toFloat();
            if (stepProgress > 1.0) {
                stepProgress = 1.0;
            }
        }

        // Format time
        var hour = clockTime.hour;
        var min = clockTime.min;
        var sec = clockTime.sec;
        var isPM = hour >= 12;

        // 12-hour format if not 24h
        if (!deviceSettings.is24Hour) {
            if (hour > 12) {
                hour = hour - 12;
            }
            if (hour == 0) {
                hour = 12;
            }
        }

        var timeStr = hour.format("%d") + ":" + min.format("%02d");

        // Calculate dimensions for clipping
        var baseY = Theme.TIME_Y;
        var digitHeight = 76;  // Approximate height of large time font
        var fillHeight = (digitHeight * stepProgress).toNumber();
        var topY = baseY - digitHeight;
        var fillY = baseY - fillHeight;

        // Use the largest number font available
        var timeFont = Graphics.FONT_NUMBER_HOT;

        // Draw UNFILLED portion (top part - dark gray)
        dc.setClip(0, topY - 20, Theme.SCREEN_SIZE, (digitHeight - fillHeight + 20));
        dc.setColor(Theme.TIME_UNFILLED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER, baseY, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.clearClip();

        // Draw FILLED portion (bottom part - teal)
        if (fillHeight > 0) {
            dc.setClip(0, fillY, Theme.SCREEN_SIZE, fillHeight + 20);
            dc.setColor(Theme.TIME_FILL, Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.CENTER, baseY, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.clearClip();
        }

        // AM/PM indicator (right of time, smaller)
        if (!deviceSettings.is24Hour) {
            var timeWidth = dc.getTextWidthInPixels(timeStr, timeFont);
            var ampmX = Theme.CENTER + (timeWidth / 2) + 8;

            dc.setColor(Theme.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ampmX, baseY - 40, Graphics.FONT_XTINY, isPM ? "PM" : "AM", Graphics.TEXT_JUSTIFY_LEFT);

            // Seconds below AM/PM
            dc.setColor(Theme.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ampmX, baseY - 20, Graphics.FONT_TINY, sec.format("%02d"), Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            // 24h mode - just show seconds to the right
            var timeWidth = dc.getTextWidthInPixels(timeStr, timeFont);
            var secX = Theme.CENTER + (timeWidth / 2) + 8;
            dc.setColor(Theme.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(secX, baseY - 20, Graphics.FONT_TINY, sec.format("%02d"), Graphics.TEXT_JUSTIFY_LEFT);
        }
    }
}

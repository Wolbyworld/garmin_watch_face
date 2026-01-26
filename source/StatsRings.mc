using Toybox.Graphics;
using Toybox.ActivityMonitor;
using Toybox.Activity;

// Renders Apple Watch-style concentric activity rings
// Outer: Steps, Middle: Heart Rate, Inner: Floors
class StatsRings {

    function initialize() {
    }

    function draw(dc as Dc) as Void {
        var ringsX = Theme.CENTER;
        var ringsY = Theme.RINGS_Y;

        // Get activity data
        var activityInfo = ActivityMonitor.getInfo();

        // Steps progress
        var stepsProgress = 0.0;
        var currentSteps = 0;
        if (activityInfo.steps != null && activityInfo.stepGoal != null && activityInfo.stepGoal > 0) {
            currentSteps = activityInfo.steps;
            stepsProgress = activityInfo.steps.toFloat() / activityInfo.stepGoal.toFloat();
            if (stepsProgress > 1.0) {
                stepsProgress = 1.0;
            }
        }

        // Floors progress
        var floorsProgress = 0.0;
        var currentFloors = 0;
        if (activityInfo.floorsClimbed != null && activityInfo.floorsClimbedGoal != null && activityInfo.floorsClimbedGoal > 0) {
            currentFloors = activityInfo.floorsClimbed;
            floorsProgress = activityInfo.floorsClimbed.toFloat() / activityInfo.floorsClimbedGoal.toFloat();
            if (floorsProgress > 1.0) {
                floorsProgress = 1.0;
            }
        }

        // Heart rate - normalize to 50-180 range
        var hrProgress = 0.0;
        var currentHR = 0;
        var hrIterator = ActivityMonitor.getHeartRateHistory(1, true);
        if (hrIterator != null) {
            var sample = hrIterator.next();
            if (sample != null && sample.heartRate != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                currentHR = sample.heartRate;
                hrProgress = (currentHR - 50).toFloat() / 130.0;  // 50-180 range
                if (hrProgress < 0) {
                    hrProgress = 0.0;
                }
                if (hrProgress > 1.0) {
                    hrProgress = 1.0;
                }
            }
        }

        // Draw concentric rings (outer to inner)
        // Steps Ring (outer - teal)
        drawRing(dc, ringsX, ringsY, Theme.RING_OUTER_RADIUS, Theme.RING_STROKE, stepsProgress, Theme.STEPS_RING);

        // HR Ring (middle - red)
        drawRing(dc, ringsX, ringsY, Theme.RING_MIDDLE_RADIUS, Theme.RING_STROKE, hrProgress, Theme.HR_RING);

        // Floors Ring (inner - green)
        drawRing(dc, ringsX, ringsY, Theme.RING_INNER_RADIUS, Theme.RING_STROKE, floorsProgress, Theme.FLOORS_RING);

        // Stats labels below rings
        var statsY = ringsY + Theme.RING_OUTER_RADIUS + 15;

        // Steps (left)
        var stepsStr = formatSteps(currentSteps);
        dc.setColor(Theme.STEPS_RING, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER - 60, statsY, Graphics.FONT_XTINY, stepsStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER - 60, statsY + 14, Graphics.FONT_XTINY, "steps", Graphics.TEXT_JUSTIFY_CENTER);

        // HR (center)
        var hrStr = currentHR > 0 ? currentHR.format("%d") : "--";
        dc.setColor(Theme.HR_RING, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER, statsY, Graphics.FONT_XTINY, hrStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER, statsY + 14, Graphics.FONT_XTINY, "bpm", Graphics.TEXT_JUSTIFY_CENTER);

        // Floors (right)
        var floorsStr = currentFloors.format("%d");
        dc.setColor(Theme.FLOORS_RING, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER + 60, statsY, Graphics.FONT_XTINY, floorsStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.CENTER + 60, statsY + 14, Graphics.FONT_XTINY, "floors", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Draw a single progress ring
    private function drawRing(dc as Dc, x as Number, y as Number, radius as Number, stroke as Number, progress as Float, color as Number) as Void {
        dc.setPenWidth(stroke);

        // Background ring (dimmed color)
        var bgColor = Theme.dimColor(color, 0.2);
        dc.setColor(bgColor, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, 90, -270);

        // Progress arc (from top, going clockwise)
        if (progress > 0) {
            var sweepDegrees = (progress * 360).toNumber();
            var endAngle = 90 - sweepDegrees;

            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, 90, endAngle);
        }
    }

    // Format steps with K suffix for thousands
    private function formatSteps(steps as Number) as String {
        if (steps >= 1000) {
            var k = steps.toFloat() / 1000.0;
            return k.format("%.1f") + "k";
        }
        return steps.format("%d");
    }
}

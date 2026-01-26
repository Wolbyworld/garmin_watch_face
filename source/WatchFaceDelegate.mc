using Toybox.WatchUi;
using Toybox.System;

// Delegate for handling watch face power budget and sleep mode transitions
class WatchFaceDelegate extends WatchUi.WatchFaceDelegate {

    function initialize() {
        WatchFaceDelegate.initialize();
    }

    // Called when the watch enters or exits sleep mode (AOD)
    function onPowerBudgetExceeded(powerInfo as WatchUi.PowerBudgetInfo) as Void {
        // Reduce rendering complexity when power budget is exceeded
        // The view will check sleep mode and render AOD accordingly
        System.println("Power budget exceeded - switching to low power mode");
    }
}

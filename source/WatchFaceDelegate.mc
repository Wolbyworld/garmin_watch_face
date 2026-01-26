using Toybox.WatchUi;

class WatchFaceDelegate extends WatchUi.WatchFaceDelegate {

    function initialize() {
        WatchFaceDelegate.initialize();
    }

    function onPowerBudgetExceeded(powerInfo) {
        // View will handle AOD rendering
    }
}

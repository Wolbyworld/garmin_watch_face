using Toybox.Application;
using Toybox.WatchUi;

// Main application entry point for the OLED Weather Watch Face
class WatchFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // Called when the application starts
    function onStart(state as Dictionary?) as Void {
    }

    // Called when the application stops
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view and delegate for the watch face
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new WatchFaceView(), new WatchFaceDelegate()];
    }

    // Handle settings changes from Garmin Connect Mobile
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}

using Toybox.Application;
using Toybox.WatchUi;

// Main application entry point for the OLED Weather Watch Face
class WatchFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        return [new WatchFaceView(), new WatchFaceDelegate()];
    }

    function onSettingsChanged() {
        WatchUi.requestUpdate();
    }
}

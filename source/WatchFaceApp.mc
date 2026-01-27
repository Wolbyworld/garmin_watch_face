using Toybox.Application;
using Toybox.WatchUi;
using Toybox.System;

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

    // Return the service delegate for background operations (weather fetching)
    function getServiceDelegate() {
        return [new WeatherService()];
    }

    // Called when background service completes
    function onBackgroundData(data) {
        // Background service has completed - trigger UI refresh
        WatchUi.requestUpdate();
    }

    function onSettingsChanged() {
        WatchUi.requestUpdate();
    }
}

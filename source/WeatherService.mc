using Toybox.System;
using Toybox.Background;
using Toybox.Application;
using Toybox.Time;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.Position;

// Background service delegate that fetches weather data from Open-Meteo API
// Runs every 30 minutes via temporal event registered from WeatherDataManager
(:background)
class WeatherService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    // Called when the background service is triggered by temporal event
    function onTemporalEvent() {
        // Try to get last known GPS position (from previous activities like running)
        var lat = null;
        var lon = null;

        var posInfo = Position.getInfo();
        if (posInfo != null && posInfo.position != null) {
            var coords = posInfo.position.toDegrees();
            if (coords != null && coords.size() >= 2) {
                lat = coords[0];  // latitude
                lon = coords[1];  // longitude

                // Cache the position for future reference
                Application.Storage.setValue("weather_lat", lat);
                Application.Storage.setValue("weather_lon", lon);
            }
        }

        // If no GPS position, try cached values from storage
        if (lat == null) {
            lat = Application.Storage.getValue("weather_lat");
            lon = Application.Storage.getValue("weather_lon");
        }

        // If still no location, skip this fetch (no point fetching weather for unknown location)
        if (lat == null || lon == null) {
            System.println("No GPS position available - skipping weather fetch");
            Background.exit(null);
            return;
        }

        // Build Open-Meteo API URL
        // Requesting: temperature, precipitation probability, cloud cover, wind speed
        // 4 days of hourly data (UI shows 72h, but need 4 days to cover all time-of-day cases)
        var url = "https://api.open-meteo.com/v1/forecast" +
            "?latitude=" + lat.format("%.4f") +
            "&longitude=" + lon.format("%.4f") +
            "&hourly=temperature_2m,precipitation_probability,cloudcover,windspeed_10m" +
            "&forecast_days=4" +
            "&timezone=auto";

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(url, null, options, method(:handleResponse));
    }

    // Callback when HTTP response is received
    // Note: SDK 8.4.0+ requires typed callbacks
    function handleResponse(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
        if (responseCode == 200 && data != null) {
            if (data instanceof Lang.Dictionary) {
                processWeatherData(data);
            }
        } else {
            // Log error - data will fallback to Garmin API
            System.println("Weather fetch failed: " + responseCode);
        }

        // Signal completion - pass null as no data needs to be sent to foreground
        Background.exit(null);
    }

    // Process and store weather data from API response
    function processWeatherData(data) {
        if (data.hasKey("hourly")) {
            var hourly = data["hourly"];

            // Store raw arrays in Application.Storage
            // WeatherDataManager will read these
            if (hourly.hasKey("temperature_2m")) {
                Application.Storage.setValue("ext_temps", hourly["temperature_2m"]);
            }
            if (hourly.hasKey("precipitation_probability")) {
                Application.Storage.setValue("ext_precips", hourly["precipitation_probability"]);
            }
            if (hourly.hasKey("cloudcover")) {
                Application.Storage.setValue("ext_clouds", hourly["cloudcover"]);
            }
            if (hourly.hasKey("windspeed_10m")) {
                Application.Storage.setValue("ext_winds", hourly["windspeed_10m"]);
            }
            if (hourly.hasKey("time")) {
                Application.Storage.setValue("ext_times", hourly["time"]);
            }

            // Store fetch timestamp
            Application.Storage.setValue("ext_fetch_time", Time.now().value());

            // Store source indicator
            Application.Storage.setValue("ext_source", "open-meteo");
        }
    }
}

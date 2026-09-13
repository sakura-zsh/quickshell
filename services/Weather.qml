pragma Singleton

import qs.config
import qs.utils
import Caelestia
import Quickshell
import QtQuick

Singleton {
    id: root

    property string city
    property string loc
    property var cc
    property var forecast
    property var hourly: []
    property string error: ""
    property string _cachedLoc: ""
    property string _cachedCity: ""
    property real _lastLocationFetchMs: 0
    property bool _locationFetchInProgress: false
    property bool _geocodingInProgress: false
    property string _lastGeocodedCity: ""

    readonly property string icon: cc ? Icons.getWeatherIcon(cc.weatherCode) : "cloud_alert"
    readonly property string description: cc?.weatherDesc[0].value ?? qsTr("无天气")
    readonly property string temp: Config.services.useFahrenheit ? `${cc?.temp_F ?? 0}°F` : `${cc?.temp_C ?? 0}°C`
    readonly property string feelsLike: Config.services.useFahrenheit ? `${cc?.FeelsLikeF ?? 0}°F` : `${cc?.FeelsLikeC ?? 0}°C`
    readonly property int humidity: cc?.humidity ?? 0
    readonly property real windSpeed: cc?.windSpeed ?? 0.0

    function reload(): void {
        let configLocation = Config.services.weatherLocation;

        if (configLocation && configLocation !== "") {
            if (configLocation.indexOf(",") !== -1 && !isNaN(parseFloat(configLocation.split(",")[0]))) {
                loc = configLocation;
            } else {
                fetchCoordsFromCity(configLocation);
            }
        }
        else {
            // Re-use cached location if less than 24 hours old
            const now = Date.now();
            const twentyFourHours = 86400000;
            if (_cachedLoc && (now - _lastLocationFetchMs) < twentyFourHours) {
                if (loc !== _cachedLoc) {
                    loc = _cachedLoc;
                    city = _cachedCity;
                } else {
                    fetchWeatherData();
                }
                return;
            }

            if (!loc && !_locationFetchInProgress) {
                _locationFetchInProgress = true;
                Requests.get("https://ipinfo.io/json", text => {
                    _locationFetchInProgress = false;
                    try {
                        const response = JSON.parse(text);
                        if (response.loc) {
                            loc = response.loc;
                            city = response.city ?? "";
                            _cachedLoc = loc;
                            _cachedCity = city;
                            _lastLocationFetchMs = Date.now();
                            error = "";
                        }
                    } catch (e) {
                        console.warn("Weather: Failed to parse location response:", e);
                        error = qsTr("位置不可用");
                    }
                }, err => {
                    _locationFetchInProgress = false;
                    console.warn("Weather: Location fetch failed:", err);
                    error = qsTr("位置不可用");
                });
            }
        }
    }

    function fetchCoordsFromCity(cityName) {
        // Skip if already geocoding or if we already resolved this city
        if (_geocodingInProgress) return;
        if (_lastGeocodedCity === cityName && loc) {
            fetchWeatherData();
            return;
        }

        _geocodingInProgress = true;
        const url = "https://geocoding-api.open-meteo.com/v1/search?name=" 
            + encodeURIComponent(cityName) 
            + "&count=1&language=en&format=json";

        Requests.get(url, text => {
            _geocodingInProgress = false;
            try {
                const json = JSON.parse(text);
                if (!json.results || json.results.length === 0) {
                    console.error("Geocoding failed for: " + cityName);
                    error = qsTr("未找到城市");
                    return;
                }
                const result = json.results[0];
                const newLoc = result.latitude + "," + result.longitude;
                _lastGeocodedCity = cityName;
                city = result.name;
                error = "";
                if (loc === newLoc) {
                    // Same location, just refresh weather
                    fetchWeatherData();
                } else {
                    loc = newLoc; // triggers onLocChanged -> fetchWeatherData
                }
            } catch (e) {
                console.warn("Weather: Failed to parse geocoding response:", e);
                error = qsTr("未找到城市");
            }
        }, err => {
            _geocodingInProgress = false;
            console.warn("Weather: Geocoding fetch failed:", err);
            error = qsTr("位置不可用");
        });
    }

    onLocChanged: {
        fetchWeatherData()
    }

    readonly property int windDirection: cc?.windDirection ?? 0

    // Beaufort scale helpers (input: km/h)
    function beaufortLevel(kmh: real): int {
        const bounds = [1, 5, 11, 19, 28, 38, 49, 61, 74, 88, 102, 117];
        for (let i = 0; i < bounds.length; i++) {
            if (kmh < bounds[i])
                return i;
        }
        return 12;
    }

    function beaufortName(level: int): string {
        const names = [qsTr("无风"), qsTr("软风"), qsTr("轻风"), qsTr("微风"), qsTr("和风"), qsTr("劲风"), qsTr("强风"), qsTr("疾风"), qsTr("大风"), qsTr("烈风"), qsTr("狂风"), qsTr("暴风"), qsTr("飓风")];
        return names[level] ?? "";
    }

    function beaufortText(kmh: real): string {
        const level = beaufortLevel(kmh);
        return level + " 级 " + beaufortName(level);
    }

    readonly property string windDirName: {
        const dirs = [qsTr("北"), qsTr("东北"), qsTr("东"), qsTr("东南"), qsTr("南"), qsTr("西南"), qsTr("西"), qsTr("西北")];
        return dirs[Math.round(((windDirection % 360) + 360) % 360 / 45) % 8];
    }

    function fetchWeatherData() {
        let url = getWeatherUrl();
        if (url === "") return;

        Requests.get(url, text => {
            try {
                const json = JSON.parse(text);
                if (!json.current || !json.daily) return;

                error = "";
                cc = {
                    "weatherCode": String(json.current.weather_code),
                    "weatherDesc": [{ "value": getWeatherCondition(String(json.current.weather_code))}],
                    "temp_C": Math.round(json.current.temperature_2m),
                    "temp_F": Math.round(json.current.temperature_2m * 9/5 + 32),
                    "FeelsLikeC": Math.round(json.current.apparent_temperature),
                    "FeelsLikeF": Math.round(json.current.apparent_temperature * 9/5 + 32),
                    "humidity": json.current.relative_humidity_2m,
                    "windSpeed": json.current.wind_speed_10m,
                    "windDirection": json.current.wind_direction_10m ?? 0,
                    "precipitation": json.current.precipitation ?? 0,
                    "isDay": json.current.is_day,
                    "sunrise": json.daily.sunrise[0].split("T")[1],
                    "sunset": json.daily.sunset[0].split("T")[1]
                };

                let forecastList = []
                for (let i = 0; i < json.daily.time.length; i++) {
                    forecastList.push({
                        "date": json.daily.time[i],
                        "maxTempC": Math.round(json.daily.temperature_2m_max[i]),
                        "maxTempF": Math.round(json.daily.temperature_2m_max[i] * 9/5 + 32),
                        "minTempC": Math.round(json.daily.temperature_2m_min[i]),
                        "minTempF": Math.round(json.daily.temperature_2m_min[i] * 9/5 + 32),
                        "weatherCode": String(json.daily.weather_code[i]),
                        "icon": Icons.getWeatherIcon(String(json.daily.weather_code[i])),
                        "precipProb": json.daily.precipitation_probability_max?.[i] ?? 0,
                        "precipSum": json.daily.precipitation_sum?.[i] ?? 0,
                        "windMax": Math.round(json.daily.wind_speed_10m_max?.[i] ?? 0),
                        "windDir": json.daily.wind_direction_10m_dominant?.[i] ?? 0
                    });
                }
                forecast = forecastList;

                // Hourly series starting from the current hour, next 48h
                let hourlyList = [];
                if (json.hourly && json.hourly.time) {
                    const now = new Date();
                    const nowMs = new Date(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours()).getTime();
                    let start = 0;
                    while (start < json.hourly.time.length && new Date(json.hourly.time[start]).getTime() < nowMs)
                        start++;
                    for (let i = start; i < json.hourly.time.length && i < start + 48; i++) {
                        const t = new Date(json.hourly.time[i]);
                        hourlyList.push({
                            "hour": String(t.getHours()).padStart(2, "0") + ":00",
                            "tempC": Math.round(json.hourly.temperature_2m[i]),
                            "tempF": Math.round(json.hourly.temperature_2m[i] * 9/5 + 32),
                            "icon": Icons.getWeatherIcon(String(json.hourly.weather_code[i])),
                            "precipProb": json.hourly.precipitation_probability?.[i] ?? 0,
                            "precip": json.hourly.precipitation?.[i] ?? 0,
                            "humidity": json.hourly.relative_humidity_2m?.[i] ?? 0,
                            "windSpeed": Math.round(json.hourly.wind_speed_10m?.[i] ?? 0),
                            "windDir": json.hourly.wind_direction_10m?.[i] ?? 0
                        });
                    }
                }
                hourly = hourlyList;
            } catch (e) {
                console.warn("Weather: Failed to parse weather data:", e);
                error = qsTr("天气数据不可用");
            }
        }, err => {
            console.warn("Weather: Data fetch failed:", err);
            error = qsTr("天气数据不可用");
        });
    }

    function getWeatherUrl() {
        if (!loc || loc.indexOf(",") === -1) return "";

        let coords = loc.split(",");
        let lat = coords[0];
        let lon = coords[1];

        const baseUrl = "https://api.open-meteo.com/v1/forecast";
        const params = [
            "latitude=" + lat,
            "longitude=" + lon,
            "daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max,precipitation_sum,wind_speed_10m_max,wind_direction_10m_dominant",
            "hourly=temperature_2m,weather_code,precipitation_probability,precipitation,relative_humidity_2m,wind_speed_10m,wind_direction_10m",
            "current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m,wind_direction_10m,precipitation",
            "timezone=auto",
            "forecast_days=16"
        ];

        return baseUrl + "?" + params.join("&");
    }

    function getWeatherCondition(code: string): string {
        const conditions = {
            "0": "Clear",
            "1": "Clear",
            "2": "Partly cloudy",
            "3": "Overcast",
            "45": "Fog",
            "48": "Fog",
            "51": "Drizzle",
            "53": "Drizzle",
            "55": "Drizzle",
            "56": "Freezing drizzle",
            "57": "Freezing drizzle",
            "61": "Light rain",
            "63": "Rain",
            "65": "Heavy rain",
            "66": "Light rain",
            "67": "Heavy rain",
            "71": "Light snow",
            "73": "Snow",
            "75": "Heavy snow",
            "77": "Snow",
            "80": "Light rain",
            "81": "Rain",
            "82": "Heavy rain",
            "85": "Light snow showers",
            "86": "Heavy snow showers",
            "95": "Thunderstorm",
            "96": "Thunderstorm with hail",
            "99": "Thunderstorm with hail"
        };
        return conditions[code] || "Unknown";
    }

    // Refresh current location hourly
    Timer {
        interval: 3600000 // 1 hour
        running: true
        repeat: true
        onTriggered: fetchWeatherData()
    }
}

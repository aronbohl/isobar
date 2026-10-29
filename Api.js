// Request URLs for every data source. Open-Meteo takes comma-separated
// coordinates, so one forecast request and one air-quality request cover
// every saved location; NWS alerts are one request per US location.

var USER_AGENT = "isobar (github.com/aronbohl/isobar)"

var CURRENT = [
  "temperature_2m", "apparent_temperature", "relative_humidity_2m", "dew_point_2m",
  "weather_code", "is_day", "wind_speed_10m", "wind_direction_10m", "wind_gusts_10m",
  "pressure_msl", "visibility", "uv_index", "precipitation"
]
var HOURLY = [
  "temperature_2m", "apparent_temperature", "precipitation_probability", "precipitation",
  "weather_code", "is_day", "pressure_msl", "uv_index", "wind_speed_10m"
]
var DAILY = [
  "weather_code", "temperature_2m_max", "temperature_2m_min", "precipitation_probability_max",
  "precipitation_sum", "sunrise", "sunset", "uv_index_max"
]

function coordinates(locations) {
  var lat = []
  var lon = []
  for (var i = 0; i < locations.length; i++) {
    lat.push(String(locations[i].latitude))
    lon.push(String(locations[i].longitude))
  }
  return "latitude=" + lat.join(",") + "&longitude=" + lon.join(",")
}

// Metric in, always: the views convert, so a unit toggle never refetches.
function forecastUrl(locations) {
  return "https://api.open-meteo.com/v1/forecast?" + coordinates(locations)
    + "&current=" + CURRENT.join(",")
    + "&hourly=" + HOURLY.join(",")
    + "&daily=" + DAILY.join(",")
    + "&timezone=auto&past_hours=24&forecast_hours=48&past_days=1&forecast_days=10"
}

function airQualityUrl(locations) {
  return "https://air-quality-api.open-meteo.com/v1/air-quality?" + coordinates(locations)
    + "&current=us_aqi,pm2_5,pm10,ozone&timezone=auto"
}

function geocodeUrl(query) {
  return "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(String(query || ""))
    + "&count=8&language=en&format=json"
}

function alertsUrl(location) {
  return "https://api.weather.gov/alerts/active?point="
    + Number(location.latitude).toFixed(4) + "," + Number(location.longitude).toFixed(4)
}

var NWS_COUNTRIES = ["US", "PR", "GU", "VI", "AS", "MP"]

function inBox(lat, lon, south, north, west, east) {
  return lat >= south && lat <= north && lon >= west && lon <= east
}

// Whether NWS covers a location (it answers 400 "out of bounds" elsewhere).
// The geocoder's country code decides; hand-entered locations without one
// fall back to rough bounding boxes for the states and territories.
function nwsCovers(location) {
  if (!location) return false
  var code = String(location.countryCode || "").toUpperCase()
  if (code) return NWS_COUNTRIES.indexOf(code) !== -1
  var lat = Number(location.latitude)
  var lon = Number(location.longitude)
  return inBox(lat, lon, 24.4, 49.4, -124.8, -66.9)   // contiguous US
    || inBox(lat, lon, 51.2, 71.5, -179.9, -129.9)     // Alaska
    || inBox(lat, lon, 18.9, 22.3, -160.3, -154.7)     // Hawaii
    || inBox(lat, lon, 17.8, 18.6, -67.3, -65.2)       // Puerto Rico
}

// A GET as { command, environment } for a Process. The URL holds saved
// coordinates or a search query, and other local users can read process
// arguments, so it reaches curl as a config file on stdin, fed from an
// environment variable (owner-only in /proc) by the shell's printf builtin.
// NWS rejects requests without a User-Agent.
function curl(url, timeoutSeconds) {
  var argv = ["sh", "-c", 'printf "%s\\n" "$ISOBAR_CURL_CONFIG" | curl -K - "$@"', "sh",
    "-fsS", "--compressed", "--max-time", String(timeoutSeconds || 10)]
  if (url.indexOf("api.weather.gov") !== -1)
    argv.push("-A", USER_AGENT, "-H", "Accept: application/geo+json")
  var quoted = String(url).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
  return { command: argv, environment: { ISOBAR_CURL_CONFIG: 'url = "' + quoted + '"' } }
}

if (typeof module !== "undefined") {
  module.exports = {
    USER_AGENT: USER_AGENT, forecastUrl: forecastUrl, airQualityUrl: airQualityUrl, geocodeUrl: geocodeUrl,
    alertsUrl: alertsUrl, nwsCovers: nwsCovers, curl: curl
  }
}

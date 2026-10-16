// Pure forecast helpers: settings, Open-Meteo normalization, units, and the
// descriptive copy the views show. No QML or I/O here, so tests/*.test.js can
// exercise everything against saved API responses.
//
// Times: Open-Meteo answers with `timezone=auto`, so its timestamps are the
// location's wall-clock time without an offset ("2026-10-15T22:00"). They are
// kept as "local ms": Date.UTC() of those wall-clock fields. The location's
// current wall-clock time is `nowMs + utcOffsetSeconds * 1000` in the same
// scale, and every formatter here reads the UTC getters, so the machine's own
// timezone never leaks in.

var DAY_MS = 86400000
var HOUR_MS = 3600000
var DAYS_SHORT = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
var COMPASS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

function trim(value) {
  return String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
}

function num(value) {
  if (value === undefined || value === null || value === "") return null
  var n = Number(value)
  return isFinite(n) ? n : null
}

function clone(value) {
  return value === undefined ? undefined : JSON.parse(JSON.stringify(value))
}

// ---------------------------------------------------------------- settings

function normalizeLocation(value) {
  if (!value || typeof value !== "object") return null
  var latitude = num(value.latitude)
  var longitude = num(value.longitude)
  var name = trim(value.name)
  if (latitude === null || longitude === null || name === "") return null
  if (Math.abs(latitude) > 90 || Math.abs(longitude) > 180) return null
  return {
    name: name,
    region: trim(value.region),
    latitude: latitude,
    longitude: longitude,
    countryCode: trim(value.countryCode).toUpperCase()
  }
}

function locationKey(location) {
  return location ? Number(location.latitude).toFixed(3) + "," + Number(location.longitude).toFixed(3) : ""
}

// The plugin's shell.json entry → settings with defaults. `legacy` is the
// stock widget's weather.json ({name, latitude, longitude}); it seeds the
// first location until the entry has a list of its own, even an empty one.
function normalizeSettings(entry, legacy) {
  var source = entry && typeof entry === "object" ? entry : {}
  var locations = []
  var seen = {}
  var list = Array.isArray(source.locations) ? source.locations : []
  for (var i = 0; i < list.length; i++) {
    var location = normalizeLocation(list[i])
    if (!location || seen[locationKey(location)]) continue
    seen[locationKey(location)] = true
    locations.push(location)
  }
  // Absent, not empty: removing the last location must stick.
  if (!Array.isArray(source.locations)) {
    var seed = normalizeLocation(legacy)
    if (seed) locations.push(seed)
  }

  var selected = parseInt(source.selected, 10)
  if (isNaN(selected) || selected < 0 || selected >= locations.length) selected = 0

  var units = trim(source.units).toLowerCase()
  if (units !== "metric" && units !== "imperial") units = "auto"

  var refresh = parseInt(source.refreshMinutes, 10)
  // Trackpad scroll multiplier in percent; 250 roughly cancels Omarchy's
  // 0.4 touchpad scroll_factor.
  var scroll = Number(source.scrollSpeed)
  return {
    locations: locations,
    selected: selected,
    units: units,
    skyFx: source.skyFx !== false,
    refreshMinutes: isNaN(refresh) ? 15 : Math.max(10, Math.min(120, refresh)),
    scrollSpeed: isFinite(scroll) && source.scrollSpeed !== null && source.scrollSpeed !== "" ? Math.max(50, Math.min(800, scroll)) : 250
  }
}

// weather.json from omarchy-weather-location; anything unusable is null.
function parseLegacyLocation(raw) {
  try {
    return normalizeLocation(JSON.parse(String(raw || "")))
  } catch (e) {
    return null
  }
}

// Open-Meteo geocoding → location rows for search.
function parseGeocoding(raw) {
  try {
    var results = JSON.parse(String(raw || "{}")).results || []
    var out = []
    for (var i = 0; i < results.length; i++) {
      var r = results[i] || {}
      var location = normalizeLocation({
        name: r.name,
        region: [r.admin1, r.country].filter(function(part) { return !!part }).join(", "),
        latitude: r.latitude,
        longitude: r.longitude,
        countryCode: r.country_code
      })
      if (location) out.push(location)
    }
    return out
  } catch (e) {
    return []
  }
}

// ------------------------------------------------------------------- units

function localeUsesImperial(localeName) {
  var name = String(localeName || "").replace(".", "_")
  return /^en[_-]US($|[_.-])/.test(name) || /^en[_-]LR($|[_.-])/.test(name) || /^my($|[_.-])/.test(name)
}

function useImperial(units, localeName) {
  if (units === "imperial") return true
  if (units === "metric") return false
  return localeUsesImperial(localeName)
}

function temp(celsius, imperial) {
  var c = num(celsius)
  if (c === null) return null
  return Math.round(imperial ? c * 9 / 5 + 32 : c)
}

// "44°", or "44°F" with the unit; "—" when missing.
function fmtTemp(celsius, imperial, withUnit) {
  var t = temp(celsius, imperial)
  if (t === null) return "—"
  return t + "°" + (withUnit ? (imperial ? "F" : "C") : "")
}

function tempUnit(imperial) {
  return imperial ? "°F" : "°C"
}

function speed(kmh, imperial) {
  var v = num(kmh)
  if (v === null) return null
  return Math.round(imperial ? v * 0.621371 : v)
}

function speedUnit(imperial) {
  return imperial ? "mph" : "km/h"
}

function fmtSpeed(kmh, imperial) {
  var v = speed(kmh, imperial)
  return v === null ? "—" : v + " " + speedUnit(imperial)
}

function fmtDistance(meters, imperial) {
  var m = num(meters)
  if (m === null) return "—"
  var v = imperial ? m / 1609.344 : m / 1000
  return (v < 10 ? Math.round(v * 10) / 10 : Math.round(v)) + (imperial ? " mi" : " km")
}

function fmtPrecip(mm, imperial) {
  var v = num(mm)
  if (v === null) return "—"
  if (imperial) return (Math.round(v / 25.4 * 100) / 100).toFixed(2) + " in"
  return (Math.round(v * 10) / 10).toFixed(1) + " mm"
}

function pressure(hPa, imperial) {
  var v = num(hPa)
  if (v === null) return null
  return imperial ? Math.round(v * 0.02953 * 100) / 100 : Math.round(v)
}

function fmtPressure(hPa, imperial) {
  var v = pressure(hPa, imperial)
  if (v === null) return "—"
  return (imperial ? v.toFixed(2) : String(v))
}

function pressureUnit(imperial) {
  return imperial ? "inHg" : "hPa"
}

function compass(degrees) {
  var d = num(degrees)
  if (d === null) return ""
  return COMPASS[Math.round((((d % 360) + 360) % 360) / 45) % 8]
}

// ------------------------------------------------------------------- time

// "2026-10-15T22:00" / "2026-10-15" → local ms; NaN when unparseable.
function localMs(text) {
  var m = String(text || "").match(/^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2}))?/)
  if (!m) return NaN
  return Date.UTC(+m[1], +m[2] - 1, +m[3], m[4] ? +m[4] : 0, m[5] ? +m[5] : 0)
}

function localNow(nowMs, utcOffsetSeconds) {
  return nowMs + (num(utcOffsetSeconds) || 0) * 1000
}

function dateKey(localMsValue) {
  return new Date(localMsValue).toISOString().slice(0, 10)
}

// "9:04 PM"
function clock(localMsValue) {
  var d = new Date(localMsValue)
  var h = d.getUTCHours()
  var m = d.getUTCMinutes()
  return ((h % 12) || 12) + ":" + (m < 10 ? "0" : "") + m + " " + (h < 12 ? "AM" : "PM")
}

// Compact hour for forecast strips: "10P", "12A".
function hourLabel(localMsValue) {
  var h = new Date(localMsValue).getUTCHours()
  return ((h % 12) || 12) + (h < 12 ? "A" : "P")
}

function dayShort(localMsValue) {
  return DAYS_SHORT[new Date(localMsValue).getUTCDay()]
}

// "updated just now" / "updated 4 min ago" / "updated 2 h ago".
function ago(thenMs, nowMs) {
  if (!thenMs) return ""
  var minutes = Math.floor(Math.max(0, nowMs - thenMs) / 60000)
  if (minutes < 1) return "updated just now"
  if (minutes < 60) return "updated " + minutes + " min ago"
  var hours = Math.floor(minutes / 60)
  if (hours < 48) return "updated " + hours + " h ago"
  return "updated " + Math.floor(hours / 24) + " d ago"
}

// ------------------------------------------------------------- conditions

function isPrecipCode(code) {
  var c = num(code)
  return c !== null && c >= 51
}

function isSnowCode(code) {
  var c = num(code)
  return c === 71 || c === 73 || c === 75 || c === 77 || c === 85 || c === 86
}

function conditionText(code, isDay) {
  var day = num(isDay) !== 0
  switch (num(code)) {
    case 0: return day ? "Sunny" : "Clear"
    case 1: return day ? "Mostly Sunny" : "Mostly Clear"
    case 2: return "Partly Cloudy"
    case 3: return "Cloudy"
    case 45: return "Fog"
    case 48: return "Freezing Fog"
    case 51: return "Light Drizzle"
    case 53: return "Drizzle"
    case 55: return "Heavy Drizzle"
    case 56: case 57: return "Freezing Drizzle"
    case 61: return "Light Rain"
    case 63: return "Rain"
    case 65: return "Heavy Rain"
    case 66: case 67: return "Freezing Rain"
    case 71: return "Light Snow"
    case 73: return "Snow"
    case 75: return "Heavy Snow"
    case 77: return "Snow Grains"
    case 80: return "Light Showers"
    case 81: return "Showers"
    case 82: return "Heavy Showers"
    case 85: return "Snow Showers"
    case 86: return "Heavy Snow Showers"
    case 95: return "Thunderstorms"
    case 96: case 99: return "Thunderstorms, Hail"
    default: return ""
  }
}

// Nerd Font weather glyphs (the same set the stock Omarchy widget uses).
function glyph(code, isDay) {
  var night = num(isDay) === 0
  var c = num(code)
  if (c === 0 || c === 1) return night ? "\ue32b" : "\ue30d"
  if (c === 2) return night ? "\ue32e" : "\ue302"
  if (c === 45 || c === 48) return night ? "\ue346" : "\ue313"
  if (c === 56 || c === 57 || c === 66 || c === 67) return "\ue3ad"
  if (c === 80 || c === 81 || c === 82) return night ? "\ue333" : "\ue308"
  if (c !== null && c >= 51 && c <= 65) return "\ue318"
  if (isSnowCode(c)) return "\ue31a"
  if (c === 95 || c === 96 || c === 99) return "\ue31d"
  return "\ue33d"
}

// Which ASCII sky to draw: stars | sun | partly | clouds | rain | storm | snow.
function skyKind(code, isDay) {
  var c = num(code)
  var day = num(isDay) !== 0
  if (c === 95 || c === 96 || c === 99) return "storm"
  if (isSnowCode(c)) return "snow"
  if (c !== null && c >= 51) return "rain"
  if (c === 0 || c === 1) return day ? "sun" : "stars"
  if (c === 2) return day ? "partly" : "stars"
  return "clouds"
}

// ---------------------------------------------------------- normalization

function column(block, key, i) {
  return block && block[key] ? num(block[key][i]) : null
}

// Open-Meteo answers a multi-location request with an array and a single
// location with a bare object.
function asList(raw) {
  try {
    var data = typeof raw === "string" ? JSON.parse(raw) : raw
    if (Array.isArray(data)) return data
    return data && typeof data === "object" ? [data] : []
  } catch (e) {
    return []
  }
}

// One location's Open-Meteo forecast → the shape every view reads. Hourly
// starts at the current hour; `days` starts at today (past_days=1 puts
// yesterday at index 0, which only feeds the past-24h precipitation).
function normalizeForecast(raw, nowMs) {
  if (!raw || !raw.current || num(raw.current.temperature_2m) === null) return null
  var offset = num(raw.utc_offset_seconds) || 0
  var now = localNow(nowMs, offset)
  var hourStart = now - now % HOUR_MS
  var cur = raw.current

  var hourly = []
  var past24 = 0
  var pressure3h = null
  var hr = raw.hourly || {}
  var times = hr.time || []
  for (var i = 0; i < times.length; i++) {
    var t = localMs(times[i])
    if (isNaN(t)) continue
    if (t < hourStart) {
      if (t >= hourStart - 24 * HOUR_MS) past24 += column(hr, "precipitation", i) || 0
      if (t === hourStart - 3 * HOUR_MS) pressure3h = column(hr, "pressure_msl", i)
      continue
    }
    if (hourly.length >= 24) continue
    hourly.push({
      t: t,
      tempC: column(hr, "temperature_2m", i),
      feelsC: column(hr, "apparent_temperature", i),
      pop: column(hr, "precipitation_probability", i),
      precipMm: column(hr, "precipitation", i),
      code: column(hr, "weather_code", i),
      isDay: column(hr, "is_day", i),
      uv: column(hr, "uv_index", i),
      windKmh: column(hr, "wind_speed_10m", i)
    })
  }

  var days = []
  var dy = raw.daily || {}
  var today = dateKey(now)
  var dates = dy.time || []
  for (var j = 0; j < dates.length; j++) {
    if (String(dates[j]) < today) continue
    days.push({
      date: String(dates[j]),
      t: localMs(dates[j]),
      code: column(dy, "weather_code", j),
      maxC: column(dy, "temperature_2m_max", j),
      minC: column(dy, "temperature_2m_min", j),
      pop: column(dy, "precipitation_probability_max", j),
      precipMm: column(dy, "precipitation_sum", j),
      uvMax: column(dy, "uv_index_max", j),
      sunrise: dy.sunrise ? localMs(dy.sunrise[j]) : NaN,
      sunset: dy.sunset ? localMs(dy.sunset[j]) : NaN
    })
  }

  var pressureNow = num(cur.pressure_msl)
  return {
    timezone: String(raw.timezone || ""),
    utcOffset: offset,
    current: {
      tempC: num(cur.temperature_2m),
      feelsC: num(cur.apparent_temperature),
      humidity: num(cur.relative_humidity_2m),
      dewC: num(cur.dew_point_2m),
      code: num(cur.weather_code),
      isDay: num(cur.is_day),
      windKmh: num(cur.wind_speed_10m),
      windDir: num(cur.wind_direction_10m),
      gustKmh: num(cur.wind_gusts_10m),
      pressureHpa: pressureNow,
      visibilityM: num(cur.visibility),
      uv: num(cur.uv_index),
      precipMm: num(cur.precipitation)
    },
    hourly: hourly,
    days: days.slice(0, 10),
    past24PrecipMm: Math.round(past24 * 10) / 10,
    pressureChange3h: pressureNow !== null && pressure3h !== null ? Math.round((pressureNow - pressure3h) * 10) / 10 : null
  }
}

function normalizeAirQuality(raw) {
  if (!raw || !raw.current) return null
  var aqi = num(raw.current.us_aqi)
  if (aqi === null) return null
  return {
    usAqi: Math.round(aqi),
    pm25: num(raw.current.pm2_5),
    pm10: num(raw.current.pm10),
    ozone: num(raw.current.ozone)
  }
}

// ------------------------------------------------------------ descriptions

function aqiLevel(aqi) {
  var v = num(aqi)
  if (v === null) return { label: "", desc: "" }
  if (v <= 50) return { label: "Good", desc: "Air quality is satisfactory and poses little or no risk." }
  if (v <= 100) return { label: "Moderate", desc: "Acceptable; unusually sensitive people should limit long outdoor exertion." }
  if (v <= 150) return { label: "Unhealthy for Sensitive Groups", desc: "Sensitive groups should reduce prolonged outdoor exertion." }
  if (v <= 200) return { label: "Unhealthy", desc: "Everyone may begin to feel effects; limit time outdoors." }
  if (v <= 300) return { label: "Very Unhealthy", desc: "Health alert: everyone should avoid prolonged outdoor exertion." }
  return { label: "Hazardous", desc: "Emergency conditions: stay indoors and keep activity low." }
}

function uvLabel(uv) {
  var v = num(uv)
  if (v === null) return ""
  if (v < 3) return "Low"
  if (v < 6) return "Moderate"
  if (v < 8) return "High"
  if (v < 11) return "Very High"
  return "Extreme"
}

// Sun-protection window from today's remaining hours with UV ≥ 3.
function uvAdvice(forecast) {
  if (!forecast) return ""
  var today = forecast.hourly.length ? dateKey(forecast.hourly[0].t) : ""
  var first = null
  var last = null
  for (var i = 0; i < forecast.hourly.length; i++) {
    var h = forecast.hourly[i]
    if (dateKey(h.t) !== today) break
    if ((h.uv || 0) >= 3) {
      if (first === null) first = h.t
      last = h.t
    }
  }
  if (first === null) return "Low for the rest of the day."
  return "Use sun protection until " + clock(last + HOUR_MS) + "."
}

function feelsNote(current) {
  if (!current || current.feelsC === null || current.tempC === null) return ""
  var diff = current.feelsC - current.tempC
  if (diff <= -1.5) return (current.windKmh || 0) >= 5 ? "wind chill" : "feels cooler"
  if (diff >= 1.5) return "humidity"
  return "similar"
}

function feelsDesc(current) {
  var note = feelsNote(current)
  if (note === "wind chill") return "Wind is making it feel colder."
  if (note === "feels cooler") return "It feels cooler than the actual temperature."
  if (note === "humidity") return "Humidity is making it feel warmer."
  return note ? "Similar to the actual temperature." : ""
}

function visibilityDesc(meters) {
  var m = num(meters)
  if (m === null) return ""
  if (m >= 16000) return "Perfectly clear view."
  if (m >= 10000) return "Clear view."
  if (m >= 4000) return "Haze is slightly reducing visibility."
  if (m >= 1000) return "Haze or mist is reducing visibility."
  return "Fog is severely reducing visibility."
}

// 3-hour change in hPa → "rising" | "falling" | "steady" ("" when unknown).
function pressureTrend(change3h) {
  var v = num(change3h)
  if (v === null) return ""
  if (v >= 1) return "rising"
  if (v <= -1) return "falling"
  return "steady"
}

// Next sunrise or sunset, plus how far through today's daylight we are.
function sunInfo(forecast, nowMs) {
  if (!forecast || !forecast.days.length) return null
  var now = localNow(nowMs, forecast.utcOffset)
  var today = forecast.days[0]
  var tomorrow = forecast.days[1] || null
  var progress = isNaN(today.sunrise) || isNaN(today.sunset) ? null
    : Math.max(0, Math.min(1, (now - today.sunrise) / (today.sunset - today.sunrise)))
  if (now < today.sunrise)
    return { next: "sunrise", time: today.sunrise, other: "sunset", otherTime: today.sunset, progress: progress, isDay: false }
  if (now < today.sunset)
    return { next: "sunset", time: today.sunset, other: "sunrise", otherTime: tomorrow ? tomorrow.sunrise : NaN, progress: progress, isDay: true }
  return {
    next: "sunrise", time: tomorrow ? tomorrow.sunrise : NaN,
    other: "sunset", otherTime: tomorrow ? tomorrow.sunset : NaN, progress: progress, isDay: false
  }
}

// Coldest low over the next `count` days after today: { minC, t } or null.
function coldestAhead(forecast, count) {
  if (!forecast) return null
  var best = null
  for (var i = 1; i < forecast.days.length && i <= (count || 5); i++) {
    var d = forecast.days[i]
    if (d.minC === null) continue
    if (!best || d.minC < best.minC) best = { minC: d.minC, t: d.t }
  }
  return best
}

// Next day with meaningful precipitation: "0.12 in expected Tue." etc.
function precipOutlook(forecast, imperial) {
  if (!forecast) return ""
  for (var i = 0; i < forecast.days.length; i++) {
    var d = forecast.days[i]
    if ((d.precipMm || 0) >= 0.5) {
      var when = i === 0 ? "today" : (i === 1 ? "tomorrow" : dayShort(d.t))
      return fmtPrecip(d.precipMm, imperial) + " expected " + when + "."
    }
  }
  return "None expected in the next " + forecast.days.length + " days."
}

function precipWord(code) {
  return isSnowCode(code) ? "Snow" : "Rain"
}

// The hero's one-line "> ..." summary. Precipitation first (starting or
// ending), then tonight's low or today's high, then strong gusts.
function summary(forecast, nowMs, imperial) {
  if (!forecast) return ""
  var now = localNow(nowMs, forecast.utcOffset)
  var hour = new Date(now).getUTCHours()
  var cur = forecast.current
  var hourly = forecast.hourly
  var parts = []

  if (isPrecipCode(cur.code)) {
    var ending = null
    for (var i = 1; i < Math.min(hourly.length, 12); i++)
      if ((hourly[i].pop || 0) < 30 && !isPrecipCode(hourly[i].code)) { ending = hourly[i]; break }
    parts.push(precipWord(cur.code) + (ending ? " ending around " + clock(ending.t) + "." : " continuing for the next several hours."))
  } else {
    for (var j = 1; j < Math.min(hourly.length, 12); j++) {
      var h = hourly[j]
      if ((h.pop || 0) >= 50 && isPrecipCode(h.code)) {
        parts.push(precipWord(h.code) + " likely around " + clock(h.t) + ".")
        break
      }
    }
  }

  // Lead with the condition only when no precipitation sentence came first.
  var lead = parts.length ? "" : conditionText(cur.code, cur.isDay)
  if (hour >= 17 || hour < 5) {
    var low = null
    for (var k = 0; k < Math.min(hourly.length, 14); k++)
      if (hourly[k].tempC !== null && (low === null || hourly[k].tempC < low)) low = hourly[k].tempC
    if (low !== null) {
      var night = lead ? lead + " tonight, low " + fmtTemp(low, imperial) : "Low " + fmtTemp(low, imperial) + " tonight"
      parts.push(night + (low <= 0 && (cur.tempC || 0) > 0 ? ", below freezing." : "."))
    }
  } else if (forecast.days.length && forecast.days[0].maxC !== null) {
    var high = fmtTemp(forecast.days[0].maxC, imperial)
    parts.push(lead ? lead + " today, high " + high + "." : "High " + high + " today.")
  }

  if ((cur.gustKmh || 0) >= 50) parts.push("Gusts up to " + fmtSpeed(cur.gustKmh, imperial) + ".")
  return parts.join(" ")
}

// "Omaha" → "omaha", for the app header's ~/path.
function slug(name) {
  return trim(name).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
}

// Sidebar filter: every word of the query appears in the name or region.
function matchesQuery(location, query) {
  var words = trim(query).toLowerCase().split(/\s+/).filter(function(w) { return !!w })
  if (!location) return false
  var hay = (location.name + " " + (location.region || "")).toLowerCase()
  for (var i = 0; i < words.length; i++) if (hay.indexOf(words[i]) === -1) return false
  return true
}

// A sidebar card. `forecast` may be null while the first fetch is in flight.
function cardView(location, forecast, imperial, nowMs) {
  var cur = forecast ? forecast.current : null
  var today = forecast && forecast.days.length ? forecast.days[0] : null
  return {
    name: location ? location.name : "",
    time: forecast ? clock(localNow(nowMs, forecast.utcOffset)) : "",
    glyph: cur ? glyph(cur.code, cur.isDay) : "",
    temp: cur ? fmtTemp(cur.tempC, imperial) : "—",
    condition: cur ? conditionText(cur.code, cur.isDay) : "",
    hi: today ? fmtTemp(today.maxC, imperial) : "—",
    lo: today ? fmtTemp(today.minC, imperial) : "—"
  }
}

// The app's hero block for the selected location.
function heroView(location, forecast, imperial, nowMs) {
  if (!location || !forecast) return null
  var card = cardView(location, forecast, imperial, nowMs)
  return {
    name: location.name,
    region: location.region || "",
    time: card.time,
    temp: card.temp,
    glyph: card.glyph,
    condition: card.condition,
    hi: card.hi,
    lo: card.lo,
    summary: summary(forecast, nowMs, imperial)
  }
}

function popLabel(pop) {
  var p = num(pop)
  return p === null || p < 10 ? "" : Math.round(p / 10) * 10 + "%"
}

function clamp01(v) {
  return Math.max(0, Math.min(1, v))
}

// ¹ hourly panel: 24 columns plus the numbers the temperature line plots.
function hourlyView(forecast, imperial) {
  if (!forecast) return []
  return forecast.hourly.map(function(slot, i) {
    var h = i === 0 ? nowSlot(forecast) : slot
    return {
      label: i === 0 ? "Now" : hourLabel(h.t),
      glyph: glyph(h.code, h.isDay),
      pop: popLabel(h.pop),
      temp: fmtTemp(h.tempC, imperial),
      value: temp(h.tempC, imperial)
    }
  })
}

// The first hourly slot is the top of the current hour; "Now" should show
// current conditions instead (at 7:34 the 7:00 slot can still be night).
function nowSlot(forecast) {
  var first = forecast.hourly[0]
  var cur = forecast.current
  return { t: first.t, pop: first.pop, code: cur.code, isDay: cur.isDay, tempC: cur.tempC }
}

// ² 10-day panel. `left`/`width` place each day's low–high bar on the
// shared range across all days (0–1); `now` puts today's dot at the
// current temperature.
function dailyView(forecast, imperial) {
  if (!forecast || !forecast.days.length) return []
  var lo = null
  var hi = null
  forecast.days.forEach(function(d) {
    if (d.minC !== null && (lo === null || d.minC < lo)) lo = d.minC
    if (d.maxC !== null && (hi === null || d.maxC > hi)) hi = d.maxC
  })
  var span = hi !== null && lo !== null && hi > lo ? hi - lo : 1
  return forecast.days.map(function(d, i) {
    var left = d.minC === null ? 0 : clamp01((d.minC - lo) / span)
    var right = d.maxC === null ? left : clamp01((d.maxC - lo) / span)
    return {
      label: i === 0 ? "Today" : dayShort(d.t),
      today: i === 0,
      glyph: glyph(d.code, 1),
      pop: popLabel(d.pop),
      lo: fmtTemp(d.minC, imperial),
      hi: fmtTemp(d.maxC, imperial),
      left: left,
      width: Math.max(0.02, right - left),
      now: i === 0 && forecast.current.tempC !== null ? clamp01((forecast.current.tempC - lo) / span) : null
    }
  })
}

// Pressure gauge position: 960–1060 hPa across the dial.
function pressurePosition(hPa) {
  var v = num(hPa)
  return v === null ? null : clamp01((v - 960) / 100)
}

// 0 good … 4 hazardous, indexing the meter color scale.
function aqiScaleLevel(aqi) {
  var v = num(aqi)
  if (v === null) return null
  return v <= 50 ? 0 : v <= 100 ? 1 : v <= 150 ? 2 : v <= 200 ? 3 : 4
}

function uvScaleLevel(uv) {
  var v = num(uv)
  if (v === null) return null
  return v < 3 ? 0 : v < 6 ? 1 : v < 8 ? 2 : v < 11 ? 3 : 4
}

// Every tile below the panels. `moon` is Astro.moon() for the location.
function tilesView(forecast, airQuality, moon, imperial, nowMs) {
  if (!forecast) return null
  var cur = forecast.current
  var aqi = airQuality ? airQuality.usAqi : null
  var aqiInfo = aqiLevel(aqi)
  var sun = sunInfo(forecast, nowMs)
  var trend = pressureTrend(forecast.pressureChange3h)
  var offset = forecast.utcOffset * 1000
  var uv = cur.uv === null ? null : Math.round(cur.uv)
  return {
    aqi: {
      value: aqi === null ? "—" : String(aqi),
      label: aqiInfo.label,
      desc: aqi === null ? "Air quality data isn't available here." : aqiInfo.desc,
      position: aqi === null ? null : clamp01(aqi / 300),
      level: aqiScaleLevel(aqi)
    },
    uv: {
      value: uv === null ? "—" : String(uv),
      label: uvLabel(cur.uv),
      desc: uvAdvice(forecast),
      position: uv === null ? null : clamp01(uv / 11),
      level: uvScaleLevel(uv)
    },
    sun: sun ? {
      title: sun.next,
      time: isNaN(sun.time) ? "—" : clock(sun.time),
      sub: sun.other + " " + (isNaN(sun.otherTime) ? "—" : clock(sun.otherTime)),
      progress: sun.progress,
      isDay: sun.isDay
    } : null,
    wind: {
      speed: speed(cur.windKmh, imperial) === null ? "—" : String(speed(cur.windKmh, imperial)),
      unit: speedUnit(imperial),
      direction: cur.windDir,
      from: compass(cur.windDir),
      gust: cur.gustKmh === null ? "—" : String(speed(cur.gustKmh, imperial))
    },
    precip: {
      past: fmtPrecip(forecast.past24PrecipMm, imperial),
      outlook: precipOutlook(forecast, imperial)
    },
    feels: {
      value: fmtTemp(cur.feelsC, imperial),
      desc: feelsDesc(cur)
    },
    humidity: {
      value: cur.humidity === null ? "—" : Math.round(cur.humidity) + "%",
      cells: cur.humidity === null ? 0 : Math.round(cur.humidity / 5),
      dew: fmtTemp(cur.dewC, imperial)
    },
    visibility: {
      value: fmtDistance(cur.visibilityM, imperial),
      desc: visibilityDesc(cur.visibilityM)
    },
    pressure: {
      value: fmtPressure(cur.pressureHpa, imperial),
      unit: pressureUnit(imperial),
      trend: trend ? trend + (trend === "steady" ? "" : " over 3h") : "",
      position: pressurePosition(cur.pressureHpa)
    },
    moon: moon ? {
      name: moon.name,
      phase: moon.phase,
      illuminated: moon.illuminated + "% illuminated",
      rise: moon.rise === null ? "no moonrise today" : "moonrise " + clock(moon.rise + offset),
      full: moon.daysToFull === 0 ? "full moon tonight" : "full moon in " + moon.daysToFull + (moon.daysToFull === 1 ? " day" : " days")
    } : null
  }
}

// Everything the bar popover shows above and below its hourly chart
// (which uses hourlyView), as display strings.
function popoverView(forecast, imperial) {
  if (!forecast) return null
  var cur = forecast.current
  var today = forecast.days[0] || {}
  var cold = coldestAhead(forecast, 5)
  var gust = speed(cur.gustKmh, imperial)
  var days = forecast.days.slice(1, 6).map(function(d) {
    return { label: dayShort(d.t).toUpperCase(), glyph: glyph(d.code, 1), hi: fmtTemp(d.maxC, imperial), lo: fmtTemp(d.minC, imperial) }
  })
  return {
    glyph: glyph(cur.code, cur.isDay),
    condition: conditionText(cur.code, cur.isDay),
    temp: String(temp(cur.tempC, imperial)),
    unit: tempUnit(imperial),
    feels: fmtTemp(cur.feelsC, imperial, true),
    feelsNote: feelsNote(cur),
    wind: speed(cur.windKmh, imperial) === null ? "—" : fmtSpeed(cur.windKmh, imperial),
    // The arrow points where the wind blows to; the label says where it's from.
    windRotation: cur.windDir === null ? 0 : (cur.windDir + 180) % 360,
    windNote: [compass(cur.windDir), gust === null ? "" : "gusts " + gust].filter(function(s) { return !!s }).join(" · "),
    humidity: cur.humidity === null ? "—" : Math.round(cur.humidity) + "%",
    dewNote: cur.dewC === null ? "" : "dew pt " + fmtTemp(cur.dewC, imperial),
    hi: fmtTemp(today.maxC, imperial),
    lo: fmtTemp(today.minC, imperial),
    coldNote: cold ? "low " + fmtTemp(cold.minC, imperial) + " " + dayShort(cold.t) : "",
    days: days
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    normalizeLocation: normalizeLocation, locationKey: locationKey, normalizeSettings: normalizeSettings,
    parseLegacyLocation: parseLegacyLocation, parseGeocoding: parseGeocoding,
    localeUsesImperial: localeUsesImperial, useImperial: useImperial,
    temp: temp, fmtTemp: fmtTemp, tempUnit: tempUnit, speed: speed, speedUnit: speedUnit, fmtSpeed: fmtSpeed,
    fmtDistance: fmtDistance, fmtPrecip: fmtPrecip, pressure: pressure, fmtPressure: fmtPressure,
    pressureUnit: pressureUnit, compass: compass,
    localMs: localMs, localNow: localNow, dateKey: dateKey, clock: clock, hourLabel: hourLabel, dayShort: dayShort, ago: ago,
    isPrecipCode: isPrecipCode, isSnowCode: isSnowCode, conditionText: conditionText, glyph: glyph, skyKind: skyKind,
    asList: asList, normalizeForecast: normalizeForecast, normalizeAirQuality: normalizeAirQuality,
    aqiLevel: aqiLevel, uvLabel: uvLabel, uvAdvice: uvAdvice, feelsNote: feelsNote, feelsDesc: feelsDesc,
    visibilityDesc: visibilityDesc, pressureTrend: pressureTrend, sunInfo: sunInfo, coldestAhead: coldestAhead,
    precipOutlook: precipOutlook, summary: summary, popoverView: popoverView,
    slug: slug, matchesQuery: matchesQuery, cardView: cardView, heroView: heroView,
    popLabel: popLabel, hourlyView: hourlyView, dailyView: dailyView, pressurePosition: pressurePosition,
    aqiScaleLevel: aqiScaleLevel, uvScaleLevel: uvScaleLevel, tilesView: tilesView
  }
}

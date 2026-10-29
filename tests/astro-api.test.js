// Run with: node --test tests/*.test.js
const test = require("node:test")
const assert = require("node:assert/strict")
const Astro = require("../Astro.js")
const Api = require("../Api.js")

test("moon illumination matches known phases", () => {
  // Full moon 13 Jan 2025 22:27 UTC; new moon 29 Jan 2025 12:36 UTC.
  const full = Astro.illumination(Date.parse("2025-01-13T22:27:00Z"))
  assert.ok(full.fraction > 0.99, String(full.fraction))
  assert.equal(Astro.phaseName(full.phase), "Full Moon")
  const fresh = Astro.illumination(Date.parse("2025-01-29T12:36:00Z"))
  assert.ok(fresh.fraction < 0.01, String(fresh.fraction))
  assert.equal(Astro.phaseName(fresh.phase), "New Moon")
  assert.equal(Astro.phaseName(0.1), "Waxing Crescent")
  assert.equal(Astro.phaseName(0.62), "Waning Gibbous")
  assert.equal(Astro.daysToFull(0.25), 7)
  assert.equal(Astro.daysToFull(0.75), 22)
})

test("moon tile for Omaha on 16 Oct 2026", () => {
  const now = Date.parse("2026-10-16T19:52:00Z")
  const moon = Astro.moon(now, 41.25626, -95.94043, -18000)
  assert.equal(moon.name, "Waxing Crescent")
  assert.ok(moon.illuminated > 20 && moon.illuminated < 45, String(moon.illuminated))
  // Moonrise falls on the location's local day (16 Oct, CDT), early afternoon.
  const local = new Date(moon.rise - 18000000)
  assert.equal(local.toISOString().slice(0, 10), "2026-10-16")
  assert.ok(local.getUTCHours() >= 11 && local.getUTCHours() <= 15, local.toISOString())
})

test("one forecast request covers every location", () => {
  const url = Api.forecastUrl([{ latitude: 51.50853, longitude: -0.12574 }, { latitude: 41.25626, longitude: -95.94043 }])
  assert.match(url, /latitude=51\.50853,41\.25626&longitude=-0\.12574,-95\.94043/)
  assert.match(url, /timezone=auto/)
  assert.match(url, /dew_point_2m/)
  assert.match(Api.airQualityUrl([{ latitude: 1, longitude: 2 }]), /current=us_aqi/)
  assert.equal(Api.geocodeUrl("São Paulo"), "https://geocoding-api.open-meteo.com/v1/search?name=S%C3%A3o%20Paulo&count=8&language=en&format=json")
  assert.equal(Api.alertsUrl({ latitude: 41.25626, longitude: -95.94043 }), "https://api.weather.gov/alerts/active?point=41.2563,-95.9404")
})

test("NWS coverage", () => {
  assert.equal(Api.nwsCovers({ countryCode: "US", latitude: 0, longitude: 0 }), true)
  assert.equal(Api.nwsCovers({ countryCode: "PR", latitude: 18.4, longitude: -66.1 }), true)
  assert.equal(Api.nwsCovers({ countryCode: "GB", latitude: 51.5, longitude: -0.1 }), false)
  assert.equal(Api.nwsCovers({ latitude: 41.25626, longitude: -95.94043 }), true)
  assert.equal(Api.nwsCovers({ latitude: 61.2, longitude: -149.9 }), true)
  assert.equal(Api.nwsCovers({ latitude: 51.5, longitude: -0.1 }), false)
  assert.equal(Api.nwsCovers(null), false)
})

test("only NWS requests carry the User-Agent", () => {
  const nws = Api.curl("https://api.weather.gov/alerts/active?point=1,2")
  assert.ok(nws.command.includes(Api.USER_AGENT))
  assert.ok(!Api.curl("https://api.open-meteo.com/v1/forecast").command.includes("-A"))
})

test("request URLs stay out of process arguments", () => {
  const url = Api.geocodeUrl("Omaha \"NE\"")
  const request = Api.curl(url, 6)
  assert.ok(!request.command.some(arg => arg.includes("Omaha") || arg.includes("open-meteo")))
  assert.ok(request.command.includes("6"))
  assert.equal(request.environment.ISOBAR_CURL_CONFIG,
    'url = "' + url.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"')
})

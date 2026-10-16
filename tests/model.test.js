// Run with: node --test tests/*.test.js
const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const Model = require("../Model.js")

const fixture = (name) => fs.readFileSync(path.join(__dirname, "fixtures", name), "utf8")
// Omaha's fixture was captured at 2:52 PM CDT on Fri 16 Oct 2026.
const NOW = Date.parse("2026-10-16T19:52:00Z")
const omaha = () => Model.normalizeForecast(JSON.parse(fixture("forecast-omaha.json")), NOW)

test("settings fill defaults and drop invalid locations", () => {
  const s = Model.normalizeSettings({
    locations: [
      { name: "Omaha", latitude: 41.25626, longitude: -95.94043, countryCode: "us" },
      { name: "Duplicate", latitude: 41.256261, longitude: -95.940431 },
      { name: "", latitude: 1, longitude: 2 },
      { name: "Nowhere", latitude: 95, longitude: 0 },
      { name: "London", region: "England, United Kingdom", latitude: "51.50853", longitude: "-0.12574" }
    ],
    selected: 7,
    units: "Imperial",
    refreshMinutes: 2
  })
  assert.deepEqual(s.locations.map((l) => l.name), ["Omaha", "London"])
  assert.equal(s.locations[0].countryCode, "US")
  assert.equal(s.locations[1].latitude, 51.50853)
  assert.equal(s.selected, 0)
  assert.equal(s.units, "imperial")
  assert.equal(s.skyFx, true)
  assert.equal(s.refreshMinutes, 10)
  assert.equal(s.scrollSpeed, 250)
  assert.equal(Model.normalizeSettings({ scrollSpeed: 400 }).scrollSpeed, 400)
  assert.equal(Model.normalizeSettings({ scrollSpeed: 5000 }).scrollSpeed, 800)
  assert.equal(Model.normalizeSettings({ scrollSpeed: "fast" }).scrollSpeed, 250)
})

test("the stock widget's location seeds a missing list, not an emptied one", () => {
  const legacy = Model.parseLegacyLocation('{"name": "Omaha", "latitude": 41.25626, "longitude": -95.94043}')
  assert.equal(Model.normalizeSettings({}, legacy).locations[0].name, "Omaha")
  // Removing the last location saves an empty list; that has to stick.
  assert.deepEqual(Model.normalizeSettings({ locations: [] }, legacy).locations, [])
  assert.equal(Model.normalizeSettings({ locations: [{ name: "Oslo", latitude: 59.9, longitude: 10.7 }] }, legacy).locations[0].name, "Oslo")
  assert.equal(Model.parseLegacyLocation(""), null)
  assert.equal(Model.parseLegacyLocation('{"name": "Paris"}'), null)
  assert.deepEqual(Model.normalizeSettings(null, null).locations, [])
})

test("geocoding results become locations with region and country code", () => {
  const rows = Model.parseGeocoding(fixture("geocode-omaha.json"))
  assert.deepEqual(rows[0], {
    name: "Omaha", region: "Nebraska, United States", latitude: 41.25626, longitude: -95.94043, countryCode: "US"
  })
  assert.deepEqual(Model.parseGeocoding("{}"), [])
  assert.deepEqual(Model.parseGeocoding("not json"), [])
})

test("unit conversions", () => {
  assert.equal(Model.useImperial("auto", "en_US.UTF-8"), true)
  assert.equal(Model.useImperial("auto", "en_GB"), false)
  assert.equal(Model.useImperial("metric", "en_US"), false)
  assert.equal(Model.fmtTemp(5.7, true), "42°")
  assert.equal(Model.fmtTemp(5.7, false, true), "6°C")
  assert.equal(Model.fmtTemp(null, true), "—")
  assert.equal(Model.fmtSpeed(6.4, true), "4 mph")
  assert.equal(Model.fmtSpeed(6.4, false), "6 km/h")
  assert.equal(Model.fmtDistance(25500, true), "16 mi")
  assert.equal(Model.fmtDistance(4200, false), "4.2 km")
  assert.equal(Model.fmtPrecip(7.62, true), "0.30 in")
  assert.equal(Model.fmtPrecip(7.62, false), "7.6 mm")
  assert.equal(Model.fmtPressure(1035.5, true), "30.58")
  assert.equal(Model.fmtPressure(1035.5, false), "1036")
  assert.deepEqual([0, 44, 135, 192, 315, 350, -45].map(Model.compass), ["N", "NE", "SE", "S", "NW", "N", "NW"])
})

test("time labels read the location's wall clock", () => {
  const t = Model.localMs("2026-10-15T22:00")
  assert.equal(Model.clock(t), "10:00 PM")
  assert.equal(Model.hourLabel(t), "10P")
  assert.equal(Model.hourLabel(Model.localMs("2026-10-16T00:00")), "12A")
  assert.equal(Model.dayShort(Model.localMs("2026-10-16")), "Fri")
  assert.equal(Model.clock(Model.localNow(NOW, -18000)), "2:52 PM")
  assert.equal(Model.ago(NOW - 20000, NOW), "updated just now")
  assert.equal(Model.ago(NOW - 2 * 60000, NOW), "updated 2 min ago")
  assert.equal(Model.ago(NOW - 3 * 3600000, NOW), "updated 3 h ago")
})

test("conditions map to text, glyphs and skies", () => {
  assert.equal(Model.conditionText(0, 1), "Sunny")
  assert.equal(Model.conditionText(0, 0), "Clear")
  assert.equal(Model.conditionText(99, 1), "Thunderstorms, Hail")
  assert.equal(Model.glyph(0, 0), "\ue32b")
  assert.equal(Model.glyph(0, 1), "\ue30d")
  assert.equal(Model.glyph(73, 1), "\ue31a")
  assert.deepEqual([[0, 0], [0, 1], [2, 1], [3, 1], [45, 0], [63, 1], [95, 1], [75, 0]].map((a) => Model.skyKind(a[0], a[1])),
    ["stars", "sun", "partly", "clouds", "clouds", "rain", "storm", "snow"])
})

test("a forecast normalizes from the current hour", () => {
  const f = omaha()
  assert.equal(f.timezone, "America/Chicago")
  assert.equal(f.utcOffset, -18000)
  assert.equal(f.current.tempC, 10.2)
  assert.equal(f.current.windDir, 345)
  assert.equal(f.hourly.length, 24)
  assert.equal(Model.hourLabel(f.hourly[0].t), "2P")
  assert.equal(f.days.length, 10)
  assert.equal(f.days[0].date, "2026-10-16")
  assert.equal(f.past24PrecipMm, 1.7)
  assert.equal(f.pressureChange3h, -1)
})

test("a multi-location response normalizes per location", () => {
  const list = Model.asList(fixture("forecast-multi.json"))
  assert.deepEqual(list.map((r) => r.timezone), ["Europe/London", "America/Chicago"])
  const london = Model.normalizeForecast(list[0], NOW)
  assert.equal(Model.hourLabel(london.hourly[0].t), "8P")
  assert.equal(london.days[0].date, "2026-10-16")
  assert.deepEqual(Model.asList("garbage"), [])
  assert.equal(Model.normalizeForecast({}, NOW), null)
})

test("air quality reads the current US AQI", () => {
  const list = Model.asList(fixture("aq-multi.json")).map(Model.normalizeAirQuality)
  assert.deepEqual(list.map((a) => a.usAqi), [28, 28])
  assert.equal(Model.aqiLevel(28).label, "Good")
  assert.equal(Model.aqiLevel(151).label, "Unhealthy")
  assert.equal(Model.aqiLevel(400).label, "Hazardous")
  assert.equal(Model.normalizeAirQuality({ current: {} }), null)
})

test("tile copy from the Omaha forecast", () => {
  const f = omaha()
  assert.equal(Model.feelsNote(f.current), "wind chill")
  assert.equal(Model.feelsDesc(f.current), "Wind is making it feel colder.")
  assert.equal(Model.uvAdvice(f), "Use sun protection until 5:00 PM.")
  assert.equal(Model.precipOutlook(f, true), "0.07 in expected Wed.")
  assert.equal(Model.visibilityDesc(f.current.visibilityM), "Perfectly clear view.")
  assert.equal(Model.pressureTrend(f.pressureChange3h), "falling")
  assert.equal(Model.pressureTrend(-0.4), "steady")
  const cold = Model.coldestAhead(f, 5)
  assert.equal(Model.fmtTemp(cold.minC, true), "35°")
  assert.equal(Model.dayShort(cold.t), "Sat")
  const sun = Model.sunInfo(f, NOW)
  assert.equal(sun.next, "sunset")
  assert.equal(Model.clock(sun.time), "6:41 PM")
  assert.equal(sun.isDay, true)
})

// A minimal normalized forecast for summary scenarios.
function synthetic(hourStart, hours, overrides) {
  const start = Model.localMs(hourStart)
  return Object.assign({
    utcOffset: 0,
    current: { tempC: 10, code: 0, isDay: 1, gustKmh: 10 },
    hourly: hours.map((h, i) => Object.assign({ t: start + i * 3600000, tempC: 10, pop: 0, code: 0 }, h)),
    days: [{ maxC: 18, minC: 4 }]
  }, overrides)
}

test("summary leads with precipitation, then the high or low", () => {
  assert.equal(Model.summary(omaha(), NOW, true), "Mostly Sunny today, high 52°.")

  const afternoon = Date.parse("2026-10-15T13:10:00Z")
  const dry = synthetic("2026-10-15T13:00", new Array(12).fill({}))
  assert.equal(Model.summary(dry, afternoon, false), "Sunny today, high 18°.")

  const showers = synthetic("2026-10-15T13:00", [{}, {}, { pop: 70, code: 61 }, {}])
  assert.equal(Model.summary(showers, afternoon, false), "Rain likely around 3:00 PM. High 18° today.")

  const snowing = synthetic("2026-10-15T20:00", [{ code: 73, pop: 90, tempC: 1 }, { code: 73, pop: 80, tempC: -1 }, { code: 3, pop: 10, tempC: -2 }],
    { current: { tempC: 1, code: 73, isDay: 0, gustKmh: 60 } })
  assert.equal(Model.summary(snowing, Date.parse("2026-10-15T20:30:00Z"), false),
    "Snow ending around 10:00 PM. Low -2° tonight, below freezing. Gusts up to 60 km/h.")
})

test("the popover view from the Omaha forecast", () => {
  const v = Model.popoverView(omaha(), true)
  assert.equal(v.temp, "50")
  assert.equal(v.unit, "°F")
  assert.equal(v.glyph, "\ue30d")
  assert.equal(v.condition, "Mostly Sunny")
  assert.equal(v.feels, "40°F")
  assert.equal(v.feelsNote, "wind chill")
  assert.equal(v.wind, "16 mph")
  assert.equal(v.windRotation, 165)
  assert.equal(v.windNote, "N · gusts 27")
  assert.equal(v.humidity, "57%")
  assert.equal(v.dewNote, "dew pt 36°")
  assert.equal(v.hi, "52°")
  assert.equal(v.lo, "41°")
  assert.equal(v.coldNote, "low 35° Sat")
  assert.deepEqual(v.days.map((d) => d.label), ["SAT", "SUN", "MON", "TUE", "WED"])
  assert.equal(v.days[1].hi, "66°")
  assert.equal(Model.popoverView(null, true), null)
  assert.equal(Model.popoverView(omaha(), false).windNote, "N · gusts 44")
})

test("app views: slug, filter, sidebar card and hero", () => {
  assert.equal(Model.slug("Omaha"), "omaha")
  assert.equal(Model.slug("  São Paulo, BR "), "s-o-paulo-br")
  const omahaLoc = { name: "Omaha", region: "Nebraska, United States" }
  assert.equal(Model.matchesQuery(omahaLoc, "oma neb"), true)
  assert.equal(Model.matchesQuery(omahaLoc, "lincoln"), false)
  assert.equal(Model.matchesQuery(omahaLoc, ""), true)

  const card = Model.cardView(omahaLoc, omaha(), true, NOW)
  assert.deepEqual(card, { name: "Omaha", time: "2:52 PM", glyph: "\ue30d", temp: "50°", condition: "Mostly Sunny", hi: "52°", lo: "41°" })
  assert.equal(Model.cardView(omahaLoc, null, true, NOW).temp, "—")

  const hero = Model.heroView(omahaLoc, omaha(), false, NOW)
  assert.equal(hero.region, "Nebraska, United States")
  assert.equal(hero.temp, "10°")
  assert.equal(hero.summary, "Mostly Sunny today, high 11°.")
  assert.equal(Model.heroView(omahaLoc, null, false, NOW), null)
})

test("hourly and 10-day panels", () => {
  const hours = Model.hourlyView(omaha(), true)
  assert.equal(hours.length, 24)
  assert.deepEqual(hours[0], { label: "Now", glyph: "\ue30d", pop: "", temp: "50°", value: 50 })
  assert.equal(Model.popLabel(5), "")
  assert.equal(Model.popLabel(58), "60%")
  assert.deepEqual(Model.hourlyView(null, true), [])

  const days = Model.dailyView(omaha(), true)
  assert.equal(days.length, 10)
  assert.equal(days[0].label, "Today")
  assert.equal(days[0].pop, "")
  assert.equal(days[7].pop, "20%")
  assert.equal(days[1].label, "Sat")
  // Sat holds the coldest low and the next Sat the warmest high across the 10 days.
  assert.equal(days[1].left, 0)
  assert.ok(Math.abs(days[8].left + days[8].width - 1) < 1e-9)
  assert.ok(days[0].now > days[0].left && days[0].now < days[0].left + days[0].width)
  assert.equal(days[1].now, null)
})

test("tiles from the Omaha forecast", () => {
  const Astro = require("../Astro.js")
  const aq = Model.normalizeAirQuality(Model.asList(fixture("aq-multi.json"))[1])
  const t = Model.tilesView(omaha(), aq, Astro.moon(NOW, 41.25626, -95.94043, -18000), true, NOW)
  assert.deepEqual(t.aqi, { value: "28", label: "Good", desc: "Air quality is satisfactory and poses little or no risk.", position: 28 / 300, level: 0 })
  assert.deepEqual([0, 51, 101, 151, 201, 400].map(Model.aqiScaleLevel), [0, 1, 2, 3, 4, 4])
  assert.deepEqual([0, 3, 6, 8, 11].map(Model.uvScaleLevel), [0, 1, 2, 3, 4])
  assert.equal(t.uv.value, "4")
  assert.equal(t.uv.label, "Moderate")
  assert.equal(t.sun.title, "sunset")
  assert.equal(t.sun.time, "6:41 PM")
  assert.equal(t.sun.sub, "sunrise 7:37 AM")
  assert.equal(t.sun.isDay, true)
  assert.ok(t.sun.progress > 0.6 && t.sun.progress < 0.7, String(t.sun.progress))
  assert.deepEqual(t.wind, { speed: "16", unit: "mph", direction: 345, from: "N", gust: "27" })
  assert.deepEqual(t.precip, { past: "0.07 in", outlook: "0.07 in expected Wed." })
  assert.deepEqual(t.humidity, { value: "57%", cells: 11, dew: "36°" })
  assert.equal(t.pressure.value, "30.50")
  assert.equal(t.pressure.trend, "falling over 3h")
  assert.equal(t.moon.name, "Waxing Crescent")
  assert.equal(t.moon.rise, "moonrise 1:46 PM")
  assert.equal(t.moon.full, "full moon in 9 days")

  const metric = Model.tilesView(omaha(), null, null, false, NOW)
  assert.equal(metric.aqi.value, "—")
  assert.equal(metric.aqi.position, null)
  assert.equal(metric.pressure.unit, "hPa")
  assert.equal(metric.wind.unit, "km/h")
  assert.equal(metric.moon, null)
  assert.equal(Model.tilesView(null), null)
})

test("Now shows current conditions, not the top-of-hour slot", () => {
  // 7:34 AM, sunny now, but the 7:00 slot was still before sunrise.
  const f = synthetic("2026-10-16T07:00", [{ code: 0, tempC: 1.7 }, { code: 0, tempC: 4 }],
    { current: { tempC: 1.1, code: 0, isDay: 1, gustKmh: 0 } })
  f.hourly[0].isDay = 0
  const hours = Model.hourlyView(f, true)
  assert.equal(hours[0].glyph, "")
  assert.equal(hours[0].temp, "34°")
})

// Run with: node --test tests/*.test.js
const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const Radar = require("../Radar.js")

const fixture = (name) => fs.readFileSync(path.join(__dirname, "fixtures", name), "utf8")

test("projection matches the standard slippy-map tile for Omaha", () => {
  // Omaha, NE sits in tile 29/47 at zoom 7.
  const p = Radar.project(41.25626, -95.94043, 7)
  assert.equal(Math.floor(p.x / 256), 29)
  assert.equal(Math.floor(p.y / 256), 47)
  const origin = Radar.project(0, 0, 0)
  assert.ok(Math.abs(origin.x - 128) < 1e-9 && Math.abs(origin.y - 128) < 1e-9)
})

test("tiles cover the view, centered on the location", () => {
  const t = Radar.tiles(41.25626, -95.94043, 7, 600, 240)
  // Every pixel of the view is covered by some tile.
  for (const [vx, vy] of [[0, 0], [599, 0], [0, 239], [599, 239], [300, 120]])
    assert.ok(t.some((k) => vx >= k.left && vx < k.left + 256 && vy >= k.top && vy < k.top + 256), `${vx},${vy}`)
  // The center pixel falls in Omaha's tile.
  const center = t.find((k) => 300 >= k.left && 300 < k.left + 256 && 120 >= k.top && 120 < k.top + 256)
  assert.deepEqual([center.x, center.y, center.z], [29, 47, 7])
})

test("tiles wrap across the antimeridian", () => {
  const t = Radar.tiles(-17.7, 179.9, 3, 600, 240)
  const xs = new Set(t.map((k) => k.x))
  assert.ok(xs.has(0) && xs.has(7))
  assert.ok(t.every((k) => k.x >= 0 && k.x < 8))
})

test("weather-maps.json parses into frames, oldest first", () => {
  const radar = Radar.parseFrames(fixture("rainviewer-maps.json"))
  assert.equal(radar.host, "https://tilecache.rainviewer.com")
  assert.equal(radar.frames.length, 13)
  assert.ok(radar.frames.every((f, i) => i === 0 || f.time > radar.frames[i - 1].time))
  assert.equal(radar.frames[12].time - radar.frames[0].time, 2 * 3600 * 1000)
  assert.equal(Radar.parseFrames("{}"), null)
  assert.equal(Radar.parseFrames("nope"), null)
})

test("tile URLs and frame labels", () => {
  const tile = { x: 26, y: 48, z: 7 }
  assert.equal(Radar.radarUrl("https://tilecache.rainviewer.com", { path: "/v2/radar/abc" }, tile),
    "https://tilecache.rainviewer.com/v2/radar/abc/512/7/26/48/2/1_1.png")
  const newest = { time: 7200000 }
  assert.equal(Radar.frameLabel(newest, newest), "now")
  assert.equal(Radar.frameLabel({ time: 6600000 }, newest), "−10m")
  assert.equal(Radar.frameLabel({ time: 2400000 }, newest), "−1h 20m")
  assert.equal(Radar.frameLabel(undefined, newest), "")
  assert.equal(Radar.frameLabel({ time: 0 }, newest), "−2h")
  assert.equal(Radar.clampZoom(9), 7)
  assert.equal(Radar.clampZoom(1), 3)
  assert.equal(Radar.fullMapUrl(41.25626, -95.94043, 7), "https://www.rainviewer.com/map.html?loc=41.2563,-95.9404,7")
})

test("the base map clips to the view with non-overlapping city labels", () => {
  const basemap = require("../data/basemap.json")
  const v = Radar.basemapView(basemap, 41.25626, -95.94043, 7, 600, 400)
  assert.ok(v.lines.some((l) => l.kind === 2), "state borders around Nebraska")
  assert.deepEqual(v.places.map((p) => p.name), ["Des Moines"])
  // Des Moines is due east of Omaha, about 2° of longitude away.
  const [desMoines] = v.places
  assert.ok(desMoines.x > 450 && Math.abs(desMoines.y - 200) < 60, JSON.stringify(desMoines))

  const london = Radar.basemapView(basemap, 51.5, -0.12, 6, 600, 400)
  assert.ok(london.lines.some((l) => l.kind === 0) && london.lines.some((l) => l.kind === 1))
  assert.equal(london.places.length, 8)
  assert.equal(Radar.basemapView(basemap, 51.5, -0.12, 6, 600, 400, 3).places.length, 3)
  assert.deepEqual(Radar.basemapView(null, 0, 0, 5, 100, 100), { lines: [], places: [] })
})

test("the base map wraps across the antimeridian like the tiles", () => {
  const basemap = require("../data/basemap.json")
  // Suva, Fiji at 178.4°E: the right half of the view is past 180°.
  const v = Radar.basemapView(basemap, -18.14, 178.44, 5, 600, 400)
  const maxX = Math.max(...v.lines.flatMap((l) => l.points.filter((_, i) => i % 2 === 0)))
  assert.ok(maxX > 500, "coastlines east of 180°: " + maxX)
  // Samoa and Tonga lie east of the line; their labels land right of center.
  const east = v.places.filter((p) => p.x > 300).map((p) => p.name)
  assert.ok(east.includes("Apia") && east.includes("Nuku'alofa"), JSON.stringify(east))
})

test("full-map redirect page carries the escaped URL", () => {
  const url = Radar.fullMapUrl(41.2563, -95.9404, 7)
  const page = Radar.fullMapRedirect(url + "&x=<b>")
  assert.ok(page.includes('content="0;url=' + url + '&amp;x=&lt;b>"'))
  assert.ok(!page.includes("<b>"))
})

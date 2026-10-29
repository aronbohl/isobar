// Precipitation radar: RainViewer frames over a base map drawn from Natural
// Earth (data/basemap.json), positioned with Web Mercator tile math. Pure,
// so tests/radar.test.js can check it. (CARTO's free base-map tiles now
// require an API key and return a watermark without one.)
//
// RainViewer's free API (checked 2026-10): past frames only (2 h at 10 min),
// zoom ≤ 7 (higher zooms return a "Zoom Level Not Supported" tile), and a
// single color scheme ("Universal Blue", requested as color 2).

var TILE = 256
var MIN_ZOOM = 3
var MAX_ZOOM = 7

var MAPS_URL = "https://api.rainviewer.com/public/weather-maps.json"

// Universal Blue, light → heavy, sampled from live tiles; for the legend.
var LEGEND = ["#88ddee", "#0091ca", "#004768", "#ffee00", "#ff8100", "#e00000", "#ff60ff"]

function clampZoom(z) {
  return Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, Math.round(Number(z) || MAX_ZOOM)))
}

// Latitude/longitude → global pixel position at zoom z.
function project(lat, lon, z) {
  var size = TILE * Math.pow(2, z)
  var clamped = Math.max(-85.05112878, Math.min(85.05112878, lat))
  var s = Math.sin(clamped * Math.PI / 180)
  return {
    x: (lon + 180) / 360 * size,
    y: (0.5 - Math.log((1 + s) / (1 - s)) / (4 * Math.PI)) * size
  }
}

// The tiles covering a width × height view centered on lat/lon:
// [{ x, y, z, left, top }] with x wrapped around the antimeridian and
// left/top the tile's offset inside the view.
function tiles(lat, lon, z, width, height) {
  var center = project(lat, lon, z)
  var originX = center.x - width / 2
  var originY = center.y - height / 2
  var count = Math.pow(2, z)
  var out = []
  var x0 = Math.floor(originX / TILE)
  var x1 = Math.floor((originX + width) / TILE)
  var y0 = Math.max(0, Math.floor(originY / TILE))
  var y1 = Math.min(count - 1, Math.floor((originY + height) / TILE))
  for (var ty = y0; ty <= y1; ty++) {
    for (var tx = x0; tx <= x1; tx++) {
      out.push({
        x: ((tx % count) + count) % count,
        y: ty,
        z: z,
        left: Math.round(tx * TILE - originX),
        top: Math.round(ty * TILE - originY)
      })
    }
  }
  return out
}

// weather-maps.json → { host, frames: [{ time (ms), path }] }, oldest first.
function parseFrames(raw) {
  try {
    var data = typeof raw === "string" ? JSON.parse(raw) : raw
    var past = data && data.radar && Array.isArray(data.radar.past) ? data.radar.past : []
    var frames = past.filter(function(f) { return f && f.path && isFinite(f.time) })
      .map(function(f) { return { time: f.time * 1000, path: String(f.path) } })
    frames.sort(function(a, b) { return a.time - b.time })
    return frames.length && data.host ? { host: String(data.host), frames: frames } : null
  } catch (e) {
    return null
  }
}

// 512px images for each 256px tile, so radar stays sharp on HiDPI screens.
function radarUrl(host, frame, tile) {
  return host + frame.path + "/512/" + tile.z + "/" + tile.x + "/" + tile.y + "/2/1_1.png"
}

// "now" for the newest frame, else how long before it: "−10m", "−1h 20m".
function frameLabel(frame, newest) {
  // Bindings can ask mid-update, before the frame index catches up.
  if (!frame || !newest) return ""
  var minutes = Math.round((newest.time - frame.time) / 60000)
  if (minutes <= 0) return "now"
  var h = Math.floor(minutes / 60)
  var m = minutes % 60
  return "−" + (h ? h + "h" + (m ? " " + m + "m" : "") : m + "m")
}

// Base map (data/basemap.json, Natural Earth) clipped to a view: lines as
// flat [x, y, …] pixel arrays and up to `maxPlaces` city labels that don't
// overlap each other or the location's own label at the center.
function basemapView(basemap, lat, lon, z, width, height, maxPlaces) {
  if (!basemap) return { lines: [], places: [] }
  var center = project(lat, lon, z)
  var ox = center.x - width / 2
  var oy = center.y - height / 2
  // The view's bounds in degrees, to skip lines that can't be in it.
  var size = TILE * Math.pow(2, z)
  var west = ox / size * 360 - 180
  var east = (ox + width) / size * 360 - 180
  function latAt(py) {
    var n = Math.PI - 2 * Math.PI * py / size
    return 180 / Math.PI * Math.atan(0.5 * (Math.exp(n) - Math.exp(-n)))
  }
  var north = latAt(oy)
  var south = latAt(oy + height)

  // Near the antimeridian the view runs past ±180°, as the radar tiles do;
  // the map's copies one world to either side fill that in.
  var shifts = [0]
  if (west < -180) shifts.push(-360)
  if (east > 180) shifts.push(360)

  var lines = []
  for (var i = 0; i < basemap.lines.length; i++) {
    var l = basemap.lines[i]
    if (l[4] < south || l[2] > north) continue
    for (var s = 0; s < shifts.length; s++) {
      var shift = shifts[s]
      if (l[3] + shift < west || l[1] + shift > east) continue
      var pts = []
      for (var j = 5; j < l.length; j += 2) {
        var p = project(l[j + 1], l[j], z)
        pts.push(Math.round((p.x + shift / 360 * size - ox) * 10) / 10, Math.round((p.y - oy) * 10) / 10)
      }
      lines.push({ kind: l[0], points: pts })
    }
  }

  // Greedy by importance (rank 0 first); a label is ~7px a character.
  var taken = [{ x0: width / 2 - 10, y0: height / 2 - 12, x1: width / 2 + 120, y1: height / 2 + 12 }]
  var places = []
  var limit = maxPlaces === undefined ? 8 : maxPlaces
  for (var k = 0; k < basemap.places.length && places.length < limit; k++) {
    var pl = basemap.places[k]
    if (pl[2] < south || pl[2] > north) continue
    var lonShift = null
    for (var t = 0; t < shifts.length; t++)
      if (pl[1] + shifts[t] >= west && pl[1] + shifts[t] <= east) lonShift = shifts[t]
    if (lonShift === null) continue
    var q = project(pl[2], pl[1], z)
    var x = q.x + lonShift / 360 * size - ox
    var y = q.y - oy
    var box = { x0: x - 4, y0: y - 9, x1: x + 10 + pl[0].length * 7, y1: y + 9 }
    if (box.x1 > width - 4 || box.y0 < 2 || box.y1 > height - 22) continue
    var overlaps = taken.some(function(t) { return box.x0 < t.x1 && box.x1 > t.x0 && box.y0 < t.y1 && box.y1 > t.y0 })
    if (overlaps) continue
    taken.push(box)
    places.push({ name: pl[0], x: Math.round(x), y: Math.round(y), rank: pl[3] })
  }
  return { lines: lines, places: places }
}

// RainViewer's full map, centered on the location ("m" in the app).
function fullMapUrl(lat, lon, z) {
  return "https://www.rainviewer.com/map.html?loc=" + Number(lat).toFixed(4) + "," + Number(lon).toFixed(4) + "," + clampZoom(z)
}

// A local page that forwards to the full map. Opening it instead of the URL
// keeps the coordinates out of the browser's process arguments.
function fullMapRedirect(url) {
  var safe = String(url).replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;")
  return '<!doctype html><meta charset="utf-8"><meta name="referrer" content="no-referrer">'
    + '<meta http-equiv="refresh" content="0;url=' + safe + '"><title>Radar</title>'
    + '<a href="' + safe + '">Open the radar map</a>\n'
}

if (typeof module !== "undefined") {
  module.exports = {
    TILE: TILE, MIN_ZOOM: MIN_ZOOM, MAX_ZOOM: MAX_ZOOM, MAPS_URL: MAPS_URL, LEGEND: LEGEND,
    clampZoom: clampZoom, project: project, tiles: tiles, parseFrames: parseFrames,
    radarUrl: radarUrl, frameLabel: frameLabel, basemapView: basemapView, fullMapUrl: fullMapUrl, fullMapRedirect: fullMapRedirect
  }
}

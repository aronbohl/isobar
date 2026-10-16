// Builds data/basemap.json, the radar's base map, from Natural Earth 1:50m
// GeoJSON (public domain, https://www.naturalearthdata.com):
//
//   node tools/build-basemap.js <dir with the .geojson files> > data/basemap.json
//
// Needs ne_50m_coastline, ne_50m_lakes, ne_50m_admin_0_boundary_lines_land,
// ne_50m_admin_1_states_provinces_lines and ne_50m_populated_places_simple
// from github.com/nvkelso/natural-earth-vector/tree/master/geojson.
//
// Output: { lines: [[kind, minLon, minLat, maxLon, maxLat, lon, lat, lon,
// lat, …]], places: [[name, lon, lat, rank]] }. kind 0 = coast or lake,
// 1 = country border, 2 = state/province border. Coordinates are rounded
// to 0.01° (~1 km), finer than the 1:50m source resolves.

const fs = require("node:fs")
const path = require("node:path")

const dir = process.argv[2]
if (!dir) {
  console.error("usage: node tools/build-basemap.js <geojson dir>")
  process.exit(1)
}

const read = (name) => JSON.parse(fs.readFileSync(path.join(dir, name + ".geojson"), "utf8"))
const round = (v) => Math.round(v * 100) / 100

// Every line of a geometry as arrays of [lon, lat]; polygon rings count too.
function linesOf(geometry) {
  if (!geometry) return []
  switch (geometry.type) {
    case "LineString": return [geometry.coordinates]
    case "MultiLineString": return geometry.coordinates
    case "Polygon": return geometry.coordinates
    case "MultiPolygon": return geometry.coordinates.flat()
    default: return []
  }
}

function pack(kind, coords) {
  const flat = []
  let lastLon = null
  let lastLat = null
  for (const [lon, lat] of coords) {
    const x = round(lon)
    const y = round(lat)
    if (x === lastLon && y === lastLat) continue
    flat.push(x, y)
    lastLon = x
    lastLat = y
  }
  if (flat.length < 4) return null
  let minLon = Infinity, minLat = Infinity, maxLon = -Infinity, maxLat = -Infinity
  for (let i = 0; i < flat.length; i += 2) {
    minLon = Math.min(minLon, flat[i]); maxLon = Math.max(maxLon, flat[i])
    minLat = Math.min(minLat, flat[i + 1]); maxLat = Math.max(maxLat, flat[i + 1])
  }
  return [kind, minLon, minLat, maxLon, maxLat, ...flat]
}

const lines = []
const layers = [
  ["ne_50m_coastline", 0],
  ["ne_50m_lakes", 0],
  ["ne_50m_admin_0_boundary_lines_land", 1],
  ["ne_50m_admin_1_states_provinces_lines", 2]
]
for (const [name, kind] of layers) {
  for (const feature of read(name).features) {
    for (const coords of linesOf(feature.geometry)) {
      const packed = pack(kind, coords)
      if (packed) lines.push(packed)
    }
  }
}

const places = read("ne_50m_populated_places_simple").features
  .map((f) => [String(f.properties.name || "").replace(/\s+/g, " ").trim(), round(f.geometry.coordinates[0]), round(f.geometry.coordinates[1]), f.properties.scalerank])
  .filter((p) => p[0] && isFinite(p[1]) && isFinite(p[2]))
  .sort((a, b) => a[3] - b[3])

process.stdout.write(JSON.stringify({
  source: "Natural Earth 1:50m (public domain)",
  lines,
  places
}))

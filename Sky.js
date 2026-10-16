// The app's ASCII sky: a character-grid simulation redrawn ~10 times a
// second behind the hero, in two layers (dim and bright). Ported from the
// design mockup. Pure: `random` is injectable so tests are deterministic.
//
// Kinds (Model.skyKind): stars · sun · partly · clouds · rain · storm · snow.
// Wind above 35 km/h adds horizontal streaks and slants the rain.

var CLOUDS = [
  ["   .--.    ", ".-(    ).  ", "(___.__)__)"],
  ["      .-~~~-.     ", "  .- ~  ~    ~-.  ", " (   ~    ~     ) ", "  `-.________.-'  "],
  ["    _.--._    ", " .-(      )-. ", "(____________)"]
]
var TWINKLE = [" ", ".", "·", "+", "*", "+", "·", ".", " ", " ", " "]

function create(kind, windKmh, cols, rows, random) {
  var R = random || Math.random
  var wind = Math.max(0, Number(windKmh) || 0)
  var s = {
    kind: kind, cols: cols, rows: rows, f: 0,
    slant: Math.min(0.9, wind / 60),
    drops: [], flakes: [], stars: [], clouds: [], streaks: [], shoot: null, bolt: null
  }
  var wet = kind === "rain" || kind === "storm"
  var i
  if (wet) {
    var drops = Math.round(cols * (kind === "storm" ? 1.3 : 0.9))
    for (i = 0; i < drops; i++) s.drops.push({ x: R() * cols, y: R() * rows, v: 0.9 + R() * 0.9, len: 2 + Math.floor(R() * 3) })
  }
  if (kind === "snow") {
    var flakes = Math.round(cols * 0.8)
    for (i = 0; i < flakes; i++) s.flakes.push({ x: R() * cols, y: R() * rows, v: 0.12 + R() * 0.3, ph: R() * 6.28, big: R() < 0.25 })
  }
  if (kind === "stars") {
    var stars = Math.round(cols * 0.6)
    for (i = 0; i < stars; i++) s.stars.push({ x: Math.floor(R() * cols), y: Math.floor(R() * rows * 0.75), ph: R() * 11, sp: 0.04 + R() * 0.08 })
  }
  var clouds = kind === "clouds" ? 7 : kind === "partly" ? 3 : (wet || kind === "snow") ? 4 : 0
  for (i = 0; i < clouds; i++)
    s.clouds.push({ x: R() * cols, y: Math.floor(R() * (kind === "clouds" ? 30 : 8)), v: 0.04 + R() * 0.08 + wind / 600, sp: i % 3 })
  if (wind > 35)
    for (i = 0; i < 14; i++) s.streaks.push({ x: R() * cols, y: Math.floor(R() * rows), len: 4 + Math.floor(R() * 6), v: 2 + R() * 2 })
  if (kind === "sun" || kind === "partly") s.sun = sunCells(cols, rows)
  s.blank = []
  for (i = 0; i < cols; i++) s.blank.push(" ")
  return s
}

// The sun's geometry never changes, so each cell's distance and ray are
// worked out once; a frame then only checks the animated phases. (QML's JS
// engine is slow enough that sqrt/atan2 per cell per frame showed up.)
function sunCells(cols, rows) {
  var cx = cols - 16
  var cy = 6
  var cells = []
  for (var y = 0; y < Math.min(rows, 36); y++) {
    for (var x = Math.max(0, cx - 72); x < cols; x++) {
      var dx = x - cx
      var dy = (y - cy) * 2.1
      var d = Math.sqrt(dx * dx + dy * dy)
      var cell = { x: x, y: y, d: d, core: d < 1.3 ? "@" : d < 2.8 ? "O" : "", ray: "", ring: d > 4 && d < 64 ? (d < 26 ? ":" : "·") : "" }
      if (!cell.core && d > 3.5 && d < 16) {
        var k = Math.atan2(dy, dx) / (Math.PI / 4)
        var kr = Math.round(k)
        if (Math.abs(k - kr) * d < 0.6) cell.ray = ["-", "\\", "|", "/"][((kr % 4) + 4) % 4]
      }
      if (cell.core || cell.ray || cell.ring) cells.push(cell)
    }
  }
  return cells
}

function grid(blank, rows) {
  var g = []
  for (var r = 0; r < rows; r++) g.push(blank.slice())
  return g
}

// Draws the current frame and, when `animate`, advances the simulation one
// tick. Returns { dim, bright }: arrays of `rows` strings, `cols` wide each.
function step(s, animate, random) {
  var R = random || Math.random
  var cols = s.cols
  var rows = s.rows
  if (animate) s.f++
  var dim = grid(s.blank, rows)
  var bri = grid(s.blank, rows)
  function put(g, x, y, ch) {
    x = Math.round(x)
    y = Math.round(y)
    if (y >= 0 && y < rows && x >= 0 && x < cols) g[y][x] = ch
  }
  function wrapX(x) {
    return ((x % cols) + cols) % cols
  }

  // A character sun at the top right: core, rotating rays, pulsing rings.
  if (s.sun) {
    var rayShift = s.f * 0.3
    var ringShift = s.f * 0.45
    for (var c = 0; c < s.sun.length; c++) {
      var cell = s.sun[c]
      if (cell.core) { bri[cell.y][cell.x] = cell.core; continue }
      if (cell.ray && (((cell.d - rayShift) % 4) + 4) % 4 < 2.5) { bri[cell.y][cell.x] = cell.ray; continue }
      if (cell.ring && (((cell.d - ringShift) % 9) + 9) % 9 < 0.9) dim[cell.y][cell.x] = cell.ring
    }
  }

  // Twinkling stars and the occasional shooting star.
  if (s.stars.length) {
    s.stars.forEach(function(st) {
      var ch = TWINKLE[Math.floor(s.f * st.sp + st.ph) % TWINKLE.length]
      if (ch !== " ") put(ch === "*" || ch === "+" ? bri : dim, st.x, st.y, ch)
    })
    if (animate && !s.shoot && R() < 0.012) s.shoot = { x: R() * cols * 0.6, y: R() * rows * 0.3, life: 22 }
    if (s.shoot) {
      var sh = s.shoot
      put(bri, sh.x, sh.y, "*")
      for (var t = 1; t <= 7; t++) put(dim, sh.x - t * 1.2, sh.y - t * 0.35, t < 3 ? "=" : "-")
      if (animate) {
        sh.x += 2.4
        sh.y += 0.7
        if (--sh.life <= 0) s.shoot = null
      }
    }
  }

  // Drifting clouds, wrapping around.
  s.clouds.forEach(function(cl) {
    var sprite = CLOUDS[cl.sp]
    var w = sprite[0].length
    sprite.forEach(function(line, ly) {
      for (var lx = 0; lx < w; lx++) if (line[lx] !== " ") put(dim, cl.x + lx, cl.y + ly, line[lx])
    })
    if (animate) {
      cl.x += cl.v
      if (cl.x > cols) cl.x = -w
    }
  })

  // Rain: falling | with . trails, slanted by the wind.
  var slashed = s.slant > 0.2
  s.drops.forEach(function(dr) {
    if (animate) {
      dr.y += dr.v
      dr.x = wrapX(dr.x + dr.v * s.slant)
      if (dr.y > rows) {
        dr.y = -R() * 6
        dr.x = R() * cols
      }
    }
    put(s.kind === "storm" ? dim : bri, dr.x, dr.y, slashed ? "\\" : "|")
    for (var n = 1; n <= dr.len; n++) put(dim, dr.x - s.slant * n, dr.y - n, n === 1 ? (slashed ? "\\" : "|") : ".")
  })

  // Storms: brief jagged lightning.
  if (s.kind === "storm") {
    if (animate && !s.bolt && R() < 0.025) {
      var bx = 10 + R() * (cols - 20)
      var pts = []
      var len = 18 + Math.floor(R() * 18)
      for (var by = 0; by < len; by++) {
        var dir = Math.floor(R() * 3) - 1
        pts.push([bx, by, dir < 0 ? "/" : dir > 0 ? "\\" : "|"])
        bx += dir
      }
      s.bolt = { pts: pts, life: 5 }
    }
    if (s.bolt) {
      s.bolt.pts.forEach(function(p) { put(bri, p[0], p[1], p[2]) })
      if (animate && --s.bolt.life <= 0) s.bolt = null
    }
  }

  // Snow: drifting * and . flakes.
  s.flakes.forEach(function(fl) {
    if (animate) {
      fl.y += fl.v
      fl.x = wrapX(fl.x + Math.sin(s.f * 0.06 + fl.ph) * 0.25 + s.slant * 0.5)
      if (fl.y > rows) {
        fl.y = -1
        fl.x = R() * cols
      }
    }
    if (fl.big) put(bri, fl.x, fl.y, "*")
    else put(dim, fl.x, fl.y, fl.ph > 3 ? "·" : ".")
  })

  // Strong wind: ~---- streaks.
  s.streaks.forEach(function(st) {
    for (var q = 0; q < st.len; q++) put(dim, st.x - q, st.y, q === 0 ? "~" : "-")
    if (animate) {
      st.x += st.v
      if (st.x - st.len > cols) {
        st.x = -R() * 30
        st.y = Math.floor(R() * rows)
      }
    }
  })

  return {
    dim: dim.map(function(r) { return r.join("") }),
    bright: bri.map(function(r) { return r.join("") })
  }
}

// Small deterministic generator for tests (mulberry32).
function seeded(seed) {
  var a = seed >>> 0
  return function() {
    a = (a + 0x6D2B79F5) >>> 0
    var t = a
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

if (typeof module !== "undefined") {
  module.exports = { CLOUDS: CLOUDS, create: create, step: step, seeded: seeded }
}

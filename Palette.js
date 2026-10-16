// Maps the active Omarchy theme's colors.toml onto the tokens every Weather
// surface uses. Pure functions over hex strings so tests/palette.test.js can
// check them against real theme files.
//
// Alert colors are fixed rather than taken from the theme: several themes
// repurpose red/yellow (hackerman's red is green, lumon's is blue, the
// monochrome themes are grey), and an alert has to read as an alert.
// Light and dark variants keep >= 3:1 against every stock theme background.
var ALERTS = {
  dark: { advisory: "#e8c547", watch: "#f28c38", warning: "#f04a4a" },
  light: { advisory: "#946200", watch: "#b84a00", warning: "#c81e1e" }
}

// AQI and UV meters run good → hazardous on the same fixed hues, for the
// same reason: the scale has to mean the same thing in every theme.
var SCALE = {
  dark: ["#5fc66a", "#e8c547", "#f28c38", "#f04a4a", "#b67ee8"],
  light: ["#2e7d32", "#946200", "#b84a00", "#c81e1e", "#7b3fb8"]
}

var FALLBACK = {
  background: "#1a1b26",
  foreground: "#a9b1d6",
  accent: "#7aa2f7"
}

function parseToml(raw) {
  var values = {}
  var lines = String(raw || "").split(/\r?\n/)
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].replace(/^\s+|\s+$/g, "")
    if (line.charAt(0) === "[") break // only the top-level table carries the palette
    var match = line.match(/^([A-Za-z0-9_-]+)\s*=\s*["']([^"']*)["']/)
    if (match) values[match[1]] = match[2]
  }
  return values
}

function isHex(value) {
  return /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})$/.test(String(value || ""))
}

function channels(hex) {
  var value = String(hex).replace("#", "")
  if (value.length === 3) value = value.replace(/(.)/g, "$1$1")
  return [0, 2, 4].map(function(i) { return parseInt(value.substr(i, 2), 16) })
}

function toHex(rgb) {
  return "#" + rgb.map(function(v) {
    var n = Math.max(0, Math.min(255, Math.round(v)))
    return (n < 16 ? "0" : "") + n.toString(16)
  }).join("")
}

// t = 0 returns a, t = 1 returns b.
function mix(a, b, t) {
  var x = channels(a), y = channels(b)
  return toHex([0, 1, 2].map(function(i) { return x[i] + (y[i] - x[i]) * t }))
}

function luminance(hex) {
  var c = channels(hex).map(function(v) {
    v /= 255
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
  })
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
}

function contrast(a, b) {
  var x = luminance(a), y = luminance(b)
  return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
}

// The first key that holds a hex color, lowercased; else the fallback.
function pick(palette, keys, fallback) {
  for (var i = 0; i < keys.length; i++) {
    var value = palette[keys[i]]
    if (isHex(value)) return value.toLowerCase()
  }
  return fallback
}

// Quietest blend of bg→fg that still reaches `ratio` against bg.
function readable(bg, fg, ratio, from) {
  for (var t = from; t < 1; t += 0.05) {
    var candidate = mix(bg, fg, t)
    if (contrast(candidate, bg) >= ratio) return candidate
  }
  return fg
}

// Nudge a signal color toward the foreground until it reads on bg (some
// themes ship a dark red that disappears on their own background).
function legible(color, bg, fg) {
  for (var t = 0; t <= 1; t += 0.1) {
    var candidate = mix(color, fg, t)
    if (contrast(candidate, bg) >= 3) return candidate
  }
  return fg
}

// `palette` is colors.toml's keys; `base` carries the shell's resolved
// foreground/background/accent, which win for those roles.
function build(palette, base) {
  palette = palette || {}
  base = base || {}
  var bg = isHex(base.background) ? base.background.toLowerCase() : pick(palette, ["background", "color0"], FALLBACK.background)
  var fg = isHex(base.foreground) ? base.foreground.toLowerCase() : pick(palette, ["foreground", "color7"], FALLBACK.foreground)
  var light = palette.mode === "light" || (palette.mode !== "dark" && luminance(bg) > 0.5)

  var alerts = light ? ALERTS.light : ALERTS.dark
  var muted = readable(bg, fg, 4.5, 0.55)

  return {
    light: light,
    bg: bg,
    fg: fg,
    accent: isHex(base.accent) ? base.accent.toLowerCase() : pick(palette, ["accent", "color4"], FALLBACK.accent),
    muted: muted,
    // Decorative only (the ASCII sky's dim layer, rules); never for text.
    faint: readable(bg, fg, 1.6, 0.1),
    border: mix(bg, fg, 0.16),
    // Precipitation chances: the theme's own cyan or blue.
    rain: legible(pick(palette, ["cyan", "color6", "blue", "color4"], FALLBACK.accent), bg, fg),
    scale: light ? SCALE.light : SCALE.dark,
    raised: pick(palette, ["lighter_background"], mix(bg, fg, 0.06)),
    // The ASCII sky's two layers: quiet enough to sit behind the hero text.
    skyDim: mix(bg, fg, 0.2),
    skyBright: mix(bg, isHex(base.accent) ? base.accent.toLowerCase() : pick(palette, ["accent", "color4"], FALLBACK.accent), 0.55),
    alerts: {
      statement: muted,
      advisory: legible(alerts.advisory, bg, fg),
      watch: legible(alerts.watch, bg, fg),
      warning: legible(alerts.warning, bg, fg),
      emergency: legible(alerts.warning, bg, fg)
    }
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    ALERTS: ALERTS, SCALE: SCALE, parseToml: parseToml, isHex: isHex, mix: mix, contrast: contrast, build: build
  }
}

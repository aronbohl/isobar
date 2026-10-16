// Moon phase, illumination and moonrise, computed locally (Open-Meteo has no
// lunar data). The formulas are SunCalc's (Vladimir Agafonkin, BSD-2-Clause),
// after Astronomical Algorithms (Meeus).

var RAD = Math.PI / 180
var DAY_MS = 86400000
var J1970 = 2440588
var J2000 = 2451545
var OBLIQUITY = RAD * 23.4397
var SYNODIC_DAYS = 29.530589

function toDays(ms) {
  return ms / DAY_MS - 0.5 + J1970 - J2000
}

function rightAscension(l, b) {
  return Math.atan2(Math.sin(l) * Math.cos(OBLIQUITY) - Math.tan(b) * Math.sin(OBLIQUITY), Math.cos(l))
}

function declination(l, b) {
  return Math.asin(Math.sin(b) * Math.cos(OBLIQUITY) + Math.cos(b) * Math.sin(OBLIQUITY) * Math.sin(l))
}

function altitude(H, phi, dec) {
  return Math.asin(Math.sin(phi) * Math.sin(dec) + Math.cos(phi) * Math.cos(dec) * Math.cos(H))
}

function siderealTime(d, lw) {
  return RAD * (280.16 + 360.9856235 * d) - lw
}

function astroRefraction(h) {
  if (h < 0) h = 0
  return 0.0002967 / Math.tan(h + 0.00312536 / (h + 0.08901179))
}

function sunCoords(d) {
  var M = RAD * (357.5291 + 0.98560028 * d)
  var C = RAD * (1.9148 * Math.sin(M) + 0.02 * Math.sin(2 * M) + 0.0003 * Math.sin(3 * M))
  var L = M + C + RAD * 102.9372 + Math.PI
  return { dec: declination(L, 0), ra: rightAscension(L, 0) }
}

function moonCoords(d) {
  var L = RAD * (218.316 + 13.176396 * d)
  var M = RAD * (134.963 + 13.064993 * d)
  var F = RAD * (93.272 + 13.229350 * d)
  var l = L + RAD * 6.289 * Math.sin(M)
  var b = RAD * 5.128 * Math.sin(F)
  return { ra: rightAscension(l, b), dec: declination(l, b), dist: 385001 - 20905 * Math.cos(M) }
}

function moonAltitude(ms, lat, lon) {
  var d = toDays(ms)
  var c = moonCoords(d)
  var H = siderealTime(d, RAD * -lon) - c.ra
  var h = altitude(H, RAD * lat, c.dec)
  return h + astroRefraction(h)
}

// { fraction: lit share 0–1, phase: 0 new → 0.5 full → 1 new }
function illumination(ms) {
  var d = toDays(ms)
  var s = sunCoords(d)
  var m = moonCoords(d)
  var sdist = 149598000
  var phi = Math.acos(Math.sin(s.dec) * Math.sin(m.dec) + Math.cos(s.dec) * Math.cos(m.dec) * Math.cos(s.ra - m.ra))
  var inc = Math.atan2(sdist * Math.sin(phi), m.dist - sdist * Math.cos(phi))
  var angle = Math.atan2(Math.cos(s.dec) * Math.sin(s.ra - m.ra),
    Math.sin(s.dec) * Math.cos(m.dec) - Math.cos(s.dec) * Math.sin(m.dec) * Math.cos(s.ra - m.ra))
  return {
    fraction: (1 + Math.cos(inc)) / 2,
    phase: 0.5 + 0.5 * inc * (angle < 0 ? -1 : 1) / Math.PI
  }
}

function phaseName(phase) {
  var p = ((phase % 1) + 1) % 1
  var tolerance = 1 / SYNODIC_DAYS   // about a day either side of the exact phase
  if (p < tolerance || p > 1 - tolerance) return "New Moon"
  if (Math.abs(p - 0.25) < tolerance) return "First Quarter"
  if (Math.abs(p - 0.5) < tolerance) return "Full Moon"
  if (Math.abs(p - 0.75) < tolerance) return "Last Quarter"
  if (p < 0.25) return "Waxing Crescent"
  if (p < 0.5) return "Waxing Gibbous"
  if (p < 0.75) return "Waning Gibbous"
  return "Waning Crescent"
}

function daysToFull(phase) {
  var p = ((phase % 1) + 1) % 1
  return Math.round(((p <= 0.5 ? 0.5 : 1.5) - p) * SYNODIC_DAYS)
}

// Moonrise during the local day containing `nowMs` (UTC ms), as UTC ms, or
// null when the moon doesn't rise that day. Scans the 24 hours in 2-hour
// steps, fitting a parabola to find where altitude crosses the horizon.
function moonrise(nowMs, lat, lon, utcOffsetSeconds) {
  var offset = (utcOffsetSeconds || 0) * 1000
  var local = nowMs + offset
  var start = local - ((local % DAY_MS) + DAY_MS) % DAY_MS - offset
  var hc = 0.133 * RAD
  var at = function(hours) { return moonAltitude(start + hours * 3600000, lat, lon) - hc }
  var h0 = at(0)
  for (var i = 1; i <= 24; i += 2) {
    var h1 = at(i)
    var h2 = at(i + 1)
    var a = (h0 + h2) / 2 - h1
    var b = (h2 - h0) / 2
    var xe = -b / (2 * a)
    var ye = (a * xe + b) * xe + h1
    var disc = b * b - 4 * a * h1
    if (disc >= 0) {
      var dx = Math.sqrt(disc) / (Math.abs(a) * 2)
      var x1 = xe - dx
      var x2 = xe + dx
      var roots = (Math.abs(x1) <= 1 ? 1 : 0) + (Math.abs(x2) <= 1 ? 1 : 0)
      if (x1 < -1) x1 = x2
      if (roots === 1 && h0 < 0) return start + (i + x1) * 3600000
      if (roots === 2) return start + (i + (ye < 0 ? x2 : x1)) * 3600000
    }
    h0 = h2
  }
  return null
}

// Everything the moon tile shows.
function moon(nowMs, lat, lon, utcOffsetSeconds) {
  var lit = illumination(nowMs)
  return {
    name: phaseName(lit.phase),
    phase: lit.phase,
    illuminated: Math.round(lit.fraction * 100),
    daysToFull: daysToFull(lit.phase),
    rise: moonrise(nowMs, lat, lon, utcOffsetSeconds)
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    illumination: illumination, phaseName: phaseName, daysToFull: daysToFull, moonrise: moonrise, moon: moon
  }
}

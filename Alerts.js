// NWS active-alert parsing and the design's five alert levels. Pure, so the
// tests can run it against saved api.weather.gov responses.
//
// Levels come from the event name's last word ("Freeze Warning" → warning),
// which is how NWS itself tiers its products. CAP severity only decides
// events with no tier word ("Air Quality Alert") and promotes extreme,
// immediate threats to emergency.

var LEVELS = ["statement", "advisory", "watch", "warning", "emergency"]
var DAYS_SHORT = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

function rank(level) {
  return LEVELS.indexOf(level) + 1
}

function level(event, severity, urgency) {
  var name = String(event || "").toLowerCase()
  var sev = String(severity || "").toLowerCase()
  if (/\bemergency\b/.test(name)) return "emergency"
  if (sev === "extreme" && String(urgency || "").toLowerCase() === "immediate") return "emergency"
  if (/\bwarning$/.test(name)) return "warning"
  if (/\bwatch$/.test(name)) return "watch"
  if (/\badvisory$/.test(name)) return "advisory"
  if (/\b(statement|outlook)$/.test(name)) return "statement"
  if (sev === "extreme" || sev === "severe") return "warning"
  if (sev === "moderate") return "advisory"
  return "statement"
}

// "2026-10-16T09:00:00-06:00" → wall-clock fields as written, so times read
// in the issuing office's zone (which is the alert area's zone).
function wallClock(iso) {
  var m = String(iso || "").match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/)
  if (!m) return null
  var day = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3])).getUTCDay()
  var h = +m[4]
  return {
    date: m[1] + "-" + m[2] + "-" + m[3],
    day: DAYS_SHORT[day],
    time: ((h % 12) || 12) + ":" + m[5] + " " + (h < 12 ? "AM" : "PM")
  }
}

// The zone abbreviation from the headline ("… until October 17 at 9:00AM CDT
// by NWS Omaha/Valley NE"), since the ISO timestamps only carry an offset.
function zoneFromHeadline(headline) {
  var matches = String(headline || "").match(/\d[AP]M ([A-Za-z]{2,5})\b/g)
  if (!matches) return ""
  return matches[matches.length - 1].replace(/^\d[AP]M /, "")
}

function parseTime(iso) {
  var t = Date.parse(String(iso || ""))
  return isNaN(t) ? null : t
}

// The VTEC event an alert belongs to, "KOAX.FZ.W.0003" (office, phenomenon,
// significance, event number), shared by every update of that event; "" when
// the alert carries no VTEC (statements, non-NWS sources).
function vtecEvent(params) {
  var codes = params && Array.isArray(params.VTEC) ? params.VTEC : []
  for (var i = 0; i < codes.length; i++) {
    var m = String(codes[i]).match(/^\/[OTEX]\.([A-Z]{3})\.([A-Z]{4})\.([A-Z]{2})\.([A-Z])\.(\d{4})\./)
    if (m && m[1] !== "CAN" && m[1] !== "EXP" && m[1] !== "UPG") return m[2] + "." + m[3] + "." + m[4] + "." + m[5]
  }
  return ""
}

// api.weather.gov /alerts/active GeoJSON → alerts, newest first. Drops test
// and exercise messages, cancellations, anything already expired at `nowMs`,
// and alerts superseded by a newer one in the list: an update that
// references them, or a later message for the same VTEC event. Distinct
// events stay separate, even of the same type from the same office.
function parse(raw, nowMs) {
  var features
  try {
    var data = typeof raw === "string" ? JSON.parse(raw) : raw
    features = data && Array.isArray(data.features) ? data.features : []
  } catch (e) {
    return []
  }

  var byEvent = {}
  var out = []
  for (var i = 0; i < features.length; i++) {
    var p = features[i] && features[i].properties
    if (!p || !p.event || !p.id) continue
    if (p.status !== "Actual" || p.messageType === "Cancel") continue
    var ends = parseTime(p.ends) || parseTime(p.expires)
    if (ends !== null && nowMs !== undefined && ends <= nowMs) continue

    var refs = []
    var vtec = vtecEvent(p.parameters)
    var references = Array.isArray(p.references) ? p.references : []
    for (var r = 0; r < references.length; r++)
      if (references[r] && references[r].identifier) refs.push(String(references[r].identifier))

    var alert = {
      id: String(p.id),
      references: refs,
      event: String(p.event),
      level: level(p.event, p.severity, p.urgency),
      severity: String(p.severity || ""),
      urgency: String(p.urgency || ""),
      sent: parseTime(p.sent) || 0,
      ends: ends,
      onsetIso: String(p.onset || p.effective || ""),
      endsIso: String(p.ends || p.expires || ""),
      zone: zoneFromHeadline(p.headline),
      sender: String(p.senderName || ""),
      headline: String(p.headline || ""),
      description: String(p.description || ""),
      instruction: typeof p.instruction === "string" ? p.instruction : "",
      area: String(p.areaDesc || "")
    }

    var key = vtec || alert.id
    var existing = byEvent[key]
    if (existing) {
      if (alert.sent > existing.sent) out[out.indexOf(existing)] = byEvent[key] = alert
      continue
    }
    byEvent[key] = alert
    out.push(alert)
  }
  var replaced = {}
  for (var a = 0; a < out.length; a++)
    for (var b = 0; b < out[a].references.length; b++) replaced[out[a].references[b]] = true
  out = out.filter(function(x) { return !replaced[x.id] })
  out.sort(function(a, b) { return b.sent - a.sent })
  return out
}

// Alerts still in effect at `nowMs` (cached lists outlive their alerts).
function active(alerts, nowMs) {
  return (alerts || []).filter(function(a) { return a.ends === null || a.ends > nowMs })
}

// The most severe level among `alerts`, or "" when there are none.
function topLevel(alerts) {
  var best = ""
  for (var i = 0; i < (alerts || []).length; i++)
    if (rank(alerts[i].level) > rank(best)) best = alerts[i].level
  return best
}

// The most severe alert (the newest among equals, since lists are newest
// first), or null.
function top(alerts) {
  var best = null
  for (var i = 0; i < (alerts || []).length; i++)
    if (!best || rank(alerts[i].level) > rank(best.level)) best = alerts[i]
  return best
}

// "Until Sat 9:00 AM CDT", or "Sat 1:00 AM – 9:00 AM CDT" when it hasn't
// started yet.
function timing(alert, nowMs) {
  var end = wallClock(alert.endsIso)
  var zone = alert.zone ? " " + alert.zone : ""
  var onset = parseTime(alert.onsetIso)
  var start = wallClock(alert.onsetIso)
  if (start && onset !== null && nowMs !== undefined && onset > nowMs) {
    var from = start.day + " " + start.time
    if (!end) return "From " + from + zone
    return from + " – " + (end.date === start.date ? "" : end.day + " ") + end.time + zone
  }
  return end ? "Until " + end.day + " " + end.time + zone : ""
}

// Popover/app one-liner: "Until Sat 9:00 AM CDT · issued by NWS Omaha/Valley NE".
function summaryLine(alert, nowMs) {
  var parts = []
  var when = timing(alert, nowMs)
  if (when) parts.push(when)
  if (alert.sender) parts.push("issued by " + alert.sender)
  return parts.join(" · ")
}

// NWS hard-wraps its text at ~70 columns. Join wrapped lines, keep blank
// lines as paragraph breaks, so the app can wrap to its own width.
function reflow(text) {
  return String(text || "").replace(/\r/g, "").split(/\n\s*\n/).map(function(p) {
    return p.replace(/\s*\n\s*/g, " ").replace(/^\s+|\s+$/g, "")
  }).filter(function(p) { return !!p }).join("\n\n")
}

function firstSentence(text) {
  var flat = String(text || "").replace(/\s+/g, " ").replace(/^\s+|\s+$/g, "")
  var m = flat.match(/^.*?[.!?](\s|$)/)
  return m ? m[0].replace(/\s+$/, "") : flat
}

// Desktop notification for an alert at a saved location. Omarchy's notifier
// keeps every critical notification until dismissed, so only an emergency is
// critical; watches and warnings are normal and time out.
function notification(alert, locationName, nowMs) {
  var when = timing(alert, nowMs)
  var advice = firstSentence(alert.instruction)
  return {
    title: alert.event.toUpperCase() + " · " + String(locationName || "").toUpperCase(),
    body: [when ? when + "." : "", advice].filter(function(s) { return !!s }).join(" "),
    urgency: alert.level === "emergency" ? "critical" : "normal"
  }
}

// Alerts that deserve a desktop notification and haven't had one. An update
// reissues an alert under a new id that references the old one, so a
// referenced id counts as already notified.
function unnotified(alerts, notifiedIds) {
  var seen = {}
  for (var i = 0; i < (notifiedIds || []).length; i++) seen[notifiedIds[i]] = true
  var out = []
  for (var j = 0; j < (alerts || []).length; j++) {
    var a = alerts[j]
    if (rank(a.level) < rank("watch") || seen[a.id]) continue
    var known = false
    for (var r = 0; r < a.references.length; r++) if (seen[a.references[r]]) known = true
    if (!known) out.push(a)
  }
  return out
}

if (typeof module !== "undefined") {
  module.exports = {
    LEVELS: LEVELS, rank: rank, level: level, vtecEvent: vtecEvent, wallClock: wallClock, zoneFromHeadline: zoneFromHeadline,
    parse: parse, active: active, topLevel: topLevel, top: top, timing: timing, summaryLine: summaryLine, reflow: reflow, firstSentence: firstSentence,
    notification: notification, unnotified: unnotified
  }
}

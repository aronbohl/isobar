// Run with: node --test tests/*.test.js
const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const Alerts = require("../Alerts.js")

const fixture = (name) => fs.readFileSync(path.join(__dirname, "fixtures", name), "utf8")
const NOW = Date.parse("2026-10-16T04:05:00Z")
const SAMPLE_NOW = Date.parse("2026-10-16T05:00:00Z")
// Omaha's fixture was captured at 2:52 PM CDT on Fri 16 Oct 2026.
const OMAHA_NOW = Date.parse("2026-10-16T19:52:00Z")

function feature(props) {
  return {
    properties: Object.assign({
      id: "urn:test:1", event: "Freeze Warning", severity: "Severe", urgency: "Expected",
      status: "Actual", messageType: "Alert", sent: "2026-10-15T10:50:00-05:00",
      ends: "2026-10-16T10:00:00-05:00", senderName: "NWS Omaha/Valley NE"
    }, props)
  }
}

test("levels follow the event's tier word", () => {
  assert.equal(Alerts.level("Special Weather Statement", "Moderate", "Expected"), "statement")
  assert.equal(Alerts.level("Hydrologic Outlook", "Unknown", "Future"), "statement")
  assert.equal(Alerts.level("Wind Advisory", "Moderate", "Expected"), "advisory")
  assert.equal(Alerts.level("Freeze Watch", "Severe", "Future"), "watch")
  assert.equal(Alerts.level("Freeze Warning", "Severe", "Expected"), "warning")
  assert.equal(Alerts.level("Tornado Emergency", "Extreme", "Immediate"), "emergency")
  assert.equal(Alerts.level("Extreme Wind Warning", "Extreme", "Immediate"), "emergency")
  assert.equal(Alerts.level("Air Quality Alert", "Unknown", "Unknown"), "statement")
  assert.equal(Alerts.level("Blizzard Alert", "Severe", "Expected"), "warning")
})

test("the live Omaha freeze warning parses", () => {
  const [alert, ...rest] = Alerts.parse(fixture("nws-omaha.json"), OMAHA_NOW)
  assert.equal(rest.length, 0)
  assert.equal(alert.event, "Freeze Warning")
  assert.equal(alert.level, "warning")
  assert.equal(alert.zone, "CDT")
  assert.equal(alert.sender, "NWS Omaha/Valley NE")
  assert.match(alert.id, /^urn:oid:/)
  assert.equal(Alerts.summaryLine(alert, OMAHA_NOW), "Sat 1:00 AM – 9:00 AM CDT · issued by NWS Omaha/Valley NE")
  // Once it has started, the line reads as a countdown to the end.
  assert.equal(Alerts.summaryLine(alert, Date.parse("2026-10-17T07:00:00Z")), "Until Sat 9:00 AM CDT · issued by NWS Omaha/Valley NE")
  // And after it ends it's gone.
  assert.deepEqual(Alerts.parse(fixture("nws-omaha.json"), Date.parse("2026-10-17T15:00:00Z")), [])
})

test("the nationwide sample drops tests and expired alerts, newest first", () => {
  const alerts = Alerts.parse(fixture("nws-sample.json"), SAMPLE_NOW)
  const events = alerts.map((a) => a.event)
  assert.ok(!events.includes("Test Message"))
  assert.ok(!events.includes("Hydrologic Outlook"))
  for (let i = 1; i < alerts.length; i++) assert.ok(alerts[i - 1].sent >= alerts[i].sent)
  const outlook = Alerts.parse(fixture("nws-sample.json"), Date.parse("2026-10-16T01:00:00Z"))
  assert.ok(outlook.some((a) => a.event === "Hydrologic Outlook"))
  assert.equal(Alerts.zoneFromHeadline("Hydrologic Outlook issued October 16 at 1:48PM ChST by NWS Tiyan GU"), "ChST")
  assert.equal(Alerts.zoneFromHeadline(""), "")
})

test("cancellations are dropped and superseded alerts collapse to the latest", () => {
  const alerts = Alerts.parse({
    features: [
      feature({ id: "a", sent: "2026-10-15T10:00:00-05:00" }),
      feature({ id: "b", sent: "2026-10-15T11:00:00-05:00", references: [{ identifier: "a" }] }),
      feature({ id: "c", event: "Wind Advisory", messageType: "Cancel" }),
      feature({ id: "d", event: "Winter Storm Watch", sent: "2026-10-15T09:00:00-05:00" })
    ]
  }, NOW)
  assert.deepEqual(alerts.map((a) => a.id), ["b", "d"])
  assert.equal(Alerts.topLevel(alerts), "warning")
  assert.equal(Alerts.topLevel([]), "")
  assert.deepEqual(Alerts.parse("not json", NOW), [])
})

test("distinct warnings of the same type from one office both stay", () => {
  const alerts = Alerts.parse({
    features: [
      feature({ id: "t1", event: "Tornado Warning", sent: "2026-10-15T10:00:00-05:00",
        parameters: { VTEC: ["/O.NEW.KOAX.TO.W.0041.261015T1500Z-261015T1545Z/"] } }),
      feature({ id: "t2", event: "Tornado Warning", sent: "2026-10-15T10:10:00-05:00",
        parameters: { VTEC: ["/O.NEW.KOAX.TO.W.0042.261015T1510Z-261015T1600Z/"] } })
    ]
  }, NOW)
  assert.deepEqual(alerts.map((a) => a.id), ["t2", "t1"])
})

test("messages for the same VTEC event collapse to the newest", () => {
  const alerts = Alerts.parse({
    features: [
      feature({ id: "n", sent: "2026-10-15T10:00:00-05:00", parameters: { VTEC: ["/O.NEW.KOAX.FZ.W.0003.261017T0600Z-261017T1400Z/"] } }),
      feature({ id: "x", sent: "2026-10-15T14:00:00-05:00", parameters: { VTEC: ["/O.EXT.KOAX.FZ.W.0003.261017T0600Z-261017T1500Z/"] } })
    ]
  }, NOW)
  assert.deepEqual(alerts.map((a) => a.id), ["x"])
  assert.equal(Alerts.vtecEvent({ VTEC: ["/O.NEW.KOAX.FZ.W.0003.261017T0600Z-261017T1400Z/"] }), "KOAX.FZ.W.0003")
  // An upgrade's cancelled half doesn't name the event; the new half does.
  assert.equal(Alerts.vtecEvent({ VTEC: ["/O.UPG.KOAX.FZ.A.0002.000000T0000Z-000000T0000Z/", "/O.NEW.KOAX.FZ.W.0003.261017T0600Z-261017T1400Z/"] }), "KOAX.FZ.W.0003")
  assert.equal(Alerts.vtecEvent(undefined), "")
})

test("notifications go out once per alert, including across updates", () => {
  const [first] = Alerts.parse({ features: [feature({ id: "a" })] }, NOW)
  assert.deepEqual(Alerts.unnotified([first], []).map((a) => a.id), ["a"])
  assert.deepEqual(Alerts.unnotified([first], ["a"]), [])

  const [update] = Alerts.parse({ features: [feature({ id: "a2", references: [{ identifier: "a" }] })] }, NOW)
  assert.deepEqual(Alerts.unnotified([update], ["a"]), [])

  const advisory = Alerts.parse({ features: [feature({ id: "w", event: "Wind Advisory" })] }, NOW)
  assert.deepEqual(Alerts.unnotified(advisory, []), [])
})

test("notification copy and urgency", () => {
  const [alert] = Alerts.parse(fixture("nws-omaha.json"), OMAHA_NOW)
  assert.deepEqual(Alerts.notification(alert, "Omaha", OMAHA_NOW), {
    title: "FREEZE WARNING · OMAHA",
    body: "Sat 1:00 AM – 9:00 AM CDT. Take steps now to protect tender plants from the cold.",
    urgency: "normal"
  })
  const [emergency] = Alerts.parse({ features: [feature({ event: "Tornado Emergency", instruction: "TAKE COVER NOW!  Move to a basement." })] }, NOW)
  const n = Alerts.notification(emergency, "Omaha", NOW)
  assert.equal(n.urgency, "critical")
  assert.equal(n.body, "Until Fri 10:00 AM. TAKE COVER NOW!")
  const [watch] = Alerts.parse({ features: [feature({ event: "Freeze Watch" })] }, NOW)
  assert.equal(Alerts.notification(watch, "Omaha", NOW).urgency, "normal")
})

test("cached alerts expire on their end time", () => {
  const alerts = Alerts.parse(fixture("nws-omaha.json"), OMAHA_NOW)
  assert.equal(Alerts.active(alerts, OMAHA_NOW).length, 1)
  assert.equal(Alerts.active(alerts, Date.parse("2026-10-17T15:00:00Z")).length, 0)
  const [open] = Alerts.parse({ features: [feature({ ends: null, expires: null })] }, NOW)
  assert.equal(Alerts.active([open], NOW + 1e10).length, 1)
})

test("top picks the most severe, newest first among equals", () => {
  const alerts = Alerts.parse({ features: [
    feature({ id: "adv", event: "Wind Advisory", sent: "2026-10-15T12:00:00-05:00" }),
    feature({ id: "w1", event: "Freeze Warning", sent: "2026-10-15T10:00:00-05:00" }),
    feature({ id: "w2", event: "High Wind Warning", sent: "2026-10-15T11:00:00-05:00" })
  ] }, NOW)
  assert.equal(Alerts.top(alerts).id, "w2")
  assert.equal(Alerts.top([]), null)
})

test("reflow joins NWS hard wraps and keeps paragraphs", () => {
  const [alert] = Alerts.parse(fixture("nws-omaha.json"), OMAHA_NOW)
  const text = Alerts.reflow(alert.description)
  assert.ok(text.startsWith("* WHAT...Sub-freezing temperatures as low as 28 expected.\n\n* WHERE...Portions of southwest and west central Iowa"))
  assert.equal(Alerts.reflow("a\nb\n\n\nc  \n d"), "a b\n\nc d")
  assert.equal(Alerts.reflow(null), "")
})

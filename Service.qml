import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model
import "Alerts.js" as Alerts
import "Api.js" as Api
import "Radar.js" as Radar

// The single source of weather state for the bar icon, popover and app.
// Settings live inline on the plugin's shell.json entry (the bar widget hands
// them over through applyEntry); API responses are cached under
// ~/.cache/isobar/ so a restart or an offline network still shows
// the last forecast.
Item {
  id: root
  visible: false

  readonly property string moduleName: "io.github.aronbohl.isobar"
  readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/isobar"

  property var shell: null
  readonly property Tokens tokens: Tokens {}

  // ------------------------------------------------------------ settings

  // The raw shell.json entry. Unknown keys are preserved on write.
  property var entry: ({})
  // The stock widget's location, used only to seed an empty list.
  property var legacyLocation: null

  readonly property var settings: Model.normalizeSettings(entry, legacyLocation)
  readonly property var locations: settings.locations
  readonly property int selected: settings.selected
  readonly property var location: locations.length ? locations[selected] : null
  readonly property string locationKey: Model.locationKey(location)
  readonly property bool imperial: Model.useImperial(settings.units, Qt.locale().name)
  readonly property bool skyFx: settings.skyFx
  // Trackpad multiplier for the app's scroll areas (scrollSpeed is percent).
  readonly property real scrollSpeed: settings.scrollSpeed / 100

  // ---------------------------------------------------------------- data

  // Raw responses keyed by Model.locationKey. Views read the derived maps
  // below, which re-normalize as `now` advances so hourly strips roll over
  // and expired alerts drop out without a refetch.
  property var rawForecasts: ({})
  property var rawAirQuality: ({})
  property var parsedAlerts: ({})
  property real fetchedAt: 0

  // Ticks every 30 s; everything time-relative binds to it.
  property real now: Date.now()

  readonly property var forecasts: {
    var out = {}
    for (var key in rawForecasts) out[key] = Model.normalizeForecast(rawForecasts[key], now)
    return out
  }
  readonly property var airQuality: {
    var out = {}
    for (var key in rawAirQuality) out[key] = Model.normalizeAirQuality(rawAirQuality[key])
    return out
  }
  readonly property var alerts: {
    var out = {}
    for (var key in parsedAlerts) out[key] = Alerts.active(parsedAlerts[key], now)
    return out
  }

  // Shortcuts for the selected location.
  readonly property var forecast: forecasts[locationKey] || null
  readonly property var currentAirQuality: airQuality[locationKey] || null
  readonly property var currentAlerts: alerts[locationKey] || []
  readonly property string alertLevel: Alerts.topLevel(currentAlerts)

  // A refresh runs until both the forecast and air quality have landed.
  property bool forecastPending: false
  property bool airQualityPending: false
  readonly property bool refreshing: forecastPending || airQualityPending
  // The last forecast fetch failed; cached data (if any) is still shown.
  property bool offline: false
  readonly property bool hasData: forecast !== null
  readonly property string updatedLabel: Model.ago(fetchedAt, now)

  // RainViewer frame list ({ host, frames }), shared by every location.
  property var radar: null
  property real radarFetchedAt: 0

  // Geocoding search state for the location picker.
  property var searchResults: []
  property string searchedQuery: ""
  property bool searching: false

  // Alert ids that already produced a notification.
  property var notifiedIds: []

  signal popoverRequested()

  // -------------------------------------------------------- settings API

  function applyEntry(value) {
    var next = Model.clone(value || {}) || {}
    if (JSON.stringify(next) !== JSON.stringify(entry)) entry = next
  }

  // Refetch when the saved set changes (not on reorder or reselect: one
  // request already covers every location).
  property string locationSet: ""
  onLocationsChanged: {
    var keys = locations.map(Model.locationKey).sort().join(";")
    if (keys === locationSet) return
    locationSet = keys
    Qt.callLater(refresh)
  }

  function persist(patch) {
    var next = Model.clone(entry) || {}
    next.locations = locations
    next.selected = selected
    for (var key in patch) next[key] = patch[key]
    entry = next
    if (shell && typeof shell.updateEntryInline === "function")
      shell.updateEntryInline(moduleName, next)
  }

  function select(index) {
    if (index < 0 || index >= locations.length || index === selected) return
    persist({ selected: index })
  }

  // Right-click on the bar icon, j/k in the app.
  function cycle(step) {
    if (locations.length < 2) return
    persist({ selected: (selected + (step || 1) + locations.length) % locations.length })
  }

  function addLocation(value) {
    var location = Model.normalizeLocation(value)
    if (!location) return
    var key = Model.locationKey(location)
    for (var i = 0; i < locations.length; i++) {
      if (Model.locationKey(locations[i]) === key) {
        select(i)
        return
      }
    }
    var next = locations.concat([location])
    persist({ locations: next, selected: next.length - 1 })
  }

  function removeLocation(index) {
    if (index < 0 || index >= locations.length) return
    var next = locations.slice()
    next.splice(index, 1)
    var sel = selected > index ? selected - 1 : Math.min(selected, next.length - 1)
    persist({ locations: next, selected: Math.max(0, sel) })
  }

  function moveLocation(index, step) {
    var to = index + step
    if (index < 0 || to < 0 || index >= locations.length || to >= locations.length) return
    var next = locations.slice()
    var moved = next.splice(index, 1)[0]
    next.splice(to, 0, moved)
    var sel = selected === index ? to : (selected === to ? index : selected)
    persist({ locations: next, selected: sel })
  }

  function setUnits(units) {
    persist({ units: units === "imperial" ? "imperial" : "metric" })
  }

  function toggleUnits() {
    setUnits(imperial ? "metric" : "imperial")
  }

  function setSkyFx(enabled) {
    persist({ skyFx: enabled === true })
  }

  // --------------------------------------------------------------- views

  function openPopover() {
    popoverRequested()
  }

  // `alertId` opens the app with that alert expanded (popover "DETAILS ›").
  function openApp(alertId) {
    if (shell && typeof shell.summon === "function")
      shell.summon(moduleName, JSON.stringify({ view: "app", alert: alertId || "" }))
  }

  // ------------------------------------------------------------ fetching

  // The locations each in-flight request asked for, in request order, kept
  // until its own response lands (responses are matched up by position).
  property var forecastLocations: []
  property var airQualityLocations: []
  property var alertQueue: []
  property var alertQueueLocation: null
  // A refresh asked for mid-flight (say, a location was just added) runs
  // once the current one lands.
  property bool refreshQueued: false

  function refresh() {
    if (locations.length === 0) return
    if (refreshing) {
      refreshQueued = true
      return
    }
    var requested = locations.slice()
    forecastPending = true
    forecastLocations = requested
    forecastProc.command = Api.curl(Api.forecastUrl(requested), 15)
    forecastProc.running = true
    airQualityPending = true
    airQualityLocations = requested
    airQualityProc.command = Api.curl(Api.airQualityUrl(requested), 15)
    airQualityProc.running = true
    alertQueue = requested.filter(Api.nwsCovers)
    nextAlerts()
    refreshRadar(true)
  }

  // Radar frames update every 10 minutes; `force` comes with a full refresh.
  function refreshRadar(force) {
    if (radarProc.running) return
    if (!force && now - radarFetchedAt < 10 * 60000) return
    radarProc.command = Api.curl(Radar.MAPS_URL, 10)
    radarProc.running = true
  }

  function nextAlerts() {
    if (alertsProc.running) return
    if (alertQueue.length === 0) {
      alertQueueLocation = null
      return
    }
    alertQueueLocation = alertQueue[0]
    alertQueue = alertQueue.slice(1)
    alertsProc.command = Api.curl(Api.alertsUrl(alertQueueLocation), 10)
    alertsProc.running = true
  }

  // One response entry per requested location, in request order.
  function storeByLocation(target, text, requested) {
    var list = Model.asList(text)
    if (list.length !== requested.length) return null
    var next = Model.clone(target) || {}
    for (var i = 0; i < list.length; i++) next[Model.locationKey(requested[i])] = list[i]
    return next
  }

  // Runs a refresh that was asked for mid-flight, once both requests are in.
  function refreshSettled() {
    if (refreshing || !refreshQueued) return
    refreshQueued = false
    Qt.callLater(refresh)
  }

  function onForecast(ok, text) {
    var next = ok ? storeByLocation(rawForecasts, text, forecastLocations) : null
    if (next) {
      rawForecasts = pruned(next)
      fetchedAt = Date.now()
      offline = false
      saveCache()
    } else {
      offline = true
      retryTimer.restart()
    }
    forecastPending = false
    refreshSettled()
  }

  function onAirQuality(ok, text) {
    var next = ok ? storeByLocation(rawAirQuality, text, airQualityLocations) : null
    if (next) {
      rawAirQuality = pruned(next)
      saveCache()
    }
    airQualityPending = false
    refreshSettled()
  }

  function onAlerts(location, text) {
    // Empty output means curl failed (-f); keep the cached list.
    if (!location || String(text || "").length === 0) return
    var list = Alerts.parse(text, Date.now())
    var next = Model.clone(parsedAlerts) || {}
    next[Model.locationKey(location)] = list
    parsedAlerts = pruned(next)
    saveCache()
    notify(location, list)
  }

  // Drop cached entries for locations that are no longer saved.
  function pruned(map) {
    var keep = {}
    for (var i = 0; i < locations.length; i++) {
      var key = Model.locationKey(locations[i])
      if (map[key] !== undefined) keep[key] = map[key]
    }
    return keep
  }

  // --------------------------------------------------------- notifications

  function notify(location, list) {
    var fresh = Alerts.unnotified(list, notifiedIds)
    for (var i = 0; i < fresh.length; i++) {
      var n = Alerts.notification(fresh[i], location.name, Date.now())
      // Emergencies go out as notify-send so they also break through Do Not
      // Disturb; Omarchy's notifier only trusts that app name for critical.
      var argv = ["omarchy-notification-send",
        "--app-name", n.urgency === "critical" ? "notify-send" : "Isobar",
        "-g", "\uf071", "-u", n.urgency, n.title, n.body,
        "--exec", "omarchy-shell", "shell", "call", moduleName, "popover", ""]
      Quickshell.execDetached(argv)
    }

    // Remember every current id (not just the notified ones) so an update
    // that references one of them stays quiet. Bounded, oldest first out.
    var ids = notifiedIds.slice()
    for (var j = 0; j < list.length; j++) {
      if (ids.indexOf(list[j].id) === -1) ids.push(list[j].id)
      for (var r = 0; r < list[j].references.length; r++)
        if (ids.indexOf(list[j].references[r]) === -1) ids.push(list[j].references[r])
    }
    if (ids.length === notifiedIds.length) return
    notifiedIds = ids.slice(-300)
    notifiedFile.setText(JSON.stringify(notifiedIds))
  }

  // -------------------------------------------------------------- search

  // Results always belong to `searchedQuery`. A query typed while another is
  // in flight waits for it, then runs; only the latest one is kept.
  property string wantedQuery: ""

  function search(query) {
    wantedQuery = String(query || "").replace(/^\s+|\s+$/g, "")
    runSearch()
  }

  function runSearch() {
    if (geocodeProc.running || wantedQuery === searchedQuery) return
    if (wantedQuery.length < 2) {
      searchedQuery = wantedQuery
      searchResults = []
      return
    }
    searching = true
    geocodeProc.query = wantedQuery
    geocodeProc.command = Api.curl(Api.geocodeUrl(wantedQuery), 6)
    geocodeProc.running = true
  }

  // --------------------------------------------------------------- cache

  function saveCache() {
    cacheFile.setText(JSON.stringify({
      version: 1,
      fetchedAt: fetchedAt,
      forecast: rawForecasts,
      airQuality: rawAirQuality,
      alerts: parsedAlerts
    }))
  }

  function loadCache(text) {
    try {
      var data = JSON.parse(String(text || ""))
      if (!data || data.version !== 1) return
      rawForecasts = data.forecast || {}
      rawAirQuality = data.airQuality || {}
      parsedAlerts = data.alerts || {}
      fetchedAt = Number(data.fetchedAt) || 0
    } catch (e) {}
  }

  FileView {
    id: cacheFile
    path: root.cacheDir + "/cache.json"
    printErrors: false
    atomicWrites: true
    onLoaded: root.loadCache(text())
  }

  FileView {
    id: notifiedFile
    path: root.cacheDir + "/notified.json"
    printErrors: false
    atomicWrites: true
    onLoaded: {
      try {
        var ids = JSON.parse(text())
        if (Array.isArray(ids)) root.notifiedIds = ids.map(String)
      } catch (e) {}
    }
  }

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
    printErrors: false
    onLoaded: root.legacyLocation = Model.parseLegacyLocation(text())
  }

  // ---------------------------------------------------------- processes

  // curl runs with -f, so a failed request closes stdout empty; handling
  // everything once the stream finishes keeps body and outcome together.
  Process {
    id: forecastProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.onForecast(text.length > 0, text)
    }
  }

  Process {
    id: airQualityProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.onAirQuality(text.length > 0, text)
    }
  }

  Process {
    id: alertsProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.onAlerts(root.alertQueueLocation, text)
    }
    // Chained from exit, not stream end: `running` is still true until here.
    onExited: Qt.callLater(root.nextAlerts)
  }

  Process {
    id: radarProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Radar.parseFrames(text)
        if (!parsed) return
        root.radar = parsed
        root.radarFetchedAt = Date.now()
      }
    }
  }

  Process {
    id: geocodeProc
    property string query: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.searchedQuery = geocodeProc.query
        root.searchResults = Model.parseGeocoding(text)
      }
    }
    onExited: {
      root.searching = false
      Qt.callLater(root.runSearch)
    }
  }

  // ------------------------------------------------------------- timers

  // The clock for every time-relative label. Also the refresh scheduler:
  // checking staleness on each tick (rather than a fixed-interval timer)
  // catches up immediately after suspend.
  Timer {
    interval: 30000
    repeat: true
    running: true
    onTriggered: {
      root.now = Date.now()
      if (root.now - root.fetchedAt >= root.settings.refreshMinutes * 60000) root.refresh()
    }
  }

  // After a failure, try again sooner than the regular interval.
  Timer {
    id: retryTimer
    interval: 60000
    onTriggered: root.refresh()
  }

  // The first fetch is triggered by onLocationsChanged once the settings
  // (or the stock widget's seed location) arrive.
  Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.cacheDir])
}

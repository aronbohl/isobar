import QtQuick
import Quickshell
import Quickshell.Hyprland
import "Model.js" as Model
import "Astro.js" as Astro
import "Radar.js" as Radar
import "components"

// Isobar, the weather app: a regular Hyprland window with saved locations on the
// left and the selected location's forecast on the right.
//
// Keys: j/k location · J/K reorder · / search · 0 expand alerts · 1-3 focus pane ·
// PgUp/PgDn/Space/Home/End scroll · m full radar map · p pause radar ·
// u units · a sky fx ·
// r refresh · x remove · ? cheatsheet · q close (Esc only unfocuses a pane).
// With the radar focused: ←/→ (h/l) step frames, +/− zoom. Every action is
// also clickable.
Item {
  id: root

  required property var service
  property bool opened: false
  // Alert ids shown expanded in the banner list.
  property var expanded: ({})

  readonly property var tokens: service.tokens
  readonly property var hero: Model.heroView(service.location, service.forecast, service.imperial, service.now)
  readonly property var hours: Model.hourlyView(service.forecast, service.imperial)
  readonly property var days: Model.dailyView(service.forecast, service.imperial)
  readonly property var tiles: {
    var loc = service.location
    var fc = service.forecast
    if (!loc || !fc) return null
    var moon = Astro.moon(service.now, loc.latitude, loc.longitude, fc.utcOffset)
    return Model.tilesView(fc, service.currentAirQuality, moon, service.imperial, service.now)
  }
  // 0 = none, 1 = hourly, 2 = 10-day, 3 = radar.
  property int focusedPane: 0
  property bool cheatsheetShown: false
  // Narrow windows have no room for the sidebar; it opens as a drawer over
  // the forecast instead (header "locations" button or /).
  property bool drawerOpen: false
  // Leaving the radar pane resumes a loop paused by stepping through it,
  // but not one paused deliberately with p or the button.
  property bool radarStepped: false
  onFocusedPaneChanged: if (focusedPane !== 3 && radarStepped) { radarStepped = false; radarPanel.resume() }

  signal closed()

  // ------------------------------------------------------------ window

  // This window as Hyprland sees it, to find and move it between workspaces.
  readonly property var hyprWindow: {
    var list = Hyprland.toplevels.values
    for (var i = 0; i < list.length; i++) {
      var toplevel = list[i]
      if (toplevel.title === window.title && toplevel.wayland && toplevel.wayland.appId === "org.quickshell")
        return toplevel
    }
    return null
  }

  function dispatch(commands) {
    var script = commands.map(function(_, i) { return 'hyprctl dispatch "$' + i + '" >/dev/null' }).join("; ")
    Quickshell.execDetached(["bash", "-c", script].concat(commands))
  }

  function target() {
    return 'window = "address:0x' + hyprWindow.address + '"'
  }

  function onCurrentWorkspace() {
    var here = Hyprland.focusedWorkspace
    var there = hyprWindow ? hyprWindow.workspace : null
    if (!here || !there) return true
    return there === here || there.name === here.name
  }

  // Move the open window to the focused workspace (if it's elsewhere) and focus it.
  function bringHere() {
    var here = Hyprland.focusedWorkspace
    if (!hyprWindow || !here) return
    var workspace = /^[0-9]+$/.test(here.name) ? here.name : "name:" + here.name
    var commands = []
    if (!onCurrentWorkspace())
      commands.push('hl.dsp.window.move({ workspace = "' + workspace + '", follow = false, ' + target() + ' })')
    commands.push('hl.dsp.focus({ ' + target() + ' })')
    dispatch(commands)
  }

  function show(alertId) {
    opened = true
    if (alertId) {
      var next = {}
      next[alertId] = true
      expanded = next
    }
    service.refreshRadar(false)
    if (window.visible) bringHere()
    else {
      // Every open starts at the top.
      main.cancelFlick()
      main.contentY = 0
    }
    window.visible = true
    Qt.callLater(sidebar.reveal)
    focusShortcuts()
  }

  function hide() {
    if (!opened) return
    opened = false
    cheatsheetShown = false
    drawerOpen = false
    window.visible = false
    closed()
  }

  function toggleAlert(id) {
    var next = {}
    for (var key in expanded) next[key] = expanded[key]
    if (next[id]) delete next[id]
    else next[id] = true
    expanded = next
  }

  // 0: expand every alert for this location, or collapse them if all are
  // already open. Expanding scrolls up to them.
  function toggleAllAlerts() {
    var alerts = service.currentAlerts
    if (!alerts.length) return
    var allOpen = alerts.every(function(a) { return expanded[a.id] === true })
    var next = {}
    if (!allOpen) {
      alerts.forEach(function(a) { next[a.id] = true })
      main.cancelFlick()
      main.contentY = 0
    }
    expanded = next
  }

  function openDrawer() {
    drawerOpen = true
    Qt.callLater(sidebar.reveal)
  }

  // / and the footer hint: the sidebar's search, opening the drawer first
  // when the sidebar is tucked away.
  function openSearch() {
    if (!side.wide) openDrawer()
    sidebar.focusSearch(false)
  }

  function move(delta) {
    var count = service.locations.length
    if (count) service.select(Math.max(0, Math.min(count - 1, service.selected + delta)))
  }

  // Scroll a pane into view and highlight it.
  function focusPane(n) {
    var pane = n === 1 ? hourlyPanel : n === 2 ? dailyPanel : n === 3 ? radarPanel : null
    if (!pane || !pane.visible) return
    focusedPane = n
    var y = pane.mapToItem(content, 0, 0).y - tokens.px(24)
    main.contentY = Math.max(0, Math.min(y, main.contentHeight - main.height))
  }

  function openMap() {
    service.openFullMap(service.location, radarPanel.zoom)
  }

  function scrollBy(dy) {
    main.contentY = Math.max(0, Math.min(main.contentY + dy, main.contentHeight - main.height))
  }

  function focusShortcuts() {
    keys.forceActiveFocus()
  }

  FloatingWindow {
    id: window
    visible: false
    title: "Isobar"
    color: root.tokens.bg
    implicitWidth: root.tokens.px(1360)
    implicitHeight: root.tokens.px(920)
    minimumSize: Qt.size(root.tokens.px(640), root.tokens.px(480))

    // Closed from Hyprland (e.g. killactive): treat it like q.
    onVisibleChanged: if (!visible && root.opened) root.hide()

    // A plain Item rather than a FocusScope, so the shortcuts can take focus
    // back from the search field.
    Item {
      id: keys
      anchors.fill: parent
      focus: true

      // Clicking outside the search box leaves it.
      TapHandler {
        onTapped: function(eventPoint) {
          if (!sidebar.searchFocused) return
          var local = keys.mapToItem(sidebar, eventPoint.position.x, eventPoint.position.y)
          if (local.y > root.tokens.px(70) || local.x < 0 || local.x > sidebar.width) root.focusShortcuts()
        }
      }

      Keys.onPressed: function(event) {
        if (sidebar.searchFocused) return
        var text = event.text
        var handled = true
        // While the cheatsheet is up, only closing it (or quitting) works.
        if (root.cheatsheetShown) {
          if (text === "?" || event.key === Qt.Key_Escape) root.cheatsheetShown = false
          else if (text === "q") root.hide()
          event.accepted = true
          return
        }
        if (text === "?") root.cheatsheetShown = true
        else if (event.key === Qt.Key_Down || text === "j") root.move(1)
        else if (event.key === Qt.Key_Up || text === "k") root.move(-1)
        else if (text === "J") root.service.moveLocation(root.service.selected, 1)
        else if (text === "K") root.service.moveLocation(root.service.selected, -1)
        else if (text === "/") root.openSearch()
        else if (text === "0") root.toggleAllAlerts()
        else if (text === "1" || text === "2" || text === "3") root.focusPane(Number(text))
        else if (root.focusedPane === 3 && (event.key === Qt.Key_Left || text === "h")) { radarPanel.step(-1); root.radarStepped = true }
        else if (root.focusedPane === 3 && (event.key === Qt.Key_Right || text === "l")) { radarPanel.step(1); root.radarStepped = true }
        else if (root.focusedPane === 3 && (text === "+" || text === "=")) radarPanel.zoomBy(1)
        else if (root.focusedPane === 3 && (text === "-" || text === "_")) radarPanel.zoomBy(-1)
        else if (text === "m") root.openMap()
        else if (text === "p") radarPanel.togglePause()
        else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Space) root.scrollBy(main.height * 0.85)
        else if (event.key === Qt.Key_PageUp) root.scrollBy(-main.height * 0.85)
        else if (event.key === Qt.Key_Home) root.scrollBy(-main.contentHeight)
        else if (event.key === Qt.Key_End) root.scrollBy(main.contentHeight)
        else if (text === "u") root.service.toggleUnits()
        else if (text === "a") root.service.setSkyFx(!root.service.skyFx)
        else if (text === "r") root.service.refresh()
        else if (text === "x" || event.key === Qt.Key_Delete) root.service.removeLocation(root.service.selected)
        else if (event.key === Qt.Key_Escape && root.drawerOpen) root.drawerOpen = false
        else if (event.key === Qt.Key_Escape) root.focusedPane = 0
        else if (text === "q") root.hide()
        else handled = false
        event.accepted = handled
      }

      // Content fills the window; Hyprland draws the window border.
      Item {
        id: frame
        anchors.fill: parent

        // -------------------------------------------------------- header
        Item {
          id: header
          width: parent.width
          height: root.tokens.px(44)

          Row {
            x: root.tokens.px(16)
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.tokens.px(10)

            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: "isobar"
              color: root.tokens.accent
              font.family: root.tokens.fontFamily
              font.pixelSize: root.tokens.px(14)
              font.bold: true
            }
            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: "~/" + (root.service.location ? Model.slug(root.service.location.name) : "")
              color: root.tokens.fg
              font.family: root.tokens.fontFamily
              font.pixelSize: root.tokens.px(14)
            }

            // Narrow windows: the way in to the location drawer.
            HeaderButton {
              visible: !side.wide
              anchors.verticalCenter: parent.verticalCenter
              tokens: root.tokens
              text: "locations " + (root.service.locations.length ? (root.service.selected + 1) + "/" + root.service.locations.length : "+")
              selected: root.drawerOpen
              onClicked: root.drawerOpen ? (root.drawerOpen = false) : root.openDrawer()
            }
          }

          Row {
            anchors.right: parent.right
            anchors.rightMargin: root.tokens.px(16)
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.tokens.px(12)

            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: (root.service.offline ? "offline · " : "") + root.service.updatedLabel
              color: root.service.offline ? root.tokens.alert("warning") : root.tokens.muted
              font.family: root.tokens.fontFamily
              font.pixelSize: root.tokens.px(12)
            }

            HeaderButton {
              tokens: root.tokens
              text: "sky fx: " + (root.service.skyFx ? "on" : "off")
              onClicked: root.service.setSkyFx(!root.service.skyFx)
            }

            HeaderButton {
              id: refreshButton
              tokens: root.tokens
              text: ""
              fontSize: root.tokens.px(13)
              onClicked: root.service.refresh()

              RotationAnimator {
                target: refreshButton.label
                running: root.service.refreshing
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                onRunningChanged: if (!running) refreshButton.label.rotation = 0
              }
            }

            Row {
              HeaderButton {
                tokens: root.tokens
                text: "°C"
                selected: !root.service.imperial
                onClicked: root.service.setUnits("metric")
              }
              HeaderButton {
                tokens: root.tokens
                text: "°F"
                selected: root.service.imperial
                onClicked: root.service.setUnits("imperial")
              }
            }
          }

          Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: root.tokens.border
          }
        }

        // -------------------------------------------------------- footer
        Item {
          id: footer
          anchors.bottom: parent.bottom
          width: parent.width
          // Grows to a second line when the hints wrap in a narrow window.
          height: hints.implicitHeight + root.tokens.px(18)

          Rectangle {
            width: parent.width
            height: 1
            color: root.tokens.border
          }

          Flow {
            id: hints
            x: root.tokens.px(16)
            width: parent.width - root.tokens.px(32)
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.tokens.px(20)

            KeyHint { tokens: root.tokens; key: "j/k"; label: "location"; onTriggered: root.move(1) }
            KeyHint { tokens: root.tokens; key: "/"; label: "search"; onTriggered: root.openSearch() }
            KeyHint {
              visible: root.service.currentAlerts.length > 0
              tokens: root.tokens; key: "0"; label: "alerts"; onTriggered: root.toggleAllAlerts()
            }
            KeyHint { tokens: root.tokens; key: "1-3"; label: "focus pane"; onTriggered: root.focusPane(root.focusedPane % 3 + 1) }
            KeyHint { tokens: root.tokens; key: "u"; label: "units"; onTriggered: root.service.toggleUnits() }
            KeyHint { tokens: root.tokens; key: "m"; label: "map"; onTriggered: root.openMap() }
            KeyHint { tokens: root.tokens; key: "p"; label: radarPanel.paused ? "play radar" : "pause radar"; onTriggered: radarPanel.togglePause() }
            KeyHint { tokens: root.tokens; key: "a"; label: "sky fx"; onTriggered: root.service.setSkyFx(!root.service.skyFx) }
            KeyHint { tokens: root.tokens; key: "r"; label: "refresh"; onTriggered: root.service.refresh() }
            KeyHint { tokens: root.tokens; key: "x"; label: "remove"; onTriggered: root.service.removeLocation(root.service.selected) }
            KeyHint { tokens: root.tokens; key: "?"; label: "keys"; onTriggered: root.cheatsheetShown = true }
            KeyHint { tokens: root.tokens; key: "q"; label: "quit"; onTriggered: root.hide() }
          }
        }

        // ------------------------------------------------------- sidebar
        Item {
          id: side
          // Beside the forecast when there's room; otherwise a drawer over it.
          readonly property bool wide: frame.width >= root.tokens.px(760)
          onWideChanged: if (wide) root.drawerOpen = false
          visible: wide || root.drawerOpen
          z: wide ? 0 : 2
          anchors.top: header.bottom
          anchors.bottom: footer.top
          width: wide ? Math.min(root.tokens.px(300), Math.max(root.tokens.px(240), frame.width * 0.22))
            : Math.min(root.tokens.px(300), frame.width - root.tokens.px(48))

          Rectangle {
            anchors.fill: parent
            visible: !side.wide
            color: root.tokens.bg
          }

          Sidebar {
            id: sidebar
            anchors.fill: parent
            anchors.margins: root.tokens.px(16)
            anchors.topMargin: root.tokens.px(20)
            tokens: root.tokens
            service: root.service
            onDone: {
              if (!side.wide) root.drawerOpen = false
              root.focusShortcuts()
            }
            onPicked: if (!side.wide) root.drawerOpen = false
          }

          Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height
            color: root.tokens.border
          }
        }

        // Dims the forecast behind the drawer; a click closes it.
        Rectangle {
          visible: root.drawerOpen && !side.wide
          z: 1
          anchors.top: header.bottom
          anchors.bottom: footer.top
          width: parent.width
          color: Qt.rgba(root.tokens.bg.r, root.tokens.bg.g, root.tokens.bg.b, 0.6)
          TapHandler { onTapped: root.drawerOpen = false }
          WheelHandler { onWheel: function(event) { event.accepted = true } }
        }

        // ---------------------------------------------------------- main
        Flickable {
          id: main
          anchors.top: header.bottom
          anchors.bottom: footer.top
          anchors.left: side.wide ? side.right : parent.left
          anchors.right: parent.right
          clip: true
          contentWidth: width
          contentHeight: content.implicitHeight + root.tokens.px(52)
          boundsBehavior: Flickable.StopAtBounds

          // Behind the alerts and hero; scrolls away with them.
          AsciiSky {
            width: main.width
            height: Math.min(root.tokens.px(768), Math.max(main.height, root.tokens.px(400)))
            tokens: root.tokens
            visible: root.service.forecast !== null
            kind: root.service.forecast ? Model.skyKind(root.service.forecast.current.code, root.service.forecast.current.isDay) : "stars"
            wind: root.service.forecast ? (root.service.forecast.current.windKmh || 0) : 0
            animate: root.service.skyFx
            // Only while it's the focused window and in view; frozen otherwise.
            running: window.visible && root.hyprWindow !== null && root.hyprWindow.activated && main.contentY < height
          }

          Column {
            id: content
            x: root.tokens.px(20)
            y: root.tokens.px(24)
            width: main.width - root.tokens.px(40)
            spacing: root.tokens.px(32)

            Text {
              textFormat: Text.PlainText
              visible: root.hero === null
              width: parent.width
              wrapMode: Text.Wrap
              text: root.service.locations.length === 0
                ? "No saved locations. Press / or “+ add location” to find one."
                : (root.service.offline ? "Can't reach the forecast service. Retrying…" : "Fetching forecast…")
              color: root.tokens.muted
              font.family: root.tokens.fontFamily
              font.pixelSize: root.tokens.px(13)
            }

            Column {
              visible: root.service.currentAlerts.length > 0
              width: parent.width
              spacing: root.tokens.px(10)

              Repeater {
                model: root.service.currentAlerts

                AlertBanner {
                  required property var modelData
                  width: parent.width
                  tokens: root.tokens
                  alert: modelData
                  now: root.service.now
                  expanded: root.expanded[modelData.id] === true
                  onToggled: root.toggleAlert(modelData.id)
                }
              }
            }

            Hero {
              visible: root.hero !== null
              width: parent.width
              tokens: root.tokens
              view: root.hero || ({ name: "", region: "", time: "", temp: "", glyph: "", condition: "", hi: "", lo: "", summary: "" })
            }

            HourlyPanel {
              id: hourlyPanel
              visible: root.hours.length > 0
              width: parent.width
              tokens: root.tokens
              hours: root.hours
              focused: root.focusedPane === 1
            }

            // The 10-day panel beside the tiles when there's room (the
            // mockup's 360px and 460px columns, sharing extra width 1:2),
            // stacked above them when there isn't.
            Item {
              id: lower
              visible: root.tiles !== null
              width: parent.width
              readonly property real gap: root.tokens.px(20)
              readonly property bool wide: width >= root.tokens.px(840)
              readonly property real leftWidth: wide ? root.tokens.px(360) + (width - gap - root.tokens.px(820)) / 3 : width
              height: wide ? Math.max(leftColumn.height, tileColumn.height)
                : leftColumn.height + root.tokens.px(32) + tileColumn.height

              Column {
                id: leftColumn
                width: lower.leftWidth
                spacing: root.tokens.px(32)

                DailyPanel {
                  id: dailyPanel
                  width: parent.width
                  tokens: root.tokens
                  days: root.days
                  focused: root.focusedPane === 2
                }

                RadarPanel {
                  id: radarPanel
                  width: parent.width
                  tokens: root.tokens
                  radar: root.service.radar
                  location: root.service.location
                  focused: root.focusedPane === 3
                  active: window.visible && root.hyprWindow !== null && root.hyprWindow.activated
                  onMapRequested: root.openMap()
                }
              }

              Column {
                id: tileColumn
                x: lower.wide ? lower.leftWidth + lower.gap : 0
                y: lower.wide ? 0 : leftColumn.height + root.tokens.px(32)
                width: lower.wide ? lower.width - lower.leftWidth - lower.gap : lower.width
                spacing: root.tokens.px(32)

                AirQualityTile {
                  width: parent.width
                  tokens: root.tokens
                  view: root.tiles ? root.tiles.aqi : ({})
                }

                // Equal-height tiles, as many 200px+ columns as fit.
                Grid {
                  id: tileGrid
                  width: parent.width
                  columnSpacing: root.tokens.px(20)
                  rowSpacing: root.tokens.px(32)
                  columns: Math.max(1, Math.floor((width + columnSpacing) / (root.tokens.px(200) + columnSpacing)))
                  readonly property real cellWidth: (width - columnSpacing * (columns - 1)) / columns
                  readonly property real cellHeight: {
                    var h = 0
                    for (var i = 0; i < children.length; i++)
                      if (children[i].implicitHeight > h) h = children[i].implicitHeight
                    return h
                  }

                  UvTile { width: tileGrid.cellWidth; height: tileGrid.cellHeight; tokens: root.tokens; view: root.tiles ? root.tiles.uv : ({}) }
                  SunTile {
                    visible: root.tiles !== null && root.tiles.sun !== null
                    width: tileGrid.cellWidth; height: tileGrid.cellHeight; tokens: root.tokens
                    view: root.tiles && root.tiles.sun ? root.tiles.sun : ({ title: "", time: "", sub: "", progress: null, isDay: false })
                  }
                  WindTile { width: tileGrid.cellWidth; height: tileGrid.cellHeight; tokens: root.tokens; view: root.tiles ? root.tiles.wind : ({}) }
                  PrecipTile { width: tileGrid.cellWidth; height: tileGrid.cellHeight; tokens: root.tokens; view: root.tiles ? root.tiles.precip : ({}) }
                  FeelsTile { width: tileGrid.cellWidth; height: tileGrid.cellHeight; tokens: root.tokens; view: root.tiles ? root.tiles.feels : ({}) }
                  HumidityTile { width: tileGrid.cellWidth; height: tileGrid.cellHeight; tokens: root.tokens; view: root.tiles ? root.tiles.humidity : ({ cells: 0 }) }
                  VisibilityTile { width: tileGrid.cellWidth; height: tileGrid.cellHeight; tokens: root.tokens; view: root.tiles ? root.tiles.visibility : ({}) }
                  PressureTile { width: tileGrid.cellWidth; height: tileGrid.cellHeight; tokens: root.tokens; view: root.tiles ? root.tiles.pressure : ({ position: null }) }
                  MoonTile {
                    visible: root.tiles !== null && root.tiles.moon !== null
                    width: tileGrid.cellWidth; height: tileGrid.cellHeight; tokens: root.tokens
                    view: root.tiles && root.tiles.moon ? root.tiles.moon : ({ name: "", phase: 0, illuminated: "", rise: "", full: "" })
                  }
                }
              }
            }
          }
        }

        // Touchpad scrolling at a usable speed, with momentum.
        WheelScroller {
          anchors.fill: main
          flickable: main
          speed: root.service.scrollSpeed
        }

        Cheatsheet {
          anchors.fill: parent
          visible: root.cheatsheetShown
          tokens: root.tokens
          onDismissed: root.cheatsheetShown = false
        }
      }
    }
  }
}

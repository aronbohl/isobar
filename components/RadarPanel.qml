import QtQuick
import Quickshell.Io
import "../Radar.js" as Radar

// ³ precipitation radar: the last two hours of RainViewer frames, centered
// on the location and looping on its own, with coastlines, borders and
// cities drawn in theme colors from the bundled Natural Earth base map.
//
// p (anywhere in the app) or the ▶/❚❚ button pauses and resumes the loop.
// While the pane is focused: ←/→ (h/l) step frames (and pause), +/− zoom.
Box {
  id: root

  required property var radar        // service.radar: { host, frames } or null
  required property var location
  property bool active: true         // focused window: animate the loop
  // Zoom 6 shows a few hundred km around the location: enough for nearby
  // borders and cities in a 240px-tall panel. RainViewer stops at 7.
  property int zoom: 6

  property int frameIndex: -1
  property bool paused: false

  signal mapRequested()

  readonly property var frames: radar ? radar.frames : []
  readonly property int current: frameIndex < 0 ? frames.length - 1 : Math.min(frameIndex, frames.length - 1)
  readonly property var tiles: location && map.width > 0
    ? Radar.tiles(location.latitude, location.longitude, zoom, map.width, map.height) : []

  // data/basemap.json is 1.6 MB, so it's read the first time the radar is
  // actually on screen rather than at shell startup.
  property bool wanted: false
  onActiveChanged: if (active) wanted = true
  property var basemap: null
  readonly property var geo: basemap && location && map.width > 0
    ? Radar.basemapView(basemap, location.latitude, location.longitude, zoom, map.width, map.height, 8)
    : ({ lines: [], places: [] })

  // Frame paths whose tiles may load. Nothing loads until the radar has been
  // on screen; then the current frame and the next two do, so the loop runs
  // ahead of the network without fetching every frame up front. Loaded
  // frames stay loaded.
  property var loadedFrames: ({})
  function loadNearby() {
    if (!wanted || !frames.length) return
    var next = null
    for (var k = 0; k < 3; k++) {
      var path = frames[(current + k) % frames.length].path
      if (loadedFrames[path]) continue
      if (!next) next = Object.assign({}, loadedFrames)
      next[path] = true
    }
    if (next) loadedFrames = next
  }
  onCurrentChanged: loadNearby()
  onWantedChanged: loadNearby()

  FileView {
    path: root.wanted ? decodeURIComponent(Qt.resolvedUrl("../data/basemap.json").toString().replace(/^file:\/\//, "")) : ""
    printErrors: false
    onLoaded: {
      try { root.basemap = JSON.parse(text()) } catch (e) {}
    }
  }

  function step(delta) {
    if (!frames.length) return
    paused = true
    frameIndex = Math.max(0, Math.min(frames.length - 1, current + delta))
  }

  function zoomBy(delta) {
    zoom = Radar.clampZoom(zoom + delta)
  }

  // Back to the live loop (Esc / leaving the pane).
  function resume() {
    paused = false
  }

  function togglePause() {
    paused = !paused
  }

  panel: true
  title: "³ precipitation radar"
  spacing: tokens.px(10)

  onFramesChanged: {
    if (!paused) frameIndex = -1
    loadNearby()
  }

  // ~1.6 frames a second through the two hours, holding on "now".
  Timer {
    property int hold: 0
    interval: 600
    repeat: true
    running: root.active && !root.paused && root.frames.length > 1 && root.visible
    onTriggered: {
      if (root.current === root.frames.length - 1) {
        if (++hold < 4) return
        hold = 0
        root.frameIndex = 0
      } else root.frameIndex = root.current + 1
    }
  }

  Item {
    id: map
    width: parent.width
    height: root.tokens.px(240)
    clip: true

    Rectangle {
      anchors.fill: parent
      color: root.tokens.bg
    }

    // Only the current frame shows; see loadedFrames for which ones load.
    Repeater {
      model: root.frames

      Item {
        id: frame
        required property var modelData
        required property int index
        anchors.fill: parent
        visible: index === root.current

        Repeater {
          model: root.tiles

          Image {
            required property var modelData
            x: modelData.left
            y: modelData.top
            width: Radar.TILE
            height: Radar.TILE
            sourceSize: Qt.size(Radar.TILE * 2, Radar.TILE * 2)
            source: root.loadedFrames[frame.modelData.path] ? Radar.radarUrl(root.radar.host, frame.modelData, modelData) : ""
            asynchronous: true
            opacity: 0.85
          }
        }
      }
    }

    // Coastlines, lakes and borders, above the rain so places stay legible.
    Canvas {
      id: lines
      anchors.fill: parent

      readonly property var geo: root.geo
      onGeoChanged: requestPaint()

      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.lineJoin = "round"
        // Coast and country borders in muted; state lines quieter.
        var styles = [
          { color: root.tokens.muted, width: 1.2, alpha: 0.9 },
          { color: root.tokens.muted, width: 1.2, alpha: 0.9 },
          { color: root.tokens.muted, width: 0.8, alpha: 0.55 }
        ]
        for (var kind = 0; kind < 3; kind++) {
          ctx.strokeStyle = styles[kind].color
          ctx.lineWidth = styles[kind].width
          ctx.globalAlpha = styles[kind].alpha
          ctx.beginPath()
          for (var i = 0; i < geo.lines.length; i++) {
            var line = geo.lines[i]
            if (line.kind !== kind) continue
            var p = line.points
            ctx.moveTo(p[0], p[1])
            for (var j = 2; j < p.length; j += 2) ctx.lineTo(p[j], p[j + 1])
          }
          ctx.stroke()
        }
      }
    }

    // Nearby cities.
    Repeater {
      model: root.geo.places

      Row {
        required property var modelData
        x: modelData.x - root.tokens.px(2)
        y: modelData.y - height / 2
        spacing: root.tokens.px(5)

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: root.tokens.px(4)
          height: width
          radius: width / 2
          color: root.tokens.muted
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.name
          color: root.tokens.muted
          font.family: root.tokens.fontFamily
          font.pixelSize: root.tokens.px(11)
          style: Text.Outline
          styleColor: root.tokens.bg
        }
      }
    }

    // The mockup's terminal grid, over everything.
    Repeater {
      model: Math.max(0, Math.ceil(map.width / root.tokens.px(32)))
      Rectangle {
        required property int index
        x: index * root.tokens.px(32)
        width: 1
        height: map.height
        color: root.tokens.border
        opacity: 0.35
      }
    }
    Repeater {
      model: Math.max(0, Math.ceil(map.height / root.tokens.px(32)))
      Rectangle {
        required property int index
        y: index * root.tokens.px(32)
        width: map.width
        height: 1
        color: root.tokens.border
        opacity: 0.35
      }
    }

    // The location, at the center.
    Row {
      x: map.width / 2 - dot.width / 2
      y: map.height / 2 - dot.height / 2
      spacing: root.tokens.px(8)

      Rectangle {
        id: dot
        anchors.verticalCenter: parent.verticalCenter
        width: root.tokens.px(12)
        height: width
        radius: width / 2
        color: root.tokens.accent
        border.width: 2
        border.color: root.tokens.bg
      }
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: placeName.implicitWidth + root.tokens.px(12)
        height: placeName.implicitHeight + root.tokens.px(4)
        color: root.tokens.bg
        border.width: 1
        border.color: root.tokens.border

        Text {
          id: placeName
          anchors.centerIn: parent
          text: root.location ? root.location.name : ""
          color: root.tokens.fg
          font.family: root.tokens.fontFamily
          font.pixelSize: root.tokens.px(12)
        }
      }
    }

    Text {
      visible: !root.radar
      anchors.centerIn: parent
      text: "loading radar…"
      color: root.tokens.muted
      font.family: root.tokens.fontFamily
      font.pixelSize: root.tokens.px(12)
    }

    // Data sources (RainViewer asks for attribution).
    Text {
      x: root.tokens.px(8)
      anchors.bottom: parent.bottom
      anchors.bottomMargin: root.tokens.px(6)
      text: "RainViewer · Natural Earth"
      color: root.tokens.muted
      font.family: root.tokens.fontFamily
      font.pixelSize: root.tokens.px(10)
      style: Text.Outline
      styleColor: root.tokens.bg
    }

    // Legend: RainViewer's own palette, light → heavy.
    Row {
      anchors.right: parent.right
      anchors.rightMargin: root.tokens.px(8)
      anchors.bottom: parent.bottom
      anchors.bottomMargin: root.tokens.px(8)
      spacing: root.tokens.px(6)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "light"
        color: root.tokens.muted
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(10)
        style: Text.Outline
        styleColor: root.tokens.bg
      }
      Row {
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
          model: Radar.LEGEND
          Rectangle {
            required property string modelData
            width: root.tokens.px(10)
            height: root.tokens.px(6)
            color: modelData
          }
        }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "heavy"
        color: root.tokens.muted
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(10)
        style: Text.Outline
        styleColor: root.tokens.bg
      }
    }
  }

  // Timeline: one tick per frame, the current one bright; click to jump.
  Item {
    width: parent.width
    height: timeline.height

    Row {
      id: timeline
      spacing: root.tokens.px(8)

      // Play/pause, styled like the header buttons.
      HeaderButton {
        anchors.verticalCenter: parent.verticalCenter
        tokens: root.tokens
        text: root.paused ? "\uf04b" : "\uf04c"   // nf-fa-play / nf-fa-pause
        fontSize: root.tokens.px(10)
        minWidth: root.tokens.px(26)
        implicitHeight: root.tokens.px(22)
        onClicked: root.togglePause()
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.frames.length ? Radar.frameLabel(root.frames[0], root.frames[root.frames.length - 1]) : ""
        color: root.tokens.muted
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(12)
      }

      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.tokens.px(3)

        Repeater {
          model: root.frames.length

          Rectangle {
            required property int index
            width: root.tokens.px(6)
            height: root.tokens.px(index === root.current ? 10 : 6)
            anchors.verticalCenter: parent.verticalCenter
            color: index === root.current ? root.tokens.accent : root.tokens.border

            TapHandler {
              onTapped: {
                root.paused = true
                root.frameIndex = parent.index
              }
            }
          }
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.frames.length ? Radar.frameLabel(root.frames[root.current], root.frames[root.frames.length - 1])
          + (root.paused ? " · paused" : "") : ""
        color: root.tokens.fg
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(12)
        TapHandler { onTapped: root.paused = !root.paused }
      }
    }

    Text {
      anchors.right: parent.right
      anchors.verticalCenter: timeline.verticalCenter
      textFormat: Text.StyledText
      text: "<font color='" + root.tokens.accent + "'>m</font> open full map"
      color: mapHover.hovered ? root.tokens.fg : root.tokens.muted
      font.family: root.tokens.fontFamily
      font.pixelSize: root.tokens.px(12)
      HoverHandler { id: mapHover; cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: root.mapRequested() }
    }
  }
}

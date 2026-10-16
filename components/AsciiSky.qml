import QtQuick
import Quickshell.Io
import "../Sky.js" as Sky

// The ASCII sky behind the hero: Sky.js's two character layers drawn as
// monospace text at ~10 fps, fading into the page toward the panels.
//
// It freezes on a still frame when `animate` is off (sky fx: off, or
// Hyprland's animations are disabled) and stops ticking while `running` is
// false (window hidden, or scrolled out of view).
Item {
  id: root

  required property var tokens
  property string kind: "stars"
  property real wind: 0
  property bool animate: true
  property bool running: true

  // Hyprland's own animations switch stands in for "reduced motion".
  property bool reducedMotion: false
  readonly property bool moving: animate && !reducedMotion

  FontMetrics {
    id: metrics
    font.family: root.tokens.fontFamily
    font.pixelSize: root.tokens.px(13)
  }

  readonly property real cellWidth: Math.max(1, metrics.advanceWidth("M"))
  readonly property real lineHeight: root.tokens.px(16)
  readonly property int cols: Math.max(40, Math.min(260, Math.ceil(width / cellWidth)))
  readonly property int rows: Math.max(8, Math.ceil(height / lineHeight))

  property var sim: null
  // One string per row, so rows that didn't change keep their text layout.
  property var dimRows: []
  property var brightRows: []

  function rebuild() {
    if (width <= 0 || height <= 0) return
    sim = Sky.create(kind, wind, cols, rows)
    draw(false)
  }

  function draw(advance) {
    if (!sim) return
    var frame = Sky.step(sim, advance)
    dimRows = frame.dim
    brightRows = frame.bright
  }

  onKindChanged: Qt.callLater(rebuild)
  onWindChanged: Qt.callLater(rebuild)
  onColsChanged: Qt.callLater(rebuild)
  onRowsChanged: Qt.callLater(rebuild)
  Component.onCompleted: Qt.callLater(rebuild)

  clip: true

  Timer {
    interval: 100
    repeat: true
    running: root.running && root.moving && root.visible && root.sim !== null
    onTriggered: root.draw(true)
  }

  Process {
    running: true
    command: ["hyprctl", "getoption", "animations:enabled", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var option = JSON.parse(text)
          root.reducedMotion = option.bool === false || option.int === 0
        } catch (e) {}
      }
    }
  }

  Repeater {
    model: root.dimRows.length

    Item {
      required property int index
      y: index * root.lineHeight
      width: root.width
      height: root.lineHeight

      Text {
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        text: root.dimRows[parent.index] || ""
        color: root.tokens.skyDim
        font: metrics.font
      }
      Text {
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        text: root.brightRows[parent.index] || ""
        color: root.tokens.skyBright
        opacity: 0.75
        font: metrics.font
      }
    }
  }

  // Full strength over the hero, fading out toward the panels (the mockup's
  // mask: solid to 320px, gone by 760px).
  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0.0; color: Qt.rgba(root.tokens.bg.r, root.tokens.bg.g, root.tokens.bg.b, 0) }
      GradientStop { position: 0.42; color: Qt.rgba(root.tokens.bg.r, root.tokens.bg.g, root.tokens.bg.b, 0) }
      GradientStop { position: 1.0; color: root.tokens.bg }
    }
  }
}

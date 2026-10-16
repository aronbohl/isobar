import QtQuick
import Quickshell.Io
import qs.Commons
import "Palette.js" as Palette

// Design tokens shared by every Weather surface. One instance lives on the
// service (`service.tokens`). The shell's Color singleton only exposes the
// foundational roles, so the theme's colors.toml is read for the surfaces.
// Alert colors are fixed (see Palette.js).
QtObject {
  id: root

  property var themePalette: ({})

  readonly property var values: Palette.build(themePalette, {
    background: String(Color.background),
    foreground: String(Color.foreground),
    accent: String(Color.accent)
  })

  readonly property bool light: values.light
  readonly property color bg: values.bg
  readonly property color raised: values.raised
  readonly property color border: values.border
  readonly property color fg: values.fg
  readonly property color muted: values.muted
  readonly property color faint: values.faint
  readonly property color accent: values.accent
  readonly property color rain: values.rain
  readonly property color skyDim: values.skyDim
  readonly property color skyBright: values.skyBright
  // Good → hazardous meter colors (AQI, UV), as hex strings for gradients.
  readonly property var scale: values.scale

  readonly property string fontFamily: Style.fontFamily

  // Design sizes are specified at the default 12px base; follow the user's text size.
  function px(size) {
    return Math.max(1, Math.round(size * Style.fontScale))
  }

  // statement | advisory | watch | warning | emergency → color.
  function alert(level) {
    return values.alerts[level] || values.muted
  }

  property FileView colorsFile: FileView {
    path: Color.currentThemePath + "/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.themePalette = Palette.parseToml(text())
    onFileChanged: reload()
    onLoadFailed: root.themePalette = ({})
  }

  // Theme switches arrive over IPC and update Color without touching the
  // watched path (the theme directory is swapped), so re-read on any change.
  property Connections themeSwitch: Connections {
    target: Color
    function onBackgroundChanged() { root.colorsFile.reload() }
    function onForegroundChanged() { root.colorsFile.reload() }
    function onAccentChanged() { root.colorsFile.reload() }
  }
}

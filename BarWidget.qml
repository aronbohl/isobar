import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The bar icon: the current sky for the selected location, tinted by the
// most severe active alert, dimmed while offline. Click toggles the popover,
// right-click cycles saved locations, middle-click opens the app.
BarWidget {
  id: root
  moduleName: "io.github.aronbohl.isobar"

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property var tokens: service ? service.tokens : null
  readonly property var current: service && service.forecast ? service.forecast.current : null
  readonly property string level: service ? service.alertLevel : ""
  // Statements stay in the popover; every other level colors the icon.
  readonly property bool alerting: level !== "" && level !== "statement"

  // Typed so the theme's hex string converts and exposes r/g/b.
  readonly property color alertColor: tokens && alerting ? tokens.alert(level) : "transparent"

  // Emergency pulse, 0..1, applied to the alert color's alpha (opacity is
  // already the button's dimmed state).
  property real pulse: 1

  // Shape contract for the bar's popout routing (summon/hide, panel switching).
  readonly property bool opened: popover.item ? popover.item.opened === true : false
  readonly property bool popoutSwitchClosing: popover.item ? popover.item.popoutSwitchClosing === true : false
  function open() { if (popover.item) popover.item.open() }
  function close() { if (popover.item) popover.item.close() }
  function toggle() { if (popover.item) popover.item.toggle() }
  function closeForPopoutSwitch() { if (popover.item) popover.item.closeForPopoutSwitch() }

  function applySettings() {
    if (service) service.applyEntry(settings)
  }

  function press(button) {
    if (!service) return
    if (button === Qt.RightButton) service.cycle(1)
    else if (button === Qt.MiddleButton) service.openApp()
    else toggle()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onSettingsChanged: applySettings()
  onServiceChanged: applySettings()

  // A notification click or IPC asks for the popover. Every bar copy hears
  // it; the bar's own summon picks the focused monitor's copy, so all of
  // them asking still opens exactly one.
  Connections {
    target: root.service
    function onPopoverRequested() {
      if (root.bar && typeof root.bar.summonBarWidget === "function") root.bar.summonBarWidget(root.moduleName)
      else root.open()
    }
  }

  Loader {
    id: popover
    active: root.service !== null
    visible: false
    sourceComponent: Component {
      Popover {
        bar: root.bar
        settings: root.settings
        anchorItem: button
        hostWidget: root
        service: root.service
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Cloud until the first forecast lands, so the widget never vanishes.
    text: root.current ? Model.glyph(root.current.code, root.current.isDay) : "\ue33d"
    slotSize: Style.bar.statusSlot
    active: root.alerting
    activeColor: root.alerting
      ? Qt.rgba(root.alertColor.r, root.alertColor.g, root.alertColor.b, 0.35 + 0.65 * root.pulse)
      : (root.bar ? root.bar.urgent : Color.urgent)
    dimmed: !root.service || root.service.offline || !root.service.hasData
    tooltipText: ""
    onPressed: function(b) { root.press(b) }
  }

  SequentialAnimation on pulse {
    running: root.level === "emergency"
    loops: Animation.Infinite
    NumberAnimation { to: 0; duration: 700; easing.type: Easing.InOutSine }
    NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
    onRunningChanged: if (!running) root.pulse = 1
  }
}

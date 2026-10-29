import QtQuick

// The plugin's panel entry, kept loaded so IPC always reaches it:
//   omarchy-shell shell call io.github.aronbohl.isobar <method> ''
// toggle  — open the app, or close it if it's open on this workspace
// popover — open the bar popover
// alert   — notification click-through: select the alert's place, then
//           open the popover (payload is an opaque token)
// refresh — refetch now
// next    — cycle to the next saved location
Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null

  readonly property string pluginId: manifest && manifest.id ? manifest.id : "io.github.aronbohl.isobar"
  // Lets `shell toggle` and the shell's open bookkeeping see the app's state.
  readonly property bool opened: app.item ? app.item.opened === true : false

  function parse(payloadJson) {
    try {
      var value = JSON.parse(payloadJson || "{}")
      return value && typeof value === "object" ? value : {}
    } catch (error) {
      return {}
    }
  }

  // Summoned with {"view": "app", "alert": "<id>"} (middle-click, the
  // popover's footer and DETAILS ›).
  function open(payloadJson) {
    var request = parse(payloadJson)
    if (app.item) app.item.show(request.alert || "")
  }

  function close() {
    if (app.item) app.item.hide()
  }

  // The keybind: closes the app only when it's on the current workspace;
  // from anywhere else, the window is brought here instead.
  function toggle() {
    if (!app.item) return
    if (app.item.opened && app.item.onCurrentWorkspace()) app.item.hide()
    else app.item.show("")
  }

  // Clear the shell's open state once the app closes, so the next summon
  // opens it again instead of toggling closed.
  function release() {
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
  }

  function popover() {
    if (service) service.openPopover()
  }

  function alert(token) {
    if (service) service.openNotification(token)
  }

  function refresh() {
    if (service) service.refresh()
  }

  function next() {
    if (service) service.cycle(1)
  }

  // Created once the shell hands over the service, so bindings never see null tokens.
  Loader {
    id: app
    active: root.service !== null
    sourceComponent: Component {
      AppWindow {
        service: root.service
        onClosed: root.release()
      }
    }
  }
}

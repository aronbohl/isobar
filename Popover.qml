import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Alerts.js" as Alerts
import "components"

// The bar popover: the stock Omarchy weather layout (big icon and
// temperature, location, stats) extended with alerts, the next 8 hours and
// a 5-day row.
//
// Keys: ←/→ (h/l) location · ↑/↓ (j/k) alert · ↵ open app · u units ·
// r refresh · Esc close.
Panel {
  id: root
  moduleName: "io.github.aronbohl.isobar"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null

  readonly property var tokens: service ? service.tokens : null
  readonly property bool imperial: service ? service.imperial : false
  readonly property var view: service ? Model.popoverView(service.forecast, imperial) : null
  readonly property var alerts: service ? service.currentAlerts : []
  property int alertIndex: 0
  readonly property var alert: alerts.length ? alerts[Math.min(alertIndex, alerts.length - 1)] : null
  readonly property string fontFamily: bar ? bar.fontFamily : Style.fontFamily

  // The bar tracks the widget in its slot, not this nested panel.
  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function") return bar.switchPanelFrom(hostWidget || root, direction)
    return false
  }

  function openApp(alertId) {
    close()
    if (service) service.openApp(alertId)
  }

  function stepAlert(step) {
    if (alerts.length > 1) alertIndex = (alertIndex + step + alerts.length) % alerts.length
  }

  // A notification's alert, matched by id or by an update that replaced it.
  // Requests older than a few seconds are spent, so later opens start at 0.
  function showRequestedAlert() {
    var request = service ? service.popoverRequest : null
    alertIndex = 0
    if (!request || !request.alert || Date.now() - request.at > 5000) return
    for (var i = 0; i < alerts.length; i++) {
      if (alerts[i].id === request.alert || (alerts[i].references || []).indexOf(request.alert) !== -1) {
        alertIndex = i
        break
      }
    }
  }

  onOpenedChanged: {
    if (!opened || !service) return
    showRequestedAlert()
    // Opening is a good moment to catch up if the data is getting old.
    if (service.now - service.fetchedAt > 5 * 60000) service.refresh()
  }

  Connections {
    target: root.service
    function onLocationKeyChanged() { root.alertIndex = 0 }
    // Already open when a notification is clicked.
    function onPopoverRequestChanged() { if (root.opened) root.showRequestedAlert() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened && root.tokens !== null
    centerOnBar: true
    focusTarget: keys
    contentWidth: panel.fittedContentWidth(root.tokens ? root.tokens.px(600) : 600)
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onActivateRequested: root.openApp()
      onMoveRequested: function(dx, dy) {
        if (!root.service) return
        if (dx !== 0) root.service.cycle(dx)
        else root.stepAlert(dy)
      }
      onTextKey: function(text) {
        if (!root.service) return
        if (text === "u") root.service.toggleUnits()
        else if (text === "r") root.service.refresh()
      }

      Column {
        id: content
        width: parent.width
        visible: root.tokens !== null
        spacing: 0

        // ------------------------------------------------ empty / loading
        Text {
          textFormat: Text.PlainText
          visible: !root.view
          width: parent.width
          topPadding: root.tokens ? root.tokens.px(8) : 0
          bottomPadding: topPadding
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          text: !root.service ? ""
            : root.service.locations.length === 0 ? "No saved location yet. Press ↵ to open Weather and add one."
            : root.service.offline ? "Can't reach the forecast service. Retrying…"
            : "Fetching forecast…"
          color: root.tokens ? root.tokens.muted : "transparent"
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        // ------------------------------------------------------- hero
        Row {
          visible: root.view !== null
          width: parent.width
          spacing: root.tokens ? root.tokens.px(32) : 0

          Row {
            id: heroLeft
            spacing: root.tokens ? root.tokens.px(16) : 0

            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: root.view ? root.view.glyph : ""
              color: root.tokens ? root.tokens.fg : "transparent"
              font.family: root.fontFamily
              // Decorative; intentionally outside the Style.font scale.
              font.pixelSize: root.tokens ? root.tokens.px(52) : 52
            }

            Row {
              anchors.verticalCenter: parent.verticalCenter

              Text {
                id: bigTemp
                textFormat: Text.PlainText
                text: root.view ? root.view.temp : ""
                color: root.tokens ? root.tokens.fg : "transparent"
                font.family: root.fontFamily
                font.pixelSize: root.tokens ? root.tokens.px(68) : 68
                font.weight: Font.Medium
              }
              Text {
                textFormat: Text.PlainText
                anchors.top: bigTemp.top
                anchors.topMargin: root.tokens ? root.tokens.px(8) : 0
                leftPadding: root.tokens ? root.tokens.px(4) : 0
                text: root.view ? root.view.unit : ""
                color: root.tokens ? root.tokens.fg : "transparent"
                font.family: root.fontFamily
                font.pixelSize: root.tokens ? root.tokens.px(22) : 22
              }
            }
          }

          Column {
            width: parent.width - heroLeft.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.tokens ? root.tokens.px(16) : 0

            // Location, with its place in the saved list. Clicking cycles,
            // same as right-clicking the bar icon.
            Item {
              width: parent.width
              height: locationRow.height

              Row {
                id: locationRow
                spacing: root.tokens ? root.tokens.px(8) : 0

                Text {
                  textFormat: Text.PlainText
                  anchors.verticalCenter: parent.verticalCenter
                  text: "\uf041"
                  color: root.tokens ? root.tokens.muted : "transparent"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
                Text {
                  textFormat: Text.PlainText
                  text: root.service && root.service.location ? root.service.location.name.toUpperCase() : ""
                  color: root.tokens ? root.tokens.muted : "transparent"
                  font.family: root.fontFamily
                  font.pixelSize: root.tokens ? root.tokens.px(13) : 13
                  font.letterSpacing: 1.8
                  elide: Text.ElideRight
                }
              }

              Text {
                textFormat: Text.PlainText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.service !== null && root.service.locations.length > 1
                text: root.service ? (root.service.selected + 1) + "/" + root.service.locations.length : ""
                color: root.tokens ? root.tokens.muted : "transparent"
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              TapHandler { onTapped: if (root.service) root.service.cycle(1) }
              HoverHandler { cursorShape: root.service && root.service.locations.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor }
            }

            Grid {
              id: stats
              width: parent.width
              columns: 4
              readonly property real cell: (width - columnSpacing * 3) / 4
              columnSpacing: root.tokens ? root.tokens.px(12) : 0

              Stat {
                width: stats.cell
                tokens: root.tokens
                fontFamily: root.fontFamily
                label: "FEELS"
                value: root.view ? root.view.feels : ""
                note: root.view ? root.view.feelsNote : ""
              }
              Stat {
                width: stats.cell
                tokens: root.tokens
                fontFamily: root.fontFamily
                label: "WIND"
                value: root.view ? root.view.wind : ""
                note: root.view ? root.view.windNote : ""
                leading: Text {
                  anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                  text: "↑"
                  rotation: root.view ? root.view.windRotation : 0
                  color: root.tokens ? root.tokens.fg : "transparent"
                  font.family: root.fontFamily
                  font.pixelSize: root.tokens ? root.tokens.px(14) : 14
                  font.bold: true
                }
              }
              Stat {
                width: stats.cell
                tokens: root.tokens
                fontFamily: root.fontFamily
                label: "HUMID"
                value: root.view ? root.view.humidity : ""
                note: root.view ? root.view.dewNote : ""
              }
              Stat {
                width: stats.cell
                tokens: root.tokens
                fontFamily: root.fontFamily
                label: "HI/LO"
                value: root.view ? root.view.hi : ""
                secondary: root.view ? root.view.lo : ""
                note: root.view ? root.view.coldNote : ""
              }
            }
          }
        }

        // ------------------------------------------------------ alert
        Column {
          visible: root.view !== null && root.alert !== null
          width: parent.width
          topPadding: root.tokens ? root.tokens.px(22) : 0
          spacing: root.tokens ? root.tokens.px(6) : 0

          Item {
            width: parent.width
            height: alertTitle.height

            Row {
              id: alertTitle
              spacing: root.tokens ? root.tokens.px(10) : 0
              width: parent.width - alertNav.width - (root.tokens ? root.tokens.px(12) : 0)

              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf071"
                color: root.alert && root.tokens ? root.tokens.alert(root.alert.level) : "transparent"
                font.family: root.fontFamily
                font.pixelSize: root.tokens ? root.tokens.px(13) : 13
              }
              Text {
                textFormat: Text.PlainText
                width: parent.width - x
                text: root.alert ? root.alert.event.toUpperCase() : ""
                color: root.alert && root.tokens ? root.tokens.alert(root.alert.level) : "transparent"
                font.family: root.fontFamily
                font.pixelSize: root.tokens ? root.tokens.px(13) : 13
                font.letterSpacing: 1.8
                elide: Text.ElideRight
              }
            }

            Row {
              id: alertNav
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter

              Text {
                textFormat: Text.PlainText
                text: (root.alertIndex + 1) + " OF " + root.alerts.length + " · "
                color: root.tokens ? root.tokens.muted : "transparent"
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1.2
                TapHandler { onTapped: root.stepAlert(1) }
                HoverHandler { cursorShape: root.alerts.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor }
              }
              Text {
                textFormat: Text.PlainText
                text: "DETAILS ›"
                color: detailsHover.hovered && root.tokens ? root.tokens.fg : (root.tokens ? root.tokens.muted : "transparent")
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1.2
                TapHandler { onTapped: root.openApp(root.alert ? root.alert.id : "") }
                HoverHandler { id: detailsHover; cursorShape: Qt.PointingHandCursor }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: root.alert && root.service ? Alerts.summaryLine(root.alert, root.service.now) : ""
            color: root.tokens ? root.tokens.muted : "transparent"
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }
        }

        Rule { tokens: root.tokens; visible: root.view !== null }

        // -------------------------------------------------- next 24h
        Column {
          visible: root.view !== null
          width: parent.width
          spacing: root.tokens ? root.tokens.px(10) : 0

          Text {
            textFormat: Text.PlainText
            text: "NEXT 24 HOURS" + (hourly.step > 1 ? " · EVERY " + hourly.step + "H" : "")
            color: root.tokens ? root.tokens.muted : "transparent"
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.letterSpacing: 1.5
          }

          // The same chart as the app's ¹ hourly panel.
          HourlyChart {
            id: hourly
            width: parent.width
            tokens: root.tokens
            fontFamily: root.fontFamily
            hours: root.service ? Model.hourlyView(root.service.forecast, root.imperial) : []
          }
        }

        Rule { tokens: root.tokens; visible: root.view !== null }

        // ----------------------------------------------------- 5 days
        Row {
          visible: root.view !== null
          width: parent.width

          Repeater {
            model: root.view ? root.view.days : []

            Row {
              required property var modelData
              width: parent.width / 5
              spacing: root.tokens ? root.tokens.px(10) : 0

              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.glyph
                color: root.tokens.fg
                font.family: root.fontFamily
                font.pixelSize: root.tokens.px(22)
              }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.tokens.px(4)

                Text {
                  textFormat: Text.PlainText
                  text: modelData.label
                  color: root.tokens.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.letterSpacing: 1.4
                }
                Row {
                  spacing: root.tokens.px(6)
                  Text {
                    textFormat: Text.PlainText
                    text: modelData.hi
                    color: root.tokens.fg
                    font.family: root.fontFamily
                    font.pixelSize: root.tokens.px(13)
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: modelData.lo
                    color: root.tokens.muted
                    font.family: root.fontFamily
                    font.pixelSize: root.tokens.px(13)
                  }
                }
              }
            }
          }
        }

        // ----------------------------------------------------- footer
        Item {
          width: parent.width
          height: footerLeft.height + (root.tokens ? root.tokens.px(20) : 0)

          Text {
            id: footerLeft
            anchors.bottom: parent.bottom
            text: "<font color='" + (root.tokens ? root.tokens.fg : "") + "'>↵</font> OPEN WEATHER"
            textFormat: Text.StyledText
            color: root.tokens ? root.tokens.muted : "transparent"
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.letterSpacing: 1
            TapHandler { onTapped: root.openApp() }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
          }

          // Only when the data is suspect: offline, or older than two
          // refresh intervals.
          Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            visible: root.service !== null && root.view !== null && (root.service.offline
              || root.service.now - root.service.fetchedAt > 2 * root.service.settings.refreshMinutes * 60000)
            text: root.service ? (root.service.offline ? "offline · " : "") + root.service.updatedLabel : ""
            color: root.tokens ? root.tokens.muted : "transparent"
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }
      }
    }
  }
}

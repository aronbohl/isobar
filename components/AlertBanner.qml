import QtQuick
import "../Alerts.js" as Alerts

// An active alert above the hero, bordered in its level's color. Clicking
// expands the full NWS text (what/where/when, then what to do).
Rectangle {
  id: root

  required property var tokens
  required property var alert
  property real now: Date.now()
  property bool expanded: false

  signal toggled()

  readonly property color tone: tokens.alert(alert.level)

  implicitHeight: body.implicitHeight + tokens.px(24)
  color: Qt.rgba(tokens.bg.r, tokens.bg.g, tokens.bg.b, 0.92)
  border.width: 1
  border.color: tone

  HoverHandler { cursorShape: Qt.PointingHandCursor }
  TapHandler { onTapped: root.toggled() }

  Row {
    id: body
    x: root.tokens.px(14)
    y: root.tokens.px(12)
    width: root.width - root.tokens.px(28)
    spacing: root.tokens.px(12)

    Text {
      id: icon
      text: ""
      color: root.tone
      font.family: root.tokens.fontFamily
      font.pixelSize: root.tokens.px(13)
    }

    Column {
      width: parent.width - icon.width - parent.spacing
      spacing: root.tokens.px(10)

      Text {
        width: parent.width
        textFormat: Text.StyledText
        wrapMode: Text.Wrap
        text: "<b>" + root.alert.event + "</b> <font color='" + root.tokens.fg + "'>· "
          + Alerts.summaryLine(root.alert, root.now) + "</font>"
          + " <font color='" + root.tokens.muted + "'>" + (root.expanded ? "▴" : "▾") + "</font>"
        color: root.tone
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(13)
        lineHeight: 1.3
      }

      Text {
        visible: root.expanded && root.alert.description !== ""
        width: parent.width
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: Alerts.reflow(root.alert.description)
        color: root.tokens.fg
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(12)
        lineHeight: 1.3
      }

      Text {
        visible: root.expanded && root.alert.instruction !== ""
        width: parent.width
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: Alerts.reflow(root.alert.instruction)
        color: root.tone
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(12)
        lineHeight: 1.3
      }

      Text {
        visible: root.expanded && root.alert.area !== ""
        width: parent.width
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: root.alert.area
        color: root.tokens.muted
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(11)
      }
    }
  }
}

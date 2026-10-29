import QtQuick

// A saved location in the app sidebar: name and local time, sky and
// temperature, condition and today's range, and the top alert if any.
Rectangle {
  id: root

  required property var tokens
  required property var view       // Model.cardView
  property var alert: null         // Alerts.top for this location
  property bool selected: false

  signal clicked()
  signal removeRequested()

  readonly property real pad: tokens.px(12)

  implicitHeight: content.implicitHeight + pad * 2
  color: selected ? tokens.raised : (hover.hovered ? Qt.rgba(tokens.raised.r, tokens.raised.g, tokens.raised.b, 0.5) : "transparent")
  border.width: 1
  border.color: selected ? tokens.accent : tokens.border

  HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
  TapHandler { onTapped: root.clicked() }

  Column {
    id: content
    x: root.pad
    y: root.pad
    width: root.width - root.pad * 2
    spacing: root.tokens.px(6)

    Item {
      width: parent.width
      height: Math.max(names.height, reading.height)

      Column {
        id: names
        width: parent.width - reading.width - root.tokens.px(8)
        spacing: root.tokens.px(2)

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: root.view.name
          color: root.tokens.fg
          font.family: root.tokens.fontFamily
          font.pixelSize: root.tokens.px(14)
          font.bold: true
          elide: Text.ElideRight
        }
        Text {
          textFormat: Text.PlainText
          text: root.view.time
          color: root.tokens.muted
          font.family: root.tokens.fontFamily
          font.pixelSize: root.tokens.px(12)
        }
      }

      Row {
        id: reading
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.tokens.px(8)

        Text {
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          text: root.view.glyph
          color: root.tokens.fg
          font.family: root.tokens.fontFamily
          font.pixelSize: root.tokens.px(20)
        }
        Text {
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          text: root.view.temp
          color: root.tokens.fg
          font.family: root.tokens.fontFamily
          font.pixelSize: root.tokens.px(24)
          font.weight: Font.Light
        }
      }
    }

    Item {
      width: parent.width
      height: condition.height

      Text {
        id: condition
        textFormat: Text.PlainText
        width: parent.width - range.width - root.tokens.px(8)
        text: root.view.condition
        color: root.tokens.fg
        opacity: 0.85
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(12)
        elide: Text.ElideRight
      }

      Row {
        id: range
        anchors.right: parent.right
        spacing: root.tokens.px(8)

        Text {
          textFormat: Text.PlainText
          text: "H " + root.view.hi + "  L " + root.view.lo
          color: root.tokens.muted
          font.family: root.tokens.fontFamily
          font.pixelSize: root.tokens.px(12)
        }

        // Remove, shown on hover (x / Delete from the keyboard).
        Text {
          textFormat: Text.PlainText
          visible: hover.hovered
          text: "×"
          color: removeHover.hovered ? root.tokens.alert("warning") : root.tokens.muted
          font.family: root.tokens.fontFamily
          font.pixelSize: root.tokens.px(12)
          HoverHandler { id: removeHover }
          TapHandler { onTapped: root.removeRequested() }
        }
      }
    }

    Text {
      textFormat: Text.PlainText
      visible: root.alert !== null
      width: parent.width
      text: root.alert ? "! " + root.alert.event : ""
      color: root.alert ? root.tokens.alert(root.alert.level) : "transparent"
      font.family: root.tokens.fontFamily
      font.pixelSize: root.tokens.px(11)
      elide: Text.ElideRight
    }
  }
}

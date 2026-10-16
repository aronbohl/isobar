import QtQuick

// The app's headline block: region and local time, the city, a big
// temperature with the sky glyph, the condition with today's range, and the
// one-line summary (beside it when there's room, below when there isn't).
Flow {
  id: root

  required property var tokens
  required property var view       // Model.heroView

  readonly property real summaryWidth: Math.min(tokens.px(380), width)

  spacing: tokens.px(24)

  Column {
    id: reading
    spacing: root.tokens.px(6)

    Text {
      text: root.view.region ? root.view.region + " · " + root.view.time + " local" : root.view.time + " local"
      color: root.tokens.muted
      font.family: root.tokens.fontFamily
      font.pixelSize: root.tokens.px(13)
    }

    Text {
      text: root.view.name
      color: root.tokens.fg
      font.family: root.tokens.fontFamily
      font.pixelSize: root.tokens.px(28)
      font.bold: true
    }

    Row {
      spacing: root.tokens.px(20)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.view.temp
        color: root.tokens.fg
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(104)
        font.weight: Font.ExtraLight
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.view.glyph
        color: root.tokens.fg
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(60)
      }
    }

    Text {
      textFormat: Text.StyledText
      text: root.view.condition + " <font color='" + root.tokens.muted + "'>· H " + root.view.hi + "  L " + root.view.lo + "</font>"
      color: root.tokens.fg
      font.family: root.tokens.fontFamily
      font.pixelSize: root.tokens.px(15)
    }
  }

  // Bottom-aligned with the reading when it sits beside it.
  Item {
    width: root.width - reading.width - root.spacing >= root.summaryWidth ? root.width - reading.width - root.spacing : root.width
    height: width === root.width ? summary.implicitHeight : reading.height

    Text {
      id: summary
      // Right-aligned beside the reading; flush left once it wraps below.
      x: parent.width === root.width ? 0 : parent.width - width
      anchors.bottom: parent.bottom
      width: Math.min(root.summaryWidth, parent.width)
      wrapMode: Text.Wrap
      textFormat: Text.StyledText
      text: "<font color='" + root.tokens.accent + "'>&gt; </font>" + root.view.summary
      color: root.tokens.fg
      opacity: 0.9
      font.family: root.tokens.fontFamily
      font.pixelSize: root.tokens.px(13)
      lineHeight: 1.5
    }
  }
}

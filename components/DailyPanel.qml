import QtQuick

// ² 10-day: one row per day with sky, chance of rain, and the low–high
// range as a bar on a scale shared by all ten days; today's bar carries a
// dot at the current temperature.
Box {
  id: root

  required property var days         // Model.dailyView

  panel: true
  title: "² 10-day forecast"
  topPadding: tokens.px(14)
  padding: tokens.px(16)
  spacing: 0

  Repeater {
    model: root.days

    Item {
      id: row
      required property var modelData
      required property int index
      width: parent.width
      height: root.tokens.px(42)

      readonly property real labelW: root.tokens.px(52)
      readonly property real glyphW: root.tokens.px(24)
      readonly property real popW: root.tokens.px(38)
      readonly property real tempW: root.tokens.px(40)
      readonly property real gap: root.tokens.px(10)

      Text {
        id: day
        textFormat: Text.PlainText
        width: row.labelW
        anchors.verticalCenter: parent.verticalCenter
        text: row.modelData.label
        color: root.tokens.fg
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(14)
        font.bold: row.modelData.today
      }
      Text {
        id: sky
        textFormat: Text.PlainText
        x: row.labelW + row.gap
        width: row.glyphW
        anchors.verticalCenter: parent.verticalCenter
        text: row.modelData.glyph
        color: root.tokens.fg
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(18)
      }
      Text {
        textFormat: Text.PlainText
        x: sky.x + row.glyphW + row.gap
        width: row.popW
        anchors.verticalCenter: parent.verticalCenter
        text: row.modelData.pop
        color: root.tokens.rain
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(11)
      }
      Text {
        id: low
        textFormat: Text.PlainText
        x: sky.x + row.glyphW + row.popW + row.gap * 2
        width: row.tempW
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: row.modelData.lo
        color: root.tokens.muted
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(14)
      }

      // The shared-scale range bar.
      Item {
        id: track
        x: low.x + row.tempW + row.gap
        width: row.width - x - row.tempW - row.gap
        height: root.tokens.px(6)
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
          anchors.fill: parent
          radius: height / 2
          color: root.tokens.border
        }
        Rectangle {
          x: row.modelData.left * track.width
          width: Math.max(height, row.modelData.width * track.width)
          height: parent.height
          radius: height / 2
          color: root.tokens.accent
        }
        Rectangle {
          visible: row.modelData.now !== null
          x: (row.modelData.now || 0) * track.width - width / 2
          anchors.verticalCenter: parent.verticalCenter
          width: root.tokens.px(12)
          height: width
          radius: width / 2
          color: root.tokens.fg
          border.width: 2
          border.color: root.tokens.bg
        }
      }

      Text {
        textFormat: Text.PlainText
        anchors.right: parent.right
        width: row.tempW
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: row.modelData.hi
        color: root.tokens.fg
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(14)
      }

      Rectangle {
        visible: row.index < root.days.length - 1
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: root.tokens.border
        opacity: 0.6
      }
    }
  }
}

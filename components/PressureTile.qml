import QtQuick

// Sea-level pressure on a 270° dial (960–1060 hPa), with the 3-hour trend.
Box {
  id: root

  required property var view         // tilesView().pressure

  title: "pressure"
  minHeight: tokens.px(150)
  spacing: tokens.px(4)

  Item {
    width: parent.width
    height: gauge.height

    Canvas {
      id: gauge
      anchors.horizontalCenter: parent.horizontalCenter
      width: root.tokens.px(112)
      height: root.tokens.px(100)

      readonly property var position: root.view.position
      onPositionChanged: requestPaint()

      readonly property real start: Math.PI * 0.75
      readonly property real sweep: Math.PI * 1.5

      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var cx = width / 2
        var cy = width / 2
        var r = width / 2 - 6
        ctx.lineWidth = 1
        ctx.strokeStyle = root.tokens.border
        for (var i = 0; i <= 40; i++) {
          var a = start + sweep * i / 40
          var inner = i % 10 === 0 ? r - 9 : r - 5
          ctx.beginPath()
          ctx.moveTo(cx + inner * Math.cos(a), cy + inner * Math.sin(a))
          ctx.lineTo(cx + r * Math.cos(a), cy + r * Math.sin(a))
          ctx.stroke()
        }
        if (position === null || position === undefined) return
        var p = start + sweep * position
        ctx.lineWidth = 3
        ctx.strokeStyle = root.tokens.accent
        ctx.beginPath()
        ctx.moveTo(cx + (r - 12) * Math.cos(p), cy + (r - 12) * Math.sin(p))
        ctx.lineTo(cx + (r + 1) * Math.cos(p), cy + (r + 1) * Math.sin(p))
        ctx.stroke()
      }

      Column {
        x: (gauge.width - width) / 2
        y: gauge.width / 2 - height / 2

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.view.value
          color: root.tokens.fg
          font.family: root.tokens.fontFamily
          font.pixelSize: root.tokens.px(18)
        }
        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.view.unit
          color: root.tokens.muted
          font.family: root.tokens.fontFamily
          font.pixelSize: root.tokens.px(10)
        }
      }
    }
  }

  TileText {
    tokens: root.tokens
    horizontalAlignment: Text.AlignHCenter
    text: root.view.trend
  }
}

import QtQuick

// Compass with an arrow showing where the wind blows to, speed in the
// middle, and where it comes from (with gusts) below.
Box {
  id: root

  required property var view         // tilesView().wind

  title: "wind"
  minHeight: tokens.px(150)
  spacing: tokens.px(8)

  Item {
    width: parent.width
    height: dial.height

    Canvas {
      id: dial
      anchors.horizontalCenter: parent.horizontalCenter
      width: root.tokens.px(112)
      height: width

      readonly property var direction: root.view.direction
      onDirectionChanged: requestPaint()

      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var c = width / 2
        var r = c - root.tokens.px(14)
        ctx.strokeStyle = root.tokens.border
        ctx.lineWidth = 1
        for (var deg = 0; deg < 360; deg += 10) {
          var a = deg * Math.PI / 180
          var inner = deg % 90 === 0 ? r - 7 : r - 4
          ctx.beginPath()
          ctx.moveTo(c + inner * Math.sin(a), c - inner * Math.cos(a))
          ctx.lineTo(c + r * Math.sin(a), c - r * Math.cos(a))
          ctx.stroke()
        }
        if (direction === null || direction === undefined) return
        // Arrow from the upwind edge to the downwind edge.
        var to = (direction + 180) * Math.PI / 180
        var len = r - 10
        var tipX = c + len * Math.sin(to)
        var tipY = c - len * Math.cos(to)
        ctx.strokeStyle = root.tokens.accent
        ctx.fillStyle = root.tokens.accent
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.moveTo(c - len * Math.sin(to), c + len * Math.cos(to))
        ctx.lineTo(tipX, tipY)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(tipX, tipY)
        ctx.lineTo(tipX - 9 * Math.sin(to - 0.45), tipY + 9 * Math.cos(to - 0.45))
        ctx.lineTo(tipX - 9 * Math.sin(to + 0.45), tipY + 9 * Math.cos(to + 0.45))
        ctx.closePath()
        ctx.fill()
        // Clear the middle for the speed read-out.
        ctx.fillStyle = root.tokens.bg
        ctx.beginPath()
        ctx.arc(c, c, r * 0.42, 0, Math.PI * 2)
        ctx.fill()
      }

      Repeater {
        model: [["N", 0], ["E", 90], ["S", 180], ["W", 270]]

        Text {
          required property var modelData
          readonly property real angle: modelData[1] * Math.PI / 180
          readonly property real radius: dial.width / 2 - root.tokens.px(6)
          x: dial.width / 2 + radius * Math.sin(angle) - width / 2
          y: dial.height / 2 - radius * Math.cos(angle) - height / 2
          text: modelData[0]
          color: modelData[0] === "N" ? root.tokens.fg : root.tokens.muted
          font.family: root.tokens.fontFamily
          font.pixelSize: root.tokens.px(10)
        }
      }

      Column {
        anchors.centerIn: parent

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.view.speed
          color: root.tokens.fg
          font.family: root.tokens.fontFamily
          font.pixelSize: root.tokens.px(18)
        }
        Text {
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
    text: "from " + (root.view.from || "—") + " · gusts " + root.view.gust
  }
}

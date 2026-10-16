import QtQuick

// Moon phase drawn as a lit disc, with illumination, moonrise and the days
// to the next full moon.
Box {
  id: root

  required property var view         // tilesView().moon

  title: "moon"
  minHeight: tokens.px(150)
  spacing: tokens.px(8)

  Row {
    spacing: root.tokens.px(14)

    Canvas {
      id: disc
      width: root.tokens.px(44)
      height: width

      readonly property real phase: root.view.phase
      onPhaseChanged: requestPaint()

      // The lit part: the bright limb's semicircle, closed by the
      // terminator, an ellipse whose x-radius is r·cos(2π·phase). New moon
      // collapses it to nothing; full moon opens it to the whole disc.
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var c = width / 2
        var r = c - 1
        ctx.fillStyle = root.tokens.border
        ctx.beginPath()
        ctx.arc(c, c, r, 0, Math.PI * 2)
        ctx.fill()

        var k = Math.cos(2 * Math.PI * phase)
        var side = phase <= 0.5 ? 1 : -1      // waxing lit on the right
        var steps = 32
        ctx.fillStyle = root.tokens.fg
        ctx.beginPath()
        for (var i = 0; i <= steps; i++) {
          var t = -Math.PI / 2 + Math.PI * i / steps
          var x = c + side * r * Math.cos(t)
          var y = c + r * Math.sin(t)
          if (i === 0) ctx.moveTo(x, y)
          else ctx.lineTo(x, y)
        }
        for (var j = 0; j <= steps; j++) {
          var u = Math.PI / 2 - Math.PI * j / steps
          ctx.lineTo(c + side * k * r * Math.cos(u), c + r * Math.sin(u))
        }
        ctx.closePath()
        ctx.fill()
      }
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: root.tokens.px(2)

      Text {
        text: root.view.name
        color: root.tokens.fg
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(14)
      }
      Text {
        text: root.view.illuminated
        color: root.tokens.muted
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(12)
      }
    }
  }

  TileText { tokens: root.tokens; text: root.view.rise + "\n" + root.view.full }
}

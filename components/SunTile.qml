import QtQuick

// Next sunrise or sunset, with the sun's progress along today's arc.
Box {
  id: root

  required property var view         // tilesView().sun

  title: view.title
  minHeight: tokens.px(150)
  spacing: tokens.px(6)

  BigValue { tokens: root.tokens; value: root.view.time }

  Canvas {
    id: arc
    width: parent.width
    height: root.tokens.px(44)

    readonly property var progress: root.view.progress
    readonly property bool isDay: root.view.isDay
    onProgressChanged: requestPaint()
    onIsDayChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var cx = width / 2
      var cy = height - 2
      var r = Math.min(width / 2 - 8, height - 6)
      ctx.lineWidth = 1
      ctx.strokeStyle = root.tokens.border
      ctx.beginPath()
      ctx.moveTo(0, cy)
      ctx.lineTo(width, cy)
      ctx.stroke()
      ctx.lineWidth = 2
      ctx.beginPath()
      ctx.arc(cx, cy, r, Math.PI, Math.PI * 2)
      ctx.stroke()
      if (progress === null) return
      // Canvas angles run clockwise from +x, so π → 2π passes over the top.
      var end = Math.PI + Math.PI * progress
      ctx.strokeStyle = root.tokens.fg
      ctx.beginPath()
      ctx.arc(cx, cy, r, Math.PI, end)
      ctx.stroke()
      if (!isDay) return
      ctx.fillStyle = root.tokens.fg
      ctx.beginPath()
      ctx.arc(cx + r * Math.cos(end), cy + r * Math.sin(end), 5, 0, Math.PI * 2)
      ctx.fill()
    }
  }

  TileText { tokens: root.tokens; text: root.view.sub }
}

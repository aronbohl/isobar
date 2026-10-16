import QtQuick

// The next 24 hours as columns (time, sky, chance of rain) over a
// temperature line, used by the app's ¹ hourly panel and the bar popover.
// Rather than scrolling sideways, it shows every hour when there's room and
// every 2nd or 3rd hour when there isn't (`step`).
Column {
  id: root

  required property var tokens
  required property var hours          // Model.hourlyView
  property string fontFamily: tokens.fontFamily
  property real minColumnWidth: tokens.px(52)

  readonly property int fits: Math.max(1, Math.floor(width / minColumnWidth))
  readonly property int step: Math.max(1, Math.ceil(hours.length / fits))
  readonly property var shown: hours.filter(function(_, i) { return i % step === 0 })
  readonly property real columnWidth: shown.length ? width / shown.length : 0

  spacing: tokens.px(4)

  Row {
    width: parent.width

    Repeater {
      model: root.shown

      Column {
        required property var modelData
        required property int index
        width: root.columnWidth
        spacing: root.tokens.px(8)

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: modelData.label
          color: index === 0 ? root.tokens.fg : root.tokens.muted
          font.family: root.fontFamily
          font.pixelSize: root.tokens.px(12)
          font.bold: index === 0
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: modelData.glyph
          color: root.tokens.fg
          font.family: root.fontFamily
          font.pixelSize: root.tokens.px(20)
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          // Keeps its line even when empty, so the chart lines up.
          text: modelData.pop || " "
          color: root.tokens.rain
          font.family: root.fontFamily
          font.pixelSize: root.tokens.px(11)
        }
      }
    }
  }

  // The temperature line through each shown hour.
  Canvas {
    width: parent.width
    height: root.tokens.px(56)

    readonly property var values: root.shown.map(function(h) { return h.value })
    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()

    function yFor(v, lo, hi) {
      var pad = root.tokens.px(8)
      return hi === lo ? height / 2 : pad + (hi - v) / (hi - lo) * (height - pad * 2)
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var vals = values.filter(function(v) { return v !== null })
      if (vals.length < 2) return
      var lo = Math.min.apply(null, vals)
      var hi = Math.max.apply(null, vals)
      var w = root.columnWidth
      ctx.lineWidth = 2
      ctx.strokeStyle = root.tokens.accent
      ctx.lineJoin = "round"
      ctx.beginPath()
      var started = false
      for (var i = 0; i < values.length; i++) {
        if (values[i] === null) continue
        var x = w * i + w / 2
        var y = yFor(values[i], lo, hi)
        if (started) ctx.lineTo(x, y)
        else { ctx.moveTo(x, y); started = true }
      }
      ctx.stroke()
      ctx.fillStyle = root.tokens.accent
      for (var j = 0; j < values.length; j++) {
        if (values[j] === null) continue
        ctx.beginPath()
        ctx.arc(w * j + w / 2, yFor(values[j], lo, hi), j === 0 ? 3.5 : 2, 0, Math.PI * 2)
        ctx.fill()
      }
    }
  }

  Row {
    width: parent.width

    Repeater {
      model: root.shown

      Text {
        required property var modelData
        width: root.columnWidth
        horizontalAlignment: Text.AlignHCenter
        text: modelData.temp
        color: root.tokens.fg
        font.family: root.fontFamily
        font.pixelSize: root.tokens.px(15)
      }
    }
  }
}

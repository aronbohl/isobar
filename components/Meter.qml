import QtQuick

// Good → hazardous gradient bar with a dot at `position` (0–1), for the AQI
// and UV tiles. `stops` places the five scale colors along the bar.
Item {
  id: root

  required property var tokens
  property var position: null
  property var stops: [0, 0.25, 0.5, 0.75, 1]

  implicitHeight: tokens.px(12)

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: root.tokens.px(6)
    radius: height / 2
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: root.stops[0]; color: root.tokens.scale[0] }
      GradientStop { position: root.stops[1]; color: root.tokens.scale[1] }
      GradientStop { position: root.stops[2]; color: root.tokens.scale[2] }
      GradientStop { position: root.stops[3]; color: root.tokens.scale[3] }
      GradientStop { position: root.stops[4]; color: root.tokens.scale[4] }
    }
  }

  Rectangle {
    visible: root.position !== null
    x: Math.max(0, Math.min(root.width - width, (root.position || 0) * root.width - width / 2))
    anchors.verticalCenter: parent.verticalCenter
    width: root.tokens.px(12)
    height: width
    radius: width / 2
    color: root.tokens.fg
    border.width: 2
    border.color: root.tokens.bg
  }
}

import QtQuick

// The ? overlay: every app shortcut, grouped, over the dimmed window.
// ? or Esc (or a click outside the box) closes it.
Item {
  id: root

  required property var tokens

  signal dismissed()

  readonly property var groups: [
    { title: "general", keys: [
      ["?", "this cheatsheet"],
      ["q", "quit"],
      ["esc", "unfocus pane"],
      ["r", "refresh"],
      ["u", "toggle °C / °F"],
      ["a", "sky fx on / off"]
    ] },
    { title: "locations", keys: [
      ["j / k  ↓ / ↑", "next / previous"],
      ["J / K", "move up / down"],
      ["x  del", "remove selected"],
      ["/", "search saved"],
      ["  ↵", "pick, or search online"],
      ["  ↑ / ↓", "move through results"],
      ["  esc", "leave search"]
    ] },
    { title: "scroll", keys: [
      ["0", "expand / collapse alerts"],
      ["1  2  3", "hourly · 10-day · radar"],
      ["space  pgdn", "page down"],
      ["pgup", "page up"],
      ["home / end", "top / bottom"]
    ] },
    { title: "radar", keys: [
      ["p", "pause / play"],
      ["m", "full map in browser"],
      ["← / →  h / l", "step frames (focused)"],
      ["+ / −", "zoom (focused)"]
    ] }
  ]

  // Dims the app behind; a click anywhere outside the box closes it.
  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(root.tokens.bg.r, root.tokens.bg.g, root.tokens.bg.b, 0.85)

    TapHandler {
      onTapped: function(eventPoint) {
        var p = box.mapFromItem(root, eventPoint.position.x, eventPoint.position.y)
        if (!box.contains(p)) root.dismissed()
      }
    }
    // Keeps the wheel from scrolling the page underneath.
    WheelHandler { onWheel: function(event) { event.accepted = true } }
  }

  // Box fills are see-through for the sky; this one sits on solid bg.
  Rectangle {
    anchors.fill: box
    color: root.tokens.bg
  }

  Box {
    id: box
    tokens: root.tokens
    panel: true
    title: "keys <font color='" + root.tokens.muted + "'>· ? or esc to close</font>"
    anchors.centerIn: parent
    width: Math.min(root.width - root.tokens.px(48), root.tokens.px(780))
    padding: root.tokens.px(20)
    topPadding: root.tokens.px(26)

    Flow {
      id: flow
      width: parent.width
      spacing: root.tokens.px(28)

      readonly property real groupWidth: {
        var min = root.tokens.px(220)
        var columns = Math.max(1, Math.floor((width + spacing) / (min + spacing)))
        return (width - spacing * (columns - 1)) / columns
      }

      Repeater {
        model: root.groups

        Column {
          id: group
          required property var modelData
          width: flow.groupWidth
          spacing: root.tokens.px(6)

          Text {
            text: group.modelData.title
            color: root.tokens.accent
            font.family: root.tokens.fontFamily
            font.pixelSize: root.tokens.px(12)
            font.bold: true
            bottomPadding: root.tokens.px(2)
          }

          Repeater {
            model: group.modelData.keys

            Row {
              id: line
              required property var modelData
              spacing: root.tokens.px(10)

              Text {
                width: root.tokens.px(96)
                text: line.modelData[0]
                color: root.tokens.fg
                font.family: root.tokens.fontFamily
                font.pixelSize: root.tokens.px(12)
              }
              Text {
                width: group.width - root.tokens.px(106)
                text: line.modelData[1]
                color: root.tokens.muted
                font.family: root.tokens.fontFamily
                font.pixelSize: root.tokens.px(12)
                elide: Text.ElideRight
              }
            }
          }
        }
      }
    }
  }
}

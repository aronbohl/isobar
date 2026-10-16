import QtQuick

// Footer hint: the key in the accent color, then what it does. Clicking it
// does the same thing, so every shortcut also works with the mouse.
Row {
  id: root

  required property var tokens
  property string key: ""
  property string label: ""

  signal triggered()

  spacing: tokens.px(6)

  Text {
    text: root.key
    color: root.tokens.accent
    font.family: root.tokens.fontFamily
    font.pixelSize: root.tokens.px(12)
  }

  Text {
    text: root.label
    color: hover.hovered ? root.tokens.fg : root.tokens.muted
    font.family: root.tokens.fontFamily
    font.pixelSize: root.tokens.px(12)
  }

  HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
  TapHandler { onTapped: root.triggered() }
}

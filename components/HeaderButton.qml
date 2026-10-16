import QtQuick

// Bordered header control: a text or glyph button, optionally "selected"
// (filled with the accent, as in the °C/°F group).
Rectangle {
  id: root

  required property var tokens
  property string text: ""
  property bool selected: false
  property bool bordered: true
  property real minWidth: tokens.px(32)
  property int fontSize: tokens.px(12)
  property alias label: label

  signal clicked()

  implicitWidth: Math.max(minWidth, label.implicitWidth + tokens.px(20))
  implicitHeight: tokens.px(30)
  color: selected ? tokens.accent : (hover.hovered ? tokens.raised : "transparent")
  border.width: bordered ? 1 : 0
  border.color: tokens.border

  Text {
    id: label
    anchors.centerIn: parent
    text: root.text
    color: root.selected ? root.tokens.bg : (hover.hovered ? root.tokens.fg : root.tokens.muted)
    font.family: root.tokens.fontFamily
    font.pixelSize: root.fontSize
  }

  HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
  TapHandler { onTapped: root.clicked() }
}

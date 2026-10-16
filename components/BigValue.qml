import QtQuick

// A tile's headline number, with an optional label after it.
Row {
  id: root

  required property var tokens
  property string value: ""
  property string label: ""
  property color labelColor: tokens.fg
  property string note: ""

  spacing: tokens.px(10)

  Text {
    id: big
    text: root.value
    color: root.tokens.fg
    font.family: root.tokens.fontFamily
    font.pixelSize: root.tokens.px(32)
    font.weight: Font.ExtraLight
  }
  Text {
    visible: root.label !== ""
    anchors.baseline: big.baseline
    text: root.label
    color: root.labelColor
    font.family: root.tokens.fontFamily
    font.pixelSize: root.tokens.px(14)
  }
  Text {
    visible: root.note !== ""
    anchors.baseline: big.baseline
    text: root.note
    color: root.tokens.muted
    font.family: root.tokens.fontFamily
    font.pixelSize: root.tokens.px(12)
  }
}

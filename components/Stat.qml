import QtQuick

// One popover stat: a tracked-out label, the value, and a muted note.
// `leading` is an optional item placed before the value (the wind arrow).
Column {
  id: root

  required property var tokens
  property string fontFamily: tokens.fontFamily
  property string label: ""
  property string value: ""
  property string secondary: ""
  property string note: ""
  property alias leading: leadingSlot.data

  spacing: tokens.px(7)

  Text {
    textFormat: Text.PlainText
    text: root.label
    color: root.tokens.muted
    font.family: root.fontFamily
    font.pixelSize: root.tokens.px(11)
    font.letterSpacing: 1.5
  }

  Row {
    spacing: root.tokens.px(6)

    Item {
      id: leadingSlot
      width: childrenRect.width
      height: valueText.height
    }

    Text {
      id: valueText
      textFormat: Text.PlainText
      text: root.value
      color: root.tokens.fg
      font.family: root.fontFamily
      font.pixelSize: root.tokens.px(15)
    }

    Text {
      textFormat: Text.PlainText
      visible: root.secondary !== ""
      anchors.baseline: valueText.baseline
      text: root.secondary
      color: root.tokens.muted
      font.family: root.fontFamily
      font.pixelSize: root.tokens.px(15)
    }
  }

  Text {
    textFormat: Text.PlainText
    visible: root.note !== ""
    text: root.note
    color: root.tokens.muted
    font.family: root.fontFamily
    font.pixelSize: root.tokens.px(11)
  }
}

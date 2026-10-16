import QtQuick

// A tile's descriptive line.
Text {
  required property var tokens

  width: parent ? parent.width : implicitWidth
  wrapMode: Text.Wrap
  color: tokens.fg
  opacity: 0.85
  font.family: tokens.fontFamily
  font.pixelSize: tokens.px(12)
  lineHeight: 1.3
}

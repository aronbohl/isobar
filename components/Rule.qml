import QtQuick

// Horizontal divider between popover sections.
Item {
  id: root

  required property var tokens

  width: parent ? parent.width : 0
  height: tokens ? tokens.px(36) : 0

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: 1
    color: root.tokens ? root.tokens.border : "transparent"
  }
}

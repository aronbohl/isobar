import QtQuick

// btop-style box: a 1px border with the title inset into its top edge.
// Panels title in the accent ("¹ hourly"); tiles in the muted color. The
// fill is slightly translucent so the ASCII sky shows through behind it.
Item {
  id: root

  required property var tokens
  property string title: ""          // StyledText
  property bool panel: false
  property bool focused: false
  property real padding: tokens.px(16)
  property real topPadding: tokens.px(22)
  property real minHeight: 0
  property alias spacing: body.spacing
  default property alias content: body.data

  implicitHeight: Math.max(minHeight, body.implicitHeight + topPadding + padding)

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(root.tokens.bg.r, root.tokens.bg.g, root.tokens.bg.b, 0.88)
    border.width: 1
    border.color: root.focused ? root.tokens.accent : root.tokens.border
  }

  // The title sits on the border line, on a bg-colored patch.
  Rectangle {
    x: root.tokens.px(12)
    y: -height / 2
    width: titleText.implicitWidth + root.tokens.px(12)
    height: titleText.implicitHeight
    color: root.tokens.bg
    visible: root.title !== ""

    Text {
      id: titleText
      anchors.centerIn: parent
      textFormat: Text.StyledText
      text: root.title
      color: root.panel || root.focused ? root.tokens.accent : root.tokens.muted
      font.family: root.tokens.fontFamily
      font.pixelSize: root.tokens.px(12)
      font.weight: Font.Medium
    }
  }

  Column {
    id: body
    x: root.padding
    y: root.topPadding
    width: root.width - root.padding * 2
    spacing: root.tokens.px(10)
  }
}

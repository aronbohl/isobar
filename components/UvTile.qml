import QtQuick

// UV index now, and how long sun protection is needed today.
Box {
  id: root

  required property var view         // tilesView().uv

  title: "uv index"
  minHeight: tokens.px(150)

  BigValue {
    tokens: root.tokens
    value: root.view.value
    label: root.view.label
    labelColor: root.view.level === null ? root.tokens.muted : root.tokens.scale[root.view.level]
  }
  // UV breakpoints 3/6/8/11 on a 0–11 bar.
  Meter {
    width: parent.width
    tokens: root.tokens
    position: root.view.position
    stops: [0, 3 / 11, 6 / 11, 8 / 11, 1]
  }
  TileText { tokens: root.tokens; text: root.view.desc }
}

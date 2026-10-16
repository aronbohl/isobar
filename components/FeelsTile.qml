import QtQuick

Box {
  id: root

  required property var view         // tilesView().feels

  title: "feels like"
  minHeight: tokens.px(150)

  BigValue { tokens: root.tokens; value: root.view.value }
  TileText { tokens: root.tokens; text: root.view.desc }
}

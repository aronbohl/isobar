import QtQuick

// Rain (or snow water) over the last 24 hours, and the next wet day.
Box {
  id: root

  required property var view         // tilesView().precip

  title: "precipitation"
  minHeight: tokens.px(150)

  BigValue { tokens: root.tokens; value: root.view.past }
  Text {
    text: "in last 24h"
    color: root.tokens.fg
    font.family: root.tokens.fontFamily
    font.pixelSize: root.tokens.px(13)
  }
  TileText { tokens: root.tokens; text: root.view.outlook }
}

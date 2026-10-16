import QtQuick

// Relative humidity as 20 cells, and the dew point.
Box {
  id: root

  required property var view         // tilesView().humidity

  title: "humidity"
  minHeight: tokens.px(150)

  BigValue { tokens: root.tokens; value: root.view.value }

  Row {
    id: cells
    width: parent.width
    spacing: 2

    Repeater {
      model: 20

      Rectangle {
        required property int index
        width: (cells.width - cells.spacing * 19) / 20
        height: root.tokens.px(10)
        color: index < root.view.cells ? root.tokens.rain : root.tokens.border
      }
    }
  }

  TileText { tokens: root.tokens; text: "The dew point is " + root.view.dew + " right now." }
}

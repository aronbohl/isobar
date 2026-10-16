import QtQuick

// US AQI with its category, on the good → hazardous scale.
Box {
  id: root

  required property var view         // tilesView().aqi

  title: "air quality"

  BigValue {
    tokens: root.tokens
    value: root.view.value
    label: root.view.label
    labelColor: root.view.level === null ? root.tokens.muted : root.tokens.scale[root.view.level]
    note: "US AQI"
  }
  // AQI breakpoints 50/100/150/200/300 on a 0–300 bar.
  Meter {
    width: parent.width
    tokens: root.tokens
    position: root.view.position
    stops: [0, 1 / 6, 2 / 6, 3 / 6, 4 / 6]
  }
  TileText { tokens: root.tokens; text: root.view.desc }
}

import QtQuick

// ¹ hourly: the app's boxed HourlyChart, titled with how densely it shows
// the 24 hours.
Box {
  id: root

  required property var hours        // Model.hourlyView

  panel: true
  title: "¹ hourly <font color='" + tokens.muted + "'>· next 24h" + (chart.step > 1 ? " · every " + chart.step + "h" : "") + "</font>"
  padding: tokens.px(8)
  topPadding: tokens.px(20)

  HourlyChart {
    id: chart
    width: parent.width
    tokens: root.tokens
    hours: root.hours
  }
}

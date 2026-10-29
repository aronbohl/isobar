import QtQuick
import QtQuick.Shapes
import "../Model.js" as Model
import "../Alerts.js" as Alerts

// Saved locations and location search.
//
// Typing filters the saved cards. ↵ picks the first match; with no match (or
// after "+ add location") it searches places online instead, and the results
// replace the cards: ↑/↓ move, ↵ adds, Esc backs out.
Item {
  id: root

  required property var tokens
  required property var service

  readonly property string query: field.text.replace(/^\s+|\s+$/g, "")
  readonly property bool searchFocused: field.activeFocus
  // Online place search, entered from "+ add location" or a query with no
  // saved match.
  property bool online: false
  property int highlight: 0

  readonly property var matches: {
    var out = []
    var list = service.locations
    for (var i = 0; i < list.length; i++)
      if (Model.matchesQuery(list[i], query)) out.push({ location: list[i], index: i })
    return out
  }
  readonly property bool resultsCurrent: online && service.searchedQuery === query && query.length >= 2
  readonly property var results: resultsCurrent ? service.searchResults : []

  // Hands keyboard focus back to the window's shortcuts.
  signal done()
  // A saved location was clicked (the app closes its drawer).
  signal picked()

  function focusSearch(placeSearch) {
    online = placeSearch === true
    highlight = 0
    field.forceActiveFocus()
    field.selectAll()
  }

  function reset() {
    field.text = ""
    online = false
    highlight = 0
    done()
  }

  function submit() {
    if (online) {
      if (results.length) {
        service.addLocation(results[Math.min(highlight, results.length - 1)])
        reset()
      } else if (query.length >= 2) service.search(query)
      return
    }
    if (query === "") return reset()
    if (matches.length) {
      service.select(matches[0].index)
      reset()
    } else {
      online = true
      service.search(query)
    }
  }

  // Scrolls the list just enough to show the selected card (or, while
  // searching, the highlighted match or result).
  function reveal() {
    var item = null
    if (online) item = resultCards.itemAt(highlight)
    else if (query !== "") item = savedCards.itemAt(highlight)
    else for (var i = 0; i < matches.length; i++)
      if (matches[i].index === service.selected) item = savedCards.itemAt(i)
    if (!item) return
    var pad = tokens.px(8)
    var top = item.y - pad
    var bottom = item.y + item.height + pad - list.height
    var y = list.contentY
    if (top < y) y = top
    else if (bottom > y) y = bottom
    y = Math.max(0, Math.min(y, list.contentHeight - list.height))
    if (y !== list.contentY) {
      list.cancelFlick()
      list.contentY = y
    }
  }

  onHighlightChanged: Qt.callLater(reveal)
  Connections {
    target: root.service
    function onSelectedChanged() { Qt.callLater(root.reveal) }
    function onLocationsChanged() { Qt.callLater(root.reveal) }
  }

  function step(delta) {
    var count = online ? results.length : matches.length
    if (count > 0) highlight = Math.max(0, Math.min(count - 1, highlight + delta))
  }

  // While searching places, typing searches as you go (debounced).
  Timer {
    id: debounce
    interval: 350
    onTriggered: if (root.online) root.service.search(root.query)
  }

  Column {
    id: top
    width: parent.width
    spacing: root.tokens.px(10)

    Text {
      textFormat: Text.PlainText
      text: root.online ? "add a location" : "search locations"
      color: root.tokens.muted
      font.family: root.tokens.fontFamily
      font.pixelSize: root.tokens.px(12)
    }

    Rectangle {
      width: parent.width
      height: root.tokens.px(36)
      color: "transparent"
      border.width: 1
      border.color: field.activeFocus ? root.tokens.accent : root.tokens.border

      Text {
        id: slash
        textFormat: Text.PlainText
        x: root.tokens.px(12)
        anchors.verticalCenter: parent.verticalCenter
        text: "/"
        color: root.tokens.accent
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(14)
      }

      TextInput {
        id: field
        anchors.left: slash.right
        anchors.leftMargin: root.tokens.px(8)
        anchors.right: parent.right
        anchors.rightMargin: root.tokens.px(10)
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: root.tokens.fg
        selectionColor: root.tokens.accent
        selectedTextColor: root.tokens.bg
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(13)

        onTextChanged: {
          root.highlight = 0
          if (root.online) debounce.restart()
        }

        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            root.reset()
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.submit()
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.step(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.step(-1)
            event.accepted = true
          }
        }

        Text {
          textFormat: Text.PlainText
          visible: field.text === ""
          anchors.verticalCenter: parent.verticalCenter
          text: root.online ? "city, zip or airport" : "filter saved locations"
          color: root.tokens.muted
          font: field.font
        }
      }

      TapHandler { onTapped: root.focusSearch(root.online) }
    }
  }

  Flickable {
    id: list
    anchors.top: top.bottom
    anchors.topMargin: root.tokens.px(14)
    anchors.bottom: add.top
    anchors.bottomMargin: root.tokens.px(12)
    width: parent.width
    contentHeight: listColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    // Keeps the selection in view when the window is resized.
    onHeightChanged: Qt.callLater(root.reveal)

    Column {
      id: listColumn
      width: list.width
      spacing: root.tokens.px(8)

      // Saved locations (filtered while typing).
      Repeater {
        id: savedCards
        model: root.online ? [] : root.matches

        LocationCard {
          required property var modelData
          required property int index
          width: listColumn.width
          tokens: root.tokens
          view: Model.cardView(modelData.location, root.service.forecasts[Model.locationKey(modelData.location)] || null,
            root.service.imperial, root.service.now)
          alert: Alerts.top(root.service.alerts[Model.locationKey(modelData.location)] || [])
          selected: root.query !== "" ? index === root.highlight : modelData.index === root.service.selected
          onClicked: {
            root.service.select(modelData.index)
            if (root.query !== "") root.reset()
            root.picked()
          }
          onRemoveRequested: root.service.removeLocation(modelData.index)
        }
      }

      // Place search results.
      Repeater {
        id: resultCards
        model: root.results

        Rectangle {
          id: result
          required property var modelData
          required property int index
          width: listColumn.width
          height: resultColumn.implicitHeight + root.tokens.px(20)
          color: index === root.highlight || resultHover.hovered ? root.tokens.raised : "transparent"
          border.width: 1
          border.color: index === root.highlight ? root.tokens.accent : root.tokens.border

          HoverHandler { id: resultHover; cursorShape: Qt.PointingHandCursor }
          TapHandler {
            onTapped: {
              root.service.addLocation(result.modelData)
              root.reset()
            }
          }

          Column {
            id: resultColumn
            x: root.tokens.px(12)
            y: root.tokens.px(10)
            width: parent.width - root.tokens.px(24)
            spacing: root.tokens.px(2)

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: "+ " + result.modelData.name
              color: root.tokens.fg
              font.family: root.tokens.fontFamily
              font.pixelSize: root.tokens.px(13)
              font.bold: true
              elide: Text.ElideRight
            }
            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: result.modelData.region
              color: root.tokens.muted
              font.family: root.tokens.fontFamily
              font.pixelSize: root.tokens.px(12)
              elide: Text.ElideRight
            }
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        width: listColumn.width
        topPadding: root.tokens.px(4)
        wrapMode: Text.Wrap
        visible: text !== ""
        text: {
          if (root.online) {
            if (root.query.length < 2) return "type a place name"
            if (root.service.searching) return "searching…"
            if (root.resultsCurrent && root.results.length === 0) return "no places match “" + root.query + "”"
            return root.resultsCurrent ? "↵ add the highlighted place · esc back" : ""
          }
          if (root.service.locations.length === 0) return "no saved locations yet"
          if (root.query !== "" && root.matches.length === 0)
            return "no saved location matches “" + root.query + "” · press ↵ to search online"
          return ""
        }
        color: root.tokens.muted
        font.family: root.tokens.fontFamily
        font.pixelSize: root.tokens.px(12)
      }
    }
  }

  WheelScroller {
    anchors.fill: list
    flickable: list
    speed: root.service.scrollSpeed
  }

  // "+ add location", dashed like the mockup.
  Item {
    id: add
    anchors.bottom: parent.bottom
    width: parent.width
    height: root.tokens.px(36)

    Shape {
      anchors.fill: parent
      ShapePath {
        strokeColor: addHover.hovered ? root.tokens.accent : root.tokens.border
        strokeWidth: 1
        strokeStyle: ShapePath.DashLine
        dashPattern: [4, 3]
        fillColor: "transparent"
        startX: 0.5; startY: 0.5
        PathLine { x: add.width - 0.5; y: 0.5 }
        PathLine { x: add.width - 0.5; y: add.height - 0.5 }
        PathLine { x: 0.5; y: add.height - 0.5 }
        PathLine { x: 0.5; y: 0.5 }
      }
    }

    Text {
      textFormat: Text.PlainText
      x: root.tokens.px(12)
      anchors.verticalCenter: parent.verticalCenter
      text: "+ add location"
      color: addHover.hovered ? root.tokens.fg : root.tokens.muted
      font.family: root.tokens.fontFamily
      font.pixelSize: root.tokens.px(12)
    }

    HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.focusSearch(true) }
  }
}

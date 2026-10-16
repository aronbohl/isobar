import QtQuick

// Trackpad-friendly wheel handling for a Flickable or ListView (shared
// with the Omarchy Stocks plugin). Place it as
// a sibling covering the flickable (not inside it). Qt applies trackpad
// pixels 1:1 and Omarchy scales touchpads to 0.4, which makes lists crawl;
// this scales trackpad input up and adds momentum when the fingers lift,
// using the flickable's own deceleration. Clicks and hover pass through.
MouseArea {
  id: root

  required property Flickable flickable
  // Trackpad multiplier, e.g. 2.5 roughly cancels Omarchy's 0.4 scroll_factor.
  property real speed: 2.5
  // Pixels per mouse-wheel notch.
  property real wheelStep: 96
  // A pause this long between trackpad events means the fingers lifted.
  property int liftDelay: 48

  property real velocity: 0 // px per ms; positive scrolls toward the end
  property double lastEvent: 0

  acceptedButtons: Qt.NoButton
  hoverEnabled: false

  function scrollBy(dy) {
    var f = flickable
    var top = f.originY
    var bottom = f.originY + Math.max(0, f.contentHeight - f.height)
    f.contentY = Math.max(top, Math.min(bottom, f.contentY + dy))
  }

  onWheel: function(wheel) {
    lift.stop()
    flickable.cancelFlick()
    var now = Date.now()
    if (wheel.pixelDelta.y !== 0) {
      var dy = -wheel.pixelDelta.y * speed
      var gap = now - lastEvent
      var instant = dy / Math.max(8, gap)
      // A fresh gesture starts from scratch; otherwise smooth out jitter.
      velocity = gap > 120 ? instant : velocity * 0.7 + instant * 0.3
      lastEvent = now
      scrollBy(dy)
      lift.restart()
    } else if (wheel.angleDelta.y !== 0) {
      velocity = 0
      scrollBy(-wheel.angleDelta.y / 120 * wheelStep)
    }
    wheel.accepted = true
  }

  Timer {
    id: lift
    interval: root.liftDelay
    onTriggered: {
      // Flickable velocity is px/s, positive toward the start of the content.
      if (Math.abs(root.velocity) > 0.25) root.flickable.flick(0, -root.velocity * 1000)
      root.velocity = 0
    }
  }

  Component.onCompleted: {
    flickable.maximumFlickVelocity = 8000
    flickable.flickDeceleration = 2400
  }
}

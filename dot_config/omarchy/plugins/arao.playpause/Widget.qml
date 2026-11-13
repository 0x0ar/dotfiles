import QtQuick
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons
import qs.Commons as Commons

BarWidget {
  id: root
  moduleName: "arao.playpause"

  readonly property var players: Mpris.players ? Mpris.players.values : []
  // The player that is playing, or else the first one that has anything loaded.
  readonly property var activePlayer: {
    var list = players, first = null
    for (var i = 0; i < list.length; i++) {
      if (list[i].isPlaying) return list[i]
      if (!first && (list[i].trackTitle || list[i].trackArtist)) first = list[i]
    }
    return first
  }
  readonly property bool hasMedia: activePlayer !== null && (activePlayer.trackTitle || activePlayer.trackArtist)
  readonly property bool playing: !!activePlayer && !!activePlayer.isPlaying
  readonly property string title: activePlayer ? (activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""

  visible: hasMedia
  readonly property real diameter: Style.space(20)
  implicitWidth: hasMedia ? (vertical ? root.barSize : diameter + Style.space(8)) : 0
  implicitHeight: vertical ? (hasMedia ? diameter + Style.space(8) : 0) : root.barSize

  Rectangle {
    id: disc
    anchors.centerIn: parent
    width: root.diameter
    height: root.diameter
    radius: width / 2
    color: root.bar ? root.bar.barForeground : "white"
    scale: area.pressed ? 0.92 : (area.containsMouse ? 1.06 : 1)
    Behavior on scale { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }

    Text {
      anchors.centerIn: parent
      // The play triangle sits optically left of center.
      anchors.horizontalCenterOffset: root.playing ? 0 : 1
      textFormat: Text.PlainText
      text: root.playing ? "󰏤" : "󰐊"
      color: root.bar ? root.bar.background : "black"
      font.family: root.bar ? root.bar.fontFamily : "monospace"
      font.pixelSize: Style.space(13)
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onClicked: function(mouse) {
      var p = root.activePlayer
      if (!p) return
      if (mouse.button === Qt.MiddleButton) { if (p.canGoNext) p.next() }
      else if (p.canTogglePlaying) p.togglePlaying()
    }
    onWheel: function(wheel) {
      var p = root.activePlayer
      if (!p) return
      if (wheel.angleDelta.y > 0) { if (p.canGoPrevious) p.previous() }
      else if (p.canGoNext) p.next()
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.title + (root.artist ? " — " + root.artist : ""))
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}

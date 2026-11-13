import QtQuick
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons
import qs.Commons as Commons

BarWidget {
  id: root
  moduleName: "arao.visualizer"

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
  readonly property bool playing: !!activePlayer && !!activePlayer.isPlaying

  readonly property int barCount: 7
  readonly property real barWidth: Style.space(2)
  readonly property real barGap: Style.space(2)
  readonly property real maxHeight: Style.space(14)
  readonly property real minHeight: Style.space(3)

  implicitWidth: vertical ? root.barSize : barCount * barWidth + (barCount - 1) * barGap + Style.space(8)
  implicitHeight: vertical ? barCount * barWidth + (barCount - 1) * barGap + Style.space(8) : root.barSize

  // Resting shape, so the island shows bars even while nothing plays.
  readonly property var idleLevels: [0.18, 0.4, 0.65, 0.85, 0.55, 0.35, 0.2]
  property var levels: idleLevels

  Timer {
    interval: 110
    repeat: true
    running: root.playing && root.visible && !(root.bar && root.bar.barHidden) && !Style.reduceMotion
    onTriggered: {
      var next = []
      for (var i = 0; i < root.barCount; i++) {
        // Bass in the middle, treble toward the edges, with a little noise.
        var shape = 1 - Math.abs(i - (root.barCount - 1) / 2) / root.barCount
        next.push(Math.min(1, Math.max(0.05, shape * (0.35 + Math.random() * 0.9))))
      }
      root.levels = next
    }
    onRunningChanged: if (!running) root.levels = root.idleLevels
  }

  Row {
    id: bars
    anchors.centerIn: parent
    spacing: root.barGap
    rotation: root.vertical ? 90 : 0

    Repeater {
      model: root.barCount

      Rectangle {
        required property int index
        width: root.barWidth
        height: root.minHeight + (root.maxHeight - root.minHeight) * (root.levels[index] || 0)
        anchors.verticalCenter: parent.verticalCenter
        radius: width / 2
        color: Commons.Color.accent
        opacity: root.playing ? 1 : 0.45

        Behavior on height { NumberAnimation { duration: Style.duration(110); easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: if (root.activePlayer && root.activePlayer.canTogglePlaying) root.activePlayer.togglePlaying()
  }
}

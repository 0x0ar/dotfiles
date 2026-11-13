import QtQuick
import qs.Ui
import qs.Commons
import qs.Commons as Commons

BarWidget {
  id: root
  moduleName: "arao.separator"

  readonly property real lineLength: Style.space(18)
  readonly property real lineThickness: Style.space(2)
  readonly property real glowLength: Style.space(7)
  readonly property bool animating: root.visible && !(root.bar && root.bar.barHidden) && !Style.reduceMotion

  implicitWidth: vertical ? root.barSize : lineThickness + Style.space(14)
  implicitHeight: vertical ? lineThickness + Style.space(14) : root.barSize

  Item {
    id: line
    anchors.centerIn: parent
    width: root.vertical ? root.lineLength : root.lineThickness
    height: root.vertical ? root.lineThickness : root.lineLength
    clip: true

    Rectangle {
      anchors.fill: parent
      radius: Math.min(width, height) / 2
      color: root.bar ? root.bar.barForeground : Commons.Color.foreground
      opacity: 0.22
    }

    // The light that travels the divider, swelling slightly in the middle.
    Rectangle {
      id: glow
      property real progress: 0
      readonly property real travel: root.lineLength - root.glowLength
      width: root.vertical ? root.glowLength : root.lineThickness
      height: root.vertical ? root.lineThickness : root.glowLength
      x: root.vertical ? progress * travel : 0
      y: root.vertical ? 0 : progress * travel
      radius: Math.min(width, height) / 2
      color: Commons.Color.accent
      opacity: 0.55 + 0.45 * Math.sin(Math.PI * progress)

      SequentialAnimation on progress {
        running: root.animating
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: Style.duration(1100); easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: Style.duration(1100); easing.type: Easing.InOutSine }
      }
    }
  }
}

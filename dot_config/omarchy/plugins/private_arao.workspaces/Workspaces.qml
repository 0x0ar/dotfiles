import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  // Every monitor has workspaces 1-10 of its own, which Hyprland numbers in a
  // block of ten per monitor: 1-10, 11-20, and so on (see
  // default/hypr/monitor-workspaces.lua). Each bar shows its own monitor's block,
  // numbered 1-10, and the one that monitor shows, whichever monitor has focus.
  readonly property int slots: 10

  readonly property var monitor: {
    var window = root.QsWindow.window
    var screen = window ? window.screen : null
    return screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  }
  readonly property string monitorName: root.monitor ? root.monitor.name : ""

  // Connector -> block, from the file Hyprland keeps them in.
  property var blocks: ({})

  function readBlocks(text) {
    var next = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var fields = lines[i].split("\t")
      if (fields.length >= 3 && fields[1] !== "") next[fields[1]] = parseInt(fields[0], 10)
    }
    root.blocks = next
  }

  FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/monitor-workspaces"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readBlocks(text())
    onLoadFailed: root.readBlocks("")
  }

  function blockOf(id) {
    return Math.floor((id - 1) / root.slots)
  }

  function slotOf(id) {
    return (id - 1) % root.slots + 1
  }

  function activeWorkspaceId() {
    return root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : -1
  }

  // Until Hyprland has written the file, the workspace a monitor shows is in
  // its own block.
  readonly property int block: {
    var block = root.blocks[root.monitorName]
    if (block !== undefined) return block
    var active = root.activeWorkspaceId()
    return active > 0 ? root.blockOf(active) : 0
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  // The first five of the monitor's own, and any of the rest that exist. After
  // them come workspaces that are only visiting: those of a monitor that is
  // unplugged, which had no room to join this one's.
  function workspaceIds() {
    var base = root.block * root.slots
    var ids = [base + 1, base + 2, base + 3, base + 4, base + 5]
    var guests = []
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id <= 0) continue
      if (root.blockOf(id) === root.block) {
        if (ids.indexOf(id) === -1) ids.push(id)
      } else if (values[i].monitor && values[i].monitor.name === root.monitorName) {
        guests.push(id)
      }
    }

    ids.sort(function(left, right) { return left - right })
    guests.sort(function(left, right) { return left - right })
    return ids.concat(guests)
  }

  function dispatch(expression) {
    if (root.bar) root.bar.run("hyprctl dispatch " + Util.shellQuote(expression))
  }

  function focusWorkspace(id) {
    if (root.blockOf(id) === root.block) {
      root.dispatch("o.workspaces.focus(" + root.slotOf(id) + ", \"" + root.monitorName + "\")")
    } else {
      root.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })")
    }
  }

  // A wheel notch moves one entry along the row, and a touchpad adds up its
  // smaller deltas until they make a notch's worth.
  property real wheelAccumulator: 0

  function scrollWorkspaces(delta) {
    var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
    root.wheelAccumulator = wheel.remainder
    if (wheel.steps === 0) return

    // Holds at either end rather than wrapping, so a touchpad swipe that runs
    // long stops on the last workspace.
    var ids = root.workspaceIds()
    var index = ids.indexOf(root.activeWorkspaceId())
    if (index === -1) return
    var target = ids[Util.clamp(index - wheel.steps, 0, ids.length - 1)]
    if (target !== ids[index]) root.focusWorkspace(target)
  }

  // The workspace each monitor shows carries its layout: a square tiles, a
  // circle scrolls, and a triangle floats. Clicking it cycles to the next one,
  // as Super + L does.
  property string activeMode: "dwindle"
  property bool modeStale: false

  function modeGlyph(mode) {
    if (mode === "scrolling") return "󰝥"
    if (mode === "floating") return "󰔶"
    return "󱓻"
  }

  // A layout only changes through the layout commands, which ask for a refresh,
  // or a config reload, so each workspace's mode is read once and cached rather
  // than running the script on every workspace switch.
  property var modeCache: ({})
  property int modeGeneration: 0
  property int modeProcWorkspace: -1
  property int modeProcGeneration: 0

  function showActiveMode() {
    var mode = root.modeCache[root.activeWorkspaceId()]
    if (mode !== undefined) root.activeMode = mode
    else readMode()
  }

  function readMode() {
    if (modeProc.running) {
      root.modeStale = true
      return
    }
    var id = root.activeWorkspaceId()
    if (id === -1) return
    root.modeProcWorkspace = id
    root.modeProcGeneration = root.modeGeneration
    modeProc.command = ["omarchy-hyprland-workspace-layout-current", String(id)]
    modeProc.running = true
  }

  function refresh() {
    root.modeCache = ({})
    root.modeGeneration++
    readMode()
  }

  // The layout commands act on the focused workspace, so a click on another
  // monitor's bar focuses that monitor first.
  function cycleLayout() {
    if (!root.bar) return
    var command = "omarchy-hyprland-workspace-layout-toggle"
    if (root.monitor && !root.monitor.focused) {
      command = "hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ monitor = \"" + root.monitorName + "\" })") + " >/dev/null && " + command
    }
    root.bar.run(command)
  }

  Component.onCompleted: { refresh(); root.prevShownId = root.shownId }
  onMonitorChanged: root.showActiveMode()

  Connections {
    target: root.monitor
    function onActiveWorkspaceChanged() { root.showActiveMode() }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      if (name === "configreloaded") root.refresh()
      // Quickshell credits every workspace switch to the focused monitor, as
      // the event doesn't say which one switched, and misses the workspace a
      // monitor falls back to when its own is moved away. Moving workspaces
      // between monitors switches the others, so ask Hyprland for the truth.
      // A workspace that changes number is only learned by asking too. Every
      // bar shares what Hyprland answers, so one asks after a plain switch.
      var switched = name === "workspacev2" && root.monitor !== null && root.monitor.focused
      if (switched || name === "moveworkspacev2" || name === "changeworkspaceid") {
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
      }
    }
  }

  Process {
    id: modeProc
    stdout: StdioCollector {
      onStreamFinished: {
        var mode = text.trim()
        // A read that started before a refresh may predate the change.
        if (!mode || root.modeProcGeneration !== root.modeGeneration) return
        root.modeCache[root.modeProcWorkspace] = mode
        if (root.modeProcWorkspace === root.activeWorkspaceId()) root.activeMode = mode
      }
    }
    onExited: {
      if (!root.modeStale) return
      root.modeStale = false
      // Deferred: the process still reports running while it signals exit.
      Qt.callLater(root.showActiveMode)
    }
  }

  // Super + L and the default layout change the mode without a focus change,
  // so they ask every bar to read it again.
  ShellIpc {
    target: "omarchy.workspaces"

    function refresh(): void { root.broadcast("refresh") }
  }

  // Notch style: workspaces are small dots, and the focused one stretches into
  // an accent-colored pill. Occupied workspaces are brighter than empty ones.
  readonly property real dotSize: Style.space(8)
  readonly property real pillWidth: Style.space(24)
  readonly property real dotGap: Style.space(5)

  // ---- Liquid transition ----------------------------------------------------
  // On a workspace change the pill lets go as a droplet, flies to the new dot
  // stretching on a thin neck, and splashes into a pill with a few droplets.
  readonly property int gooTravelMs: 300
  readonly property int gooSplashMs: 380
  property bool gooActive: false
  property real gooT: 0
  property int gooFromId: -1
  property int gooToId: -1
  property int gooDir: 1
  property real gooL0: 0
  property real gooR0: 0
  property real gooLeft: 0
  property real gooRight: 0
  property var gooDrops: []
  // Droplets each take one of these; the blob itself stays the theme accent.
  readonly property var dropColors: ["#f4b183", "#8ecae6", "#c3a6f5", "#9be8b4", "#f7e28b", "#f28fb0", "#7fd6d0"]
  property int shownId: root.activeWorkspaceId()
  property int prevShownId: -1

  onShownIdChanged: {
    var from = root.prevShownId
    root.prevShownId = root.shownId
    if (from > 0 && root.shownId > 0 && from !== root.shownId) root.startGoo(from, root.shownId)
  }

  function cellFor(id) {
    for (var i = 0; i < cells.count; i++) {
      var item = cells.itemAt(i)
      if (item && item.modelData === id) return item
    }
    return null
  }

  // Center of a cell's dot, were it `width` wide, in the goo canvas' space.
  function centerOf(cell, width) {
    return cell.mapToItem(goo, 0, 0).x + root.dotGap / 2 + (cell.firstGuest ? Style.space(6) : 0) + width / 2
  }

  function startGoo(fromId, toId) {
    if (root.vertical || Style.reduceMotion || Style.duration(100) === 0) return
    var from = root.cellFor(fromId)
    var to = root.cellFor(toId)
    if (!from || !to) return
    var ext = (root.pillWidth - root.dotSize) / 2
    var origin = root.centerOf(from, root.pillWidth)
    var target = root.centerOf(to, root.pillWidth)
    if (!root.gooActive) {
      root.gooL0 = origin - ext
      root.gooR0 = origin + ext
    } else {
      // Interrupted mid-flight: carry on from wherever the liquid is now.
      root.gooL0 = root.gooLeft
      root.gooR0 = root.gooRight
    }
    root.gooDir = target >= origin ? 1 : -1
    root.gooFromId = fromId
    root.gooToId = toId
    var drops = []
    for (var i = 0; i < 6; i++) {
      drops.push({
        back: 0.45 + Math.random() * 0.9,
        lift: (Math.random() - 0.5) * 2,
        size: 0.22 + Math.random() * 0.26,
        delay: Math.random() * 0.12,
        color: root.dropColors[Math.floor(Math.random() * root.dropColors.length)]
      })
    }
    root.gooDrops = drops
    root.gooActive = true
    gooAnim.stop()
    root.gooT = 0
    gooAnim.start()
  }

  NumberAnimation {
    id: gooAnim
    target: root
    property: "gooT"
    from: 0
    to: 1
    duration: Style.duration(root.gooTravelMs + root.gooSplashMs)
    easing.type: Easing.Linear
    onFinished: { root.gooActive = false; goo.requestPaint() }
  }

  onGooTChanged: goo.requestPaint()

  function easeOut(t) { return 1 - Math.pow(1 - t, 3) }
  function easeInOut(t) { return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2 }
  function clamp01(t) { return Math.max(0, Math.min(1, t)) }

  function paintGoo(canvas) {
    var ctx = canvas.getContext("2d")
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    if (!root.gooActive) return
    var to = root.cellFor(root.gooToId)
    if (!to) return

    var total = root.gooTravelMs + root.gooSplashMs
    var elapsed = root.gooT * total
    var p = root.clamp01(elapsed / root.gooTravelMs)
    var sp = root.clamp01((elapsed - root.gooTravelMs) / root.gooSplashMs)

    var dot = root.dotSize
    var r = dot / 2
    var ext = (root.pillWidth - dot) / 2
    var cy = canvas.height / 2
    var c = root.centerOf(to, root.pillWidth)
    var LT = c - ext
    var RT = c + ext
    var dir = root.gooDir

    ctx.fillStyle = Commons.Color.accent

    if (p < 1 || sp === 0) {
      // Flight: the leading end rushes ahead, the trailing end lags behind.
      var lead = root.easeOut(p)
      var trail = root.easeInOut(root.clamp01((p - 0.18) / 0.82))
      var L = root.gooL0 + (LT - root.gooL0) * (dir > 0 ? trail : lead)
      var R = root.gooR0 + (RT - root.gooR0) * (dir > 0 ? lead : trail)
      root.gooLeft = L
      root.gooRight = R

      var bulge = Math.sin(Math.PI * p)
      var stretch = Math.max(0, (R - L) - 2 * ext)
      var neck = r * Math.max(0.3, Math.min(1, 1 - stretch / (7 * dot)))
      var rL = r * (dir > 0 ? 1 - 0.25 * bulge : 1 + 0.18 * bulge)
      var rR = r * (dir > 0 ? 1 + 0.18 * bulge : 1 - 0.25 * bulge)

      // Neck, drawn as a pinched ribbon so it blends into both bulbs.
      ctx.beginPath()
      ctx.moveTo(L, cy - Math.min(rL, neck))
      ctx.quadraticCurveTo((L + R) / 2, cy - neck * 0.82, R, cy - Math.min(rR, neck))
      ctx.lineTo(R, cy + Math.min(rR, neck))
      ctx.quadraticCurveTo((L + R) / 2, cy + neck * 0.82, L, cy + Math.min(rL, neck))
      ctx.closePath()
      ctx.fill()

      ctx.beginPath(); ctx.arc(L, cy, rL, 0, Math.PI * 2); ctx.fill()
      ctx.beginPath(); ctx.arc(R, cy, rR, 0, Math.PI * 2); ctx.fill()
      return
    }

    // Splash: the blob lands, squashes, lumps up and settles into the pill.
    var squash = (1 - sp) * (1 - sp)
    var wobble = Math.sin(sp * Math.PI * 3) * (1 - sp)
    var h = dot * (1 + 0.5 * squash + 0.1 * wobble)
    var w = root.pillWidth * (1 - 0.08 * squash) + dot * 0.2 * squash
    root.gooLeft = c - w / 2
    root.gooRight = c + w / 2

    // Droplets thrown back and around from the impact.
    for (var i = 0; i < root.gooDrops.length; i++) {
      var d = root.gooDrops[i]
      var t = root.clamp01((sp - d.delay) / (1 - d.delay))
      if (t <= 0 || t >= 1) continue
      var e = root.easeOut(t)
      var x = c - dir * (w * 0.15 + d.back * dot * 3 * e)
      var y = cy + d.lift * dot * 2.1 * e + dot * 2.6 * t * t
      var rr = dot * d.size * (1 - t * 0.8)
      ctx.globalAlpha = 1 - t * t * t
      ctx.fillStyle = d.color
      ctx.beginPath(); ctx.arc(x, y, Math.max(0.2, rr), 0, Math.PI * 2); ctx.fill()
    }
    ctx.globalAlpha = 1
    ctx.fillStyle = Commons.Color.accent
    ctx.beginPath()
    ctx.roundedRect(c - w / 2, cy - h / 2, w, h, h / 2, h / 2)
    ctx.fill()
    // A couple of lumps on the surface while it is still wet.
    if (squash > 0.06) {
      ctx.beginPath(); ctx.arc(c - dir * w * 0.12, cy - h / 2 + r * 0.35, r * 0.7 * squash, 0, Math.PI * 2); ctx.fill()
      ctx.beginPath(); ctx.arc(c + dir * w * 0.18, cy - h / 2 + r * 0.35, r * 0.55 * squash, 0, Math.PI * 2); ctx.fill()
    }

  }

  implicitWidth: root.vertical ? root.barSize : row.implicitWidth + Style.space(4)
  implicitHeight: root.vertical ? row.implicitHeight + Style.space(4) : root.barSize

  Grid {
    id: row
    anchors.centerIn: parent
    flow: root.vertical ? Grid.TopToBottom : Grid.LeftToRight
    columns: root.vertical ? 1 : Math.max(1, root.workspaceIds().length)
    spacing: 0

    Repeater {
      id: cells
      model: root.workspaceIds()

      Item {
        id: cell

        required property int modelData
        required property int index

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool shown: root.monitor !== null && root.monitor.activeWorkspace !== null && root.monitor.activeWorkspace.id === modelData
        readonly property bool firstGuest: root.blockOf(modelData) !== root.block && index > 0 && root.blockOf(root.workspaceIds()[index - 1]) === root.block
        readonly property real along: (shown ? root.pillWidth : root.dotSize) + root.dotGap + (firstGuest ? Style.space(6) : 0)

        width: root.vertical ? root.barSize : along
        height: root.vertical ? along : root.barSize

        Behavior on width { enabled: !root.vertical; NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
        Behavior on height { enabled: root.vertical; NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }

        Rectangle {
          id: dot
          x: root.vertical ? Math.round((parent.width - width) / 2) : root.dotGap / 2 + (cell.firstGuest ? Style.space(6) : 0)
          y: root.vertical ? root.dotGap / 2 : Math.round((parent.height - height) / 2)
          width: root.vertical ? root.dotSize : (cell.shown ? root.pillWidth : root.dotSize)
          height: root.vertical ? (cell.shown ? root.pillWidth : root.dotSize) : root.dotSize
          radius: Math.min(width, height) / 2
          color: cell.shown ? Commons.Color.accent : (root.bar ? root.bar.barForeground : Commons.Color.foreground)
          opacity: cell.shown ? (root.gooActive ? 0 : 1) : (area.containsMouse ? 0.9 : (cell.occupied ? 0.7 : 0.38))

          Behavior on width { enabled: !root.vertical; NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
          Behavior on height { enabled: root.vertical; NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
          Behavior on opacity { enabled: !cell.shown; NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic } }
          Behavior on color { ColorAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
        }

        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (cell.shown) root.cycleLayout()
            else root.focusWorkspace(cell.modelData)
          }
          onWheel: function(wheel) { root.scrollWorkspaces(wheel.angleDelta.y) }
        }
      }
    }
  }

  // Wider than the widget so the splash droplets are not clipped.
  Canvas {
    id: goo
    z: 5
    x: -Style.space(12)
    y: 0
    width: root.width + Style.space(24)
    height: root.height
    visible: root.gooActive
    antialiasing: true
    renderTarget: Canvas.Image
    onPaint: root.paintGoo(goo)
  }
}

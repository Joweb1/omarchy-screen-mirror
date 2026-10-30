import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// Screen mirroring for external monitors. When a monitor is plugged in, every
// screen shows the same picture as the laptop panel instead of becoming a
// separate workspace. The popup switches between "Mirror" and "Extend" and
// lists the connected screens.
//
// The work happens in the bundled `screen-mirror` helper: its `watch` mode
// listens to Hyprland's event socket and re-applies the saved mode whenever a
// monitor appears or the config reloads. This file renders its JSON.
Panel {
  id: root
  moduleName: "jovibe.screen-mirror"
  ipcTarget: "jovibe.screen-mirror"

  readonly property string helper: decodeURIComponent(Qt.resolvedUrl("screen-mirror").toString().replace(/^file:\/\//, ""))

  property var info: ({ mode: "mirror", primary: "", monitors: [], external: 0 })
  property bool loaded: false
  property int knownExternal: 0

  readonly property bool mirroring: info.mode === "mirror"
  readonly property color dim: Qt.darker(bar.foreground, 1.5)

  function glyph(cp) { return String.fromCodePoint(cp) }

  function refresh() {
    if (statusProc.running) { refreshAgain = true; return }
    statusProc.running = true
  }
  property bool refreshAgain: false

  function applyInfo(next) {
    if (loaded && next.external > knownExternal && setting("notify", true)) {
      Quickshell.execDetached(["notify-send", "-a", "Display", "-i", "video-display",
        next.mode === "mirror" ? "Screen mirrored" : "Second screen connected",
        next.mode === "mirror" ? "The external monitor shows the same as your laptop"
                               : "The external monitor extends your desktop"])
    }
    knownExternal = next.external
    info = next
    loaded = true
  }

  function setMode(mode) {
    if (mode === info.mode || setProc.running) return
    setProc.command = [helper, "set", mode]
    setProc.running = true
  }

  function describe(m) {
    var parts = [m.width + "×" + m.height]
    if (m.primary) parts.push("main screen")
    else parts.push(m.mirrorOf ? "mirrors " + m.mirrorOf : "extended")
    return parts.join(" · ")
  }

  onOpenedChanged: if (opened) refresh()

  visible: setting("alwaysShow", false) || info.external > 0
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: statusProc
    command: [root.helper, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.applyInfo(JSON.parse(text)) } catch (e) {}
      }
    }
    onExited: if (root.refreshAgain) { root.refreshAgain = false; Qt.callLater(root.refresh) }
  }

  Process {
    id: setProc
    onExited: root.refresh()
  }

  // The watcher applies the saved mode on every monitor change and prints a
  // line afterwards, which is the cue to re-read the status.
  Process {
    id: watchProc
    running: true
    command: [root.helper, "watch"]
    stdout: SplitParser {
      onRead: function(line) { root.refresh() }
    }
    onExited: restartWatch.start()
  }

  Timer {
    id: restartWatch
    interval: 3000
    onTriggered: watchProc.running = true
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph(0xF0379)
    tooltipText: root.info.external === 0 ? "No external screen"
      : root.mirroring ? "Mirroring to " + root.info.external + " screen" + (root.info.external > 1 ? "s" : "")
      : "Extended desktop"
    onPressed: root.toggle()
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dx !== 0 || dy !== 0) root.setMode(root.mirroring ? "extend" : "mirror")
      }
      onActivateRequested: root.setMode(root.mirroring ? "extend" : "mirror")
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.space(14)

        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph(0xF0379)
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Screens"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              text: (root.info.external === 0 ? "No external screen"
                    : root.mirroring ? "Mirroring" : "Extended").toUpperCase()
              color: root.dim
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        Row {
          spacing: Style.space(8)

          PillButton {
            label: "Mirror"
            primary: root.mirroring
            onClicked: root.setMode("mirror")
          }

          PillButton {
            label: "Extend"
            primary: !root.mirroring
            onClicked: root.setMode("extend")
          }
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: root.mirroring
            ? "Every screen shows what your laptop shows. Switching workspaces switches them all."
            : "The external screen is its own desktop: it shows a different workspace from your laptop."
          color: root.dim
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        PanelSeparator { foreground: root.bar.foreground }

        Column {
          width: parent.width
          spacing: Style.space(8)

          Repeater {
            model: root.info.monitors

            Item {
              required property var modelData
              width: parent.width
              implicitHeight: rowLabels.implicitHeight

              Column {
                id: rowLabels
                width: parent.width
                spacing: Style.space(1)

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                  text: modelData.name + (modelData.description ? " — " + modelData.description : "")
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.body
                }

                Text {
                  textFormat: Text.PlainText
                  text: root.describe(modelData)
                  color: root.dim
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }
          }
        }
      }
    }
  }

  component PillButton: Rectangle {
    id: pb
    property string label: ""
    property bool primary: false
    signal clicked()

    implicitWidth: labelText.implicitWidth + Style.space(24)
    implicitHeight: Style.space(28)
    radius: Style.space(7)
    color: primary
      ? root.bar.foreground
      : Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.10)
    border.width: primary ? 0 : 1
    border.color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.25)

    Text {
      id: labelText
      anchors.centerIn: parent
      text: pb.label
      color: pb.primary ? root.bar.background : root.bar.foreground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: pb.clicked()
    }
  }
}

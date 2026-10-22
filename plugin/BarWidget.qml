// Unraid Backup bar widget — renders ~/.local/state/unraid-backup/status.json
// written by the unraid-backup script. Pixels only; no network.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "hendkai.unraid-backup"

  property var status: null
  property bool resolved: false
  property real nowMs: Date.now()

  readonly property string statusPath:
    (Quickshell.env("HOME") || "") + "/.local/state/unraid-backup/status.json"

  function setting(name, fallback) {
    var v = settings ? settings[name] : undefined
    return v === undefined || v === null ? fallback : v
  }
  readonly property real warnAfterHours: root.setting("warnAfterHours", 36)
  readonly property bool showAge: root.setting("showAge", true)

  readonly property real lastOkMs: (status && status.last_success_ms) || 0
  readonly property real ageMs: lastOkMs ? nowMs - lastOkMs : -1

  // running | failed | stale | none | ok | checking
  readonly property string displayState: {
    if (!resolved) return "checking"
    if (!status) return "none"
    if (status.state === "running") return "running"
    if (status.state === "error") return "failed"
    if (!lastOkMs) return "none"
    if (ageMs > warnAfterHours * 3600000) return "stale"
    return "ok"
  }
  readonly property bool problem:
    displayState === "failed" || displayState === "stale" || displayState === "none"

  function fmtAge(ms) {
    if (ms < 0) return "–"
    var m = Math.floor(ms / 60000)
    if (m < 1) return "<1m"
    if (m < 60) return m + "m"
    var h = Math.floor(m / 60)
    if (h < 48) return h + "h"
    return Math.floor(h / 24) + "d"
  }
  readonly property string glyph: {
    if (displayState === "running") return "󰓦"      // sync
    if (problem) return "󰦖"                          // cloud-alert-ish
    return "󰅟"                                       // cloud-check
  }

  function tooltip() {
    var l = []
    if (displayState === "checking") return "Unraid Backup — …"
    if (!status) return "Unraid Backup: kein Status\nsystemctl --user start unraid-backup"
    l.push("Ziel: " + (status.target || "?"))
    if (lastOkMs) l.push("Letztes Backup: " + new Date(lastOkMs).toLocaleString(Qt.locale(), Locale.ShortFormat)
                          + " (vor " + fmtAge(ageMs) + ")")
    else l.push("Noch kein erfolgreiches Backup")
    if (status.state === "running") l.push("Läuft gerade … " + (progress > 0 ? progress + " %" : ""))
    if (status.state === "error") l.push("Fehler: " + (status.message || "?"))
    if (status.state === "unreachable") l.push("Unraid nicht erreichbar (Lauf übersprungen)")
    if (displayState === "stale") l.push("Überfällig (> " + warnAfterHours + " h)")
    if (status.duration_s) l.push("Dauer: " + Math.round(status.duration_s / 60) + " min")
    l.push("Linksklick: jetzt sichern · Rechtsklick: Log")
    return l.join("\n")
  }

  function apply(text) {
    try { root.status = JSON.parse(text) } catch (e) { /* mid-write */ }
  }

  clip: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  FileView {
    id: file
    path: root.statusPath
    watchChanges: true
    printErrors: false
    onLoaded: { root.apply(text()); root.resolved = true }
    onLoadFailed: { root.status = null; root.resolved = true }
    onFileChanged: debounce.restart()
  }
  Timer { id: debounce; interval: 150; onTriggered: file.reload() }
  Timer {
    interval: 30000; repeat: true; running: true
    onTriggered: { root.nowMs = Date.now(); file.reload() }
  }

  readonly property real unit: button.fontSize / 13
  readonly property real progress: (status && typeof status.progress === "number") ? status.progress : -1
  readonly property bool running: displayState === "running"
  readonly property string ageText: displayState === "none" ? "!" : fmtAge(ageMs)

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    horizontalMargin: 8
    fixedWidth: root.vertical ? root.barSize
      : (root.showAge || root.running ? 78 : 26) * root.unit + scaledHorizontalMargin * 2
    active: root.problem
    dimmed: root.displayState === "checking"
    tooltipText: root.tooltip()
    onPressed: function(b) {
      if (b === Qt.LeftButton)
        Quickshell.execDetached(["systemctl", "--user", "start", "--no-block", "unraid-backup.service"])
      else if (b === Qt.RightButton)
        Quickshell.execDetached(["xdg-terminal-exec", "sh", "-c",
          "journalctl --user -u unraid-backup -n 40 --no-pager; echo; read -n1 -p 'Taste drücken…'"])
    }

    Row {
      anchors.centerIn: parent
      spacing: 6 * root.unit
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.glyph
        color: root.problem ? button.activeColor : button.foreground
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        textFormat: Text.PlainText
      }
      // Ladebalken während eines Laufs
      Item {
        visible: root.running
        anchors.verticalCenter: parent.verticalCenter
        width: 52 * root.unit; height: 8 * root.unit
        Rectangle {
          anchors.fill: parent; radius: height / 2
          color: Qt.alpha(button.foreground, 0.2)
          clip: true
          Rectangle {
            id: fill
            height: parent.height; radius: height / 2
            color: button.foreground
            visible: root.progress >= 0
            width: parent.width * Math.max(0.04, Math.min(100, root.progress) / 100)
            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
          }
          // unbestimmt (Dateiliste wird noch aufgebaut): wandernder Balken
          Rectangle {
            visible: root.progress <= 0
            width: parent.width * 0.3; height: parent.height; radius: height / 2
            color: button.foreground
            SequentialAnimation on x {
              running: root.running && root.progress <= 0
              loops: Animation.Infinite
              NumberAnimation { from: 0; to: 52 * root.unit * 0.7; duration: 900; easing.type: Easing.InOutQuad }
              NumberAnimation { from: 52 * root.unit * 0.7; to: 0; duration: 900; easing.type: Easing.InOutQuad }
            }
          }
        }
      }
      Text {
        visible: root.running && root.progress > 0
        anchors.verticalCenter: parent.verticalCenter
        text: root.progress + "%"
        color: button.foreground
        font.family: button.fontFamily
        font.pixelSize: button.fontSize * 0.8
        textFormat: Text.PlainText
      }
      Text {
        visible: root.showAge && !root.running && root.displayState !== "checking"
        anchors.verticalCenter: parent.verticalCenter
        text: root.ageText
        color: root.problem ? button.activeColor : button.foreground
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        textFormat: Text.PlainText
      }
    }
  }
}

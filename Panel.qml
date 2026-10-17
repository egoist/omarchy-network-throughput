import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "dev.egoist.network-throughput"
  ipcTarget: "dev.egoist.network-throughput"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool processLoading: false
  property bool processHasSnapshot: false
  property string processError: ""
  property var processRows: []

  readonly property var barIdentity: hostWidget || root
  readonly property int processRosterSize: {
    var value = Number(setting("processCount", 5))
    return isFinite(value) ? Math.max(1, Math.min(10, Math.round(value))) : 5
  }
  readonly property string processScript: localPath(Qt.resolvedUrl("scripts/process-throughput"))

  function localPath(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0) value = value.substring(7)
    try { return decodeURIComponent(value) } catch (error) { return value }
  }

  function open() {
    processError = ""
    processLoading = !processHasSnapshot
    root.controller.show()
    Qt.callLater(root.refreshProcesses)
  }

  function close() {
    root.controller.hide()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function refreshProcesses() {
    if (!processThroughput.running) processThroughput.running = true
  }

  function updateProcesses(raw) {
    try {
      var parsed = JSON.parse(String(raw || "[]"))
      processRows = mergeProcessRows(Array.isArray(parsed) ? parsed : [])
      processError = ""
      processHasSnapshot = true
      processLoading = false
    } catch (error) {
      if (!processHasSnapshot) {
        processRows = []
        processError = "Could not read network traffic"
        processHasSnapshot = true
      }
      processLoading = false
    }
  }

  function formatRate(bytesPerSecond) {
    var value = Number(bytesPerSecond)
    if (!isFinite(value) || value < 0) value = 0
    if (value < 1024) return Math.round(value) + " B/s"
    if (value < 1024 * 1024) return (value / 1024).toFixed(value < 10 * 1024 ? 1 : 0) + " KB/s"
    if (value < 1024 * 1024 * 1024) return (value / (1024 * 1024)).toFixed(value < 10 * 1024 * 1024 ? 1 : 0) + " MB/s"
    return (value / (1024 * 1024 * 1024)).toFixed(1) + " GB/s"
  }

  function normalizedAppName(value) {
    return String(value || "").toLowerCase().replace(/[^a-z0-9]/g, "")
  }

  function desktopEntryForProcess(processName) {
    var needle = normalizedAppName(processName)
    if (needle.length < 2) return null

    var entries = DesktopEntries.applications.values || []
    var bestEntry = null
    var bestScore = 0

    for (var index = 0; index < entries.length; index++) {
      var entry = entries[index]
      if (!entry) continue

      var id = normalizedAppName(entry.id).replace(/desktop$/, "")
      var name = normalizedAppName(entry.name)
      var icon = normalizedAppName(entry.icon)
      var score = 0

      if (needle === id || needle === name || needle === icon) score = 100
      else if (needle.length >= 4 && (id.indexOf(needle) >= 0 || name.indexOf(needle) >= 0 || icon.indexOf(needle) >= 0)) score = 80
      else if (id.length >= 4 && needle.indexOf(id) >= 0) score = 70

      if (score > bestScore) {
        bestScore = score
        bestEntry = entry
      }
    }

    return bestEntry
  }

  function processIconSource(processName) {
    if (String(processName || "") === "Other traffic") {
      var networkIcon = Quickshell.iconPath("network-transmit-receive", true)
      if (networkIcon) return networkIcon
    }

    var entry = desktopEntryForProcess(processName)
    var appLibrary = root.bar && root.bar.shell ? root.bar.shell.appLibrary : null
    if (entry && appLibrary && typeof appLibrary.iconSource === "function")
      return appLibrary.iconSource(entry.icon)

    if (entry && entry.icon) {
      var entryIcon = Quickshell.iconPath(String(entry.icon), true)
      if (entryIcon) return entryIcon
    }

    var processIcon = Quickshell.iconPath(String(processName || ""), true)
    if (processIcon) return processIcon
    return Quickshell.iconPath("application-x-executable", true)
  }

  function processRowKey(row) {
    var name = normalizedAppName(row && row.name)
    return name !== "" ? name : "pid:" + String(row && row.pid || "")
  }

  function processRowRate(row) {
    return Number(row && row.downloadBytesPerSecond || 0)
      + Number(row && row.uploadBytesPerSecond || 0)
  }

  function idleProcessRow(row) {
    return {
      pid: Number(row && row.pid || 0),
      name: String(row && row.name || ""),
      downloadBytesPerSecond: 0,
      uploadBytesPerSecond: 0
    }
  }

  function mergeProcessRows(nextRows) {
    var incomingByKey = ({})
    var incomingOrder = []
    var incomingOther = null
    var previousByKey = ({})
    var previousOrder = []
    var previousOther = null
    var selected = []
    var selectedKeys = ({})

    for (var nextIndex = 0; nextIndex < nextRows.length; nextIndex++) {
      var nextRow = nextRows[nextIndex]
      if (!nextRow) continue

      if (Number(nextRow.pid || 0) <= 0 || String(nextRow.name || "") === "Other traffic") {
        incomingOther = nextRow
        continue
      }

      var nextKey = processRowKey(nextRow)
      if (!(nextKey in incomingByKey)) {
        incomingByKey[nextKey] = {
          pid: Number(nextRow.pid || 0),
          name: String(nextRow.name || ""),
          downloadBytesPerSecond: 0,
          uploadBytesPerSecond: 0
        }
        incomingOrder.push(nextKey)
      }
      incomingByKey[nextKey].pid = Number(nextRow.pid || incomingByKey[nextKey].pid)
      incomingByKey[nextKey].downloadBytesPerSecond += Number(nextRow.downloadBytesPerSecond || 0)
      incomingByKey[nextKey].uploadBytesPerSecond += Number(nextRow.uploadBytesPerSecond || 0)
    }

    for (var previousIndex = 0; previousIndex < processRows.length; previousIndex++) {
      var previousRow = processRows[previousIndex]
      if (!previousRow) continue

      if (Number(previousRow.pid || 0) <= 0 || String(previousRow.name || "") === "Other traffic") {
        previousOther = previousRow
        continue
      }

      var previousKey = processRowKey(previousRow)
      if (!(previousKey in previousByKey)) {
        previousByKey[previousKey] = previousRow
        previousOrder.push(previousKey)
      }
    }

    function appendProcess(key, row) {
      if (!row || key in selectedKeys || selected.length >= processRosterSize) return
      selectedKeys[key] = true
      selected.push(row)
    }

    // New activity enters first. Existing entries keep their position and
    // update in place, including the transition to 0 B/s.
    for (var activeIndex = 0; activeIndex < incomingOrder.length; activeIndex++) {
      var activeKey = incomingOrder[activeIndex]
      if (!(activeKey in previousByKey) && processRowRate(incomingByKey[activeKey]) > 0)
        appendProcess(activeKey, incomingByKey[activeKey])
    }

    for (var retainedIndex = 0; retainedIndex < previousOrder.length; retainedIndex++) {
      var retainedKey = previousOrder[retainedIndex]
      appendProcess(retainedKey, retainedKey in incomingByKey
        ? incomingByKey[retainedKey]
        : idleProcessRow(previousByKey[retainedKey]))
    }

    for (var fillIndex = 0; fillIndex < incomingOrder.length; fillIndex++) {
      var fillKey = incomingOrder[fillIndex]
      appendProcess(fillKey, incomingByKey[fillKey])
    }

    var otherRow = incomingOther || (previousOther ? idleProcessRow(previousOther) : null)
    if (otherRow) selected.push(otherRow)
    return selected
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(processColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refreshProcesses()
      }

      Column {
        id: processColumn
        width: parent.width
        spacing: Style.space(8)

        Item {
          width: parent.width
          height: Style.space(26)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Network activity by process"
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(7)
            height: width
            radius: width / 2
            color: Commons.Color.accent
            opacity: root.processLoading ? 0.45 : 0.9

            SequentialAnimation on opacity {
              running: root.opened && root.processLoading
              loops: Animation.Infinite
              NumberAnimation { to: 0.25; duration: 450 }
              NumberAnimation { to: 0.9; duration: 450 }
            }
          }
        }

        Item {
          width: parent.width
          height: Style.space(16)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "PROCESS"
            color: Qt.darker(root.barForeground, 1.5)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Text {
            id: downloadHeader
            anchors.right: uploadHeader.left
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(96)
            text: "↓ DOWNLOAD"
            color: Qt.darker(root.barForeground, 1.5)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            horizontalAlignment: Text.AlignRight
          }

          Text {
            id: uploadHeader
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(96)
            text: "↑ UPLOAD"
            color: Qt.darker(root.barForeground, 1.5)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            horizontalAlignment: Text.AlignRight
          }
        }

        Rectangle {
          width: parent.width
          height: Math.max(1, Style.space(1))
          color: root.barForeground
          opacity: 0.16
        }

        Text {
          visible: root.processRows.length === 0
          width: parent.width
          height: Style.space(52)
          text: root.processError !== ""
            ? root.processError
            : (root.processLoading ? "Measuring network traffic…" : "No active network traffic")
          color: Qt.darker(root.barForeground, 1.35)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }

        Repeater {
          model: root.processRows

          delegate: Item {
            required property var modelData
            width: processColumn.width
            height: Style.space(27)

            Item {
              id: processIconSlot
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(22)
              height: parent.height

              Image {
                id: processIcon
                anchors.centerIn: parent
                width: Style.space(18)
                height: width
                fillMode: Image.PreserveAspectFit
                source: root.processIconSource(modelData.name)
                asynchronous: true
              }

              Text {
                anchors.centerIn: parent
                visible: processIcon.status !== Image.Ready
                text: "󰣆"
                color: root.barForeground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
              }
            }

            Text {
              anchors.left: processIconSlot.right
              anchors.leftMargin: Style.space(7)
              anchors.right: downloadSpeedLabel.left
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              text: Number(modelData.pid) > 0
                ? modelData.name + "  ·  " + modelData.pid
                : modelData.name
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }

            Text {
              id: downloadSpeedLabel
              anchors.right: uploadSpeedLabel.left
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(96)
              text: root.formatRate(modelData.downloadBytesPerSecond)
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              horizontalAlignment: Text.AlignRight
            }

            Text {
              id: uploadSpeedLabel
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(96)
              text: root.formatRate(modelData.uploadBytesPerSecond)
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              horizontalAlignment: Text.AlignRight
            }
          }
        }

        Rectangle {
          width: parent.width
          height: Math.max(1, Style.space(1))
          color: root.barForeground
          opacity: 0.12
        }

        Text {
          width: parent.width
          text: "Recent " + root.processRosterSize + " processes + unassigned traffic · R to refresh"
          color: Qt.darker(root.barForeground, 1.5)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
  }

  Process {
    id: processThroughput
    command: [root.processScript]

    onRunningChanged: {
      if (running) root.processLoading = !root.processHasSnapshot
      else root.processLoading = false
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && !root.processHasSnapshot) {
        root.processRows = []
        root.processError = "Could not read network traffic"
        root.processHasSnapshot = true
      }
      root.processLoading = false
    }

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateProcesses(text)
    }
  }

  Timer {
    interval: 1500
    running: root.opened
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshProcesses()
  }
}

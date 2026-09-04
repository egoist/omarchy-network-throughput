import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "I18n.js" as I18n

BarWidget {
  id: root
  moduleName: "dev.egoist.network-throughput"

  property string downloadText: "--"
  property string uploadText: "--"

  readonly property string localeName: Qt.locale().name
  readonly property real configuredWidth: {
    var value = Number(setting("width", 68))
    return isFinite(value) && value > 0 ? Math.max(48, Math.min(180, value)) : 68
  }
  readonly property real rateFontSize: Math.max(8, Style.font.caption)
  readonly property string throughputScript: localPath(Qt.resolvedUrl("scripts/network-throughput"))

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  function localPath(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0) value = value.substring(7)
    try { return decodeURIComponent(value) } catch (error) { return value }
  }

  function refresh() {
    if (!throughputProcess.running) throughputProcess.running = true
  }

  function updateRates(raw) {
    var match = String(raw || "").trim().match(/^↓\s+(.+?)\s+↑\s+(.+)$/)
    downloadText = match ? match[1] : "--"
    uploadText = match ? match[2] : "--"
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.settings = root.settings
    target.anchorItem = button
    target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  Component.onCompleted: refresh()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    fixedWidth: root.vertical ? -1 : root.configuredWidth
    fixedHeight: root.vertical ? Math.max(Style.bar.iconSlot * 2, Style.space(40)) : -1
    horizontalMargin: 0
    verticalPadding: 0
    labelVisible: false
    hasVisualContent: true
    tooltipText: I18n.translate(root.localeName, "tooltip")

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) root.toggle()
    }

    Column {
      id: rates
      anchors.fill: parent
      anchors.leftMargin: Style.spaceReal(2)
      anchors.rightMargin: Style.spaceReal(2)
      anchors.topMargin: Style.spaceReal(1)
      anchors.bottomMargin: Style.spaceReal(1)

      Item {
        width: rates.width
        height: rates.height / 2

        Text {
          id: uploadArrow
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: Style.spaceReal(10)
          text: "↑"
          color: button.foreground
          font.family: button.fontFamily
          font.pixelSize: root.rateFontSize
          horizontalAlignment: Text.AlignHCenter
          renderType: Text.NativeRendering
        }

        Text {
          anchors.left: uploadArrow.right
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.uploadText
          color: button.foreground
          font.family: button.fontFamily
          font.pixelSize: root.rateFontSize
          minimumPixelSize: 8
          fontSizeMode: Text.HorizontalFit
          horizontalAlignment: Text.AlignRight
          renderType: Text.NativeRendering
        }
      }

      Item {
        width: rates.width
        height: rates.height / 2

        Text {
          id: downloadArrow
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: Style.spaceReal(10)
          text: "↓"
          color: button.foreground
          font.family: button.fontFamily
          font.pixelSize: root.rateFontSize
          horizontalAlignment: Text.AlignHCenter
          renderType: Text.NativeRendering
        }

        Text {
          anchors.left: downloadArrow.right
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.downloadText
          color: button.foreground
          font.family: button.fontFamily
          font.pixelSize: root.rateFontSize
          minimumPixelSize: 8
          fontSizeMode: Text.HorizontalFit
          horizontalAlignment: Text.AlignRight
          renderType: Text.NativeRendering
        }
      }
    }
  }

  Process {
    id: throughputProcess
    command: [root.throughputScript]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateRates(text)
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }
}

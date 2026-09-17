import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "jason.chess"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: launcher
    command: ["omarchy-launch-or-focus-webapp", "Chess", "https://www.chess.com/"]
    running: false
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "♟"
    horizontalMargin: 6
    tooltipText: "Chess.com"
    onPressed: function(mouseButton) {
      launcher.running = true
    }
  }
}

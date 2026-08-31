import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "jason.chess"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰡳"
    horizontalMargin: 6
    tooltipText: "Chess.com"
    onPressed: function(mouseButton) {
      if (!root.bar) return
      root.bar.run("omarchy-launch-or-focus-webapp Chess https://www.chess.com/")
    }
  }
}

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root

  moduleName: "jason.chess"
  ipcTarget: "jason.chess"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // ----------------------------------------------------------------- Settings
  readonly property string configuredUsername: setting("username", "")
  property string currentUsername: configuredUsername
  readonly property int panelWidth: setting("panelWidth", 390)
  readonly property bool showPuzzle: setting("showPuzzle", true)
  readonly property int pollMinutes: setting("pollMinutes", 2)

  // -------------------------------------------------------------------- State
  property var playerData: null
  property var statsData: null
  property var puzzleData: null
  property var activeGames: []
  property int toMoveCount: 0
  property bool loading: false
  property string errorMessage: ""
  property bool editingUser: false
  property string userInputValue: ""

  function refreshAll() {
    errorMessage = ""
    loading = true
    var targetUser = currentUsername.trim()

    if (targetUser.length > 0) {
      Model.fetchPlayer(targetUser, function(err, player) {
        if (err) {
          errorMessage = "Player not found"
          playerData = null
          loading = false
          return
        }
        playerData = player
        Model.fetchStats(targetUser, function(errStats, stats) {
          if (!errStats) statsData = stats
        })
        Model.fetchActiveGames(targetUser, function(errGames, res) {
          loading = false
          if (!errGames && res && Array.isArray(res.games)) {
            var parsedList = []
            var count = 0
            for (var i = 0; i < res.games.length; i++) {
              var parsed = Model.parseOpponent(res.games[i], targetUser)
              parsedList.push(parsed)
              if (parsed.isMyTurn) count++
            }
            root.activeGames = parsedList
            root.toMoveCount = count
          }
        })
      })
    } else {
      playerData = null
      statsData = null
      activeGames = []
      toMoveCount = 0
      loading = false
    }

    if (showPuzzle) {
      Model.fetchPuzzle(function(err, pz) {
        if (!err) puzzleData = pz
      })
    }
  }

  onOpenedChanged: {
    if (opened) {
      refreshAll()
    }
  }

  Component.onCompleted: {
    if (currentUsername !== "") {
      refreshAll()
    } else if (showPuzzle) {
      Model.fetchPuzzle(function(err, pz) {
        if (!err) puzzleData = pz
      })
    }
  }

  Timer {
    interval: Math.max(1, root.pollMinutes) * 60 * 1000
    running: true
    repeat: true
    onTriggered: if (root.currentUsername !== "") root.refreshAll()
  }

  function launchUrl(url) {
    if (!root.bar) return
    root.bar.run("omarchy-launch-or-focus-webapp Chess '" + url + "'")
    root.close()
  }

  function saveUsername(name) {
    var clean = name.trim().toLowerCase()
    currentUsername = clean
    editingUser = false
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry["username"] = clean
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    }
    refreshAll()
  }

  // ----------------------------------------------------------- Bar Button
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.toMoveCount > 0 ? "󰡳 " + root.toMoveCount : "󰡳"
    horizontalMargin: 6
    active: root.toMoveCount > 0
    activeColor: root.accent
    tooltipText: {
      var base = root.playerData && root.playerData.username ? "Chess.com (" + root.playerData.username + ")" : "Chess.com"
      if (root.toMoveCount > 0) return base + " — " + root.toMoveCount + " move(s) to play!"
      if (root.activeGames && root.activeGames.length > 0) return base + " — " + root.activeGames.length + " active games (waiting on opponent)"
      return base
    }

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) {
        root.launchUrl("https://www.chess.com/")
      } else {
        root.toggle()
      }
    }
  }

  // ----------------------------------------------------------- Pop-out Panel
  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.opened
    triggerMode: "click"
    contentWidth: popup.fittedContentWidth(Style.space(root.panelWidth))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    Column {
      id: content
      anchors.fill: parent
      spacing: Style.space(12)

      // Header Row
      Item {
        width: parent.width
        height: Math.max(titleText.implicitHeight, webappBtn.height)

        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)
          Text {
            text: "󰡳"
            color: root.toMoveCount > 0 ? root.accent : root.foreground
            font.pixelSize: Style.font.title
            font.family: root.fontFamily
          }
          Text {
            id: titleText
            text: "CHESS.COM"
            color: root.foreground
            font.pixelSize: Style.font.title
            font.bold: true
            font.family: root.fontFamily
            font.letterSpacing: 1
          }
        }

        Rectangle {
          id: webappBtn
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: webappText.implicitWidth + Style.space(14)
          height: Style.space(26)
          radius: Style.cornerRadius
          color: webappArea.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"
          border.width: 1
          border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)

          Row {
            id: webappText
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text {
              text: "Open App"
              color: root.foreground
              font.pixelSize: Style.font.bodySmall
              font.family: root.fontFamily
            }
            Text {
              text: "󰒭"
              color: root.accent
              font.pixelSize: Style.font.bodySmall
              font.family: root.fontFamily
            }
          }

          MouseArea {
            id: webappArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.launchUrl("https://www.chess.com/")
          }
        }
      }

      // User Profile & Search Bar
      Rectangle {
        width: parent.width
        height: root.editingUser || !root.playerData ? Style.space(46) : Style.space(56)
        radius: Style.cornerRadius
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
        border.width: 1
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

        // Editing Mode
        Row {
          visible: root.editingUser || !root.playerData
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(8)

          Rectangle {
            width: parent.width - saveBtn.width - Style.space(8)
            height: parent.height
            radius: Math.max(2, Style.cornerRadius - 2)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)

            TextInput {
              id: userInput
              anchors.fill: parent
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              verticalAlignment: TextInput.AlignVCenter
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              text: root.currentUsername
              selectByMouse: true
              clip: true

              Text {
                visible: userInput.text === ""
                text: "Enter Chess.com username..."
                color: Qt.darker(root.foreground, 1.8)
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
              }

              Keys.onReturnPressed: root.saveUsername(userInput.text)
              Keys.onEnterPressed: root.saveUsername(userInput.text)
            }
          }

          Rectangle {
            id: saveBtn
            width: Style.space(64)
            height: parent.height
            radius: Math.max(2, Style.cornerRadius - 2)
            color: saveArea.containsMouse ? root.accent : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.8)

            Text {
              anchors.centerIn: parent
              text: "Save"
              color: Color.background
              font.bold: true
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: saveArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.saveUsername(userInput.text)
            }
          }
        }

        // Active Player Display Mode
        Item {
          visible: !root.editingUser && !!root.playerData
          anchors.fill: parent
          anchors.margins: Style.space(8)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(10)

            Rectangle {
              width: Style.space(40)
              height: Style.space(40)
              radius: Style.space(20)
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)
              clip: true

              Image {
                anchors.fill: parent
                source: root.playerData && root.playerData.avatar ? root.playerData.avatar : ""
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
              }

              Text {
                visible: !(root.playerData && root.playerData.avatar)
                anchors.centerIn: parent
                text: "♟"
                font.pixelSize: Style.font.title
                color: root.foreground
              }
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Row {
                spacing: Style.space(6)
                Rectangle {
                  visible: !!(root.playerData && root.playerData.title)
                  width: titleLabel.implicitWidth + Style.space(8)
                  height: Style.space(16)
                  radius: Style.space(3)
                  color: "#e69138"
                  anchors.verticalCenter: parent.verticalCenter
                  Text {
                    id: titleLabel
                    anchors.centerIn: parent
                    text: root.playerData && root.playerData.title ? root.playerData.title : ""
                    color: "#ffffff"
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }

                Text {
                  text: root.playerData && root.playerData.username ? root.playerData.username : ""
                  color: root.foreground
                  font.bold: true
                  font.pixelSize: Style.font.body
                  font.family: root.fontFamily
                }
              }

              Text {
                text: root.playerData && root.playerData.name ? root.playerData.name : (root.playerData && root.playerData.location ? root.playerData.location : "Active Player")
                color: Qt.darker(root.foreground, 1.5)
                font.pixelSize: Style.font.caption
                font.family: root.fontFamily
              }
            }
          }

          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(28)
            height: Style.space(28)
            radius: Style.space(14)
            color: editArea.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"

            Text {
              anchors.centerIn: parent
              text: "󰏫"
              color: Qt.darker(root.foreground, 1.4)
              font.pixelSize: Style.font.body
              font.family: root.fontFamily
            }

            MouseArea {
              id: editArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.editingUser = true
            }
          }
        }
      }

      // ------------------------------------------------ Active Games Section
      Column {
        visible: root.activeGames && root.activeGames.length > 0
        width: parent.width
        spacing: Style.space(6)

        Row {
          spacing: Style.space(6)
          Text {
            text: root.toMoveCount > 0 ? "⚡ YOUR TURN TO PLAY (" + root.toMoveCount + ")" : "⏳ ACTIVE DAILY GAMES (" + (root.activeGames ? root.activeGames.length : 0) + ")"
            color: root.toMoveCount > 0 ? root.accent : Qt.darker(root.foreground, 1.4)
            font.bold: true
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
            font.family: root.fontFamily
          }
        }

        Repeater {
          model: root.activeGames

          Rectangle {
            required property var modelData
            required property int index
            width: parent.width
            height: Style.space(46)
            radius: Style.cornerRadius
            color: modelData.isMyTurn 
              ? (gameArea.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12))
              : (gameArea.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04))
            border.width: 1
            border.color: modelData.isMyTurn ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

            Item {
              anchors.fill: parent
              anchors.margins: Style.space(8)

              Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(10)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.amWhite ? "⚪" : "⚫"
                  font.pixelSize: Style.font.body
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(1)

                  Row {
                    spacing: Style.space(6)
                    Text {
                      text: "vs " + modelData.opponent
                      color: root.foreground
                      font.bold: true
                      font.pixelSize: Style.font.bodySmall
                      font.family: root.fontFamily
                    }
                    Rectangle {
                      visible: modelData.isMyTurn
                      width: turnBadge.implicitWidth + Style.space(8)
                      height: Style.space(16)
                      radius: Style.space(3)
                      color: root.accent
                      anchors.verticalCenter: parent.verticalCenter
                      Text {
                        id: turnBadge
                        anchors.centerIn: parent
                        text: "YOUR TURN"
                        color: Color.background
                        font.bold: true
                        font.pixelSize: Style.font.caption
                      }
                    }
                  }

                  Text {
                    text: modelData.isMyTurn ? ("Move within: " + modelData.timeLeft) : ("Opponent thinking (" + modelData.timeLeft + " left)")
                    color: modelData.isMyTurn ? root.accent : Qt.darker(root.foreground, 1.6)
                    font.pixelSize: Style.font.caption
                    font.family: root.fontFamily
                  }
                }
              }

              Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.isMyTurn ? "Play 󰐊" : "View 󰒭"
                color: modelData.isMyTurn ? root.accent : Qt.darker(root.foreground, 1.5)
                font.bold: modelData.isMyTurn
                font.pixelSize: Style.font.bodySmall
                font.family: root.fontFamily
              }
            }

            MouseArea {
              id: gameArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.launchUrl(modelData.url)
            }
          }
        }
      }

      // ------------------------------------------------ Stats Grid
      Grid {
        visible: !!root.statsData
        width: parent.width
        columns: 2
        spacing: Style.space(8)

        // Rapid Card
        Rectangle {
          width: (parent.width - Style.space(8)) / 2
          height: Style.space(60)
          radius: Style.cornerRadius
          color: rapidArea.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
          border.width: 1
          border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

          Column {
            anchors.centerIn: parent
            spacing: Style.space(2)
            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(4)
              Text { text: "⏱"; font.pixelSize: Style.font.bodySmall }
              Text {
                text: "RAPID"
                color: Qt.darker(root.foreground, 1.4)
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
                font.family: root.fontFamily
              }
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Model.formatRating(root.statsData && root.statsData.chess_rapid && root.statsData.chess_rapid.last ? root.statsData.chess_rapid.last.rating : null)
              color: root.foreground
              font.bold: true
              font.pixelSize: Style.font.title
              font.family: root.fontFamily
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Model.formatRecord(root.statsData && root.statsData.chess_rapid ? root.statsData.chess_rapid.record : null)
              color: Qt.darker(root.foreground, 1.6)
              font.pixelSize: Style.font.caption
              font.family: root.fontFamily
            }
          }

          MouseArea {
            id: rapidArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.launchUrl("https://www.chess.com/play/online/new?time=600")
          }
        }

        // Daily Card
        Rectangle {
          width: (parent.width - Style.space(8)) / 2
          height: Style.space(60)
          radius: Style.cornerRadius
          color: dailyArea.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
          border.width: 1
          border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

          Column {
            anchors.centerIn: parent
            spacing: Style.space(2)
            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(4)
              Text { text: "📅"; font.pixelSize: Style.font.bodySmall }
              Text {
                text: "DAILY"
                color: Qt.darker(root.foreground, 1.4)
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
                font.family: root.fontFamily
              }
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Model.formatRating(root.statsData && root.statsData.chess_daily && root.statsData.chess_daily.last ? root.statsData.chess_daily.last.rating : null)
              color: root.foreground
              font.bold: true
              font.pixelSize: Style.font.title
              font.family: root.fontFamily
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Model.formatRecord(root.statsData && root.statsData.chess_daily ? root.statsData.chess_daily.record : null)
              color: Qt.darker(root.foreground, 1.6)
              font.pixelSize: Style.font.caption
              font.family: root.fontFamily
            }
          }

          MouseArea {
            id: dailyArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.launchUrl("https://www.chess.com/play/daily")
          }
        }
      }

      // ------------------------------------------------ Daily Puzzle Banner
      Rectangle {
        visible: root.showPuzzle && !!root.puzzleData
        width: parent.width
        height: Style.space(56)
        radius: Style.cornerRadius
        color: puzzleArea.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
        border.width: 1
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

        Row {
          anchors.fill: parent
          anchors.margins: Style.space(6)
          spacing: Style.space(10)

          Rectangle {
            width: Style.space(44)
            height: Style.space(44)
            radius: Math.max(2, Style.cornerRadius - 2)
            color: "#272522"
            clip: true

            Image {
              anchors.fill: parent
              source: root.puzzleData && root.puzzleData.image ? root.puzzleData.image : ""
              fillMode: Image.PreserveAspectFit
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(1)

            Row {
              spacing: Style.space(4)
              Text { text: "🧩"; font.pixelSize: Style.font.caption }
              Text {
                text: "DAILY PUZZLE"
                color: root.accent
                font.bold: true
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
                font.family: root.fontFamily
              }
            }

            Text {
              text: root.puzzleData && root.puzzleData.title ? root.puzzleData.title : "Daily Tactic"
              color: root.foreground
              font.bold: true
              font.pixelSize: Style.font.bodySmall
              font.family: root.fontFamily
              elide: Text.ElideRight
            }

            Text {
              text: "Click to solve on Chess.com"
              color: Qt.darker(root.foreground, 1.5)
              font.pixelSize: Style.font.caption
              font.family: root.fontFamily
            }
          }
        }

        MouseArea {
          id: puzzleArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.launchUrl(root.puzzleData && root.puzzleData.url ? root.puzzleData.url : "https://www.chess.com/puzzles")
        }
      }

      // Quick Launch Bar
      Row {
        width: parent.width
        spacing: Style.space(6)

        Rectangle {
          width: (parent.width - Style.space(18)) / 4
          height: Style.space(30)
          radius: Style.cornerRadius
          color: btn3mArea.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
          border.width: 1
          border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

          Text {
            anchors.centerIn: parent
            text: "⚡ 3 min"
            color: root.foreground
            font.pixelSize: Style.font.caption
            font.bold: true
            font.family: root.fontFamily
          }

          MouseArea {
            id: btn3mArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.launchUrl("https://www.chess.com/play/online/new?time=180")
          }
        }

        Rectangle {
          width: (parent.width - Style.space(18)) / 4
          height: Style.space(30)
          radius: Style.cornerRadius
          color: btn10mArea.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
          border.width: 1
          border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

          Text {
            anchors.centerIn: parent
            text: "⏱ 10 min"
            color: root.foreground
            font.pixelSize: Style.font.caption
            font.bold: true
            font.family: root.fontFamily
          }

          MouseArea {
            id: btn10mArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.launchUrl("https://www.chess.com/play/online/new?time=600")
          }
        }

        Rectangle {
          width: (parent.width - Style.space(18)) / 4
          height: Style.space(30)
          radius: Style.cornerRadius
          color: btnPzArea.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
          border.width: 1
          border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

          Text {
            anchors.centerIn: parent
            text: "🧩 Tactics"
            color: root.foreground
            font.pixelSize: Style.font.caption
            font.bold: true
            font.family: root.fontFamily
          }

          MouseArea {
            id: btnPzArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.launchUrl("https://www.chess.com/puzzles")
          }
        }

        Rectangle {
          width: (parent.width - Style.space(18)) / 4
          height: Style.space(30)
          radius: Style.cornerRadius
          color: btnBotsArea.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
          border.width: 1
          border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

          Text {
            anchors.centerIn: parent
            text: "🤖 Bots"
            color: root.foreground
            font.pixelSize: Style.font.caption
            font.bold: true
            font.family: root.fontFamily
          }

          MouseArea {
            id: btnBotsArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.launchUrl("https://www.chess.com/play/computer")
          }
        }
      }
    }
  }
}

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

  readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/omarchy-chess"
  property string localAvatarPath: ""
  property string localPuzzlePath: ""

  Process {
    id: ensureCacheDirProc
    command: ["mkdir", "-p", root.cacheDir]
    running: false
  }

  Process {
    id: webappLauncher
    command: []
    running: false
  }

  Process {
    id: avatarDownloadProc
    property string targetPath: ""
    command: []
    running: false
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0 && targetPath !== "") {
        root.localAvatarPath = targetPath
      }
    }
  }

  Process {
    id: puzzleDownloadProc
    property string targetPath: ""
    command: []
    running: false
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0 && targetPath !== "") {
        root.localPuzzlePath = targetPath
      }
    }
  }

  function fetchAvatarImage(rawUrl, username) {
    var safeUrl = Model.validateImageUrl(rawUrl)
    if (!safeUrl || !username) {
      localAvatarPath = ""
      return
    }
    var cleanUser = Model.cleanUsername(username)
    if (!cleanUser) {
      localAvatarPath = ""
      return
    }
    var dest = root.cacheDir + "/avatar_" + cleanUser + ".png"
    avatarDownloadProc.targetPath = dest
    avatarDownloadProc.command = [
      "curl",
      "--proto", "=https",
      "--max-filesize", "2097152",
      "--max-time", "10",
      "--max-redirs", "3",
      "-sSf",
      "-o", dest,
      safeUrl
    ]
    avatarDownloadProc.running = true
  }

  function fetchPuzzleImage(rawUrl) {
    var safeUrl = Model.validateImageUrl(rawUrl)
    if (!safeUrl) {
      localPuzzlePath = ""
      return
    }
    var today = new Date().toISOString().slice(0, 10)
    var dest = root.cacheDir + "/puzzle_" + today + ".png"
    puzzleDownloadProc.targetPath = dest
    puzzleDownloadProc.command = [
      "curl",
      "--proto", "=https",
      "--max-filesize", "2097152",
      "--max-time", "10",
      "--max-redirs", "3",
      "-sSf",
      "-o", dest,
      safeUrl
    ]
    puzzleDownloadProc.running = true
  }

  function launchUrl(url) {
    var safeUrl = Model.validateChessUrl(url)
    if (!safeUrl) {
      safeUrl = "https://www.chess.com/"
    }
    webappLauncher.command = ["omarchy-launch-or-focus-webapp", "Chess", safeUrl]
    webappLauncher.running = true
    root.close()
  }

  function refreshAll() {
    errorMessage = ""
    loading = true
    var targetUser = Model.cleanUsername(currentUsername)

    if (targetUser.length > 0) {
      Model.fetchPlayer(targetUser, function(err, player) {
        if (err) {
          errorMessage = "Player not found"
          playerData = null
          localAvatarPath = ""
          loading = false
          return
        }
        playerData = player
        if (player && player.avatar) {
          root.fetchAvatarImage(player.avatar, targetUser)
        } else {
          root.localAvatarPath = ""
        }
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
      localAvatarPath = ""
      loading = false
    }

    if (showPuzzle) {
      Model.fetchPuzzle(function(err, pz) {
        if (!err && pz) {
          puzzleData = pz
          if (pz.image) root.fetchPuzzleImage(pz.image)
        }
      })
    }
  }

  onOpenedChanged: {
    if (opened) {
      refreshAll()
    }
  }

  Component.onCompleted: {
    ensureCacheDirProc.running = true
    if (Model.cleanUsername(currentUsername) !== "") {
      refreshAll()
    } else if (showPuzzle) {
      Model.fetchPuzzle(function(err, pz) {
        if (!err && pz) {
          puzzleData = pz
          if (pz.image) root.fetchPuzzleImage(pz.image)
        }
      })
    }
  }

  Timer {
    interval: Math.max(1, root.pollMinutes) * 60 * 1000
    running: true
    repeat: true
    onTriggered: if (Model.cleanUsername(root.currentUsername) !== "") root.refreshAll()
  }

  function saveUsername(name) {
    var clean = Model.cleanUsername(name)
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
    text: root.toMoveCount > 0 ? "♟ " + root.toMoveCount : "♟"
    horizontalMargin: 6
    active: root.toMoveCount > 0
    activeColor: root.accent
    tooltipText: {
      var user = root.playerData && root.playerData.username ? root.playerData.username : ""
      var base = user ? ("Chess.com (" + user + ")") : "Chess.com"
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
            text: "♟"
            textFormat: Text.PlainText
            color: root.toMoveCount > 0 ? root.accent : root.foreground
            font.pixelSize: Style.font.title
            font.family: root.fontFamily
          }
          Text {
            id: titleText
            text: "CHESS.COM"
            textFormat: Text.PlainText
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
              textFormat: Text.PlainText
              color: root.foreground
              font.pixelSize: Style.font.bodySmall
              font.family: root.fontFamily
            }
            Text {
              text: "󰒭"
              textFormat: Text.PlainText
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
                textFormat: Text.PlainText
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
              textFormat: Text.PlainText
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
                source: root.localAvatarPath ? ("file://" + root.localAvatarPath) : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 80
                sourceSize.height: 80
                asynchronous: true
                cache: true
                visible: status === Image.Ready && root.localAvatarPath !== ""
              }

              Text {
                visible: !root.localAvatarPath
                anchors.centerIn: parent
                text: "♟"
                textFormat: Text.PlainText
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
                    textFormat: Text.PlainText
                    color: "#ffffff"
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }

                Text {
                  text: root.playerData && root.playerData.username ? root.playerData.username : ""
                  textFormat: Text.PlainText
                  color: root.foreground
                  font.bold: true
                  font.pixelSize: Style.font.body
                  font.family: root.fontFamily
                }
              }

              Text {
                text: root.playerData && root.playerData.name ? root.playerData.name : (root.playerData && root.playerData.location ? root.playerData.location : "Active Player")
                textFormat: Text.PlainText
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
              textFormat: Text.PlainText
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
            textFormat: Text.PlainText
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
                  textFormat: Text.PlainText
                  font.pixelSize: Style.font.body
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(1)

                  Row {
                    spacing: Style.space(6)
                    Text {
                      text: "vs " + modelData.opponent
                      textFormat: Text.PlainText
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
                        textFormat: Text.PlainText
                        color: Color.background
                        font.bold: true
                        font.pixelSize: Style.font.caption
                      }
                    }
                  }

                  Text {
                    text: modelData.isMyTurn ? ("Move within: " + modelData.timeLeft) : ("Opponent thinking (" + modelData.timeLeft + " left)")
                    textFormat: Text.PlainText
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
                textFormat: Text.PlainText
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
              Text { text: "⏱"; textFormat: Text.PlainText; font.pixelSize: Style.font.bodySmall }
              Text {
                text: "RAPID"
                textFormat: Text.PlainText
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
              textFormat: Text.PlainText
              color: root.foreground
              font.bold: true
              font.pixelSize: Style.font.title
              font.family: root.fontFamily
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Model.formatRecord(root.statsData && root.statsData.chess_rapid ? root.statsData.chess_rapid.record : null)
              textFormat: Text.PlainText
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
              Text { text: "📅"; textFormat: Text.PlainText; font.pixelSize: Style.font.bodySmall }
              Text {
                text: "DAILY"
                textFormat: Text.PlainText
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
              textFormat: Text.PlainText
              color: root.foreground
              font.bold: true
              font.pixelSize: Style.font.title
              font.family: root.fontFamily
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Model.formatRecord(root.statsData && root.statsData.chess_daily ? root.statsData.chess_daily.record : null)
              textFormat: Text.PlainText
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
              source: root.localPuzzlePath ? ("file://" + root.localPuzzlePath) : ""
              fillMode: Image.PreserveAspectFit
              sourceSize.width: 256
              sourceSize.height: 256
              asynchronous: true
              cache: true
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(1)

            Row {
              spacing: Style.space(4)
              Text { text: "🧩"; textFormat: Text.PlainText; font.pixelSize: Style.font.caption }
              Text {
                text: "DAILY PUZZLE"
                textFormat: Text.PlainText
                color: root.accent
                font.bold: true
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
                font.family: root.fontFamily
              }
            }

            Text {
              text: root.puzzleData && root.puzzleData.title ? root.puzzleData.title : "Daily Tactic"
              textFormat: Text.PlainText
              color: root.foreground
              font.bold: true
              font.pixelSize: Style.font.bodySmall
              font.family: root.fontFamily
              elide: Text.ElideRight
            }

            Text {
              text: "Click to solve on Chess.com"
              textFormat: Text.PlainText
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
            textFormat: Text.PlainText
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
            textFormat: Text.PlainText
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
            textFormat: Text.PlainText
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
            textFormat: Text.PlainText
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

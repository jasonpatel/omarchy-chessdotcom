// Model.js - Chess.com API handler for Omarchy
var USER_AGENT = "Omarchy-Chess-Plugin (https://github.com/omarchy/omarchy)"

function fetchJson(url, callback) {
  var xhr = new XMLHttpRequest()
  xhr.open("GET", url, true)
  xhr.setRequestHeader("User-Agent", USER_AGENT)
  xhr.timeout = 7000

  xhr.onreadystatechange = function() {
    if (xhr.readyState === XMLHttpRequest.DONE) {
      if (xhr.status >= 200 && xhr.status < 300) {
        try {
          var data = JSON.parse(xhr.responseText)
          callback(null, data)
        } catch (e) {
          callback(e, null)
        }
      } else {
        callback(new Error("HTTP " + xhr.status), null)
      }
    }
  }

  xhr.ontimeout = function() {
    callback(new Error("Timeout"), null)
  }

  xhr.onerror = function() {
    callback(new Error("Network Error"), null)
  }

  xhr.send()
}

function fetchPlayer(username, callback) {
  var clean = String(username || "").trim().toLowerCase()
  if (!clean) {
    callback(new Error("No username provided"), null)
    return
  }
  fetchJson("https://api.chess.com/pub/player/" + encodeURIComponent(clean), callback)
}

function fetchStats(username, callback) {
  var clean = String(username || "").trim().toLowerCase()
  if (!clean) {
    callback(new Error("No username provided"), null)
    return
  }
  fetchJson("https://api.chess.com/pub/player/" + encodeURIComponent(clean) + "/stats", callback)
}

function fetchActiveGames(username, callback) {
  var clean = String(username || "").trim().toLowerCase()
  if (!clean) {
    callback(new Error("No username provided"), null)
    return
  }
  fetchJson("https://api.chess.com/pub/player/" + encodeURIComponent(clean) + "/games", callback)
}

function fetchToMoveGames(username, callback) {
  var clean = String(username || "").trim().toLowerCase()
  if (!clean) {
    callback(new Error("No username provided"), null)
    return
  }
  fetchJson("https://api.chess.com/pub/player/" + encodeURIComponent(clean) + "/games/to-move", callback)
}

function fetchPuzzle(callback) {
  fetchJson("https://api.chess.com/pub/puzzle", callback)
}

function parseOpponent(game, myUsername) {
  if (!game) return { name: "Opponent", isWhite: false, isMyTurn: false, timeLeft: "" }
  var me = String(myUsername || "").toLowerCase()
  var whiteUrl = String(game.white || "").toLowerCase()
  var blackUrl = String(game.black || "").toLowerCase()
  
  var amWhite = whiteUrl.indexOf("/" + me) >= 0 || whiteUrl.endsWith("/" + me)
  var oppUrl = amWhite ? game.black : game.white
  var oppName = oppUrl ? oppUrl.split("/").pop() : "Opponent"
  
  var isMyTurn = (amWhite && game.turn === "white") || (!amWhite && game.turn === "black")
  
  var timeLeft = ""
  if (game.move_by) {
    var nowSec = Math.floor(Date.now() / 1000)
    var diffSec = game.move_by - nowSec
    if (diffSec > 86400) {
      var days = Math.floor(diffSec / 86400)
      var hrs = Math.floor((diffSec % 86400) / 3600)
      timeLeft = days + "d " + hrs + "h"
    } else if (diffSec > 0) {
      var h = Math.floor(diffSec / 3600)
      var m = Math.floor((diffSec % 3600) / 60)
      timeLeft = h + "h " + m + "m"
    } else {
      timeLeft = "0h 0m"
    }
  }
  
  return {
    opponent: oppName,
    amWhite: amWhite,
    isMyTurn: isMyTurn,
    timeLeft: timeLeft,
    url: game.url,
    fen: game.fen || ""
  }
}

function formatRating(val) {
  if (val === undefined || val === null || val <= 0) return "-"
  return String(val)
}

function formatRecord(record) {
  if (!record) return ""
  var w = record.win || 0
  var l = record.loss || 0
  var d = record.draw || 0
  return w + "W " + l + "L " + d + "D"
}

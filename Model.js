// Model.js - Chess.com API handler for Omarchy
var USER_AGENT = "Omarchy-Chess-Plugin (https://github.com/omarchy/omarchy)"

var MAX_BYTES_DEFAULT = 65536 // 64 KB limit for profile/stats/puzzle
var MAX_BYTES_GAMES = 262144 // 256 KB limit for games list

function cleanString(val, maxLen) {
  if (val === undefined || val === null) return ""
  var str = String(val)
  // Strip control characters and non-printable characters
  str = str.replace(/[\x00-\x1F\x7F-\x9F]/g, "")
  str = str.trim()
  if (maxLen && maxLen > 0 && str.length > maxLen) {
    str = str.substring(0, maxLen)
  }
  return str
}

function cleanUsername(val) {
  if (val === undefined || val === null) return ""
  var str = String(val).trim().toLowerCase()
  if (str.length < 1 || str.length > 40) return ""
  if (!/^[a-z0-9_-]+$/.test(str)) {
    return ""
  }
  return str
}

function validateChessUrl(url) {
  if (!url || typeof url !== "string") return ""
  var trimmed = url.trim()
  if (trimmed.length > 500) return ""
  // Strictly require https, host must be chess.com or www.chess.com, no userinfo (@), no custom port
  var match = trimmed.match(/^https:\/\/(www\.)?chess\.com(\/[a-zA-Z0-9_\-\.\/\?\=\&\%\#]*)?$/)
  if (!match) return ""
  return trimmed
}

function validateImageUrl(url) {
  if (!url || typeof url !== "string") return ""
  var trimmed = url.trim()
  if (trimmed.length > 500) return ""
  // Strictly require https, allowlisted image hosts, no userinfo, no custom port
  var match = trimmed.match(/^https:\/\/(images\.chesscomfiles\.com|(www\.)?chess\.com)\/[a-zA-Z0-9_\-\.\/\?\=\&\%\#]+$/)
  if (!match) return ""
  return trimmed
}

function fetchJson(url, maxBytes, callback) {
  if (typeof maxBytes === "function") {
    callback = maxBytes
    maxBytes = MAX_BYTES_DEFAULT
  }
  maxBytes = maxBytes || MAX_BYTES_DEFAULT

  var xhr = new XMLHttpRequest()
  xhr.open("GET", url, true)
  xhr.setRequestHeader("User-Agent", USER_AGENT)
  xhr.timeout = 7000

  var aborted = false

  xhr.onprogress = function(event) {
    if (event && event.loaded && event.loaded > maxBytes) {
      aborted = true
      xhr.abort()
      callback(new Error("Response exceeded maximum allowed size"), null)
    }
  }

  xhr.onreadystatechange = function() {
    if (aborted) return
    if (xhr.readyState === XMLHttpRequest.DONE) {
      if (xhr.status >= 200 && xhr.status < 300) {
        var respText = xhr.responseText || ""
        if (respText.length > maxBytes) {
          callback(new Error("Response exceeded maximum allowed size"), null)
          return
        }
        try {
          var data = JSON.parse(respText)
          if (!data || typeof data !== "object") {
            callback(new Error("Invalid response format"), null)
            return
          }
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
    if (aborted) return
    callback(new Error("Timeout"), null)
  }

  xhr.onerror = function() {
    if (aborted) return
    callback(new Error("Network Error"), null)
  }

  xhr.send()
}

function fetchPlayer(username, callback) {
  var clean = cleanUsername(username)
  if (!clean) {
    callback(new Error("Invalid or empty username"), null)
    return
  }
  fetchJson("https://api.chess.com/pub/player/" + encodeURIComponent(clean), MAX_BYTES_DEFAULT, function(err, raw) {
    if (err) {
      callback(err, null)
      return
    }
    // Closed schema parsing & length bounding
    var title = cleanString(raw.title, 10).toUpperCase()
    if (!/^[A-Z]{1,10}$/.test(title)) title = ""

    var player = {
      username: cleanString(raw.username, 40) || clean,
      title: title,
      name: cleanString(raw.name, 60),
      location: cleanString(raw.location, 60),
      avatar: validateImageUrl(raw.avatar),
      status: cleanString(raw.status, 20),
      url: validateChessUrl(raw.url)
    }
    callback(null, player)
  })
}

function parseRatingRecord(categoryObj) {
  if (!categoryObj || typeof categoryObj !== "object") return null
  var rating = null
  if (categoryObj.last && typeof categoryObj.last.rating === "number") {
    var r = Math.round(categoryObj.last.rating)
    if (r >= 0 && r <= 4000) rating = r
  }
  var record = null
  if (categoryObj.record && typeof categoryObj.record === "object") {
    record = {
      win: Math.max(0, Math.min(1000000, Number(categoryObj.record.win) || 0)),
      loss: Math.max(0, Math.min(1000000, Number(categoryObj.record.loss) || 0)),
      draw: Math.max(0, Math.min(1000000, Number(categoryObj.record.draw) || 0))
    }
  }
  return {
    last: rating !== null ? { rating: rating } : null,
    record: record
  }
}

function fetchStats(username, callback) {
  var clean = cleanUsername(username)
  if (!clean) {
    callback(new Error("Invalid or empty username"), null)
    return
  }
  fetchJson("https://api.chess.com/pub/player/" + encodeURIComponent(clean) + "/stats", MAX_BYTES_DEFAULT, function(err, raw) {
    if (err) {
      callback(err, null)
      return
    }
    var stats = {
      chess_rapid: parseRatingRecord(raw.chess_rapid),
      chess_daily: parseRatingRecord(raw.chess_daily),
      chess_blitz: parseRatingRecord(raw.chess_blitz)
    }
    callback(null, stats)
  })
}

function sanitizeGame(game) {
  if (!game || typeof game !== "object") return null
  var white = cleanString(game.white, 200)
  var black = cleanString(game.black, 200)
  var url = validateChessUrl(game.url)
  var turn = (game.turn === "white" || game.turn === "black") ? game.turn : ""
  var moveBy = 0
  if (typeof game.move_by === "number" && game.move_by > 0 && game.move_by < 4102444800) {
    moveBy = Math.round(game.move_by)
  }
  var fen = cleanString(game.fen, 100)

  return {
    white: white,
    black: black,
    url: url,
    turn: turn,
    move_by: moveBy,
    fen: fen
  }
}

function fetchActiveGames(username, callback) {
  var clean = cleanUsername(username)
  if (!clean) {
    callback(new Error("Invalid or empty username"), null)
    return
  }
  fetchJson("https://api.chess.com/pub/player/" + encodeURIComponent(clean) + "/games", MAX_BYTES_GAMES, function(err, raw) {
    if (err) {
      callback(err, null)
      return
    }
    var rawGames = Array.isArray(raw.games) ? raw.games : []
    // Cardinality cap: at most 30 games
    var capped = rawGames.slice(0, 30)
    var games = []
    for (var i = 0; i < capped.length; i++) {
      var sanitized = sanitizeGame(capped[i])
      if (sanitized) games.push(sanitized)
    }
    callback(null, { games: games })
  })
}

function fetchToMoveGames(username, callback) {
  var clean = cleanUsername(username)
  if (!clean) {
    callback(new Error("Invalid or empty username"), null)
    return
  }
  fetchJson("https://api.chess.com/pub/player/" + encodeURIComponent(clean) + "/games/to-move", MAX_BYTES_GAMES, function(err, raw) {
    if (err) {
      callback(err, null)
      return
    }
    var rawGames = Array.isArray(raw.games) ? raw.games : []
    var capped = rawGames.slice(0, 30)
    var games = []
    for (var i = 0; i < capped.length; i++) {
      var sanitized = sanitizeGame(capped[i])
      if (sanitized) games.push(sanitized)
    }
    callback(null, { games: games })
  })
}

function fetchPuzzle(callback) {
  fetchJson("https://api.chess.com/pub/puzzle", MAX_BYTES_DEFAULT, function(err, raw) {
    if (err) {
      callback(err, null)
      return
    }
    var puzzle = {
      title: cleanString(raw.title, 100) || "Daily Tactic",
      url: validateChessUrl(raw.url) || "https://www.chess.com/puzzles",
      image: validateImageUrl(raw.image),
      fen: cleanString(raw.fen, 100),
      publish_time: typeof raw.publish_time === "number" ? Math.round(raw.publish_time) : 0
    }
    callback(null, puzzle)
  })
}

function parseOpponent(game, myUsername) {
  if (!game) return { opponent: "Opponent", amWhite: false, isMyTurn: false, timeLeft: "", url: "https://www.chess.com/" }
  var me = cleanUsername(myUsername)
  var whiteUrl = cleanString(game.white, 200).toLowerCase()
  var blackUrl = cleanString(game.black, 200).toLowerCase()

  var amWhite = (me !== "" && (whiteUrl.indexOf("/" + me) >= 0 || whiteUrl.endsWith("/" + me)))
  var oppUrl = amWhite ? game.black : game.white
  var rawOppName = oppUrl ? String(oppUrl).split("/").pop() : "Opponent"
  var oppName = cleanUsername(rawOppName) || cleanString(rawOppName, 40).replace(/[^a-zA-Z0-9_-]/g, "") || "Opponent"

  var isMyTurn = (amWhite && game.turn === "white") || (!amWhite && game.turn === "black")

  var timeLeft = ""
  if (game.move_by && typeof game.move_by === "number" && game.move_by > 0) {
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

  var safeUrl = validateChessUrl(game.url) || "https://www.chess.com/"

  return {
    opponent: oppName,
    amWhite: amWhite,
    isMyTurn: isMyTurn,
    timeLeft: timeLeft,
    url: safeUrl,
    fen: cleanString(game.fen, 100)
  }
}

function formatRating(val) {
  if (val === undefined || val === null || val <= 0 || typeof val !== "number") return "-"
  return String(Math.round(val))
}

function formatRecord(record) {
  if (!record || typeof record !== "object") return ""
  var w = Math.max(0, Math.min(1000000, Number(record.win) || 0))
  var l = Math.max(0, Math.min(1000000, Number(record.loss) || 0))
  var d = Math.max(0, Math.min(1000000, Number(record.draw) || 0))
  return w + "W " + l + "L " + d + "D"
}

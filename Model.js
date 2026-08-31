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

function fetchPuzzle(callback) {
  fetchJson("https://api.chess.com/pub/puzzle", callback)
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

function winRate(record) {
  if (!record) return ""
  var w = record.win || 0
  var l = record.loss || 0
  var d = record.draw || 0
  var total = w + l + d
  if (total === 0) return ""
  return Math.round((w / total) * 100) + "%"
}

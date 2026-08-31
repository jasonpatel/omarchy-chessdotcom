# Omarchy Chess.com Plugin (󰡲)

A fast, responsive Chess.com status bar widget and pop-out panel for [Omarchy Linux](https://omarchy.org/).

![Omarchy Chess](preview.png)

---

## ✨ Features

- **⚡ Live Rating Cards:** Displays current ratings and Win/Loss/Draw records for:
  - ⏱ **Rapid** (10 min)
  - ⚡ **Blitz** (3 min / 5 min)
  - 🎯 **Bullet** (1 min)
  - 🧩 **Puzzles & Tactics**
- **🧩 Daily Tactical Puzzle:** Fetches and renders today's Chess.com daily puzzle with mini-board preview. Click to jump straight into solving.
- **⚡ Instant Game Launchers:** 1-click buttons to launch:
  - `⚡ 3 min Blitz`
  - `⏱ 10 min Rapid`
  - `🧩 Tactics & Puzzles`
  - `🤖 Play vs Computer Bots`
- **👤 Player Profile Card:** Displays your Chess.com avatar, username, grandmaster/master title pill, and real name.
- **🔍 Inline Username Switcher:** Type any Chess.com username directly inside the panel to inspect stats for yourself, friends, or grandmasters like `hikaru` and `magnuscarlsen`.
- **🎨 Native Theme Adaptive:** Seamlessly respects Omarchy light/dark themes, accent colors, and corner radius tokens.
- **🚀 Web App Integration:** Right-click the bar icon to launch the full standalone Chess.com web app immediately.

---

## 📦 Installation

### Method 1: Using Omarchy Plugin Clone (Recommended)

```bash
# Clone directly into your Omarchy plugins directory:
git clone https://github.com/<your-username>/omarchy-chess.git ~/.config/omarchy/plugins/jason.chess

# Force Omarchy shell to rescan plugins:
omarchy-shell shell rescanPlugins
```

### Method 2: Enable in `shell.json`

Add `jason.chess` to your bar layout in `~/.config/omarchy/shell.json`:

```json
{
  "bar": {
    "layout": {
      "right": [
        {
          "id": "jason.chess",
          "username": "your_chesscom_username"
        }
      ]
    }
  }
}
```

---

## ⚙️ Configuration Options

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `username` | `string` | `""` | Your Chess.com username. |
| `panelWidth` | `integer` | `380` | Pop-out panel width in shell units (320–600). |
| `showPuzzle` | `boolean` | `true` | Show the Daily Puzzle preview banner. |
| `pollMinutes` | `integer` | `10` | Background rating poll interval in minutes. |

---

## 📜 License

MIT License. Copyright (c) 2026 Jason.

#!/bin/bash
set -e

echo -e "\e[1;32m=== Publishing omarchy-chessdotcom to GitHub ===\e[0m\n"

if ! gh auth status &>/dev/null; then
  echo -e "Logging into GitHub CLI...\n"
  gh auth login -p https -w
fi

echo -e "\n\e[1;34mCreating public repository 'omarchy-chessdotcom' and pushing code...\e[0m\n"
cd ~/.config/omarchy/plugins/jason.chess
gh repo create omarchy-chessdotcom --public --source=. --remote=origin --push || {
  git branch -M main
  git push -u origin main
}

echo -e "\n\e[1;32m🎉 Success! Plugin published to GitHub!\e[0m"
echo -e "Repository URL: $(gh repo view --json url -q .url)\n"
read -p "Press Enter to close this window..."

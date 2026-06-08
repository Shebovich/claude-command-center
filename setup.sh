#!/usr/bin/env bash
# Setup окружения Pavel на новой Mac/Linux-машине.
# Запуск: bash setup.sh   (нужны git + gh + node, см. DEPLOY.md шаг 1)
set -e

GH_USER="Shebovich"
REPOS=(personal-assistant-cc claude-command-center dental-ai-admin lead-monitor)
ROOT="$HOME/Projects/ClaudeCode"

echo "== Setup окружения =="

# 1) Инструменты через brew (если есть brew)
if command -v brew >/dev/null 2>&1; then
  for t in yt-dlp ffmpeg ollama; do
    echo "brew: $t"; brew install "$t" 2>/dev/null || true
  done
else
  echo "brew не найден — поставь инструменты вручную (yt-dlp, ffmpeg, ollama)"
fi

# 2) Клонируем репозитории
mkdir -p "$ROOT"
for r in "${REPOS[@]}"; do
  dest="$ROOT/$r"
  if [ -d "$dest" ]; then echo "$r: уже есть, skip"
  else echo "clone $r"; gh repo clone "$GH_USER/$r" "$dest"; fi
done

# 3) npm install в Node-проектах
for p in "$ROOT/dental-ai-admin" "$ROOT/lead-monitor" "$ROOT/personal-assistant-cc"; do
  if [ -f "$p/package.json" ]; then echo "npm install: $p"; (cd "$p" && npm install --silent); fi
done

echo ""
echo "== Готово. Ручные шаги (см. DEPLOY.md): =="
echo " 1. Разложить secrets (.env по проектам + data/profile.json) — их нет в git."
echo " 2. VPN split: вывести yt-dlp/curl/git мимо VPN (НЕ node) — аналог SplitBear на Mac."
echo " 3. /start-personal-session для поднятия ассистента."

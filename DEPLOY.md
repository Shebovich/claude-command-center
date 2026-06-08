# Развёртывание на новой машине — пара действий

_Цель: новый комп (Windows или Mac) → рабочее окружение за несколько команд. Секреты переносятся отдельно (НЕ в git — там их нет специально)._

## Шаг 1 — поставить базу
**Windows:** установить [git](https://git-scm.com) + [Node.js LTS](https://nodejs.org) + [GitHub CLI](https://cli.github.com), затем `gh auth login`.
**Mac:** `brew install git node gh && gh auth login`

## Шаг 2 — клонировать всё (один скрипт)
**Windows (PowerShell):** `./setup.ps1`
**Mac/Linux:** `bash setup.sh`

Скрипт клонирует все наши репозитории в `Projects/ClaudeCode/` и ставит инструменты (yt-dlp, ffmpeg, ollama) через winget/brew.

## Шаг 3 — секреты (вручную, один раз)
Секретов в git НЕТ намеренно (профиль/ключи/токены). Перенести их отдельно (зашифрованный файл / менеджер паролей / флешка) и разложить `.env` по проектам:
- `personal-assistant/.env` — BOT_API_BASE, CLAUDE_NOTIFY_SECRET, GEMINI_API_KEY, и т.д. (шаблон — `.env.example`)
- `products/dental-ai-admin/.env` — BOT_TOKEN, GEMINI_API_KEY, ADMIN_CHAT_ID (см. `.env.example`)
- `products/lead-monitor/.env` — API_ID, API_HASH, TG_SESSION, GEMINI_API_KEY (см. `.env.example`)
- `personal-assistant/data/profile.json` — личные данные (НЕ в git, перенести отдельно)

## Шаг 4 — зависимости
`setup` уже делает `npm install` в проектах. Если вручную: в каждом проекте `npm install`.

## Шаг 5 — ручное (машино-зависимое, в чеклисте)
- **VPN split (Windows TunnelBear SplitBear):** добавить в исключения `yt-dlp.exe`, `curl.exe` (×2), `git.exe` — НЕ node.exe (см. ENVIRONMENT.md). На Mac — аналог в его VPN.
- Поднять сессию ассистента: `/start-personal-session` (poller + heartbeat).

## Репозитории (Shebovich, приватные)
- `personal-assistant-cc` — CC-сторона бота (бридж, инструменты).
- `claude-command-center` — стратегия, плейбук, environment, research.
- `dental-ai-admin` — продукт #1 (бот для стоматологий).
- `lead-monitor` — мониторинг лидов (прототип).

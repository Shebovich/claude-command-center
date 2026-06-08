# Окружение Pavel — переносимый конфиг

_Цель: при переустановке / новой машине / переходе на Mac — накатить окружение по этому файлу, не вспоминая «что и как настраивали». Гибко, расширяемо, кроссплатформенно. Живой документ._

## Принцип
Все решения проектируем ПЕРЕНОСИМО: конфиг в файле (не в голове и не только в GUI), пути и команды абстрагируем по ОС, ничего не хардкодим намертво под одну машину. У Pavel: Windows-десктоп (основной) + MacBook. Машина может меняться.

## Инструменты (ставить на новой машине)
| Инструмент | Назначение | Win (winget) | Mac (brew) |
|---|---|---|---|
| Node.js 18+ | runtime ботов/скриптов | `winget install OpenJS.NodeJS.LTS` | `brew install node` |
| yt-dlp | скачивание рилсов | `winget install yt-dlp.yt-dlp` | `brew install yt-dlp` |
| ffmpeg | обработка видео/аудио | `winget install Gyan.FFmpeg` | `brew install ffmpeg` |
| git | вкс | `winget install Git.Git` | `brew install git` |
| Ollama | локальные модели (дешёвая рутина) | `winget install Ollama.Ollama` | `brew install ollama` |

## VPN split-tunnel (оптимизация трафика — см. CLAUDE.md проекта)
Цель: тяжёлые скачиватели мимо VPN, node под VPN (Gemini=403 без западного IP).
- **Windows + TunnelBear SplitBear** (GUI → исключения по exe): добавить `yt-dlp.exe`, `curl.exe` (System32 + Git\mingw64), `git.exe`. НЕ добавлять `node.exe`.
  - Пути на текущей машине: yt-dlp в `%LOCALAPPDATA%\Microsoft\WinGet\Packages\yt-dlp.yt-dlp_*\yt-dlp.exe`; curl `C:\Windows\System32\curl.exe` и `C:\Program Files\Git\mingw64\bin\curl.exe`; git `C:\Program Files\Git\cmd\git.exe`.
- **Mac / другой VPN:** SplitBear по приложениям аналогично (если есть), либо VPN со split по приложениям/доменам. Принцип тот же: тяжёлые downloader'ы — мимо VPN, node/Gemini — через VPN.
- Проверка: скачать рилс → `Get-NetAdapterStatistics` (Win) на VPN-адаптере не должен расти. На Mac — `nettop`/`vmstat` по интерфейсу.

## Ключи/секреты (.env — НЕ в git)
Держать в `.env` каждого проекта: GEMINI_API_KEY (общий, есть), BOT_TOKEN'ы (per-bot), TRUSTMRR_API_KEY, и т.д. При переезде — перенести `.env` отдельно (вне репо).

## Проекты (структура)
`C:\Projects\ClaudeCode\` (Win) — все клавдкодные проекты. На Mac — `~/Projects/ClaudeCode/`. Внутри: STRATEGY.md, SAAS-PLAYBOOK.md, ENVIRONMENT.md (этот), products/* (dental-ai-admin, lead-monitor), research-digests/.

## TODO (расширяемость)
- [ ] setup-скрипт (`setup.ps1` / `setup.sh`), который ставит инструменты и печатает чеклист ручных шагов (SplitBear-исключения — ручной GUI-шаг, его автоматизировать сложно).
- [ ] Абстрагировать пути в скриптах (env-переменные / автодетект ОС) вместо хардкода `C:\...`.

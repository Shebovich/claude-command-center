# Инженерный self-improve дайджест №2 — 2026-06-08

Фокус: кроссплатформенность Node (Win+Mac), bootstrap окружения, надёжность 24/7-процессов, управление множеством репо. Жёсткий фильтр: только actionable + под контекст Pavel (CC-ассистент + Grammy/node:sqlite/Gemini боты, машины Win-десктоп + MacBook, воркспейс `C:\Projects\ClaudeCode`). Не повторяю цикл №1 (субагент-ТЗ, multi-agent токены, graceful shutdown, Ollama).

Контекст машины: **Node v24.16.0** (значит native `node:sqlite`, `--env-file`, `--watch`, native glob уже есть — без npm-зависимостей). Воркспейс уже существует с `.git` в корне, ENVIRONMENT.md, SAAS-PLAYBOOK.md и репо-папками — то есть bootstrap-паттерн фактически уже начат.

---

## 1. Кроссплатформенная разработка Node (Windows + macOS)

### 1.1 Никаких OS-команд в npm-скриптах — только node-обёртки
**Что:** главный источник «работает на Mac, падает на Win» — shell-команды в `scripts` (`rm`, `cp`, `set VAR=`, `&&`, `./bin/x.js`). Конкретные замены:
- `set NODE_ENV=production` (ломается в cmd.exe, точка с запятой меняет шелл навсегда) → пакет **`cross-env`**: `cross-env NODE_ENV=production node x.mjs`.
- `rm -rf` → **`rimraf`**; `cp` → `shx cp` / `ncp`.
- `a && b && c` и `a & b` (параллель) → **`npm-run-all`** (`run-s` последовательно, `run-p` параллельно, поддержка wildcard `build:*`).
- Запуск своих скриптов: всегда `node ./scripts/x.mjs`, НЕ `./scripts/x.mjs` (Win не понимает shebang).
- Бинарь из node_modules: писать просто `playwright`, не `./node_modules/.bin/playwright` — npm сам кладёт `.bin` в PATH.
**Источник:** https://alan.norbauer.com/articles/cross-platform-nodejs/ , https://github.com/bcoe/awesome-cross-platform-nodejs
**Как применить у нас:** `personal-assistant/package.json` сейчас чистый (`node scripts/...` — уже правильно). Закрепить как правило для будущих ботов/SaaS: в `scripts` только `node ...`; для env-инлайна — `cross-env`; для очистки/копирования — `rimraf`/`shx`; для цепочек — `npm-run-all`. Добавить эти 3 пакета в шаблон-репо (см. §4).

### 1.2 Пути: всегда `path`/`URL`, forward-slash, никаких строковых split
**Что:** не резать пути по `/`, не конкатенировать строками. Использовать `path.join`/`path.resolve`; forward-slash работает и на Win (cmd/Node его принимают), backslash на Mac — нет. Для путей внутри ESM-модулей: `import { fileURLToPath } from 'node:url'; const __dirname = path.dirname(fileURLToPath(import.meta.url))` (в `.mjs` нет `__dirname`). Для «домашней»/«временной» папки — `os.homedir()` / `os.tmpdir()`, не хардкод `C:\Users\...` или `/tmp`.
**Источник:** https://alan.norbauer.com/articles/cross-platform-nodejs/ , https://github.com/zoonderkins/portable-node-guide
**Как применить у нас:** прямо закрывает TODO из `ENVIRONMENT.md` строка 32 («абстрагировать пути»). В скриптах ассистента, где встречается `C:\Users\User\OneDrive\Desktop\personal-assistant`, ввести единый `const ROOT = ...` через `os.homedir()` + относительный путь, либо env-переменную `PA_ROOT` с дефолтом. Папки данных (`data/`, `_tmp/`, `_crypto/`) резолвить через `path.join(ROOT, 'data')`. На Mac это будет `~/Projects/ClaudeCode/...` без правок кода.

### 1.3 node:sqlite — сам по себе переносим, но путь к файлу БД нет
**Что:** native `node:sqlite` (стабилен в Node 24 LTS) встроен в рантайм → нет нативной компиляции, нет prebuilt-бинарей per-OS, нет build-tools — главная боль `better-sqlite3`/`sqlite3` на Win исчезает. Ограничения: нельзя кастомный билд/расширения. Для dental-бота и любых node:sqlite-ботов — это правильный дефолт именно ради переносимости Win↔Mac.
**Источник:** https://nodejs.org/api/sqlite.html , https://blog.logrocket.com/using-built-in-sqlite-module-node-js/
**Как применить у нас:** уже выбран node:sqlite — зафиксировать как стандарт стека (в SAAS-PLAYBOOK). Единственное, что остаётся переносить: ПУТЬ к `.db`-файлу — резолвить через `os.homedir()`/env, не хардкодить. .gitattributes для текстовых фикстур (см. ниже) к бинарной БД не относится.

### 1.4 Line endings — `.gitattributes` против CRLF-сюрпризов
**Что:** на Win `git core.autocrlf=true` конвертит файлы в CRLF → ломает сравнения фикстур, hash-чексуммы, иногда shebang-скрипты. Лечение — `.gitattributes` в корне репо: `* text=auto eol=lf` (+ явное `*.ps1 text eol=crlf` для PowerShell, который любит CRLF).
**Источник:** https://alan.norbauer.com/articles/cross-platform-nodejs/
**Как применить у нас:** добавить `.gitattributes` в шаблон-репо и в корень `C:\Projects\ClaudeCode`. Особенно важно когда Pavel начнёт коммитить с обеих машин (Win-десктоп + Mac) — иначе каждый файл будет «изменён» из-за EOL.

---

## 2. Bootstrap окружения (setup-скрипты, dotfiles, секреты)

### 2.1 dotenvx — зашифрованный `.env` коммитится в репо, ключ отдельно
**Что:** `dotenvx` (от автора `dotenv`, drop-in замена) шифрует значения `.env` через ECIES (AES-256, эфемерные ключи). Генерит пару: `DOTENV_PUBLIC_KEY` (шифрует, лежит в `.env`) + `DOTENV_PRIVATE_KEY` (расшифровывает, в `.env.keys`). Зашифрованный `.env` МОЖНО коммитить; `.env.keys` — НИКОГДА. На новой машине/в проде: задать `DOTENV_PRIVATE_KEY` в среде и `dotenvx run -- node bot.mjs`. Имя-конвенция: `DOTENV_PRIVATE_KEY_PRODUCTION` → `.env.production`.
**Источник:** https://dotenvx.com/docs/quickstart/encryption , https://github.com/dotenvx/dotenvx
**Как применить у нас:** прямо решает боль из ENVIRONMENT.md «при переезде перенести .env отдельно вне репо». Вместо ручного таскания plaintext .env между Win и Mac — зашифровать каждый проектный `.env` через dotenvx, закоммитить в репо, а единственный приватный ключ хранить в одном месте (KeePassXC/файл на флешке). На новой машине: клон репо + один env-var = всё расшифровано. Без облака, локально-зашифровано — ровно требование Pavel.

### 2.2 chezmoi — dotfiles + секреты с age-шифрованием, один bootstrap-командой
**Что:** chezmoi физически раскладывает конфиги по местам; встроенное **age**-шифрование (секреты лежат зашифрованными прямо в публичном репо, расшифровываются на `apply`). Скрипты `run_once_before_*` выполняются один раз на машину (трекинг по content-hash, лексикографический порядок) — ставят Homebrew/пакеты ДО раскладки конфигов. Кроссплатформенно (Win/macOS/Linux), один templated-репо для обеих ОС с `{{ if eq .chezmoi.os "windows" }}`.
**Источник:** https://dotfiles.github.io/bootstrap/ , https://www.chezmoi.io/
**Как применить у нас:** для Pavel это апгрейд `ENVIRONMENT.md` из «документ-чеклист» в «исполняемый bootstrap». Но это бОльшее усилие, чем нужно сейчас — рекомендую начать с малого (§2.3) и держать chezmoi в уме, когда машин/секретов станет много. Если возьмём — age-шифрование закрывает «локально/зашифрованно без облака».

### 2.3 setup.ps1 / setup.sh с OS-детектом + печать ручных шагов
**Что:** идиома bootstrap-репо (holman/dotfiles, obstschale): `script/bootstrap` идемпотентен, ставит пакеты через нативный пакет-менеджер, в конце ПЕЧАТАЕТ чеклист того, что автоматизировать нельзя. OS-детект: в Node — `process.platform` (`win32`/`darwin`); в shell — `$IsWindows`/`uname`.
**Источник:** https://github.com/holman/dotfiles/blob/master/script/bootstrap , https://dotfiles.github.io/bootstrap/
**Как применить у нас:** закрывает TODO ENVIRONMENT.md строка 31. Конкретно: один `setup.mjs` (node — кроссплатформенно, не дублировать ps1+sh!), который: (1) детектит ОС через `process.platform`, (2) гонит winget (Win) / brew (Mac) по таблице инструментов из ENVIRONMENT.md, (3) `npm ci` по проектам, (4) печатает ручной чеклист (SplitBear-исключения, BotFather-токены, OAuth — то, что GUI/ручное). Node-вариант предпочтительнее пары ps1/sh — одна логика, обе ОС.

---

## 3. Надёжность долгоживущих процессов (poller/бот 24/7)

### 3.1 Single-instance lock — лечение 409-конфликта Telegram (была у нас)
**Что:** 409 `terminated by other getUpdates` = два процесса поллят один токен. Корневое лечение — **эксклюзивный lock-файл перед стартом поллинга**: процесс берёт lock (atomic-create), при живом lock — выходит/ждёт. Плюс на сам 409: НЕ считать фатальным — ретрай 3× с задержкой ~10с (30с окна хватает Telegram отпустить залипшую long-poll-сессию). Webhook не страдает 409 в принципе (нет конкурентного getUpdates).
**Источник:** https://github.com/yagop/node-telegram-bot-api/issues/550 , https://github.com/anthropics/claude-plugins-official/issues/1075
**Как применить у нас:** для poller ассистента и для polling-ботов — на старте брать lock-файл (`proper-lockfile` npm или самому: atomic `fs.open` с флагом `wx` на `<root>/.poller.lock`, в lock писать PID, на старте проверять жив ли PID, снимать lock на graceful shutdown — связка с graceful shutdown из цикла №1). Это прямо предотвращает повтор инцидента 409 при двойном запуске сессии. Для критичных ботов вообще предпочесть webhook (нет класса проблемы).

### 3.2 PM2 на *nix — авто-рестарт, на Windows — отдельная история
**Что:** PM2 держит процесс вечно, рестарт на краше с `exp_backoff_restart_delay` (множитель 1.5 между попытками — защита от рестарт-шторма), cron-рестарты, `instances: 1` для шедулеров (анти-двойной-запуск). НО автозапуск после ребута (`pm2 startup`) — только *nix. На **Windows** `pm2 startup` НЕ работает: нужен `pm2-windows-service` (ставит реальный Windows Service + `pm2 save` в `dump.pm2`) ИЛИ Task Scheduler с .bat на старте (но у Task Scheduler известные баги на Win10+).
**Источник:** https://betterstack.com/community/guides/scaling-nodejs/pm2-guide/ , https://pm2.keymetrics.io/docs/usage/startup/ , https://pm2.keymetrics.io/docs/usage/restart-strategies/
**Как применить у нас:** для ботов на *nix-хосте (Vercel serverless у нас webhook — там PM2 не нужен; но для VPS-ботов) — PM2 с `exp_backoff_restart_delay` + `instances:1`. Для poller'а ассистента на Win-десктопе Pavel: PM2 ради автозапуска тут не идеален — проще Task Scheduler «At log on» → `node poll-bot.mjs loop` ИЛИ запускать poller внутри CC-сессии как сейчас. Кроссплатформенный вывод: НЕ закладывать `pm2 startup` в переносимый setup — на Mac/Linux он есть, на Win нужен другой путь; документировать оба в ENVIRONMENT.md.

### 3.3 `node --watch` / `--env-file` — это DEV, не прод-крэш-рекавери
**Что:** native `--watch` и `--env-file` (Node 20.6+, стабильны в 24) удобны локально, но `--watch` НЕ рестартит при unhandled exception (только при изменении файла) и имеет баги (рестартит до резолва pending-промисов; не следит за самим env-файлом). Для крэш-рекавери нужен process-manager (PM2/systemd), не `--watch`.
**Источник:** https://blog.logrocket.com/node-js-24-features/ , https://github.com/nodejs/node/issues/47990
**Как применить у нас:** `--env-file` можно юзать для локальной разработки вместо `dotenv`-пакета (минус одна зависимость, Node 24 уже стоит). НО для прод-секретов — dotenvx (§2.1, шифрование). И не путать `--watch` с надёжностью: для 24/7 — lock + graceful shutdown + PM2/systemd/Task Scheduler, а не watch.

---

## 4. Управление множеством репозиториев (Pavel → много SaaS)

### 4.1 Bootstrap-репо + 3-слойный CLAUDE.md (у нас уже наполовину сделано)
**Что:** над всеми проектами — корневой workspace-репо (только конфиг/контекст, не код). Claude Code идёт вверх по дереву и читает ВСЕ `CLAUDE.md`: репо-уровень → команда-уровень → орг-уровень. Слои: **орг** (`ClaudeCode/CLAUDE.md` — как находить репо, конвенции), **команда** (`SaaS/CLAUDE.md`, `Bots/CLAUDE.md` — общий стек/команды, НЕ перечислять репо, указывать на манифест), **репо** (внутри каждого git-репо, трекается отдельно). Манифест (`manifest.yaml`) — список репо с url/path/tags/desc. `.gitignore` корня: `SaaS/*` + `!SaaS/CLAUDE.md` (трекаем контекст, игнорим вложенные репо).
**Источник:** https://karun.me/blog/2026/03/26/structuring-claude-code-for-multi-repo-workspaces/ , https://code.claude.com/docs/en/workflows
**Как применить у нас:** `C:\Projects\ClaudeCode` УЖЕ это: `.git` в корне, ENVIRONMENT/STRATEGY/SAAS-PLAYBOOK, репо-папки (`personal-assistant-bot`, `dementia-tracker`, `business-sites-bot`, `products/`...). Чего не хватает: (1) корневой `CLAUDE.md` (орг-слой: «это multi-repo workspace, репо — в manifest, не перечислять»); (2) `manifest.yaml` с tags (`bot`/`saas`/`personal`); (3) проверить `.gitignore` корня, чтобы вложенные репо игнорились но их `CLAUDE.md` команда-слоя трекались; (4) сгруппировать по командам (`Bots/`, `SaaS/`) с командным `CLAUDE.md`. Низкое усилие, прямой выигрыш для CC-навигации по растущему числу проектов.

### 4.2 Polyrepo (как сейчас) — правильно для старта; шаблон-репо для переиспользования
**Что:** для соло-разраба с независимыми SaaS-продуктами polyrepo даёт автономию, изолированный CI, простую модель на репо. Монорепо (Turborepo/Nx/pnpm-workspaces) выигрывает при РЕАЛЬНОМ шаринге кода между проектами (общая UI/утилиты, кросс-рефактор). Гибрид: монорепо для shared-либ + UI, polyrepo для самостоятельных сервисов. Переиспользование в polyrepo — через **template-репо** (GitHub template / `degit`), а не копипаст.
**Источник:** https://dev.to/md-afsar/monorepo-vs-polyrepo-which-one-should-you-choose-in-2025-g77 , https://spacelift.io/blog/monorepo-vs-polyrepo
**Как применить у нас:** оставаться на polyrepo (продукты Pavel независимы, своя жизнь/деплой). НО завести **`bot-template`** репо: Grammy + node:sqlite + Gemini-обёртка + graceful shutdown + bot.catch + single-instance lock + dedup update_id (из цикла №1 §3) + `.gitattributes` + `cross-env`/`rimraf` в scripts + dotenvx. Новый бот = `degit bot-template new-bot`, не сборка с нуля. Когда появится реально общий код между ботами (напр. Gemini-клиент, expense-логгер) — вынести в `shared/` и решать монорепо точечно. Не уходить в монорепо преждевременно — это complexity-налог без выгоды пока шаринга нет.

---

## 🔧 К ВНЕДРЕНИЮ (топ-5 по польза/усилия)

1. **[надёжность] Single-instance lock-файл на старте poller'а/polling-ботов.** (низкое усилие, высокая польза) Atomic lock `<root>/.poller.lock` с PID + ретрай 409 (3×/10с) + снятие lock на graceful shutdown. Прямо предотвращает повтор инцидента 409 при двойном запуске. Самое важное — это БЫЛО реальной проблемой.

2. **[bootstrap] dotenvx для секретов вместо ручного таскания .env.** (низкое усилие) `dotenvx encrypt` каждый проектный .env → коммит в репо зашифрованным, один приватный ключ в KeePassXC/флешке. Переезд Win↔Mac = клон + один env-var. Закрывает боль ENVIRONMENT.md, локально-зашифровано без облака.

3. **[multi-repo] Корневой CLAUDE.md + manifest.yaml в C:\Projects\ClaudeCode.** (низкое усилие) Орг-слой контекста + манифест репо с tags + проверка корневого .gitignore (трекать команда-CLAUDE.md, игнорить вложенные репо). Воркспейс уже наполовину готов — дооформить. Окупится с каждым новым SaaS.

4. **[кроссплатформа] bot-template репо + setup.mjs.** (среднее усилие) Один template-репо (Grammy+node:sqlite+Gemini+lock+graceful+bot.catch+dedup, `.gitattributes`, cross-env/rimraf, dotenvx). Новый бот = `degit`. Плюс единый `setup.mjs` (node, не ps1+sh) с `process.platform`-детектом → winget/brew + печать ручного чеклиста. Закрывает 2 TODO из ENVIRONMENT.md.

5. **[кроссплатформа] Абстрагировать хардкод-пути через os.homedir()/env + .gitattributes.** (среднее усилие) Ввести `ROOT`/`PA_ROOT` вместо `C:\Users\...`, `path.join` везде, `__dirname` через `fileURLToPath`, `.gitattributes` (`* text=auto eol=lf`, `*.ps1 eol=crlf`). Без этого код Pavel не заведётся на MacBook. На Node 24 — можно заодно перейти на native `--env-file` локально (минус dotenv-пакет).

---

## Источники
- https://alan.norbauer.com/articles/cross-platform-nodejs/
- https://github.com/bcoe/awesome-cross-platform-nodejs
- https://github.com/zoonderkins/portable-node-guide
- https://nodejs.org/api/sqlite.html
- https://blog.logrocket.com/using-built-in-sqlite-module-node-js/
- https://blog.logrocket.com/node-js-24-features/
- https://github.com/nodejs/node/issues/47990
- https://dotenvx.com/docs/quickstart/encryption
- https://github.com/dotenvx/dotenvx
- https://dotfiles.github.io/bootstrap/
- https://www.chezmoi.io/
- https://github.com/holman/dotfiles/blob/master/script/bootstrap
- https://betterstack.com/community/guides/scaling-nodejs/pm2-guide/
- https://pm2.keymetrics.io/docs/usage/startup/
- https://pm2.keymetrics.io/docs/usage/restart-strategies/
- https://github.com/yagop/node-telegram-bot-api/issues/550
- https://github.com/anthropics/claude-plugins-official/issues/1075
- https://karun.me/blog/2026/03/26/structuring-claude-code-for-multi-repo-workspaces/
- https://code.claude.com/docs/en/workflows
- https://dev.to/md-afsar/monorepo-vs-polyrepo-which-one-should-you-choose-in-2025-g77
- https://spacelift.io/blog/monorepo-vs-polyrepo

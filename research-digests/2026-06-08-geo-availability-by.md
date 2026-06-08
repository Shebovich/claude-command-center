# Гео-доступность ключевых сервисов из Беларуси (прямой BY IP, без VPN)

**Дата:** 2026-06-08
**Для:** Pavel (Беларусь) — маршрутизация трафика ассистента (что можно пускать напрямую мимо VPN, что обязано идти через VPN).
**Метод:** веб-ресёрч + официальные доки сервисов (Google AI regions, GitHub Trade Controls).

---

## TL;DR

| Сервис | Прямой BY IP? | Куда направлять | Критичность |
|---|---|---|---|
| **Gemini API** (generativelanguage.googleapis.com) | ❌ **НЕТ** — Беларусь не в списке поддерживаемых регионов, 403 / "User location is not supported" | **ОБЯЗАТЕЛЬНО через VPN** (западный IP) | КРИТИЧНО |
| **Telegram API** (api.telegram.org) | ✅ Да, работает напрямую | Мимо VPN | высокая |
| **Instagram** (yt-dlp скачивание) | ⚠️ Обычно да, но нестабильно (периодический ISP-троттлинг/блок) | Напрямую, **с VPN-фоллбэком** | средняя |
| **npm registry** (registry.npmjs.org) | ✅ Да | Мимо VPN | средняя |
| **GitHub** (free public) | ✅ Да (для индивидов; ограничены только enterprise/paid-продажи) | Мимо VPN | средняя |

**Итог:** мимо VPN безопасно увести тяжёлый трафик — npm, GitHub, скачивания (Instagram/yt-dlp с фоллбэком). **Под VPN обязан остаться только Gemini API** — но он лёгкий (мало трафика), так что лимит VPN почти не тратит.

---

## 1. Gemini API / Google AI Studio — ГЛАВНОЕ

**Вердикт: из Беларуси напрямую НЕ РАБОТАЕТ. Нужен западный IP через VPN.**

- Официальная страница доступных регионов Google AI Studio / Gemini API **не содержит Беларусь** в списке поддерживаемых стран и территорий. Россия также отсутствует. (Источник: ai.google.dev/gemini-api/docs/available-regions)
- При вызове с белорусского IP API возвращает ошибку **`400 / FAILED_PRECONDITION — "User location is not supported for the API use"`**. Это подтверждается множеством репортов на форумах Google AI Developers и в issue-трекерах (LibreChat #6463, deprecated-generative-ai-python #587 и др.).
- Проверка идёт по **геолокации IP запроса**, не по стране ключа/биллинга. Поэтому белорусский IP блокируется даже с валидным ключом. Решение, которое подтверждают пользователи: сменить узел VPN на поддерживаемый регион (US/EU).

**Действие:** все вызовы Gemini (бот, анализ рилсов, лид-фильтр) **ОБЯЗАНЫ идти через VPN-туннель** с западным exit-IP. Хорошая новость — это API-вызовы (JSON), трафика мало, VPN-лимит почти не расходуется. Если Gemini пойдёт мимо VPN — всё встанет (403).

> Примечание: для регионов вне списка Google предлагает Gemini через Vertex AI / Enterprise Agent Platform (Google Cloud), но это отдельный сетап с биллингом GCP и тоже гео-чувствителен. Проще держать generativelanguage.googleapis.com под VPN.

---

## 2. Telegram API (api.telegram.org)

**Вердикт: работает напрямую с белорусского IP. Мимо VPN.**

- В отличие от России (где Telegram блокируется Роскомнадзором с начала 2026), Беларусь Telegram **не блокирует** на постоянной основе. В феврале 2026 пресс-служба официально опровергла слухи о планах блокировки мессенджеров.
- Был эпизодический троттлинг в дни выборов (ночь 10 января 2025: временно недоступны YouTube/TikTok/Telegram/Discord без VPN), и ограничения 2025–2026 касаются **коммерции** (запрет продаж через Telegram/Instagram без регистрации), а не самого протокола/API.
- Bot API и GramJS userbot работают по api.telegram.org напрямую в обычном режиме.

**Действие:** пускать мимо VPN. Держать VPN-фоллбэк на случай электоральных «учений» (редко).

---

## 3. Instagram (yt-dlp скачивание рилсов)

**Вердикт: обычно работает напрямую, но нестабильно. Напрямую с VPN-фоллбэком.**

- Instagram сам Беларусь не блокирует со своей стороны; ограничения идут **со стороны белорусских ISP/ОАЦ** и носят периодический характер (тестовые блокировки соцсетей вокруг выборов, план поэтапного троттлинга Instagram/YouTube/WhatsApp). На практике в спокойные периоды доступ есть.
- yt-dlp по сети идёт к CDN Instagram/Meta; основная нестабильность не гео-блок, а сам Instagram (анти-бот, rate-limit, требование логина) — это решается не VPN, а куками/таймингом.

**Действие:** пускать напрямую (тяжёлый трафик — экономим VPN). Реализовать **авто-фоллбэк на VPN**, если прямой запрос ловит блок/таймаут со стороны ISP.

---

## 4. npm registry (registry.npmjs.org)

**Вердикт: работает напрямую. Мимо VPN.**

- npm registry — публичный CDN, гео-блока по Беларуси нет. Санкционные истории вокруг npm — это отдельные пакеты-«санкционные баннеры» (например `@russia-sanctions/*`), которые сами авторы вставляют в свой код; на доступность реестра в целом это не влияет.

**Действие:** мимо VPN — это самый «тяжёлый» гео-независимый трафик, ему в туннеле делать нечего.

---

## 5. GitHub (clone, raw, API, releases)

**Вердикт: free public-доступ работает напрямую. Мимо VPN.**

- GitHub Trade Controls ограничивают только **продажу/экспорт платных продуктов** (GitHub Enterprise Server, Copilot) в страны Country Group E:1 (включая Беларусь). Это про корпоративные продажи и SDN-сущности, **не про бесплатный публичный доступ индивидов**.
- Клонирование публичных репо, raw-файлы, releases, публичный API — для рядового пользователя из Беларуси доступны напрямую. (Беларусь даже не попала в FAQ-секцию «что недоступно» — в отличие от КНДР/Крыма, где описаны явные ограничения публичного доступа.)

**Действие:** мимо VPN. (Если конкретный приватный аккаунт окажется flagged как SDN — это про сущность, не про IP; маршрутизацией не лечится.)

---

## Рекомендация по маршрутизации трафика ассистента

**Через VPN (западный exit-IP) — ОБЯЗАТЕЛЬНО:**
- Gemini API → generativelanguage.googleapis.com (иначе 403; трафика мало, лимит не жрёт)
- Любые другие Google AI / Vertex endpoints, если появятся

**Напрямую (мимо VPN, экономим лимит):**
- npm registry (registry.npmjs.org) — тяжёлый, гео-независимый
- GitHub (clone/raw/releases/API) — гео-независимый
- Instagram / yt-dlp скачивания — тяжёлый; **с авто-фоллбэком на VPN** при ISP-блоке
- Telegram API (api.telegram.org) — гео-независимый; **с VPN-фоллбэком** на дни электоральных учений

**Практический сплит:** split-tunnel правило — в VPN загнать только хост(ы) `*.googleapis.com` (как минимум `generativelanguage.googleapis.com`), всё остальное направить напрямую. Это даёт максимальную экономию VPN-трафика при сохранении работоспособности гео-чувствительного Gemini.

---

## Источники

- [Available regions for Google AI Studio and Gemini API — Google AI for Developers](https://ai.google.dev/gemini-api/docs/available-regions) — Беларусь и Россия отсутствуют в списке.
- [GoogleGenerativeAI Error: "User location is not supported for the API use" — Google AI Developers Forum](https://discuss.ai.google.dev/t/googlegenerativeai-error-error-fetching-from-https-generativelanguage-googleapis-com-v1beta-models-gemini-2-5-flash-400-bad-request-user-location-is-not-supported-for-the-api-use/123130)
- [User location is not supported — LibreChat Issue #6463](https://github.com/danny-avila/LibreChat/issues/6463)
- [Google AI Studio Not Supported in Your Region? — IPFoxy](https://www.ipfoxy.com/blog/ideas-inspiration/5488)
- [Censorship of Telegram — Wikipedia](https://en.wikipedia.org/wiki/Censorship_of_Telegram)
- [Why Lukashenko Isn't Blocking Telegram — topwar](https://en.topwar.ru/279897-pochemu-aleksandr-lukashenko-ne-blokiruet-telegram-paradoks-belorusskoj-cifrovoj-politiki.html)
- [Belarus: Freedom on the Net 2025 — Freedom House](https://freedomhouse.org/country/belarus/freedom-net/2025)
- [Belarus Prepares to Block Social Media Ahead of 2025 Elections — Odessa Journal](https://odessa-journal.com/foreign-intelligence-service-the-lukashenko-regime-is-actively-preparing-to-disconnect-social-media-during-the-elections)
- [GitHub and Trade Controls — GitHub Docs](https://docs.github.com/en/site-policy/other-site-policies/github-and-trade-controls)

# VPN split tunneling + ротация для фоновых задач ассистента

**Дата:** 2026-06-08
**Окружение Pavel:** Windows 10 Pro, Node 24, PowerShell 5.1, TunnelBear (Wintun/PolarBear = их WireGuard-движок), также установлен OpenVPN Connect.
**Проблема:** весь системный трафик идёт через TunnelBear, включая фоновые node-процессы ассистента (yt-dlp, npm install, fetch-ресёрчи, Gemini/GramJS). Жрёт ограниченный VPN-лимит (~2–11 ГБ на аккаунт, ~11 ГБ суммарно по нескольким аккаунтам).

Две задачи: (1) вывести трафик ассистента МИМО VPN; (2) ротировать аккаунты по исчерпанию трафика.

---

## ЗАДАЧА 1 — Split tunneling: трафик ассистента в обход VPN

### Вариант A — SplitBear (родной split tunnel TunnelBear). Условно работает, НО есть подвох.

SplitBear существует и **на Windows поддерживает исключение и приложений, и сайтов** (на мобильных — урезано). Исключённое приложение перестаёт идти через туннель и ходит **напрямую через обычное (физическое) соединение, без шифрования TunnelBear** — ровно то, что нужно для node-трафика.

Настройка: десктоп-приложение TunnelBear → сайдбар → **SplitBear** → добавить приложение (`node.exe`) или сайт в список исключений. Отключаться от VPN не нужно.

**КРИТИЧНЫЙ подвох:** SplitBear — **только платная фича**. В 2026 TunnelBear перекроил бесплатную модель: free-юзеры **потеряли SplitBear и выбор сервера**. Если аккаунты Pavel бесплатные (а судя по лимитам 2–11 ГБ — это free-tier раздачи), SplitBear на них **недоступен**.

Ещё нюанс: SplitBear исключает по имени процесса. Дочерние процессы node (yt-dlp.exe, curl.exe, отдельный powershell.exe для сетевых операций) — это **другие** exe, их тоже надо добавлять в список поимённо. node спавнит детей часто → список придётся поддерживать. Сам `node.exe` покрывает только то, что ходит из самого Node (fetch, GramJS, API-вызовы).

**Надёжность:** высокая (это родной драйверный split на уровне WFP), НО только если фича вообще доступна на аккаунте Pavel. Для free-tier — **не вариант**.

### Вариант B — ForceBindIP (привязка произвольного exe к физическому интерфейсу). Работает, но хрупко для node.

[ForceBindIP](https://r1ch.net/projects/forcebindip) — бесплатная утилита: запускает целевой exe в suspended, инжектит DLL, перехватывает `bind()/connect()/sendto()/WSAConnect()/WSASendTo()` и принудительно биндит сокеты к указанному IP/интерфейсу.

```powershell
# Запуск node, привязанного к IP физического Ethernet (напр. 192.168.1.50):
& "C:\Program Files (x86)\ForceBindIP\ForceBindIP.exe" 192.168.1.50 "C:\Program Files\nodejs\node.exe" script.mjs
# Если IP физ-адаптера динамический — можно указать GUID интерфейса вместо IP
# (GUID: HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\)
```

**Проблемы для нашего кейса:**
- **DNS течёт в VPN.** Резолв имён делает системный DNS Client (svchost), а не node → DNS-запросы всё равно уходят через дефолтный шлюз/туннель. Сам payload пойдёт мимо, но lookup'ы — нет (мелкий трафик, но «чисто мимо VPN» не гарантирует).
- **Дочерние процессы НЕ наследуют привязку автоматически.** Если node спавнит yt-dlp.exe/curl.exe — их надо запускать тоже через ForceBindIP. То есть в коде ассистента вместо `spawn('yt-dlp', ...)` придётся `spawn('ForceBindIP.exe', ['<ip>','yt-dlp.exe', ...])`. Это правка кода спавнеров.
- Программы на нестандартных стэках (не winsock) могут проигнорировать привязку.

**Надёжность:** средняя. Рабочее, бесплатное, без платной подписки — но требует обернуть ВСЕ сетевые спавны ассистента и мириться с DNS-утечкой.

### Вариант C — ProxiFyre (per-app SOCKS5 проксификатор). Мощно, но избыточно.

[ProxiFyre](https://github.com/wiresock/proxifyre) (на базе Windows Packet Filter / NDISAPI) — заворачивает TCP+UDP конкретных процессов в SOCKS5. Поддерживает список процессов, исключения, LAN-bypass, работу как Windows-сервис. Но: нужен **сам SOCKS5-прокси** на выход (которого у нас нет — выход-то и должен быть «прямой Ethernet», а не прокси). Имеет смысл только если бы заворачивали в отдельный туннель, а не «мимо». Для задачи «просто мимо VPN» — оверкилл.

### Вариант D — Маршруты `route add` по IP-назначениям. Не подходит.

Можно добавить статические маршруты к конкретным IP мимо туннеля (с метрикой/через шлюз физ-адаптера). Но **назначения динамические** (yt-dlp ходит на CDN ютуба/инсты, ресёрчи — на сотни хостов, Gemini/Telegram API). Поддерживать список IP нереально. **Отбрасываем.**

### Вывод по Задаче 1

- Если аккаунт **платный** → самый чистый путь: **SplitBear**, добавить `node.exe` + `yt-dlp.exe` + `curl.exe` в исключения. Драйверный, надёжный, без правок кода.
- Если аккаунт **free** (вероятно) → SplitBear недоступен. Тогда **ForceBindIP** — рабочий бесплатный способ (команда выше), ценой обёртки сетевых спавнов и DNS-утечки.
- **Но обе опции — костыли поверх неудобного для скриптинга TunnelBear.** Радикально чище — см. итоговую рекомендацию: держать TunnelBear для браузера Pavel, а фоновые задачи гнать через **отдельный скриптуемый VPN** (или вообще без VPN, если приватность фоновых API-вызовов не критична — тогда split не нужен вовсе, физ-Ethernet по умолчанию). Split становится нужен ТОЛЬКО потому, что TunnelBear захватывает дефолтный маршрут целиком.

---

## ЗАДАЧА 2 — Ротация VPN-аккаунтов по исчерпанию трафика

### TunnelBear для скриптинга — плохо, но не безнадёжно

- **Нет официального API / CLI.** Подключение — только из GUI-приложения или браузерного расширения. Программно логиниться/менять аккаунт через GUI — хрупкая GUI-автоматизация (поиск окон, клики), ломается на каждом обновлении приложения. **Не рекомендую.**
- **Спасение: TunnelBear умеет OpenVPN с конфигами.** Поддерживает WireGuard / OpenVPN / IKEv2. Есть документированный путь подключиться **через openvpn CLI**, минуя их GUI ([гайд](https://dev.to/riayi/openvpn-configuration-for-tunnelbear-8o1)):
  1. Скачать TunnelBear `openvpn.zip` (.ovpn по странам) + `PrivateKey.key.zip`.
  2. В .ovpn: убрать строку `keysize`, добавить `key PrivateKey.key`, заменить `auth-user-pass` → `auth-user-pass tb-auth.key`.
  3. Создать `tb-auth.key`: строка 1 — email аккаунта, строка 2 — пароль.
  4. `openvpn --config tunnelbear.ovpn` (или OpenVPN Connect, который у Pavel уже стоит).

  **Это и есть ключ к скриптуемой ротации на TunnelBear:** у каждого аккаунта свой `tb-auth.key` (email+пароль). Ротация = подменить auth-файл и перезапустить openvpn-процесс. Один и тот же .ovpn, N разных auth-файлов. Гораздо надёжнее GUI-автоматизации.

### Детект «трафик кончился»

Два сигнала:
1. **Счётчик переданных байт** через `Get-NetAdapterStatistics` по VPN-адаптеру (Wintun у TunnelBear / TAP у OpenVPN). Считаем дельту `ReceivedBytes+SentBytes` от старта аккаунта; при достижении лимита аккаунта — ротация. Минус: лимит TunnelBear считает на своей стороне по календарю, локальный счётчик может разойтись → ставить порог с запасом (напр. 90% номинала).
2. **Ошибка соединения / резкое падение пропускной** — когда лимит исчерпан, TunnelBear рвёт/режет коннект. Детект: провал health-check (`Test-Connection`/`Invoke-WebRequest` через туннель упал) → ротация. Надёжнее как fallback к счётчику.

Лучший вариант — **комбо:** основной триггер — байтовый счётчик, страховка — health-check.

### Каркас скрипта-ротатора (PowerShell, под OpenVPN-конфиги)

```powershell
# rotate-vpn.ps1 — ротация VPN-аккаунтов для фоновых задач ассистента
# Список аккаунтов: один .ovpn, разные auth-файлы (email+pass), у каждого квота в байтах.
$Accounts = @(
  @{ Name='tb1'; Auth='C:\vpn\tb1-auth.key'; Quota=2GB  },
  @{ Name='tb2'; Auth='C:\vpn\tb2-auth.key'; Quota=11GB },
  @{ Name='tb3'; Auth='C:\vpn\tb3-auth.key'; Quota=5GB  }
)
$Ovpn        = 'C:\vpn\tunnelbear.ovpn'
$OpenVpnExe  = 'C:\Program Files\OpenVPN\bin\openvpn.exe'
$AdapterName = 'OpenVPN TAP-Windows6'   # имя адаптера из Get-NetAdapter
$StatePath   = 'C:\vpn\rotation-state.json'

function Get-VpnBytes {
  $s = Get-NetAdapterStatistics -Name $AdapterName -ErrorAction SilentlyContinue
  if ($s) { return [int64]($s.ReceivedBytes + $s.SentBytes) } else { return 0 }
}

function Connect-Account($acct) {
  Get-Process openvpn -ErrorAction SilentlyContinue | Stop-Process -Force
  # подменяем auth-файл, на который ссылается .ovpn (auth-user-pass tb-auth.key)
  Copy-Item $acct.Auth 'C:\vpn\tb-auth.key' -Force
  Start-Process -FilePath $OpenVpnExe -ArgumentList "--config `"$Ovpn`"" -WindowStyle Hidden
  Start-Sleep -Seconds 8
  $ok = Test-Connection 1.1.1.1 -Count 2 -Quiet
  return $ok
}

function Test-Quota($acct, $baselineBytes) {
  $used = (Get-VpnBytes) - $baselineBytes
  return ($used -lt $acct.Quota)
}

# --- main ---
$state = if (Test-Path $StatePath) { Get-Content $StatePath -Raw | ConvertFrom-Json }
         else { @{ index=0; baseline=0 } }
$idx = [int]$state.index

# health-check текущего соединения (страховка к счётчику)
$alive = Test-Connection 1.1.1.1 -Count 2 -Quiet
$withinQuota = Test-Quota $Accounts[$idx] ([int64]$state.baseline)

if (-not $alive -or -not $withinQuota) {
  do {
    $idx = ($idx + 1) % $Accounts.Count
    $acct = $Accounts[$idx]
    Write-Host "Rotating to $($acct.Name)"
    $connected = Connect-Account $acct
  } while (-not $connected)   # перебор до первого живого аккаунта
  $state = @{ index=$idx; baseline=(Get-VpnBytes) }   # сбрасываем baseline на новом аккаунте
  $state | ConvertTo-Json | Set-Content $StatePath
}
```

Запускать по таймеру (планировщик Windows каждые N минут) ИЛИ дёргать из кода ассистента перед тяжёлой сетевой операцией. baseline сохраняется в state-файл, чтобы счётчик аккаунта переживал перезапуски. (Замечание: `Get-NetAdapterStatistics` обнуляется при пересоздании адаптера — поэтому держим baseline и пишем накопленное.)

### Альтернативные VPN с CLI и щедрым/бесплатным трафиком (под скриптуемую ротацию)

| VPN | CLI на Windows | Free-трафик | Скриптуемость ротации | Вердикт |
|-----|----------------|-------------|------------------------|---------|
| **Windscribe** | **Да, нативный `windscribe-cli`** (connect/disconnect/switch/status). Есть даже официальный «skill» для агентов. | **10 ГБ/мес** бесплатно (или unlimited за email) | Отличная: всё через shell, не нужна GUI-автоматизация | **Лучший выбор.** Один аккаунт ≈ покрывает весь суммарный лимит TunnelBear, без ротации вообще |
| **ProtonVPN** | Официального Win-CLI нет; но есть **WireGuard-конфиги** + сторонний confgen, переключение через `wireguard.exe /installtunnelservice` | Free-tier безлимитный по трафику, но мало серверов | Хорошая через WireGuard-конфиги | Хорошая запаска |
| **WireGuard (любой провайдер)** | `wireguard.exe /installtunnelservice <conf>` / `/uninstalltunnelservice <name>` (нужен admin) | зависит | Тривиально скриптуется (см. ниже) | База для ротации конфигов |
| **TunnelBear** | Нет CLI/API; только OpenVPN-конфиги вручную | 2 ГБ/мес (free) | Плохая (GUI) / средняя (через openvpn+auth-файлы) | Оставить для браузера Pavel |

Переключение WireGuard-туннелей из PowerShell (admin):
```powershell
& "C:\Program Files\WireGuard\wireguard.exe" /uninstalltunnelservice old_tunnel
& "C:\Program Files\WireGuard\wireguard.exe" /installtunnelservice "C:\vpn\new_tunnel.conf"
```

---

## ИТОГОВАЯ ПРАГМАТИЧНАЯ РЕКОМЕНДАЦИЯ

**Главный инсайт Pavel прав:** split tunneling важнее ротации. Если трафик ассистента вообще не идёт через VPN — лимиты аккаунтов почти перестают гореть, и ротация TunnelBear становится некритичной.

**Оптимальный путь (минимум боли):**

1. **Развести два контура.** TunnelBear оставить для браузера/работы Pavel (как есть). Фоновые задачи ассистента — на **отдельный скриптуемый VPN или напрямую**.

2. **Заменить TunnelBear для фона на Windscribe.** У него **нативный `windscribe-cli`** (connect/status/switch — без GUI-автоматизации) и **10 ГБ/мес бесплатно** — это больше, чем суммарный лимит, который Pavel сейчас собирает с нескольких TunnelBear-аккаунтов. Один аккаунт Windscribe ≈ снимает И задачу 1, И задачу 2: фоновый трафик уходит в свой туннель/прямой канал управляемо из скрипта, а ротация по сути не нужна (хватает квоты).

3. **Если приватность фоновых API-вызовов НЕ критична** (yt-dlp, npm, Gemini, Telegram — обычно не критична): самый простой путь — гнать фон **напрямую через физический Ethernet вообще без VPN**, а split реализовать через **ForceBindIP** для `node.exe` и его сетевых детей (команда в Задаче 1, вариант B). Ноль подписок, ноль ротации. Минус — DNS-утечка и обёртка спавнов.

4. **Если Pavel хочет остаться на TunnelBear:** единственный надёжно-скриптуемый путь — **OpenVPN-конфиги TunnelBear с per-account auth-файлами** (Задача 2) + ротатор на счётчике `Get-NetAdapterStatistics` (каркас выше). GUI-автоматизацию TunnelBear — **не делать**, хрупко.

**Короткий приоритет:**
**A.** Поставить Windscribe, увести фон ассистента в его CLI-туннель → закрывает обе задачи разом, ротация почти не нужна.
**B.** (если без новых VPN) ForceBindIP на node.exe + фон напрямую мимо TunnelBear.
**C.** (если только TunnelBear) openvpn + auth-файлы + скрипт-ротатор на байтовом счётчике.

---

## Источники

- [SplitBear — TunnelBear Help](https://help.tunnelbear.com/hc/en-us/articles/360007244451-SplitBear-Complete-control-over-your-network-traffic)
- [TunnelBear free model change (SplitBear → paid only) — TechRadar](https://www.techradar.com/vpn/vpn-services/tunnelbear-reshapes-its-free-vpn-model-amid-rising-infrastructure-costs)
- [ForceBindIP — r1ch.net](https://r1ch.net/projects/forcebindip)
- [ProxiFyre — GitHub](https://github.com/wiresock/proxifyre)
- [TunnelBear VPN Protocol (OpenVPN/WireGuard/IKEv2) — Help](https://help.tunnelbear.com/hc/en-us/articles/5907031724443-VPN-Protocol-Choosing-how-you-connect-to-TunnelBear)
- [TunnelBear OpenVPN CLI config — dev.to](https://dev.to/riayi/openvpn-configuration-for-tunnelbear-8o1)
- [Windscribe CLI / agent skill — Windscribe](https://github.com/Windscribe/Desktop-App/blob/master/skills/windscribe-cli/SKILL.md)
- [Windscribe CLI navigation — Windscribe KB](https://windscribe.com/knowledge-base/articles/how-do-i-navigate-the-cli-(v1.4)-app)
- [ProtonVPN WireGuard configs — Proton](https://protonvpn.com/support/wireguard-configurations)
- [protonvpn-wg-confgen — GitHub](https://github.com/hatemosphere/protonvpn-wg-confgen)
- [WireGuard Windows CLI (installtunnelservice)](https://github.com/WireGuard/wireguard-windows/blob/master/docs/enterprise.md)
- [Get-NetAdapterStatistics — Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/netadapter/get-netadapterstatistics)
- [Windows VPN routing decisions / interface metrics — Microsoft Learn](https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/vpn/vpn-routing)

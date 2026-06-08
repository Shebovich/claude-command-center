# Setup окружения Pavel на новой Windows-машине.
# Запуск: ./setup.ps1   (нужны git + gh + node, см. DEPLOY.md шаг 1)
# ASCII-only (PS5.1 совместимость).

$ErrorActionPreference = 'Stop'
$ghUser = 'Shebovich'
$repos  = @('personal-assistant-cc', 'claude-command-center', 'dental-ai-admin', 'lead-monitor')
$root   = "$env:USERPROFILE\Projects\ClaudeCode"

Write-Host "== Setup okruzheniya =="

# 1) Инструменты через winget (бесплатные, не падаем если уже стоит)
$tools = @('yt-dlp.yt-dlp', 'Gyan.FFmpeg', 'Ollama.Ollama')
foreach ($t in $tools) {
  Write-Host "winget: $t"
  try { winget install --id $t -e --accept-source-agreements --accept-package-agreements --disable-interactivity 2>$null | Out-Null } catch {}
}

# 2) Клонируем репозитории
New-Item -ItemType Directory -Force -Path $root | Out-Null
foreach ($r in $repos) {
  $dest = Join-Path $root $r
  if (Test-Path $dest) { Write-Host "$r: uzhe est, skip" }
  else { Write-Host "clone $r"; gh repo clone "$ghUser/$r" $dest }
}

# 3) npm install в Node-проектах
$nodeProjects = @("$root\dental-ai-admin", "$root\lead-monitor", "$root\personal-assistant-cc")
foreach ($p in $nodeProjects) {
  if (Test-Path "$p\package.json") { Write-Host "npm install: $p"; Push-Location $p; npm install --silent; Pop-Location }
}

Write-Host ""
Write-Host "== Gotovo. Ruchnye shagi (sm. DEPLOY.md): =="
Write-Host " 1. Razlozhit secrets (.env po proektam + data/profile.json) - ih net v git."
Write-Host " 2. TunnelBear SplitBear: dobavit yt-dlp.exe, curl.exe (x2), git.exe (NE node.exe)."
Write-Host " 3. /start-personal-session dlya podnyatiya assistenta."

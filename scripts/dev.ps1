# Jalankan Sirko (debug) di HP lewat ADB Wi-Fi — Windows (PowerShell 5+/7).
# Pasangan macOS/Linux: scripts/dev.sh. Panduan lengkap: SETUP.md.
#
#   .\scripts\dev.ps1 [-Connect IP:PORT] [-Api URL] [-BuildOnly] [-Extra @('--verbose')]
#
# Prioritas URL backend: -Api > env SIRKO_API_BASE > env\local.json
#                        > otomatis http://<IP-LAN-mesin-ini>:$env:SIRKO_API_PORT (default 47321)
# Prioritas Flutter:     env FLUTTER_BIN > env\local.json "FLUTTER_BIN" > `flutter` di PATH
param(
  [string]$Connect = "",
  [string]$Api = $env:SIRKO_API_BASE,
  [switch]$BuildOnly,
  [string[]]$Extra = @()
)
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$local = @{}
if (Test-Path "env\local.json") {
  (Get-Content "env\local.json" -Raw | ConvertFrom-Json).PSObject.Properties |
    ForEach-Object { $local[$_.Name] = $_.Value }
}

$flutter = if ($env:FLUTTER_BIN) { $env:FLUTTER_BIN } elseif ($local.FLUTTER_BIN) { $local.FLUTTER_BIN } else { "flutter" }
if (-not (Get-Command $flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter tak ditemukan ($flutter). Set FLUTTER_BIN di env\local.json."
}

# 1) Kunci versi Flutter — beda versi = pubspec.lock berubah = bentrok antar mesin.
$want = (Get-Content ".flutter-version" -Raw).Trim()
$have = ((& $flutter --version 2>$null) | Select-String '^Flutter ([0-9.]+)').Matches[0].Groups[1].Value
if ($have -ne $want) { throw "Flutter $have, proyek mengunci $want (.flutter-version). Lihat SETUP.md." }

# 2) URL backend
if (-not $Api) { $Api = $local.SIRKO_API_BASE }
if (-not $Api) {
  $ip = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.PrefixOrigin -in 'Dhcp','Manual' -and $_.IPAddress -notlike '169.254*' -and $_.InterfaceAlias -notmatch 'vEthernet|WSL|Loopback|VirtualBox|VMware' } |
    Select-Object -First 1).IPAddress
  if (-not $ip) { throw "IP LAN tak terdeteksi; pakai -Api URL." }
  $port = if ($env:SIRKO_API_PORT) { $env:SIRKO_API_PORT } else { "47321" }
  $Api = "http://${ip}:$port"
}
Write-Host "-> Flutter $have - backend $Api"

# 3) Debug build saja (APK di build\app\outputs\flutter-apk\app-debug.apk)
if ($BuildOnly) {
  & $flutter build apk --debug --target-platform android-arm64 "--dart-define=SIRKO_API_BASE=$Api" @Extra
  exit $LASTEXITCODE
}

# 4) Sambungkan HP (ADB Wi-Fi) bila diminta, lalu jalankan dengan hot reload.
$adb = if (Get-Command adb -ErrorAction SilentlyContinue) { "adb" } else {
  $sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA "Android\Sdk" }
  Join-Path $sdk "platform-tools\adb.exe"
}
$deviceArgs = @()
if ($Connect) { & $adb connect $Connect; $deviceArgs = @("-d", $Connect) }
& $flutter run --debug @deviceArgs "--dart-define=SIRKO_API_BASE=$Api" @Extra
exit $LASTEXITCODE

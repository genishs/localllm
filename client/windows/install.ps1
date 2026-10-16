# install.ps1 - localllm client installer for Windows
# Installs the opencode coding agent and connects it to a llama.cpp router server (Strix Halo LLM server).
#
#   One line (PowerShell):
#     irm https://raw.githubusercontent.com/genishs/localllm/main/client/windows/install.ps1 | iex
#   Or save it and run:
#     powershell -ExecutionPolicy Bypass -File install.ps1
#
# Steps (safe to re-run):
#   1 server address   2 API key + connection test   3 opencode v1.18.35 (pinned, sha256-verified)
#   4 opencode config  5 work folder + desktop launcher   6 usage summary / start
#
# Third-party software: opencode (https://github.com/anomalyco/opencode) is MIT-licensed software
# by its authors. This script downloads the official release binary from GitHub and verifies its
# sha256; this repository does not redistribute it.
# License: https://github.com/anomalyco/opencode/blob/dev/LICENSE  (see also THIRD_PARTY_NOTICES.md)
#
# ASCII only on purpose: Windows PowerShell 5.1 reads a file without BOM as ANSI.
# The whole body is inside & { ... } so that "irm URL | iex" works and nothing leaks into your session.
& {
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # the progress bar makes Invoke-WebRequest very slow in PS 5.1
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

$Ver = "v1.18.35"
$Sha = @{
  "opencode-windows-x64.zip"          = "c90d248cca75e42fd15422a29b5f83a1b30c441af83565635d6b2682adc58dd1"
  "opencode-windows-x64-baseline.zip" = "f7de76f445360f5621114753ddf7543b6e057413e806d3fd34e416846155fa33"
}
$DefaultPort = 8080

# friendly names for known model ids (from the server presets); unknown ids are shown as-is
$Known = @{
  cn   = "Qwen3-Coder-Next 80B-A3B | Q4_K_M"
  q36  = "Qwen3.6-35B-A3B | UD-Q6_K + MTP"
  orn  = "Ornith-1.5-35B-A3B | Q6_K + MTP"
  mg   = "Muse Glimmer 30B | Q4_K_XL + DFlash"
  fn   = "Qwen3.8-Flash-Next Coder (pruned) | IQ1_M"
  bolt = "Nemotron 3.5 Bolt 74B-A9B | 2-bit QAT + DFlash"
  lfm  = "LFM2.5-24B-A2B | Q8_0"
  mcv  = "MiniCPM-V 4.7 35B-A3B | Q6_K + DSpark"
  mel  = "Mellum2.1-12B-A2.5B Thinking | Q8_0"
}

function Ok($m)   { Write-Host "   OK  $m" -ForegroundColor Green }
function Bad($m)  { Write-Host "   XX  $m" -ForegroundColor Red }
function Info($m) { Write-Host "       $m" -ForegroundColor Yellow }
function Step($m) { Write-Host ""; Write-Host "== $m" -ForegroundColor Cyan }

function Get-UserVar([string]$n)     { [Environment]::GetEnvironmentVariable($n, "User") }
function Set-UserVar([string]$n, $v) { [Environment]::SetEnvironmentVariable($n, $v, "User") }
# user env (persists) + this session (so a program started from this window sees it right away)
function Set-EnvVar([string]$n, $v)  { Set-UserVar $n $v; [Environment]::SetEnvironmentVariable($n, $v, "Process") }

# "192.168.0.10" -> http://192.168.0.10:8080 ; "host:9000" -> http://host:9000 ; "http://x:8080/v1" -> http://x:8080
function ConvertTo-ServerUrl([string]$s) {
  if (-not $s) { return $null }
  $s = $s.Trim().TrimEnd("/")
  if ($s -match "/v1$") { $s = $s.Substring(0, $s.Length - 3).TrimEnd("/") }
  if (-not $s) { return $null }
  if ($s -notmatch "^[A-Za-z][A-Za-z0-9+.-]*://") {
    if ($s -match ":\d+$") { $s = "http://$s" } else { $s = "http://${s}:$DefaultPort" }
  }
  $u = $null
  if (-not [Uri]::TryCreate($s, [UriKind]::Absolute, [ref]$u)) { return $null }
  if ($u.Scheme -ne "http" -and $u.Scheme -ne "https") { return $null }
  if (-not $u.Host) { return $null }
  if ($u.Host -match "^\d+(\.\d+){3}$") {
    $ip = $null
    if (-not [Net.IPAddress]::TryParse($u.Host, [ref]$ip)) { return $null }
  }
  return $u.GetLeftPart([UriPartial]::Authority)
}

function Read-Plain([string]$prompt) {
  $ss = Read-Host $prompt -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Ask-YesNo([string]$q, [bool]$default) {
  $hint = "y/N"; if ($default) { $hint = "Y/n" }
  $a = Read-Host "$q ($hint)"
  if (-not $a) { return $default }
  return [bool]($a.Trim() -match "^[yY]")
}

function Test-Tcp([string]$h, [int]$port, [int]$ms) {
  $c = New-Object Net.Sockets.TcpClient
  try { return [bool]($c.ConnectAsync($h, $port).Wait($ms) -and $c.Connected) }
  catch { return $false }
  finally { $c.Close() }
}

# this PC's address as seen from the server (the address the server firewall must allow)
function Get-LocalIp([string]$hostName) {
  $target = $null
  try {
    $a = [Net.Dns]::GetHostAddresses($hostName) | Where-Object { $_.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork } | Select-Object -First 1
    if ($a) { $target = $a.ToString() }
  } catch {}
  if (-not $target) { return $null }
  try {
    $ip = (Find-NetRoute -RemoteIPAddress $target -ErrorAction Stop | Where-Object { $_.IPAddress } | Select-Object -First 1).IPAddress
    if ($ip) { return [string]$ip }
  } catch {}
  try {   # fallback: ask the OS which local address it would use (a UDP "connect" sends no packet)
    $u = New-Object Net.Sockets.UdpClient
    try { $u.Connect($target, 9); return $u.Client.LocalEndPoint.Address.ToString() } finally { $u.Close() }
  } catch {}
  return $null
}

# GET /v1/models. Status 0 = no HTTP answer at all (cannot connect / timeout).
function Get-ModelIds([string]$url, [string]$key) {
  try {
    $r = Invoke-RestMethod -Uri "$url/v1/models" -Headers @{ Authorization = "Bearer $key" } -TimeoutSec 15
    $ids = @($r.data | ForEach-Object { $_.id } | Where-Object { $_ })
    return @{ Ok = $true; Ids = $ids; Status = 200; Message = "" }
  } catch {
    $code = 0
    try { if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode } } catch {}
    return @{ Ok = $false; Ids = @(); Status = $code; Message = $_.Exception.Message }
  }
}

function Find-OpencodeExe([string]$dir) {
  Get-ChildItem $dir -Recurse -Filter opencode.exe -ErrorAction SilentlyContinue | Select-Object -First 1
}

function Get-OpencodeVersion($exe) {
  if (-not $exe) { return $null }
  try { $v = & $exe.FullName --version 2>$null; if ($v) { return ([string]($v | Select-Object -First 1)).Trim() } } catch {}
  return $null
}

# turn a literal profile path into %VAR% form so the .bat stays ASCII even with a non-ASCII user name
function ConvertTo-BatPath([string]$p) {
  foreach ($pair in @(@("LOCALAPPDATA", $env:LOCALAPPDATA), @("USERPROFILE", $env:USERPROFILE))) {
    $base = $pair[1]
    if ($base -and $p.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) { return ("%" + $pair[0] + "%" + $p.Substring($base.Length)) }
  }
  return $p
}

try {

# ---------------------------------------------------------------- 1/6 server address
Step "1/6 Server address"
Info "Enter the address (IP) of your Strix Halo LLM server."
Info "On the server run  ~/llm-router.sh status  (or  hostname -I )  to see it, e.g. 192.168.0.10"
$saved = ConvertTo-ServerUrl (Get-UserVar "LLM_URL")
$url = $null
for ($i = 1; $i -le 10 -and -not $url; $i++) {
  if ($saved) { $answer = Read-Host "   Server address [$saved]" } else { $answer = Read-Host "   Server address" }
  if (-not $answer -or -not $answer.Trim()) {
    if ($saved) { $url = $saved } else { Bad "The server address is required." }
    continue
  }
  $url = ConvertTo-ServerUrl $answer
  if (-not $url) { Bad "Not a valid address: $answer   (examples: 192.168.0.10  192.168.0.10:8080  myserver  http://192.168.0.10:8080)" }
}
if (-not $url) { Bad "No server address given. Run the installer again."; return }
Set-EnvVar "LLM_URL" $url
Ok "server = $url  (saved in user env LLM_URL)"

# ---------------------------------------------------------------- 2/6 API key + connection test
Step "2/6 API key and connection test"
$uri = [Uri]$url
if (-not (Test-Tcp $uri.Host $uri.Port 3000)) {
  $myIp = Get-LocalIp $uri.Host
  $shown = "<this PC IP>"; if ($myIp) { $shown = $myIp }
  Bad "Cannot connect to $url from this PC."
  if ($myIp) { Info "This PC's address: $shown" }
  else { Info "(could not work out this PC's address - the name $($uri.Host) may not resolve; check the spelling or use the IP)" }
  Info "If the server firewall is blocking it, run this ON THE SERVER:"
  Info "    ~/llm-allow.sh $shown"
  Info "Also check: the server is on (~/llm-router.sh status), same network, and the address above is right."
  Info "Then run this installer again (your answers are remembered)."
  return
}
$key = Get-UserVar "LLM_KEY"
if ($key) {
  if (-not (Ask-YesNo "   A saved API key was found. Keep it?" $true)) { $key = $null }
}
$ids = $null
for ($attempt = 1; $attempt -le 3; $attempt++) {
  if (-not $key) {
    $key = (Read-Plain "   API key (typing is hidden)").Trim()
    if (-not $key) { Bad "Empty key (try $attempt of 3)"; continue }
    Set-EnvVar "LLM_KEY" $key
  }
  $r = Get-ModelIds $url $key
  if ($r.Ok) { $ids = $r.Ids; break }
  if ($r.Status -eq 401 -or $r.Status -eq 403) {
    Bad "The server rejected the API key (HTTP $($r.Status), try $attempt of 3)."
    Set-EnvVar "LLM_KEY" $null
    $key = $null
    continue
  }
  if ($r.Status -gt 0) { Bad "The server answered HTTP $($r.Status). Is $url the LLM server?"; return }
  Bad "No answer from $url ($($r.Message))"
  Info "The port is open but the server did not answer. Check ~/llm-router.sh status on the server."
  return
}
if ($null -eq $ids) { Bad "No valid API key after 3 tries. Ask the server owner for the key and run the installer again."; return }
if ($ids.Count -eq 0) { Bad "The server answered but lists no models. Check llm-presets.ini on the server."; return }
Ok ("server reachable, API key accepted. models: " + ($ids -join ", "))

# ---------------------------------------------------------------- 3/6 opencode
Step "3/6 opencode $Ver"
$dest = Join-Path $env:LOCALAPPDATA "Programs\opencode"
$want = $Ver.TrimStart("v")
$exe = Find-OpencodeExe $dest
if ($exe -and (Get-OpencodeVersion $exe) -eq $want) {
  Ok "already installed: opencode $want ($($exe.FullName))"
} else {
  if ($exe) { Info "found a different or broken opencode in $dest - installing the pinned $Ver" }
  $exe = $null
  $tmp = Join-Path $env:TEMP "localllm-setup"
  New-Item -ItemType Directory -Force $tmp | Out-Null
  foreach ($name in @("opencode-windows-x64.zip", "opencode-windows-x64-baseline.zip")) {
    $zip = Join-Path $tmp $name
    Write-Host "   downloading $name ..."
    Invoke-WebRequest "https://github.com/anomalyco/opencode/releases/download/$Ver/$name" -OutFile $zip -UseBasicParsing
    $got = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
    if ($got -ne $Sha[$name]) { Bad "sha256 mismatch for $name - download corrupted or tampered with. Nothing was installed."; return }
    Ok "sha256 verified"
    try {
      if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
      New-Item -ItemType Directory -Force $dest | Out-Null
      Expand-Archive $zip -DestinationPath $dest -Force
    } catch {
      Bad "could not unpack into $dest ($($_.Exception.Message))"
      Info "If opencode is running, close it and run this installer again."
      return
    }
    $exe = Find-OpencodeExe $dest
    $v = Get-OpencodeVersion $exe
    if ($v) { Ok "opencode $v installed"; break }
    Info "$name did not run on this CPU, trying the baseline build"; $exe = $null
  }
  if (-not $exe) { Bad "opencode does not run on this PC"; return }
}
$bin = Split-Path $exe.FullName
$userPath = Get-UserVar "Path"; if (-not $userPath) { $userPath = "" }
if (($userPath -split ";") -notcontains $bin) {
  $newPath = $bin; if ($userPath) { $newPath = $userPath.TrimEnd(";") + ";" + $bin }
  Set-UserVar "Path" $newPath
  Ok "added to PATH (new terminals): $bin"
}
if (($env:Path -split ";") -notcontains $bin) { $env:Path = $env:Path + ";" + $bin }

# ---------------------------------------------------------------- 4/6 opencode config
Step "4/6 opencode config"
$cfg = Get-UserVar "OPENCODE_CONFIG"
if (-not $cfg) { $cfg = Join-Path $env:USERPROFILE ".config\opencode\opencode.json" }
New-Item -ItemType Directory -Force (Split-Path $cfg) | Out-Null
$perm = [ordered]@{ edit = "ask"; bash = "ask" }
$oldRaw = $null
if (Test-Path $cfg) {
  $oldRaw = [IO.File]::ReadAllText($cfg)
  try {
    $old = $oldRaw | ConvertFrom-Json
    if ($null -ne $old.permission) { $perm = $old.permission }
  } catch { Info "old config is not plain JSON (comments?) - using permission edit/bash = ask" }
}
$lim = [ordered]@{ context = 65536; output = 16384 }
$models = [ordered]@{}
foreach ($id in $ids) {
  $name = $id; if ($Known.ContainsKey($id)) { $name = $Known[$id] }
  $m = [ordered]@{ name = $name; limit = $lim }
  if ($id -eq "mg") {   # Muse Glimmer: thinking strength is chosen per request (variant)
    $m["options"]  = [ordered]@{ chat_template_kwargs = [ordered]@{ reasoning_strength = "low" } }
    $m["variants"] = [ordered]@{
      low   = [ordered]@{ chat_template_kwargs = [ordered]@{ reasoning_strength = "low" } }
      xhigh = [ordered]@{ chat_template_kwargs = [ordered]@{ reasoning_strength = "xhigh" } }
    }
  }
  $models[$id] = $m
}
$default = "halo/" + $ids[0]; if ($ids -contains "cn") { $default = "halo/cn" }
$conf = [ordered]@{
  '$schema'         = "https://opencode.ai/config.json"
  enabled_providers = @("halo")
  provider          = [ordered]@{
    halo = [ordered]@{
      npm     = "@ai-sdk/openai-compatible"
      name    = "Strix Halo LLM"
      options = [ordered]@{ baseURL = "$url/v1"; apiKey = '{env:LLM_KEY}' }
      models  = $models
    }
  }
  model      = $default
  share      = "disabled"
  permission = $perm
}
$json = $conf | ConvertTo-Json -Depth 30
$chk = $json | ConvertFrom-Json     # re-parse before writing: never leave a broken config behind
if (@($chk.provider.halo.models.PSObject.Properties).Count -ne $ids.Count) { throw "config check failed (model count)" }
if ($chk.provider.halo.options.apiKey -ne '{env:LLM_KEY}') { throw "config check failed (apiKey)" }
if ($null -ne $oldRaw -and $oldRaw.Trim() -ne $json.Trim()) {
  $bak = $cfg + ".bak-" + (Get-Date -Format "yyyyMMdd-HHmmss")
  Copy-Item $cfg $bak
  Info "old config saved as $bak"
}
[IO.File]::WriteAllText($cfg, $json, (New-Object Text.UTF8Encoding($false)))
Set-EnvVar "OPENCODE_CONFIG" $cfg
Ok "wrote $cfg  (provider halo, $($ids.Count) models, external providers off, share off)"
Info ("permission: " + ($perm | ConvertTo-Json -Depth 10 -Compress))
Info "default model: $default"

# ---------------------------------------------------------------- 5/6 work folder + launcher
Step "5/6 Work folder and desktop launcher"
$defWork = Join-Path $env:USERPROFILE "Documents\workspace\study"
if (Test-Path "D:\Documents\workspace\study") { $defWork = "D:\Documents\workspace\study" }
$work = Read-Host "   Work folder (opencode starts here) [$defWork]"
if (-not $work -or -not $work.Trim()) { $work = $defWork }
$work = $work.Trim().Trim('"')
New-Item -ItemType Directory -Force $work | Out-Null
$work = (Resolve-Path -LiteralPath $work).Path
Ok $work

$desktop = [Environment]::GetFolderPath("Desktop")
if (-not $desktop) { $desktop = Join-Path $env:USERPROFILE "Desktop" }
New-Item -ItemType Directory -Force $desktop | Out-Null
$bat = Join-Path $desktop "opencode-local.bat"
$lines = @(
  "@echo off",
  ("cd /d `"" + (ConvertTo-BatPath $work) + "`""),
  ("`"" + (ConvertTo-BatPath $exe.FullName) + "`" %*"),
  "if errorlevel 1 pause"
)
$batText = ($lines -join "`r`n") + "`r`n"
$enc = [Text.Encoding]::ASCII
if ($batText -match "[^\x00-\x7F]") {   # non-ASCII path left over: cmd.exe reads .bat files in the OEM code page
  try { $enc = [Text.Encoding]::GetEncoding([Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage) } catch {}
}
[IO.File]::WriteAllText($bat, $batText, $enc)
Ok "desktop launcher: $bat"

# ---------------------------------------------------------------- 6/6 usage + start
Step "6/6 Done"
$pick = $ids[0]; if ($ids -contains "q36") { $pick = "q36" }
Write-Host ("   models  : " + (($ids | ForEach-Object { "halo/$_" }) -join "  "))
Write-Host "   start   : opencode -m halo/$pick          auto-approve: opencode --auto -m halo/$pick"
Write-Host "   in a session: /models to switch (the first reply after a switch waits 20-80 s while the server swaps models)"
if ($ids -contains "mg") { Write-Host "   Glimmer (mg) thinking: Ctrl+T or Ctrl+P -> 'Switch model variant' -> low / xhigh" }
Write-Host "   launcher: double-click opencode-local.bat on the desktop (extra arguments work: opencode-local.bat --auto -m halo/$pick)"
Write-Host "   server  : $url   (API key is stored in user env LLM_KEY and is not shown)"
Write-Host "   new terminals have opencode on PATH; this window already does."
Write-Host ""
if (Ask-YesNo "Start opencode now?" $true) {
  Set-Location -LiteralPath $work
  & $exe.FullName
}

} catch {
  Bad ("unexpected error: " + $_.Exception.Message)
  Info "Run the same command again; if it keeps failing see docs/troubleshooting.md in the repo (https://github.com/genishs/localllm)."
}
}

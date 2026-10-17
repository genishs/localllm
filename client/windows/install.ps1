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
#   4 opencode config (auto-update off)   5 work folder + desktop launcher   6 usage summary / start
#
# Auto-update is switched off on purpose: opencode is installed from the release zip, so it cannot
# upgrade itself (its update notice would only lead to a failing upgrade) and the pinned version is the
# one verified against the server. It is turned off in two places - "autoupdate": false in the opencode
# config and the user env var OPENCODE_DISABLE_AUTOUPDATE (see README, "update notice" section).
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

# friendly names (and context size when it is not the default 65536) for known model ids, taken from the
# server presets. Unknown ids are shown as-is with the default context.
$DefaultContext = 65536
$Known = @{
  cn   = @{ name = "Qwen3-Coder-Next 80B-A3B | Q4_K_M" }
  q36  = @{ name = "Qwen3.6-35B-A3B | UD-Q6_K + MTP" }
  mg   = @{ name = "Muse Glimmer 30B | Q4_K_XL + DFlash" }
  orn  = @{ name = "Ornith-1.5-35B-A3B | Q6_K + MTP" }
  fn   = @{ name = "Qwen3.8-Flash-Next Coder (pruned) | IQ1_M" }
  mel  = @{ name = "Mellum2.1-12B-A2.5B Thinking | Q8_0" }
  bolt = @{ name = "Nemotron 3.5 Bolt 74B-A9B | 2-bit QAT + DFlash" }
  lfm  = @{ name = "LFM2.5-24B-A2B | Q8_0" }
  mcv  = @{ name = "MiniCPM-V 4.7 35B-A3B | Q6_K + DSpark" }
  q38  = @{ name = "Qwen3.8-27B (dense) | UD-Q6_K + MTP" }
  aw   = @{ name = "Qwen-AgentWorld 35B-A3B | UD-Q6_K [world model - not a coding agent]" }
  ff   = @{ name = "Qwen3.8-Flash-Next (full) | IQ3_XXS" }
  c7   = @{ name = "Qwen2.5-Coder-7B | Q8_0 [32K context]"; context = 32768 }
  c7r  = @{ name = "Qwen2.5-Coder-7B + React LoRA | Q8_0 [32K context]"; context = 32768 }
  c1   = @{ name = "Qwen2.5-Coder-1.5B | F16 [32K context]"; context = 32768 }
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

# parsed JSON (PSCustomObject / arrays / scalars) -> ordered dictionaries and ArrayLists, so keys can be set by name
# and everything the installer does not manage is written back unchanged
function ConvertTo-Plain($v) {
  if ($null -eq $v) { return $null }
  if ($v -is [string] -or $v -is [ValueType]) { return $v }
  if ($v -is [System.Collections.IDictionary]) {
    $o = [ordered]@{}
    foreach ($k in $v.Keys) { $o[[string]$k] = ConvertTo-Plain $v[$k] }
    return $o
  }
  if ($v -is [pscustomobject]) {
    $o = [ordered]@{}
    foreach ($p in $v.PSObject.Properties) { $o[$p.Name] = ConvertTo-Plain $p.Value }
    return $o
  }
  if ($v -is [System.Collections.IEnumerable]) {
    $l = New-Object System.Collections.ArrayList
    foreach ($e in $v) { [void]$l.Add((ConvertTo-Plain $e)) }
    return ,$l
  }
  return $v
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

# Start from the existing config (if it is plain JSON) and change only the keys this installer manages.
# Everything else (theme, keybinds, other providers, ...) is kept as it is.
$oldRaw = $null
$old = $null
if (Test-Path $cfg) {
  $oldRaw = [IO.File]::ReadAllText($cfg)
  if ($oldRaw.Trim()) {
    try { $parsed = $oldRaw | ConvertFrom-Json; if ($parsed -is [pscustomobject]) { $old = ConvertTo-Plain $parsed } } catch {}
    if ($null -eq $old) { Info "old config is not plain JSON (comments?) - writing a fresh config; the old file is backed up" }
  }
}
if ($null -eq $old) { $old = [ordered]@{} }
$managed = @('$schema', 'enabled_providers', 'provider', 'model', 'share', 'autoupdate', 'permission')

# the model list comes from the server; context/names come from the table above
$models = [ordered]@{}
foreach ($id in $ids) {
  $name = $id; $ctx = $DefaultContext
  if ($Known.ContainsKey($id)) {
    $name = $Known[$id].name
    if ($Known[$id].ContainsKey("context")) { $ctx = $Known[$id].context }
  }
  $m = [ordered]@{ name = $name; limit = [ordered]@{ context = $ctx; output = 16384 } }
  if ($id -eq "mg") {   # Muse Glimmer: thinking strength is chosen per request (variant)
    $m["options"]  = [ordered]@{ chat_template_kwargs = [ordered]@{ reasoning_strength = "low" } }
    $m["variants"] = [ordered]@{
      low   = [ordered]@{ chat_template_kwargs = [ordered]@{ reasoning_strength = "low" } }
      xhigh = [ordered]@{ chat_template_kwargs = [ordered]@{ reasoning_strength = "xhigh" } }
    }
  }
  if ($id -eq "bolt") {   # Nemotron Bolt: thinking is off on the server; a variant turns it on per request
    $m["options"]  = [ordered]@{ chat_template_kwargs = [ordered]@{ enable_thinking = $false } }
    $m["variants"] = [ordered]@{
      fast  = [ordered]@{ chat_template_kwargs = [ordered]@{ enable_thinking = $false } }
      think = [ordered]@{ chat_template_kwargs = [ordered]@{ enable_thinking = $true } }
    }
  }
  $models[$id] = $m
}
$halo = [ordered]@{
  npm     = "@ai-sdk/openai-compatible"
  name    = "Strix Halo LLM"
  options = [ordered]@{ baseURL = "$url/v1"; apiKey = '{env:LLM_KEY}' }
  models  = $models
}

# provider: replace provider.halo entirely, keep the other provider entries
$prov = [ordered]@{}
if ($old.Contains("provider") -and $old["provider"] -is [System.Collections.IDictionary]) {
  foreach ($k in $old["provider"].Keys) { $prov[$k] = $old["provider"][$k] }
}
$prov["halo"] = $halo

# permission: keep the existing one, else ask before edits and commands
$perm = [ordered]@{ edit = "ask"; bash = "ask" }
if ($old.Contains("permission") -and $null -ne $old["permission"]) { $perm = $old["permission"] }

# default model: keep it only if it is a halo model that exists on this server. With enabled_providers = halo
# any other default cannot be used (opencode stops with an error), so it is replaced too.
$default = "halo/" + $ids[0]; if ($ids -contains "cn") { $default = "halo/cn" }
$model = $default
$cur = $null; if ($old.Contains("model")) { $cur = $old["model"] }
if ($cur -is [string] -and $cur.StartsWith("halo/") -and ($ids -contains $cur.Substring(5))) { $model = $cur }
elseif ($cur) { Info "default model $cur is not available (only halo models are enabled) - using $default" }

$conf = [ordered]@{}
$conf['$schema'] = "https://opencode.ai/config.json"
foreach ($k in $old.Keys) { if ($managed -notcontains $k) { $conf[$k] = $old[$k] } }
$conf["enabled_providers"] = @("halo")
$conf["provider"]          = $prov
$conf["model"]             = $model
$conf["share"]             = "disabled"
$conf["autoupdate"]        = $false     # zip install cannot self-update; keep the pinned, server-verified version
$conf["permission"]        = $perm

$json = $conf | ConvertTo-Json -Depth 30
$chk = $json | ConvertFrom-Json     # re-parse before writing: never leave a broken config behind
if (@($chk.provider.halo.models.PSObject.Properties).Count -ne $ids.Count) { throw "config check failed (model count)" }
if ($chk.provider.halo.options.apiKey -ne '{env:LLM_KEY}') { throw "config check failed (apiKey)" }
if (@($chk.enabled_providers).Count -ne 1 -or @($chk.enabled_providers)[0] -ne "halo") { throw "config check failed (enabled_providers)" }
if ($chk.autoupdate -ne $false) { throw "config check failed (autoupdate)" }
$have = @($chk.PSObject.Properties.Name)
foreach ($k in $old.Keys) { if ($managed -notcontains $k -and $have -notcontains $k) { throw "config check failed (lost key $k)" } }
if (@($chk.provider.PSObject.Properties).Count -ne $prov.Count) { throw "config check failed (providers)" }

if ($null -ne $oldRaw -and $oldRaw.Trim() -ne $json.Trim()) {
  $bak = $cfg + ".bak-" + (Get-Date -Format "yyyyMMdd-HHmmss")
  Copy-Item $cfg $bak
  Info "old config saved as $bak"
}
[IO.File]::WriteAllText($cfg, $json, (New-Object Text.UTF8Encoding($false)))
Set-EnvVar "OPENCODE_CONFIG" $cfg
# opencode reads "autoupdate" only from its global config (~/.config/opencode/), not from a file named by
# OPENCODE_CONFIG that lives elsewhere. The env var works whatever the config path is (accepted values: true or 1).
Set-EnvVar "OPENCODE_DISABLE_AUTOUPDATE" "true"
Ok "wrote $cfg  (provider halo, $($ids.Count) models, external providers off, share off, auto-update off)"
$kept = @(); foreach ($k in $old.Keys) { if ($managed -notcontains $k) { $kept += $k } }
foreach ($k in $prov.Keys) { if ($k -ne "halo") { $kept += "provider.$k" } }
if ($kept.Count -gt 0) { Info ("kept your other settings: " + ($kept -join ", ")) }
Info ("permission: " + ($perm | ConvertTo-Json -Depth 10 -Compress))
Info "default model: $model"

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
if ($ids -contains "bolt") { Write-Host "   Bolt (bolt) thinking: Ctrl+T or Ctrl+P -> 'Switch model variant' -> fast (off, default) / think (on)" }
Write-Host "   launcher: double-click opencode-local.bat on the desktop (extra arguments work: opencode-local.bat --auto -m halo/$pick)"
Write-Host "   server  : $url   (API key is stored in user env LLM_KEY and is not shown)"
Write-Host "   updates : auto-update is off (the version verified with the server, $Ver, is kept)"
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

# uruncode - run Claude Code or Codex CLI through the UrunAI gateway.

$ErrorActionPreference = 'Stop'

$AppName = 'uruncode'
$DefaultBaseUrl = 'https://api.urunai.my.id/v1'
$DefaultModel_CLAUDE = 'claude-haiku-4-5-20251001'
$DefaultModel_CODEX = 'gpt-5.4-mini'
$ConfigDir = Join-Path $env:APPDATA 'uruncode'
$ConfigFile = Join-Path $ConfigDir 'config'

function Save-Key([string]$Key) {
  $Key = $Key.Trim()
  if ([string]::IsNullOrEmpty($Key)) {
    Write-Host 'Refusing to save an empty key.'
    return
  }
  New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
  Set-Content -Path $ConfigFile -Value ("URUNAI_API_KEY=" + $Key) -Encoding ASCII
  try {
    $acl = New-Object System.Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
      "$env:USERDOMAIN\$env:USERNAME", 'FullControl', 'Allow')
    $acl.AddAccessRule($rule)
    Set-Acl -Path $ConfigFile -AclObject $acl
  } catch { }
  Write-Host "Key saved to $ConfigFile"
}

function Get-Key {
  if (-not (Test-Path $ConfigFile)) { return $null }
  foreach ($line in Get-Content $ConfigFile) {
    if ($line -like 'URUNAI_API_KEY=*') {
      return $line.Substring('URUNAI_API_KEY='.Length)
    }
  }
  return $null
}

function Invoke-Setup {
  Write-Host ''
  Write-Host '+------------------------------------------+'
  Write-Host '|  uruncode - first-time setup             |'
  Write-Host '+------------------------------------------+'
  Write-Host ''
  Write-Host 'Claude Code and Codex CLI will run through UrunAI.'
  Write-Host 'You only need to enter your UrunAI API key once.'
  Write-Host ''
  for ($i = 0; $i -lt 3; $i++) {
    $secure = Read-Host -AsSecureString 'UrunAI API key'
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $key = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    $key = $key.Trim()
    if ($key) { Save-Key $key; return }
    Write-Host "Key can't be empty."
  }
  Write-Host 'Aborting after 3 empty attempts.'
  exit 1
}

function Resolve-Key {
  $key = Get-Key
  if (-not $key -and $env:URUNAI_API_KEY) {
    $key = $env:URUNAI_API_KEY.Trim()
    Write-Host 'Using URUNAI_API_KEY from environment; saving for next time.'
    Save-Key $key
  }
  if (-not $key) {
    Invoke-Setup
    $key = Get-Key
  }
  if (-not $key) {
    Write-Host "No API key available. Run '$AppName config' to set one."
    exit 1
  }
  return $key
}

function Show-Help {
  Write-Host @'
Usage:
  uruncode                  Choose Claude Code or Codex CLI interactively
  uruncode claude [ARGS...] Run Claude Code through UrunAI
  uruncode codex [ARGS...]  Run Codex CLI through UrunAI
  uruncode config [KEY]     Save or replace the UrunAI API key
  uruncode reset            Delete the stored API key
  uruncode update           Re-run the installer

Environment overrides:
  URUNAI_API_KEY       API key to save/use
  URUNAI_BASE_URL      Gateway base URL
  URUNAI_CLAUDE_MODEL  Claude Code model alias
  URUNAI_CODEX_MODEL   Codex CLI model alias
'@
}

function Select-Launcher {
  Write-Host ''
  Write-Host 'Choose a launcher:'
  Write-Host '  1) Claude Code'
  Write-Host '  2) Codex CLI'
  Write-Host ''
  $choice = Read-Host 'Selection [1-2]'
  switch ($choice.Trim()) {
    '1' { return 'claude' }
    'claude' { return 'claude' }
    'Claude' { return 'claude' }
    '2' { return 'codex' }
    'codex' { return 'codex' }
    'Codex' { return 'codex' }
    default {
      Write-Host 'Invalid selection.'
      exit 1
    }
  }
}

function Ensure-CodexProfile([string]$BaseUrl, [string]$Model) {
  $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
  $profileFile = Join-Path $codexHome 'uruncode.config.toml'
  New-Item -ItemType Directory -Force -Path $codexHome | Out-Null
  $content = @"
model = "$Model"
model_provider = "urunai"

[model_providers.urunai]
name = "UrunAI"
base_url = "$BaseUrl"
wire_api = "responses"
env_key = "URUNAI_API_KEY"
"@
  Set-Content -Path $profileFile -Value $content -Encoding ASCII
}

function Ensure-ClaudeSettings([string]$BaseUrl, [string]$Key) {
  $settingsDir = Join-Path $env:USERPROFILE ".claude"
  $settingsFile = Join-Path $settingsDir "settings.json"
  New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null
  $env:URUNCODE_CLAUDE_BASE_URL = $BaseUrl
  $env:URUNCODE_CLAUDE_AUTH_TOKEN = $Key
  $env:URUNCODE_CLAUDE_SETTINGS_FILE = $settingsFile
  node -e '
const fs = require("fs");
const file = process.env.URUNCODE_CLAUDE_SETTINGS_FILE;
let content = {};
if (fs.existsSync(file)) {
  try { content = JSON.parse(fs.readFileSync(file, "utf8")); } catch { content = {}; }
}
content.env = { ...(content.env || {}), ANTHROPIC_BASE_URL: process.env.URUNCODE_CLAUDE_BASE_URL, ANTHROPIC_AUTH_TOKEN: process.env.URUNCODE_CLAUDE_AUTH_TOKEN };
fs.writeFileSync(file, JSON.stringify(content, null, 2) + "\\n", "utf8");
'
}

function Invoke-Claude([string]$Key, [string[]]$Rest) {
  if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host 'claude CLI not found on PATH.'
    Write-Host 'Install Claude Code first: https://docs.claude.com/en/docs/claude-code'
    exit 127
  }

  $baseUrl = if ($env:URUNAI_BASE_URL) { $env:URUNAI_BASE_URL } else { $DefaultBaseUrl }

  $env:ANTHROPIC_BASE_URL = $baseUrl
  $env:ANTHROPIC_AUTH_TOKEN = $Key
  Ensure-ClaudeSettings $baseUrl $Key
  & claude @Rest
  exit $LASTEXITCODE
}

function Invoke-Codex([string]$Key, [string[]]$Rest) {
  if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    Write-Host 'codex CLI not found on PATH.'
    Write-Host 'Install Codex CLI first: https://developers.openai.com/codex'
    exit 127
  }
  $baseUrl = if ($env:URUNAI_BASE_URL) { $env:URUNAI_BASE_URL } else { $DefaultBaseUrl }
  $model = if ($env:URUNAI_CODEX_MODEL) { $env:URUNAI_CODEX_MODEL } else { $DefaultModel_CODEX }
  Ensure-CodexProfile $baseUrl $model
  $env:URUNAI_API_KEY = $Key

  if ($Rest.Count -ge 1 -and (Test-Path -Path $Rest[0] -PathType Container)) {
    $target = $Rest[0]
    $remaining = @()
    if ($Rest.Count -gt 1) { $remaining = $Rest[1..($Rest.Count - 1)] }
    & codex --profile uruncode --cd $target @remaining
    exit $LASTEXITCODE
  }
  & codex --profile uruncode @Rest
  exit $LASTEXITCODE
}

if ($args.Count -ge 1) {
  switch -Regex ($args[0]) {
    '^(config|--config|set-key|--set-key|change|--change|change-key|--change-key)$' {
      if ($args.Count -ge 2) { Save-Key $args[1] } else { Invoke-Setup }
      Write-Host "Done. Run '$AppName' to start."
      exit 0
    }
    '^(reset|--reset)$' {
      if (Test-Path $ConfigFile) { Remove-Item $ConfigFile -Force }
      Write-Host 'Stored key removed.'
      exit 0
    }
    '^(update|--update|upgrade|--upgrade)$' {
      Write-Host "Updating $AppName to the latest version..."
      $installUrl = if ($env:URUNCODE_INSTALL_URL) { $env:URUNCODE_INSTALL_URL } else { 'https://raw.githubusercontent.com/urunai/uruncode/main/install.ps1' }
      irm $installUrl | iex
      exit 0
    }
    '^(help|--help|-h)$' {
      Show-Help
      exit 0
    }
  }
}

$launcher = $null
$rest = @()
if ($args.Count -eq 0) {
  $launcher = Select-Launcher
} else {
  $launcher = $args[0]
  if ($args.Count -gt 1) { $rest = $args[1..($args.Count - 1)] }
}

$key = Resolve-Key
switch ($launcher) {
  'claude' { Invoke-Claude $key $rest }
  'cc' { Invoke-Claude $key $rest }
  'codex' { Invoke-Codex $key $rest }
  'cx' { Invoke-Codex $key $rest }
  default {
    Write-Host "Unknown launcher: $launcher"
    Show-Help
    exit 1
  }
}

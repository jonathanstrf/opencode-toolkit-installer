param(
  [string]$SpartanRepo = "$env:USERPROFILE\Code\ai-toolkit",
  [switch]$SkipSpartan,
  [switch]$SkipSuperpowers,
  [switch]$NoEnhance,
  [switch]$DryRun,
  [switch]$ApplyConfig,
  [switch]$Verify
)

$ErrorActionPreference = 'Stop'

function Get-ToolkitLockData {
  param([string]$LockFilePath)

  if (-not (Test-Path -LiteralPath $LockFilePath)) {
    throw "Lock file not found: $LockFilePath"
  }

  $raw = Get-Content -LiteralPath $LockFilePath -Raw
  $parsed = $raw | ConvertFrom-Json

  return [pscustomobject]@{
    InstallerVersion = [string]$parsed.version
    RepoUrl          = [string]$parsed.'ai-toolkit'.repo
    SpartanVersion   = [string]$parsed.'ai-toolkit'.version
    SpartanCommit    = [string]$parsed.'ai-toolkit'.commit
  }
}

function Copy-IfExists {
  param(
    [string]$Source,
    [string]$Destination,
    [switch]$WhatIfOnly
  )

  if (Test-Path -LiteralPath $Source) {
    if ($WhatIfOnly) {
      Write-Host "Would copy $Source -> $Destination" -ForegroundColor Yellow
    }
    else {
      New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force | Out-Null
      Copy-Item -Recurse -Force -Path $Source -Destination $Destination
    }
  }
  else {
    Write-Host "Warning: $Source not found, skipping" -ForegroundColor Yellow
  }
}

function Sync-DirectoryContents {
  param(
    [string]$SourceDirectory,
    [string]$DestinationDirectory,
    [switch]$WhatIfOnly
  )

  if (-not (Test-Path -LiteralPath $SourceDirectory)) {
    Write-Host "Warning: $SourceDirectory not found, skipping" -ForegroundColor Yellow
    return
  }

  if ($WhatIfOnly) {
    Write-Host "Would replace contents of $DestinationDirectory from $SourceDirectory" -ForegroundColor Yellow
    return
  }

  if (Test-Path -LiteralPath $DestinationDirectory) {
    Remove-Item -LiteralPath $DestinationDirectory -Recurse -Force
  }

  New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null
  Copy-Item -Path (Join-Path $SourceDirectory '*') -Destination $DestinationDirectory -Recurse -Force
}

function Merge-OpencodeConfigTemplate {
  param(
    [string]$ConfigPath,
    [string]$TemplatePath
  )

  if (-not (Test-Path -LiteralPath $TemplatePath)) {
    Write-Host "Warning: config template not found at $TemplatePath; skipping config merge." -ForegroundColor Yellow
    return
  }

  if (-not (Test-Path -LiteralPath $ConfigPath)) {
    Copy-Item -LiteralPath $TemplatePath -Destination $ConfigPath -Force
    Write-Host "Created $ConfigPath from template" -ForegroundColor Green
    return
  }

  $existing = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
  $template = Get-Content -LiteralPath $TemplatePath -Raw | ConvertFrom-Json

  if (-not ($existing.PSObject.Properties.Name -contains 'plugin') -or $null -eq $existing.plugin) {
    $existing | Add-Member -NotePropertyName plugin -NotePropertyValue @() -Force
  }

  $existing.plugin = @(
    @($existing.plugin) + @($template.plugin) |
      Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
      Sort-Object -Unique
  )

  if ($template.PSObject.Properties.Name -contains '$schema' -and -not ($existing.PSObject.Properties.Name -contains '$schema')) {
    $existing | Add-Member -NotePropertyName '$schema' -NotePropertyValue $template.'$schema' -Force
  }

  if ($template.PSObject.Properties.Name -contains 'agent' -and $null -ne $template.agent) {
    if (-not ($existing.PSObject.Properties.Name -contains 'agent') -or $null -eq $existing.agent) {
      $existing | Add-Member -NotePropertyName agent -NotePropertyValue ([pscustomobject]@{}) -Force
    }

    foreach ($property in $template.agent.PSObject.Properties) {
      # Template-defined agent settings are authoritative.
      $existing.agent | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value -Force
    }
  }

  $existing | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $ConfigPath -Encoding utf8
  Write-Host "Merged config template into $ConfigPath" -ForegroundColor Green
}

function Test-JsonFile {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "JSON file not found: $Path"
  }

  $null = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$Lock = Get-ToolkitLockData -LockFilePath (Join-Path $RepoRoot 'config\toolkit-version.lock')
$Target = "$env:USERPROFILE\.config\opencode"
$RepoUrl = $Lock.RepoUrl
$ToolkitRootRelative = 'toolkit'

Write-Host "OpenCode Toolkit Installer"
Write-Host "Target: $Target"
Write-Host "Locked toolkit version: $($Lock.InstallerVersion)"
Write-Host "Locked ai-toolkit version: $($Lock.SpartanVersion) ($($Lock.SpartanCommit))"
if ($DryRun) { Write-Host "DRY RUN - no changes will be made" }

if (!(Get-Command git -ErrorAction SilentlyContinue)) { throw "git is required" }
if (!(Get-Command robocopy -ErrorAction SilentlyContinue)) { Write-Host "robocopy not found; will use Copy-Item" }

if (-not (Test-Path $Target)) {
  if (-not $DryRun) { New-Item -ItemType Directory -Path $Target -Force | Out-Null }
}

if (-not $SkipSpartan) {
  Write-Host "Installing Spartan (ai-toolkit)"
  if (-not (Test-Path $SpartanRepo)) {
    if ($DryRun) { Write-Host "Would git clone $RepoUrl -> $SpartanRepo" }
    else { git clone $RepoUrl $SpartanRepo }
  }

  if ($DryRun) {
    Write-Host "Would git -C $SpartanRepo fetch origin"
    Write-Host "Would git -C $SpartanRepo checkout $($Lock.SpartanCommit)"
  }
  else {
    git -C $SpartanRepo fetch origin
    if ($LASTEXITCODE -ne 0) { throw "git fetch failed" }
    git -C $SpartanRepo reset --hard $Lock.SpartanCommit
    if ($LASTEXITCODE -ne 0) { throw "git reset --hard failed" }
    git -C $SpartanRepo clean -fd
    if ($LASTEXITCODE -ne 0) { throw "git clean failed" }
    git -C $SpartanRepo checkout $Lock.SpartanCommit
    if ($LASTEXITCODE -ne 0) { throw "git checkout failed" }
  }

  $toolkitRoot = Join-Path $SpartanRepo $ToolkitRootRelative
  if (-not (Test-Path -LiteralPath $toolkitRoot)) {
    throw "Expected toolkit root not found: $toolkitRoot"
  }

  $Backup = "$env:USERPROFILE\.config\opencode.backup-toolkits-$(Get-Date -Format yyyyMMdd-HHmmss)"
  if (Test-Path $Target) {
    if ($DryRun) { Write-Host "Would create backup $Backup" }
    else { Copy-Item -Recurse -Force -Path $Target -Destination $Backup }
  }

  Sync-DirectoryContents -SourceDirectory (Join-Path $toolkitRoot 'commands') -DestinationDirectory "$Target\commands" -WhatIfOnly:$DryRun
  Sync-DirectoryContents -SourceDirectory (Join-Path $toolkitRoot 'skills') -DestinationDirectory "$Target\skills" -WhatIfOnly:$DryRun
  Copy-IfExists -Source "$SpartanRepo\CLAUDE.md" -Destination "$Target\CLAUDE.md" -WhatIfOnly:$DryRun
  $toolkitVersionPath = Join-Path $toolkitRoot 'VERSION'
  if (Test-Path -LiteralPath $toolkitVersionPath) {
    if ($DryRun) {
      Write-Host "Would copy $toolkitVersionPath -> $Target\.spartan-version"
    }
    else {
      Copy-Item -LiteralPath $toolkitVersionPath -Destination "$Target\.spartan-version" -Force
    }
  }
  else {
    Write-Host "Warning: $toolkitVersionPath not found, skipping" -ForegroundColor Yellow
  }

  if (-not $DryRun) { Set-Content -Path "$Target\.spartan-repo" -Value $SpartanRepo }

  if (-not $NoEnhance) {
    $psEnhancer  = Join-Path $ScriptDir "enhance-claude-portable.ps1"
    $shEnhancer  = Join-Path $ScriptDir "enhance-claude-portable.sh"

    if ($DryRun) { Write-Host "Would run enhancer" }
    elseif (Test-Path $psEnhancer) {
      & $psEnhancer
    } elseif (Get-Command bash -ErrorAction SilentlyContinue) {
      bash $shEnhancer
    } else {
      Write-Host "No enhancer available; skipping CLAUDE.md enhancement (run enhance-claude-portable.ps1 manually)"
    }
  }
}

if ($ApplyConfig) {
  $configTemplatePath = Join-Path $RepoRoot 'config\opencode.template.json'
  $opencodeJsonPath = Join-Path $Target 'opencode.json'

  if ($DryRun) {
    Test-JsonFile -Path $configTemplatePath
    if (Test-Path -LiteralPath $opencodeJsonPath) {
      Test-JsonFile -Path $opencodeJsonPath
    }
    Write-Host "Would merge config template $configTemplatePath into $opencodeJsonPath"
  }
  else {
    if (-not (Test-Path -LiteralPath $Target)) {
      throw "Target directory missing: $Target"
    }
    Merge-OpencodeConfigTemplate -ConfigPath $opencodeJsonPath -TemplatePath $configTemplatePath
  }
}

if (-not $SkipSuperpowers) {
  Write-Host "Installing Superpowers (OpenCode plugin)"
  $OJF = "$Target\opencode.json"
  if ($DryRun) { Write-Host "Would merge plugin into $OJF" }
  else {
    if (-not (Test-Path $OJF)) { '{"plugin": []}' | Set-Content -Path $OJF }
    $json = Get-Content $OJF -Raw | ConvertFrom-Json
    if (-not ($json.plugin -contains 'superpowers@git+https://github.com/obra/superpowers.git')) {
      $json.plugin += 'superpowers@git+https://github.com/obra/superpowers.git'
      $json.plugin = $json.plugin | Sort-Object -Unique
      $json | ConvertTo-Json -Depth 10 | Set-Content -Path $OJF
      Write-Host "Merged superpowers into $OJF"
    } else { Write-Host "Superpowers already present in $OJF" }
  }
}

Write-Host "Complete. Restart OpenCode to load plugins."

if ($Verify) {
  $verifyScript = Join-Path $ScriptDir 'verify-installation.ps1'
  if ($DryRun) {
    Write-Host "Would run verification script $verifyScript"
  }
  elseif (Test-Path -LiteralPath $verifyScript) {
    & $verifyScript
  }
  else {
    Write-Host "Warning: verification script not found at $verifyScript; skipping"
  }
}

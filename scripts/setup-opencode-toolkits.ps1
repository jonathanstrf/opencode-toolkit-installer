param(
  [string]$SpartanRepo = "$env:USERPROFILE\Code\ai-toolkit",
  [switch]$SkipSpartan,
  [switch]$SkipSuperpowers,
  [switch]$NoEnhance,
  [switch]$DryRun
)

$Target = "$env:USERPROFILE\.config\opencode"
$RepoUrl = "https://github.com/c0x12c/ai-toolkit.git"

Write-Host "OpenCode Toolkit Installer"
Write-Host "Target: $Target"
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

  $Backup = "$env:USERPROFILE\.config\opencode.backup-toolkits-$(Get-Date -Format yyyyMMdd-HHmmss)"
  if (Test-Path $Target) {
    if ($DryRun) { Write-Host "Would create backup $Backup" }
    else { Copy-Item -Recurse -Force -Path $Target -Destination $Backup }
  }

  function Copy-IfExists($src,$dst){
    if (Test-Path $src) {
      if ($DryRun) { Write-Host "Would copy $src -> $dst" }
      else { New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null; Copy-Item -Recurse -Force -Path $src -Destination $dst }
    } else { Write-Host "Warning: $src not found, skipping" }
  }

  Copy-IfExists "$SpartanRepo\.opencode\commands\" "$Target\commands\"
  Copy-IfExists "$SpartanRepo\commands\" "$Target\commands\"
  Copy-IfExists "$SpartanRepo\.opencode\skills\" "$Target\skills\"
  Copy-IfExists "$SpartanRepo\skills\" "$Target\skills\"
  Copy-IfExists "$SpartanRepo\CLAUDE.md" "$Target\CLAUDE.md"
  Copy-IfExists "$SpartanRepo\.opencode\.spartan-version" "$Target\.spartan-version"
  Copy-IfExists "$SpartanRepo\.opencode\.spartan-packs" "$Target\.spartan-packs"

  if (-not $DryRun) { Set-Content -Path "$Target\.spartan-repo" -Value $SpartanRepo }

  if (-not $NoEnhance) {
    $scriptPath = Join-Path (Split-Path $MyInvocation.MyCommand.Path) "enhance-claude-portable.sh"
    if (Test-Path $scriptPath) {
      if ($DryRun) { Write-Host "Would run enhancer $scriptPath" }
      else { bash $scriptPath }
    } else { Write-Host "Enhancer not found; skipping" }
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

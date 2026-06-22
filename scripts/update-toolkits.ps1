param(
  [switch]$Latest,
  [switch]$Locked,
  [switch]$VerifyOnly
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
    Raw                  = $parsed
    InstallerVersion     = [string]$parsed.version
    SpartanVersion       = [string]$parsed.'ai-toolkit'.version
    SpartanCommit        = [string]$parsed.'ai-toolkit'.commit
    RepoUrl              = [string]$parsed.'ai-toolkit'.repo
    ExpectedCommandCount = [int]$parsed.checksums.expected_command_count
    ExpectedSkillCount   = [int]$parsed.checksums.expected_skill_count
  }
}

function Save-ToolkitLockData {
  param(
    [string]$LockFilePath,
    [object]$LockObject
  )

  $LockObject | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $LockFilePath -Encoding utf8
}

function Get-LocalToolkitRepoPath {
  param([string]$TargetPath)

  $repoPointerPath = Join-Path $TargetPath '.spartan-repo'
  if (Test-Path -LiteralPath $repoPointerPath) {
    $savedRepoPath = (Get-Content -LiteralPath $repoPointerPath -Raw).Trim()
    if (-not [string]::IsNullOrWhiteSpace($savedRepoPath)) {
      return $savedRepoPath
    }
  }

  return (Join-Path $env:USERPROFILE 'Code\ai-toolkit')
}

function Get-UtcDateStamp {
  return (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
}

if ($Latest -and $Locked) {
  throw 'Specify only one of -Latest or -Locked.'
}

if ($VerifyOnly -and ($Latest -or $Locked)) {
  throw 'Specify -VerifyOnly by itself.'
}

$scriptRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $scriptRoot
$lockFile = Join-Path $repoRoot 'config\toolkit-version.lock'
$target = Join-Path $env:USERPROFILE '.config\opencode'
$installerScript = Join-Path $scriptRoot 'setup-opencode-toolkits.ps1'
$verifyScript = Join-Path $scriptRoot 'verify-installation.ps1'
$lock = Get-ToolkitLockData -LockFilePath $lockFile
$localRepo = Get-LocalToolkitRepoPath -TargetPath $target

if ($VerifyOnly) {
  & $verifyScript
  exit $LASTEXITCODE
}

Write-Host 'OpenCode Toolkit Updater' -ForegroundColor Cyan
Write-Host "Locked installer version: $($lock.InstallerVersion)"
Write-Host "Locked ai-toolkit version: $($lock.SpartanVersion) ($($lock.SpartanCommit))"
Write-Host "ai-toolkit repo: $localRepo"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw 'git is required'
}

if (Test-Path -LiteralPath $localRepo) {
  $status = & git -C $localRepo status --short 2>&1
  if ($LASTEXITCODE -eq 0 -and [string]::IsNullOrWhiteSpace(($status | Out-String).Trim())) {
    Write-Host 'Repository working tree is clean' -ForegroundColor Green
  } elseif ($LASTEXITCODE -eq 0) {
    Write-Host 'Repository has local changes:' -ForegroundColor Yellow
    Write-Host $status -ForegroundColor Yellow
  } else {
    Write-Host 'Unable to inspect repository status' -ForegroundColor Yellow
  }
} else {
  Write-Host "Repository not found at $localRepo" -ForegroundColor Yellow
}

if (-not $Latest -and -not $Locked) {
  Write-Host ''
  Write-Host 'Choose update strategy:'
  Write-Host '  1) Update to latest (git pull)'
  Write-Host '  2) Stay on locked version (re-run installer)'
  Write-Host '  3) Cancel'
  $selection = Read-Host 'Selection'

  switch ($selection) {
    '1' { $Latest = $true }
    '2' { $Locked = $true }
    '3' {
      Write-Host 'Canceled.' -ForegroundColor Yellow
      exit 0
    }
    default {
      throw "Invalid selection: $selection"
    }
  }
}

if ($Latest) {
  if (-not (Test-Path -LiteralPath $localRepo)) {
    throw "ai-toolkit repo not found at $localRepo. Run the installer first or use -Locked."
  }

  Write-Host 'Updating ai-toolkit to latest...' -ForegroundColor Cyan
  & git -C $localRepo fetch origin
  if ($LASTEXITCODE -ne 0) { throw 'git fetch failed' }
  & git -C $localRepo checkout master
  if ($LASTEXITCODE -ne 0) { throw 'git checkout master failed' }
  & git -C $localRepo reset --hard origin/master
  if ($LASTEXITCODE -ne 0) { throw 'git reset --hard origin/master failed' }
  & git -C $localRepo clean -fd
  if ($LASTEXITCODE -ne 0) { throw 'git clean failed' }

  $newCommit = (& git -C $localRepo rev-parse HEAD 2>&1 | Out-String).Trim()
  $versionFile = Join-Path $localRepo 'toolkit\VERSION'
  if (-not (Test-Path -LiteralPath $versionFile)) {
    throw "Version file not found at $versionFile"
  }

  $newVersion = (Get-Content -LiteralPath $versionFile -Raw).Trim()
  $today = Get-UtcDateStamp
  $rawLock = $lock.Raw
  # Lock metadata dates are stored in UTC.
  $rawLock.last_updated = $today
  $rawLock.'ai-toolkit'.version = $newVersion
  $rawLock.'ai-toolkit'.commit = $newCommit
  $rawLock.'ai-toolkit'.verified_date = $today
  Save-ToolkitLockData -LockFilePath $lockFile -LockObject $rawLock

  & $installerScript -SpartanRepo $localRepo
  & $verifyScript
  exit $LASTEXITCODE
}

if ($Locked) {
  Write-Host 'Re-running installer at locked version...' -ForegroundColor Cyan
  & $installerScript -SpartanRepo $localRepo
  & $verifyScript
  exit $LASTEXITCODE
}

exit 0

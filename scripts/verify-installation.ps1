$ErrorActionPreference = 'Stop'

function Get-ToolkitLockData {
  param([string]$LockFilePath)

  if (-not (Test-Path -LiteralPath $LockFilePath)) {
    throw "Lock file not found: $LockFilePath"
  }

  $raw = Get-Content -LiteralPath $LockFilePath -Raw
  $parsed = $raw | ConvertFrom-Json

  return [pscustomobject]@{
    InstallerVersion      = [string]$parsed.version
    SpartanVersion        = [string]$parsed.'ai-toolkit'.version
    SpartanCommit         = [string]$parsed.'ai-toolkit'.commit
    RepoUrl               = [string]$parsed.'ai-toolkit'.repo
    ExpectedCommandCount  = [int]$parsed.checksums.expected_command_count
    ExpectedSkillCount    = [int]$parsed.checksums.expected_skill_count
  }
}

function Write-Pass {
  param([string]$Message)
  $script:PASS++
  Write-Host "$script:CheckSymbol $Message" -ForegroundColor Green
}

function Write-Fail {
  param([string]$Message)
  $script:FAIL++
  Write-Host "$script:CrossSymbol $Message" -ForegroundColor Red
}

function Write-Warn {
  param([string]$Message)
  $script:WARN++
  Write-Host "$script:WarnSymbol $Message" -ForegroundColor Yellow
}

$scriptRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $scriptRoot
$lock = Get-ToolkitLockData -LockFilePath (Join-Path $repoRoot 'config\toolkit-version.lock')

$target = Join-Path $env:USERPROFILE '.config\opencode'
$commandPath = Join-Path $target 'commands'
$skillsPath = Join-Path $target 'skills'
$claudePath = Join-Path $target 'CLAUDE.md'
$configPath = Join-Path $target 'opencode.json'
$versionPath = Join-Path $target '.spartan-version'
$repoPointerPath = Join-Path $target '.spartan-repo'

$PASS = 0
$FAIL = 0
$WARN = 0
$CheckSymbol = [char]0x2713
$CrossSymbol = [char]0x2717
$WarnSymbol = [char]0x26A0

Write-Host '=========================================='
Write-Host 'OpenCode Toolkit Verification Report'
Write-Host '=========================================='
Write-Host ''

if (Test-Path -LiteralPath $target) {
  Write-Pass 'Directory structure exists'
} else {
  Write-Fail "Directory $target does not exist"
}

if (Test-Path -LiteralPath $commandPath) {
  $commandCount = (Get-ChildItem -LiteralPath $commandPath -Recurse -File).Count
  if ($commandCount -eq $lock.ExpectedCommandCount) {
    Write-Pass "Commands: $commandCount found (expected $($lock.ExpectedCommandCount))"
  } elseif ($commandCount -gt 0) {
    Write-Warn "Commands: $commandCount found (expected $($lock.ExpectedCommandCount)) - WARNING"
  } else {
    Write-Fail 'Commands directory is empty'
  }
} else {
  Write-Fail "Commands directory missing at $commandPath"
}

if (Test-Path -LiteralPath $skillsPath) {
  $skillCount = (Get-ChildItem -LiteralPath $skillsPath -Directory).Count
  if ($skillCount -eq $lock.ExpectedSkillCount) {
    Write-Pass "Skills: $skillCount found (expected $($lock.ExpectedSkillCount))"
  } elseif ($skillCount -gt 0) {
    Write-Warn "Skills: $skillCount found (expected $($lock.ExpectedSkillCount)) - WARNING"
  } else {
    Write-Fail 'Skills directory is empty'
  }
} else {
  Write-Fail "Skills directory missing at $skillsPath"
}

if (Test-Path -LiteralPath $claudePath) {
  if (Select-String -Path $claudePath -Pattern 'DECISION CHECKPOINT' -Quiet) {
    Write-Pass 'CLAUDE.md: Decision checkpoint present'
  } else {
    Write-Fail 'CLAUDE.md: Decision checkpoint missing'
  }

  if (Select-String -Path $claudePath -Pattern 'Question Tool Usage' -Quiet) {
    Write-Pass 'CLAUDE.md: Question tool section present'
  } else {
    Write-Fail 'CLAUDE.md: Question tool section missing'
  }
} else {
  Write-Fail "CLAUDE.md missing at $claudePath"
  Write-Fail 'Cannot verify Question Tool Usage because CLAUDE.md is missing'
}

if (Test-Path -LiteralPath $configPath) {
  if (Select-String -Path $configPath -Pattern 'superpowers@git\+https://github\.com/obra/superpowers\.git' -Quiet) {
    Write-Pass 'Superpowers plugin installed'
  } else {
    Write-Fail 'Superpowers plugin missing'
  }
} else {
  Write-Fail "opencode.json missing at $configPath"
}

if (Test-Path -LiteralPath $versionPath) {
  $installedVersion = (Get-Content -LiteralPath $versionPath -Raw).Trim()
  if ($installedVersion -eq $lock.SpartanVersion) {
    Write-Pass "Version lock: $installedVersion matches $($lock.SpartanVersion)"
  } else {
    Write-Fail "Version lock: $installedVersion does not match $($lock.SpartanVersion)"
  }
} else {
  Write-Fail ".spartan-version missing at $versionPath"
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Fail 'git is not installed; cannot verify ai-toolkit repository status'
} else {
  $repoPath = Join-Path $env:USERPROFILE 'Code\ai-toolkit'
  if (Test-Path -LiteralPath $repoPointerPath) {
    $savedRepoPath = (Get-Content -LiteralPath $repoPointerPath -Raw).Trim()
    if (-not [string]::IsNullOrWhiteSpace($savedRepoPath)) {
      $repoPath = $savedRepoPath
    }
  }

  if (-not (Test-Path -LiteralPath $repoPath)) {
    Write-Warn "ai-toolkit repo: Git repository not found at $repoPath - WARNING"
  } else {
    $status = & git -C $repoPath status --porcelain 2>&1
    if ($LASTEXITCODE -ne 0) {
      Write-Warn 'ai-toolkit repo: Unable to read git status - WARNING'
    } elseif ([string]::IsNullOrWhiteSpace(($status | Out-String).Trim())) {
      Write-Pass 'ai-toolkit repo: Working tree clean'
    } else {
      Write-Warn 'ai-toolkit repo: Has uncommitted changes - WARNING'
    }
  }
}

Write-Host ''
Write-Host '=========================================='
Write-Host "Result: $PASS passed, $FAIL failed, $WARN warnings"

if ($FAIL -gt 0) {
  Write-Host 'Status: FAILED' -ForegroundColor Red
  exit 1
}

if ($WARN -gt 0) {
  Write-Host 'Status: PASSED (with warnings)' -ForegroundColor Yellow
} else {
  Write-Host 'Status: PASSED' -ForegroundColor Green
}

exit 0

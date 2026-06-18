<#
.SYNOPSIS
Clears a stale .claude scheduled task lock if the lock is orphaned or older than a safe TTL.

.DESCRIPTION
This script reads `.claude/scheduled_tasks.lock`, checks whether the recorded PID is still running,
and removes the lock if the process is not active or the lock is older than the configured TTL.

.OUTPUTS
Writes status text to the console and returns an exit code:
  0 - lock removed or no stale lock present
  1 - active lock detected and retained
#>

$root = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
$lockPath = [System.IO.Path]::Combine($root, '..', '.claude', 'scheduled_tasks.lock')
$ttlHours = 2

if (-not (Test-Path $lockPath)) {
    Write-Output "No lock file found at '$lockPath'."
    exit 0
}

try {
    $lockJson = Get-Content $lockPath -Raw | ConvertFrom-Json
} catch {
    Write-Warning "Failed to parse lock file content. Removing corrupt lock file."
    Remove-Item $lockPath -Force
    exit 0
}

$acquiredAtMs = [double]$lockJson.acquiredAt
$acquiredAt = [datetime]::UtcNow.AddMilliseconds(-1)  # dummy init
try {
    $acquiredAt = (Get-Date '1970-01-01T00:00:00Z').AddMilliseconds($acquiredAtMs)
} catch {
    Write-Warning "Invalid acquiredAt timestamp in lock file. Removing lock file."
    Remove-Item $lockPath -Force
    exit 0
}

$now = (Get-Date).ToUniversalTime()
$age = $now - $acquiredAt.ToUniversalTime()
$pidAlive = $false

if ($lockJson.pid -and $lockJson.pid -is [int]) {
    try {
        Get-Process -Id $lockJson.pid -ErrorAction Stop | Out-Null
        $pidAlive = $true
    } catch {
        $pidAlive = $false
    }
}

if (-not $pidAlive -or $age.TotalHours -gt $ttlHours) {
    Remove-Item $lockPath -Force
    Write-Output "Removed stale lock file. PID: $($lockJson.pid), age: $([math]::Round($age.TotalMinutes,1)) min."
    exit 0
}

Write-Output "Lock file appears active. PID $($lockJson.pid) is still running and lock age is $([math]::Round($age.TotalMinutes,1)) min."
exit 1

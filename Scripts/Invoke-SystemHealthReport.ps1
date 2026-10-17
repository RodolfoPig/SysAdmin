$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $root 'Logs'
$healthScript = Join-Path $PSScriptRoot 'Get-SystemHealth.ps1'

New-Item -ItemType Directory -Path $logDir -Force |
    Out-Null

if (-not (Test-Path -LiteralPath $healthScript)) {
    throw "Diagnostic script not found: $healthScript"
}

$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$report = Join-Path $logDir "SystemHealth-$timestamp.txt"
$transcriptStarted = $false

try {
    Start-Transcript -LiteralPath $report -Force | Out-Null
    $transcriptStarted = $true

    & $healthScript
}
finally {
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }
}

Write-Host "Report saved: $report" -ForegroundColor Green

[CmdletBinding()]
param(
    [ValidateRange(1, 720)]
    [int]$Hours = 24,

    [ValidateRange(1, 100)]
    [int]$MaxEvents = 20
)

$since = (Get-Date).AddHours(-$Hours)

Write-Host "`n=== SYSTEM ===" -ForegroundColor Cyan

$os = Get-CimInstance Win32_OperatingSystem
$uptime = (Get-Date) - $os.LastBootUpTime

[pscustomobject]@{
    ComputerName = $env:COMPUTERNAME
    Windows      = $os.Caption
    LastBoot     = $os.LastBootUpTime
    UptimeHours  = [math]::Round($uptime.TotalHours, 1)
} | Format-List

Write-Host "`n=== CORE SERVICES ===" -ForegroundColor Cyan

$criticalNames = @(
    'RpcSs',
    'EventLog',
    'Schedule',
    'Winmgmt',
    'Dhcp',
    'Dnscache',
    'LanmanWorkstation'
)

$services = @(
    Get-CimInstance Win32_Service |
        Where-Object { $_.Name -in $criticalNames } |
        Select-Object Name, DisplayName, State, StartMode |
        Sort-Object Name
)

$services | Format-Table -AutoSize

Write-Host "`n=== AUTOMATIC SERVICES NOT RUNNING ===" -ForegroundColor Cyan

$stoppedAuto = @(
    Get-CimInstance Win32_Service |
        Where-Object {
            $_.StartMode -eq 'Auto' -and
            $_.State -ne 'Running'
        } |
        Select-Object Name, DisplayName, State, StartMode |
        Sort-Object Name
)

if ($stoppedAuto.Count -eq 0) {
    Write-Host 'No stopped automatic services found.'
}
else {
    $stoppedAuto | Format-Table -AutoSize
    Write-Host 'Review only: some services can normally be stopped.'
}

foreach ($logName in @('System', 'Application')) {
    Write-Host "`n=== $logName EVENTS: LAST $Hours HOURS ===" `
        -ForegroundColor Cyan

    $events = @(
        Get-WinEvent -FilterHashtable @{
            LogName   = $logName
            Level     = @(1, 2)
            StartTime = $since
        } -MaxEvents $MaxEvents -ErrorAction SilentlyContinue
    )

    if ($events.Count -eq 0) {
        Write-Host 'No events returned, or the log could not be read.'
        continue
    }

    $events |
        Select-Object TimeCreated, Id, ProviderName, LevelDisplayName,
            @{
                Name = 'Message'
                Expression = {
                    $message = ($_.Message -replace '\s+', ' ').Trim()
                    if ($message.Length -gt 180) {
                        $message.Substring(0, 180) + '...'
                    }
                    else {
                        $message
                    }
                }
            } |
        Format-Table -Wrap -AutoSize
}

Write-Host "`nDiagnostics completed." -ForegroundColor Green

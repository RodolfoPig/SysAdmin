$ErrorActionPreference = 'Continue'

$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$uptime = (Get-Date) - $os.LastBootUpTime

Write-Host "`n=== SYSTEM ===" -ForegroundColor Cyan

[pscustomobject]@{
    ComputerName = $env:COMPUTERNAME
    Windows      = $os.Caption
    Build        = $os.BuildNumber
    Uptime       = '{0}d {1}h {2}m' -f $uptime.Days, $uptime.Hours, $uptime.Minutes
    RAM_TotalGB  = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    RAM_FreeGB   = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
} | Format-List

Write-Host "`n=== DISKS ===" -ForegroundColor Cyan

Get-Volume |
    Where-Object DriveLetter |
    Select-Object DriveLetter, FileSystem,
        @{N='SizeGB';E={[math]::Round($_.Size / 1GB, 1)}},
        @{N='FreeGB';E={[math]::Round($_.SizeRemaining / 1GB, 1)}} |
    Format-Table -AutoSize

Write-Host "`n=== NETWORK ADAPTERS ===" -ForegroundColor Cyan

Get-NetAdapter |
    Select-Object Name, Status, LinkSpeed, InterfaceDescription |
    Format-Table -AutoSize -Wrap

Write-Host "`n=== TOP PROCESSES BY RAM ===" -ForegroundColor Cyan

Get-Process |
    Sort-Object WorkingSet64 -Descending |
    Select-Object -First 10 ProcessName, Id,
        @{N='RAM_GB';E={[math]::Round($_.WorkingSet64 / 1GB, 2)}} |
    Format-Table -AutoSize

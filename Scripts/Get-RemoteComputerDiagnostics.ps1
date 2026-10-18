[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ComputerName,

    [System.Management.Automation.PSCredential]$Credential,

    [switch]$UseSSL
)

$testParams = @{
    ComputerName = $ComputerName
    ErrorAction  = 'Stop'
}

if ($Credential) {
    $testParams.Credential = $Credential
}
if ($UseSSL) {
    $testParams.UseSSL = $true
}

Write-Host "`n=== WINRM CONNECTIVITY ===" -ForegroundColor Cyan

try {
    Test-WSMan @testParams | Out-Null
    Write-Host "WinRM доступен на $ComputerName." -ForegroundColor Green
}
catch {
    Write-Host "WinRM недоступен на $ComputerName." -ForegroundColor Red
    Write-Host "Это не обязательно означает, что компьютер выключен." -ForegroundColor Yellow
    Write-Host "Проверь сеть, WinRM, учётные данные и настройки брандмауэра."
    Write-Host "Подробности: $($_.Exception.Message)"
    return
}

$remoteParams = @{
    ComputerName = $ComputerName
    ErrorAction  = 'Stop'
    ScriptBlock  = {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem
        $uptime = (Get-Date) - $os.LastBootUpTime

        $ipv4 = @(
            Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.IPAddress -notmatch '^(127\.|169\.254\.)'
                } |
                Select-Object InterfaceAlias, IPAddress, PrefixLength
        )

        $disks = @(
            Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' |
                Select-Object DeviceID, VolumeName,
                    @{Name='SizeGB'; Expression={
                        if ($_.Size) {
                            [math]::Round($_.Size / 1GB, 1)
                        } else { 0 }
                    }},
                    @{Name='FreeGB'; Expression={
                        if ($null -ne $_.FreeSpace) {
                            [math]::Round($_.FreeSpace / 1GB, 1)
                        } else { 0 }
                    }},
                    @{Name='FreePercent'; Expression={
                        if ($_.Size) {
                            [math]::Round($_.FreeSpace / $_.Size * 100, 1)
                        } else { 0 }
                    }}
        )

        $services = @(
            Get-Service -Name 'LanmanWorkstation', 'WinRM', 'TermService' `
                -ErrorAction SilentlyContinue |
                Select-Object Name, Status, StartType
        )

        [pscustomobject]@{
            ComputerName = $env:COMPUTERNAME
            Domain       = $cs.Domain
            PartOfDomain = $cs.PartOfDomain
            OS           = $os.Caption
            OSVersion    = $os.Version
            LastBoot     = $os.LastBootUpTime
            UptimeHours  = [math]::Round($uptime.TotalHours, 1)
            RAMTotalGB   = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
            IPv4         = $ipv4
            Disks        = $disks
            Services     = $services
        }
    }
}

if ($Credential) {
    $remoteParams.Credential = $Credential
}
if ($UseSSL) {
    $remoteParams.UseSSL = $true
}

Write-Host "`n=== REMOTE SYSTEM DIAGNOSTICS ===" -ForegroundColor Cyan

try {
    $result = Invoke-Command @remoteParams
}
catch {
    Write-Host 'Не удалось получить данные удалённого компьютера.' -ForegroundColor Red
    Write-Host 'Проверь права доступа и настройки PowerShell Remoting.'
    Write-Host "Подробности: $($_.Exception.Message)"
    return
}

Write-Host "`n=== COMPUTER ===" -ForegroundColor Cyan
$result |
    Select-Object ComputerName, Domain, PartOfDomain, OS, OSVersion,
        LastBoot, UptimeHours, RAMTotalGB |
    Format-List

Write-Host "`n=== IPv4 ADDRESSES ===" -ForegroundColor Cyan
$result.IPv4 | Format-Table -AutoSize

Write-Host "`n=== DISKS ===" -ForegroundColor Cyan
$result.Disks | Format-Table -AutoSize

Write-Host "`n=== IMPORTANT SERVICES ===" -ForegroundColor Cyan
$result.Services | Format-Table -AutoSize


# --- REPORT EXPORT ---
$reportDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'Reports'
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null

$reportStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$safeComputerName = ($result.ComputerName -replace '[^a-zA-Z0-9_.-]', '_')
$reportPath = Join-Path $reportDir "RemoteDiagnostics-$safeComputerName-$reportStamp.json"

$report = [pscustomobject]@{
    GeneratedAt = (Get-Date).ToString('o')
    RequestedTarget = $ComputerName
    Computer = [pscustomobject]@{
        Name = $result.ComputerName
        Domain = $result.Domain
        PartOfDomain = $result.PartOfDomain
        OS = $result.OS
        OSVersion = $result.OSVersion
        LastBoot = $result.LastBoot
        UptimeHours = $result.UptimeHours
        RAMTotalGB = $result.RAMTotalGB
    }
    IPv4 = @($result.IPv4 | Where-Object { $null -ne $_ })
    Disks = @($result.Disks | Where-Object { $null -ne $_ })
    Services = @($result.Services | Where-Object { $null -ne $_ })
}

$report | ConvertTo-Json -Depth 8 |
    Set-Content -LiteralPath $reportPath -Encoding utf8NoBOM

Write-Host "`nJSON report saved: $reportPath" -ForegroundColor Green

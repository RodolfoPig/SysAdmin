[CmdletBinding()]
param(
    [string[]]$Target = @('microsoft.com', 'github.com'),
    [int[]]$Port = @(443)
)

$ErrorActionPreference = 'Continue'

Write-Host "`n=== NETWORK ADAPTERS ===" -ForegroundColor Cyan

Get-NetAdapter |
    Select-Object Name, Status, LinkSpeed, InterfaceDescription |
    Format-Table -AutoSize

Write-Host "`n=== IP CONFIGURATION ===" -ForegroundColor Cyan

$configs = @(
    Get-NetIPConfiguration |
        Where-Object { $_.NetAdapter.Status -eq 'Up' }
)

$ipResults = foreach ($cfg in $configs) {
    [pscustomobject]@{
        Interface = $cfg.InterfaceAlias
        IPv4      = (@($cfg.IPv4Address |
            ForEach-Object { $_.IPAddress }) -join ', ')
        Gateway   = (@($cfg.IPv4DefaultGateway |
            ForEach-Object { $_.NextHop }) -join ', ')
        DNS       = (@($cfg.DNSServer |
            ForEach-Object { $_.ServerAddresses }) -join ', ')
    }
}

$ipResults | Format-Table -Wrap -AutoSize

Write-Host "`n=== DEFAULT ROUTES ===" -ForegroundColor Cyan

Get-NetRoute -AddressFamily IPv4 `
    -DestinationPrefix '0.0.0.0/0' `
    -ErrorAction SilentlyContinue |
    Sort-Object RouteMetric |
    Select-Object InterfaceAlias, NextHop, RouteMetric |
    Format-Table -AutoSize

Write-Host "`n=== DNS RESOLUTION ===" -ForegroundColor Cyan

$dnsResults = foreach ($hostName in $Target) {
    $parsedIP = $null

    if ([System.Net.IPAddress]::TryParse(
        [string]$hostName,
        [ref]$parsedIP
    )) {
        [pscustomobject]@{
            Target    = $hostName
            DNS       = 'SKIPPED (IP address)'
            Addresses = $parsedIP.IPAddressToString
        }
    }
    else {
        try {
            $addresses = @(
                Resolve-DnsName -Name $hostName -ErrorAction Stop |
                    Where-Object {
                        $_.Type -in @('A', 'AAAA') -and $_.IPAddress
                    } |
                    Select-Object -ExpandProperty IPAddress -Unique
            )

            [pscustomobject]@{
                Target    = $hostName
                DNS       = if ($addresses.Count) { 'OK' } else { 'NO RECORDS' }
                Addresses = $addresses -join ', '
            }
        }
        catch {
            [pscustomobject]@{
                Target    = $hostName
                DNS       = 'FAILED'
                Addresses = $_.Exception.Message
            }
        }
    }
}

$dnsResults | Format-Table -Wrap -AutoSize

Write-Host "`n=== TCP CONNECTIVITY ===" -ForegroundColor Cyan

$tcpResults = foreach ($hostName in $Target) {
    foreach ($portNumber in $Port) {
        try {
            $result = Test-NetConnection `
                -ComputerName $hostName `
                -Port $portNumber `
                -InformationLevel Detailed `
                -WarningAction SilentlyContinue

            [pscustomobject]@{
                Target        = $hostName
                Port          = $portNumber
                TCP           = if ($result.TcpTestSucceeded) {
                    'OK'
                } else {
                    'FAILED'
                }
                RemoteAddress = "$($result.RemoteAddress)"
                SourceAddress = $result.SourceAddress.IPAddress
                Interface     = $result.InterfaceAlias
            }
        }
        catch {
            [pscustomobject]@{
                Target        = $hostName
                Port          = $portNumber
                TCP           = 'ERROR'
                RemoteAddress = '-'
                SourceAddress = '-'
                Interface     = $_.Exception.Message
            }
        }
    }
}

$tcpResults | Format-Table -Wrap -AutoSize

Write-Host "`nNetwork diagnostics completed." -ForegroundColor Green



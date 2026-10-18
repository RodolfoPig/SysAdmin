BeforeAll {
    $projectRoot = Split-Path -Parent $PSScriptRoot
    $scriptsPath = Join-Path $projectRoot 'Scripts'

    $expectedScripts = @(
        'Get-SystemHealth.ps1'
        'Get-NetworkDiagnostics.ps1'
        'Get-ServiceHealth.ps1'
        'Invoke-SystemHealthReport.ps1'
        'Get-RemoteComputerDiagnostics.ps1'
    )
}

Describe 'SysAdmin Toolkit structure' {
    It 'contains README.md' {
        Test-Path (Join-Path $projectRoot 'README.md') |
            Should -BeTrue
    }

    It 'contains .gitignore' {
        Test-Path (Join-Path $projectRoot '.gitignore') |
            Should -BeTrue
    }

    It 'contains all required scripts' {
        foreach ($name in $expectedScripts) {
            Test-Path (Join-Path $scriptsPath $name) |
                Should -BeTrue -Because "$name must exist"
        }
    }

    It 'all PowerShell scripts have valid syntax' {
        $files = @(
            Get-ChildItem -LiteralPath $scriptsPath `
                -Filter '*.ps1' -File -Recurse
        )

        $files.Count | Should -BeGreaterThan 0

        foreach ($file in $files) {
            $tokens = $null
            $parseErrors = $null

            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $file.FullName,
                [ref]$tokens,
                [ref]$parseErrors
            )

            $parseErrors | Should -BeNullOrEmpty `
                -Because "$($file.Name) must have valid syntax"
        }
    }
}


Describe 'Remote diagnostics report export' {
    BeforeAll {
        $projectRoot = Split-Path $PSScriptRoot -Parent
        $sourcePath = Join-Path $projectRoot 'Scripts\Get-RemoteComputerDiagnostics.ps1'
        $reportDir = Join-Path $projectRoot 'Reports'
        $tempScript = Join-Path $projectRoot 'Scripts\__TestReportExport.ps1'
    }

    It 'creates and validates a JSON report from sample data' {
        $marker = '# --- REPORT EXPORT ---'
        $source = [System.IO.File]::ReadAllText($sourcePath)
        $index = $source.IndexOf($marker, [StringComparison]::Ordinal)

        if ($index -lt 0) {
            throw 'Report export block not found.'
        }

        $target = 'Pester-' + [guid]::NewGuid().ToString('N')
        $reportCode = $source.Substring($index)

        $ComputerName = $target
        $result = [pscustomobject]@{
            ComputerName = $target
            Domain = 'TESTDOMAIN'
            PartOfDomain = $true
            OS = 'Windows 11 Pro'
            OSVersion = '10.0.26200'
            LastBoot = (Get-Date).AddHours(-12)
            UptimeHours = 12
            RAMTotalGB = 32
            IPv4 = @(
                [pscustomobject]@{
                    InterfaceAlias = 'Ethernet'
                    IPAddress = '192.0.2.10'
                    PrefixLength = 24
                }
            )
            Disks = @(
                [pscustomobject]@{
                    DeviceID = 'C:'
                    VolumeName = 'Test'
                    SizeGB = 100
                    FreeGB = 60
                    FreePercent = 60
                }
            )
            Services = @(
                [pscustomobject]@{
                    Name = 'WinRM'
                    Status = 'Running'
                    StartType = 'Manual'
                }
            )
        }

        try {
            [System.IO.File]::WriteAllText(
                $tempScript,
                $reportCode,
                [System.Text.UTF8Encoding]::new($false)
            )

            & $tempScript

            $report = Get-ChildItem -LiteralPath $reportDir `
                -Filter "RemoteDiagnostics-$target-*.json" `
                -File -ErrorAction SilentlyContinue |
                Select-Object -First 1

            $report | Should -Not -BeNullOrEmpty

            $data = Get-Content -LiteralPath $report.FullName -Raw |
                ConvertFrom-Json -ErrorAction Stop

            $data.RequestedTarget | Should -Be $target
            $data.Computer.Name | Should -Be $target
            $data.Computer.OS | Should -Be 'Windows 11 Pro'
            $data.IPv4.Count | Should -Be 1
            $data.Disks.Count | Should -Be 1
            $data.Services.Count | Should -Be 1
        }
        finally {
            Remove-Item -LiteralPath $tempScript `
                -Force -ErrorAction SilentlyContinue

            Get-ChildItem -LiteralPath $reportDir `
                -Filter "RemoteDiagnostics-$target-*.json" `
                -File -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }

    It 'excludes generated reports from Git' {
        $ignorePath = Join-Path $projectRoot '.gitignore'
        $ignoreContent = [System.IO.File]::ReadAllText($ignorePath)

        $ignoreContent | Should -Match '(?m)^/?Reports/\r?$'
    }
}

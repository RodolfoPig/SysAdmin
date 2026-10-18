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

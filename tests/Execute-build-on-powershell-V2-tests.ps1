Describe 'Execute build.ps1 file successfully on Powershell V2' {
    $testPath;
    $normalErrorAction;
    BeforeEach {
        $name = [System.IO.Path]::GetRandomFileName()
        $path = (Join-Path $PSScriptRoot $name)
        New-Item -ItemType Directory -Path $path
        $testPath = $path
        Copy-Item -Path .\build.ps1 -Destination $testPath
        Push-Location
        Set-Location $testPath
        $normalErrorAction = $Global:ErrorActionPreference
        $Global:ErrorActionPreference = "Stop"

        'Creating Test Cake File' | Write-Output
        'Information("Test success: {0}", DateTime.Now);' > build.cake
    }
    AfterEach {
        $Global:ErrorActionPreference = $normalErrorAction
        Pop-Location
        Remove-Item -Recurse $testPath -Force
    }
    It "Execute simple build.cake" {
        'Testing with PowerShell Current' | Write-Output
        & PowerShell -Version 2.0 -File .\build.ps1
        $LastExitCode | Should -Be 0
    }
    It "Execute build.cake with addins and modules package.config" {
        New-Item -ItemType Directory ./tools/modules
        "<?xml version=""1.0"" encoding=""utf-8""?>`r`n<packages>`r`n    <package id=""Cake.Chocolatey.Module"" version=""0.5.0"" />`r`n</packages>" | Out-File -Encoding utf8 -FilePath ./tools/modules/packages.config
        New-Item -ItemType Directory ./tools/addins
        "<?xml version=""1.0"" encoding=""utf-8""?>`r`n<packages>`r`n    <package id=""Cake.MicrosoftTeams"" version=""0.7.0"" />`r`n</packages>" | Out-File -Encoding utf8 -FilePath ./tools/addins/packages.config
        'Testing with PowerShell Module & Addin restore' | Write-Output
        & PowerShell -Version 2.0 -File .\build.ps1
        $LastExitCode | Should -Be 0
    }
}

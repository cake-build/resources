param (
    [string]$testresultFolder
)

if (-not (Test-Path -Path $testresultFolder)) {
    New-Item -Type Directory -Path $testresultFolder -Force
}

"Execute tests for build.ps1 in powershell" | Write-Output

Invoke-Pester .\tests\Execute-buid-tests.ps1 -OutputFormat NUnitXml -OutputFile (Join-Path -Path $testresultFolder -ChildPath 'Execute-buid-tests.xml') -PassThru;

if (-not $IsCoreCLR) {
    Invoke-Pester .\tests\Execute-build-on-powershell-V2-tests.ps1 -OutputFormat NUnitXml -OutputFile (Join-Path -Path $testresultFolder -ChildPath 'Execute-build-on-powershell-V2-tests.xml') -PassThru;
}

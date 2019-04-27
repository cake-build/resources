$ENV:CAKE_SETTINGS_SKIPVERIFICATION = 'true';
$ENV:CAKE_NUGET_USEINPROCESSCLIENT = 'true';

$testresultFolder = '.\tests\testresults';
if (!(Test-Path -Path $testresultFolder)) {
    New-Item -Type Directory -Path $testresultFolder -Force
}

"Execute tests for build.ps1 in powershell" | Write-Output

Invoke-Pester .\tests\Execute-buid-tests.ps1 -OutputFormat NUnitXml -OutputFile (Join-Path -Path $testresultFolder -ChildPath 'Execute-buid-tests.xml') -PassThru;

if (-not $IsCoreCLR) {
    Invoke-Pester .\tests\Execute-build-on-powershell-V2-tests.ps1 -OutputFormat NUnitXml -OutputFile (Join-Path -Path $testresultFolder -ChildPath 'Execute-build-on-powershell-V2-tests.xml') -PassThru;
}

$webclient = (New-Object 'System.Net.WebClient');

foreach ($testResult in  (Get-ChildItem -Path $testresultFolder)) {
    $webclient.UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path $testResult.FullName));
}

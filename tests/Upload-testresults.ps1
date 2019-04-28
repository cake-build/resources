param(
    [string]$testresultFolder
)

$webclient = (New-Object 'System.Net.WebClient');

foreach ($testResult in  (Get-ChildItem -Path $testresultFolder)) {
    $webclient.UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path $testResult.FullName));
}

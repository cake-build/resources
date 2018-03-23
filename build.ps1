##########################################################################
# This is the Cake bootstrapper script for PowerShell.
# This file was downloaded from https://github.com/cake-build/resources
# Feel free to change this file to fit your needs.
##########################################################################

<#

.SYNOPSIS
This is a Powershell script to bootstrap a Cake build.

.DESCRIPTION
This Powershell script will download NuGet if missing, restore NuGet tools (including Cake)
and execute your Cake build script with the parameters you provide.

.PARAMETER Script
The build script to execute.
.PARAMETER Target
The build script target to run.
.PARAMETER Configuration
The build configuration to use.
.PARAMETER Verbosity
Specifies the amount of information to be displayed.
.PARAMETER ShowDescription
Shows description about tasks.
.PARAMETER DryRun
Performs a dry run.
.PARAMETER Experimental
Uses the nightly builds of the Roslyn script engine.
.PARAMETER Mono
Uses the Mono Compiler rather than the Roslyn script engine.
.PARAMETER CakeVersion
The Cake version to use when running the build script.
.PARAMETER UseNetCore
The the CORE CLR edition of Cake.
.PARAMETER ScriptArgs
Remaining arguments are added here.

.LINK
https://cakebuild.net

#>

[CmdletBinding()]
Param(
    [string]$Script = "build.cake",
    [string]$Target,
    [string]$Configuration,
    [ValidateSet("Quiet", "Minimal", "Normal", "Verbose", "Diagnostic")]
    [string]$Verbosity,
    [switch]$ShowDescription,
    [Alias("WhatIf", "Noop")]
    [switch]$DryRun,
    [switch]$Experimental,
    [switch]$Mono,
    [version]$CakeVersion = '0.28.0',
    [switch]$UseNetCore,
    [Parameter(Position=0,Mandatory=$false,ValueFromRemainingArguments=$true)]
    [string[]]$ScriptArgs
)

if (!(Test-Path Function:\Expand-Archive)) {
    function Expand-Archive() {
        param([string]$Path, [string]$DestinationPath)

        if (!(Test-Path $DestinationPath)) { New-Item -Type Directory -Path $DestinationPath }

        $isPowershellCore = $PSVersionTable -and $PSVersionTable.PSEdition -eq 'Core'
        $haveNet45 = $PSVersionTable -and $PSVersionTable.CLRVersion -and ($PSVersionTable.CLRVersion -ge [version]'4.0.30319.17001')

        if ($isPowershellCore -or $haveNet45) {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($Path, $DestinationPath)
        } else {
            $shellApplication = New-Object -ComObject shell.application
            $zipPackage = $shellApplication.namespace($Path)
            $destinationFolder = $shellApplication.namespace($DestinationPath)
            $destinationFolder.CopyHere($zipPackage.Items(), 16)
        }
    }
}

function GetProxyEnabledWebClient
{
    $wc = New-Object System.Net.WebClient
    $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
    $proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials        
    $wc.Proxy = $proxy
    return $wc
}

$TOOLS_DIR = Join-Path $PSScriptRoot "tools"
$CAKE_EXE_DIR = ""
if ($UseNetCore) {
    $CAKE_DIR_NAME = "Cake.CoreCLR"
} else {
    $CAKE_DIR_NAME = "Cake"
}

$CAKE_URL = "https://www.nuget.org/api/v2/package/$($CAKE_DIR_NAME)/$($CakeVersion)"

if ($CakeVersion) {
    $CAKE_EXE_DIR = Join-Path "$TOOLS_DIR" "$CAKE_DIR_NAME.$($CakeVersion.ToString())"
} else {
    $CAKE_EXE_DIR = Join-Path "$TOOLS_DIR" "$CAKE_DIR_NAME"
}

if ((Test-Path $PSScriptRoot) -and !(Test-Path $TOOLS_DIR)) {
    Write-Verbose "Creating tools directory..."
    New-Item -Path $TOOLS_DIR -Type Directory | Out-Null
}

if (!(Test-Path $CAKE_EXE_DIR)) {
    # We download and save it as a normal zip file, in cases
    # were we need to extract it using com.
    $tmpDownloadFile = Join-Path "$TOOLS_DIR" "$CAKE_DIR_NAME.zip"
    Write-Verbose "Downloading Cake package..."

    try {
        $wc = GetProxyEnabledWebClient
        $wc.DownloadFile($CAKE_URL, $tmpDownloadFile)
    } catch {
        throw "Could not download Cake package...`n`nException:$_"
    }

    Write-Verbose "Extracting Cake package..."
    Expand-Archive -Path $tmpDownloadFile -DestinationPath $CAKE_EXE_DIR
    Remove-Item -Recurse -Force $tmpDownloadFile,"$CAKE_EXE_DIR/_rels","$CAKE_EXE_DIR/``[Content_Types``].xml","$CAKE_EXE_DIR/package"
}

if ($UseNetCore) {
    $CAKE_EXE = Get-ChildItem -LiteralPath $CAKE_EXE_DIR -Filter "Cake.dll" -Recurse | Select-Object -First 1 -ExpandProperty FullName
    if (!$CAKE_EXE) { throw "Unable to find the Cake.dll library" }
} else {
    $CAKE_EXE = Get-ChildItem -LiteralPath $CAKE_EXE_DIR -Filter "Cake.exe" -Recurse | Select-Object -First 1 -ExpandProperty FullName
    if (!$CAKE_EXE) { throw "Unable to find the Cake.exe executable" }
}

$cakeArguments = New-Object System.Collections.Generic.List[string]
$cakeArguments.Add($Script) | Out-Null
$excludeArgs = @("Script","CakeVersion","UseNetCore","ScriptArgs", "Verbose")

$PSBoundParameters.GetEnumerator() | ? { !$excludeArgs.Contains($_.Key) } | % {
    if ($_.Value) {
        $cakeArguments.Add("-$($_.Key)=$($_.Value)")
    } else {
        $cakeArguments.Add("-$($_.Key)")
    }
} | Out-Null
if ($ScriptArgs) {
    $cakeArguments.AddRange($ScriptArgs) | Out-Null
}

if ($UseNetCore) {
    $cakeArguments.Insert(0, $CAKE_EXE) | Out-Null
    $CAKE_EXE = Get-Command -Name dotnet | ForEach-Object Definition
} elseif ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    $cakeArguments.Insert(0, $CAKE_EXE) | Out-Null
    $CAKE_EXE = Get-Command -Name mono | ForEach-Object Definition
}

Write-Host "Running build script..."
Write-Verbose "Calling & $CAKE_EXE $cakeArguments"
& $Cake_EXE $cakeArguments
exit $LASTEXITCODE

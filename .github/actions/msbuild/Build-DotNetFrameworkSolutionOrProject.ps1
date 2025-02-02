﻿param (
    [string] $SolutionOrProject,
    [string] $Verbosity,
    [string] $TreatWarningsAsErrors,
    [string] $EnableCodeAnalysis,
    [string] $Version,
    [string] $Switches)

function ConvertTo-Array([string] $rawInput)
{
    $rawInput.Replace("`r", '').Split("`n") | ForEach-Object { $PSItem.Trim() } | Where-Object { $PSItem }
}

nuget restore $SolutionOrProject

Write-Output ".NET version number: $Version"

$commonSwitches = ConvertTo-Array @"
    --verbosity:$Verbosity
    -p:RunAnalyzersDuringBuild=$EnableCodeAnalysis
    -p:Retries=4
    -p:RetryDelayMilliseconds=1000
    -p:Version=$Version
"@

if ($TreatWarningsAsErrors -eq 'true')
{
    $commonSwitches += ConvertTo-Array @'
        --warnaserror
        -p:TreatWarningsAsErrors=true
'@
}

if (Test-Path src/Utilities/Lombiq.Gulp.Extensions/Lombiq.Gulp.Extensions.csproj)
{
    Write-Output '::group::Gulp Extensions found. It needs to be explicitly built before the solution.'

    # These need to be different than those for msbuild.
    $gulpBuildSwitches = $commonSwitches + (ConvertTo-Array @'
        --configuration:Release
        --nologo
        --warnAsMessage:MSB3026
        --consoleLoggerParameters:NoSummary
'@)

    $startTime = [DateTime]::Now
    dotnet build src/Utilities/Lombiq.Gulp.Extensions/Lombiq.Gulp.Extensions.csproj @gulpBuildSwitches
    $endTime = [DateTime]::Now

    Write-Output ('Gulp Extensions build took {0:0.###} seconds.' -f ($endTime - $startTime).TotalSeconds)
    Write-Output '::endgroup::'
}

# -p:Retries and -p:RetryDelayMilliseconds are used to retry builds when they fail due to random locks.

$buildSwitches = $commonSwitches + (ConvertTo-Array @"
    -p:Configuration=Release
    -restore
    $Switches
"@)

Write-Output "Building solution or project with ``msbuild $SolutionOrProject $($buildSwitches -join ' ')``."

msbuild $SolutionOrProject @buildSwitches

# Without this, if the msbuild command fails with certain MSB error codes (not build errors), they still won't cause
# this script to fail.

# error MSB3644: The reference assemblies for .NETFramework,Version=v4.6.1 were not found. To resolve this, install the
# Developer Pack (SDK/Targeting Pack) for this framework version or retarget your application. You can download .NET
# Framework Developer Packs at https://aka.ms/msbuild/developerpacks

if ($?)
{
    Write-Output 'Build successful.'
    Stop-DotNetBuildServers
}
else
{
    Write-Output '::error::Build failed. See the errors above in the build log.'
    exit 1
}

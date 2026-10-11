$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$CapricaRoot = if ($env:AIE_CAPRICA_ROOT) { $env:AIE_CAPRICA_ROOT } else { 'Y:\Games\MODCreation\Workspace\Caprica' }
$CapricaExe = Join-Path $CapricaRoot 'Caprica.exe'
$FlagsFile = Join-Path $CapricaRoot 'FO4_Papyrus_Flags.flg'
$Fo4Source = Join-Path $CapricaRoot 'FO4_Source'
$ProjectSource = Join-Path $ProjectRoot 'Data\Scripts\Source\User'
$ProjectOutput = Join-Path $ProjectRoot 'Data\Scripts'
$BuildRoot = 'Y:\Workspace\_AIE_CapricaBuild'
$BuildSource = Join-Path $BuildRoot 'Source'
$BuildOutput = Join-Path $BuildRoot 'Output'
$Log = Join-Path $BuildRoot 'AIE_caprica_compile.log'

New-Item -ItemType Directory -Force -Path $BuildSource, $BuildOutput, $ProjectOutput | Out-Null

Get-ChildItem -LiteralPath $BuildSource -Filter '*.psc' -File -ErrorAction SilentlyContinue |
    Remove-Item -Force
Get-ChildItem -LiteralPath $BuildOutput -Filter '*.pex' -File -ErrorAction SilentlyContinue |
    Remove-Item -Force

Get-ChildItem -LiteralPath $ProjectSource -Filter '*.psc' -File |
    Copy-Item -Destination $BuildSource -Force

$arguments = @($BuildSource, '-r', '-i', $BuildSource)
if (Test-Path -LiteralPath $Fo4Source) {
    $arguments += @('-i', $Fo4Source)
}
$arguments += @('-f', $FlagsFile, '-o', $BuildOutput)

& $CapricaExe @arguments *> $Log
if ($LASTEXITCODE -ne 0) {
    Get-Content -LiteralPath $Log
    throw "Caprica failed with exit code $LASTEXITCODE."
}

$expected = @(
    'AozoraItemExtractorNative.pex',
    'AozoraItemExtractor.pex',
    'AIE_LauncherScript.pex',
    'AIE_ControllerQuestScript.pex'
)
foreach ($name in $expected) {
    $compiled = Join-Path $BuildOutput $name
    if (!(Test-Path -LiteralPath $compiled)) {
        throw "Missing compiled script: $name"
    }
    Copy-Item -LiteralPath $compiled -Destination $ProjectOutput -Force
}

Get-Content -LiteralPath $Log
Write-Output 'Papyrus compilation successful.'

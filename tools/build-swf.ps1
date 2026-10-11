[CmdletBinding()]
param(
    [string]$FlexSdk = $env:AOZORA_FLEX_SDK
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($FlexSdk)) {
    throw 'Set AOZORA_FLEX_SDK or pass -FlexSdk to the Apache Flex SDK root.'
}

$FlexSdk = (Resolve-Path -LiteralPath $FlexSdk).Path
$sourceRoot = Join-Path $projectRoot 'src\as3'
$buildRoot = Join-Path $projectRoot 'build'
$mxmlcPath = Join-Path $FlexSdk 'bin\mxmlc.bat'
$playerGlobalRoot = Join-Path $FlexSdk 'frameworks\libs\player'
$entryPoint = Join-Path $sourceRoot 'aozora\extractor\AozoraItemExtractorMenu.as'
$swfPath = Join-Path $buildRoot 'AozoraItemExtractorMenu.swf'

if (-not (Test-Path -LiteralPath $mxmlcPath)) { throw "Apache Flex compiler not found: $mxmlcPath" }
if (-not (Test-Path -LiteralPath (Join-Path $playerGlobalRoot '11.2\playerglobal.swc'))) {
    throw "Flash 11.2 playerglobal.swc not found below: $playerGlobalRoot"
}

New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
$env:PLAYERGLOBAL_HOME = $playerGlobalRoot
$compileArgs = @(
    "-compiler.source-path=$sourceRoot",
    "-output=$swfPath",
    '-default-size=1280,720',
    '-default-frame-rate=30',
    '-target-player=11.2',
    '-swf-version=15',
    '-static-link-runtime-shared-libraries=true',
    '--',
    $entryPoint
)
& $mxmlcPath @compileArgs
if ($LASTEXITCODE -ne 0) { throw "mxmlc failed with exit code $LASTEXITCODE" }
$artifact = Get-Item -LiteralPath $swfPath
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $swfPath).Hash
Write-Output "SWF=$($artifact.FullName)"
Write-Output "BYTES=$($artifact.Length)"
Write-Output "SHA256=$hash"

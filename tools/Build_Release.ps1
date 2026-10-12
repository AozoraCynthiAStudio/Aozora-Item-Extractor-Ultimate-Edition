[CmdletBinding()]
param([string]$FlexSdk = $env:AOZORA_FLEX_SDK, [string]$Python = 'python')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$nativeRoot = Join-Path $projectRoot 'src/native'
& (Join-Path $PSScriptRoot 'Compile_Papyrus.ps1')
& (Join-Path $PSScriptRoot 'Build_ESP.ps1') -Language EN
Push-Location $nativeRoot
try {
    & xmake f -m releasedbg --preview_spike=n -y
    if ($LASTEXITCODE -ne 0) { throw 'Native configuration failed' }
    & xmake -j2
    if ($LASTEXITCODE -ne 0) { throw 'Native build failed' }
} finally { Pop-Location }
& (Join-Path $PSScriptRoot 'build-swf.ps1') -FlexSdk $FlexSdk
Copy-Item -LiteralPath (Join-Path $nativeRoot 'build/windows/x64/releasedbg/AozoraItemExtractor.dll') -Destination (Join-Path $projectRoot 'Data/F4SE/Plugins/AozoraItemExtractor.dll') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'build/AozoraItemExtractorMenu.swf') -Destination (Join-Path $projectRoot 'Data/Interface/AozoraItemExtractorMenu.swf') -Force
& $Python (Join-Path $PSScriptRoot 'package_release.py')
if ($LASTEXITCODE -ne 0) { throw 'Package failed' }

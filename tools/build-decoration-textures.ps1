$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root 'Data/Textures/Interface/AozoraItemExtractor'
New-Item -ItemType Directory -Force $out | Out-Null
foreach ($name in @('peek1','peek2','peek3','corner1','corner2','corner3','corner4')) {
    & texconv -nologo -y -f BC3_UNORM -m 1 -w 1024 -h 1536 -o $out (Join-Path $root "assets/mascots/$name.png") | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to convert $name" }
    Move-Item -LiteralPath (Join-Path $out "$name.dds") -Destination (Join-Path $out "$name-a419.dds") -Force
}
$sources = @{
    'mark-a417' = 'assets/decorative/VaultMarkStatic.png'
    'watermark-nav-a418' = 'assets/watermarks/girl-rocket-selected.png'
    'watermark-left-a418' = 'assets/watermarks/space-girl-selected.png'
    'watermark-right-a418' = 'assets/watermarks/boy-toolbox-selected.png'
}
foreach ($name in $sources.Keys) {
    $source = Join-Path $root $sources[$name]
    & texconv -nologo -y -f BC3_UNORM -m 1 -w 512 -h 512 -o $out $source | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to convert $name" }
    Move-Item -LiteralPath (Join-Path $out (([IO.Path]::GetFileNameWithoutExtension($source)) + '.dds')) -Destination (Join-Path $out "$name.dds") -Force
}

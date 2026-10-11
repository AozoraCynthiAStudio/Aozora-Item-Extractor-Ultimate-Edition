param(
    [string]$OutputPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'Data\AozoraItemExtractor.esp'),
    [ValidateSet('CHS', 'EN')]
    [string]$Language = 'CHS'
)

$ErrorActionPreference = 'Stop'

function Join-Bytes {
    param([byte[][]]$Parts)
    $stream = [IO.MemoryStream]::new()
    $index = 0
    foreach ($part in $Parts) {
        if ($null -eq $part) { throw "Join-Bytes received a null byte array at index $index." }
        $stream.Write($part, 0, $part.Length)
        $index += 1
    }
    $result = $stream.ToArray()
    $stream.Dispose()
    return $result
}

function Get-UInt16Bytes { param([UInt16]$Value) return [BitConverter]::GetBytes($Value) }
function Get-UInt32Bytes { param([UInt32]$Value) return [BitConverter]::GetBytes($Value) }
function Get-AsciiZ { param([string]$Value) return [Text.Encoding]::ASCII.GetBytes($Value + [char]0) }
function Get-Utf8Z { param([string]$Value) return [Text.Encoding]::UTF8.GetBytes($Value + [char]0) }

function Get-HexBytes {
    param([string]$Hex)
    $clean = $Hex -replace '\s', ''
    if (($clean.Length % 2) -ne 0) { throw 'Invalid hex byte string.' }
    $bytes = [byte[]]::new($clean.Length / 2)
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $bytes[$i] = [Convert]::ToByte($clean.Substring($i * 2, 2), 16)
    }
    return $bytes
}

function New-SubrecordBytes {
    param([string]$Signature, [byte[]]$Data)
    if ($Signature.Length -ne 4) { throw "Subrecord signature must be four characters: $Signature" }
    if ($Data.Length -gt [UInt16]::MaxValue) { throw "Subrecord too large: $Signature" }
    $stream = [IO.MemoryStream]::new()
    $writer = [IO.BinaryWriter]::new($stream)
    $writer.Write([Text.Encoding]::ASCII.GetBytes($Signature))
    $writer.Write([UInt16]$Data.Length)
    foreach ($byte in $Data) { $writer.Write([byte]$byte) }
    $writer.Flush()
    $result = $stream.ToArray()
    $writer.Dispose()
    $stream.Dispose()
    return $result
}

function New-RecordBytes {
    param([string]$Signature, [UInt32]$Flags, [UInt32]$FormID, [byte[]]$Data)
    $stream = [IO.MemoryStream]::new()
    $writer = [IO.BinaryWriter]::new($stream)
    $writer.Write([Text.Encoding]::ASCII.GetBytes($Signature))
    $writer.Write([UInt32]$Data.Length)
    $writer.Write($Flags)
    $writer.Write($FormID)
    $writer.Write([UInt32]0)
    $writer.Write([UInt16]0x0083)
    $writer.Write([UInt16]0)
    foreach ($byte in $Data) { $writer.Write([byte]$byte) }
    $writer.Flush()
    $result = $stream.ToArray()
    $writer.Dispose()
    $stream.Dispose()
    return $result
}

function New-GroupBytes {
    param([string]$Signature, [byte[]]$Record)
    $payload = $Record
    $stream = [IO.MemoryStream]::new()
    $writer = [IO.BinaryWriter]::new($stream)
    $writer.Write([Text.Encoding]::ASCII.GetBytes('GRUP'))
    $writer.Write([UInt32](24 + $payload.Length))
    $writer.Write([Text.Encoding]::ASCII.GetBytes($Signature))
    $writer.Write([UInt32]0)
    $writer.Write([UInt16]0)
    $writer.Write([UInt16]0)
    $writer.Write([UInt32]0)
    foreach ($byte in $payload) { $writer.Write([byte]$byte) }
    $writer.Flush()
    $result = $stream.ToArray()
    $writer.Dispose()
    $stream.Dispose()
    return $result
}

function New-VmadObjectScript {
    param([string]$ScriptName, [UInt32]$ObjectFormID, [switch]$Quest)
    $base = @(
        (Get-UInt16Bytes 6),
        (Get-UInt16Bytes 2),
        (Get-UInt16Bytes 1),
        (Get-UInt16Bytes ([UInt16]$ScriptName.Length)),
        [Text.Encoding]::ASCII.GetBytes($ScriptName),
        [byte[]](0),
        (Get-UInt16Bytes 1),
        (Get-UInt16Bytes 14),
        [Text.Encoding]::ASCII.GetBytes('ControllerItem'),
        [byte[]](1, 1),
        (Get-UInt32Bytes ([UInt32]4294901760)),
        (Get-UInt32Bytes $ObjectFormID)
    )
    if ($Quest) {
        $base += ,([byte[]](3, 0, 0, 0, 0, 0, 0))
    }
    return Join-Bytes $base
}

# TES4 flags 0x200 mark this .esp as ESL. With one master, new records use
# on-disk file index 01 and local IDs 800-802.
$headerData = Join-Bytes @(
    (New-SubrecordBytes 'HEDR' (Join-Bytes @(
        [BitConverter]::GetBytes([Single]1.0),
        (Get-UInt32Bytes 3),
        (Get-UInt32Bytes 0x803)
    ))),
    (New-SubrecordBytes 'CNAM' (Get-AsciiZ 'Sylva')),
    (New-SubrecordBytes 'SNAM' (Get-AsciiZ 'Aozora Item Extractor launcher plugin <cp:utf8>')),
    (New-SubrecordBytes 'MAST' (Get-AsciiZ 'Fallout4.esm')),
    (New-SubrecordBytes 'DATA' ([byte[]]::new(8)))
)
$tes4 = New-RecordBytes -Signature 'TES4' -Flags 0x200 -FormID 0 -Data $headerData

$launcherFormID = [UInt32]0x01000800
$effectFormID = [UInt32]0x01000801
$questFormID = [UInt32]0x01000802

# Effect settings cloned from OutfitManager 2.x's proven controller item.
$effectSettings = Get-HexBytes @'
00 8E 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
01 00 00 00 FF FF FF FF 00 00 00 00 00 00 00 00
01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 02 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00
'@

$effectDisplayName = if ($Language -eq 'EN') {
    Get-AsciiZ 'Open Aozora Item Extractor'
} else {
    Get-Utf8Z '打开 Aozora 物品提取器'
}
$launcherDisplayName = if ($Language -eq 'EN') {
    Get-AsciiZ 'Aozora Item Extractor'
} else {
    Get-Utf8Z 'Aozora 物品提取器'
}

$effectData = Join-Bytes @(
    (New-SubrecordBytes 'EDID' (Get-AsciiZ 'AIE_LauncherEffect')),
    (New-SubrecordBytes 'VMAD' (New-VmadObjectScript -ScriptName 'AIE_LauncherScript' -ObjectFormID $launcherFormID)),
    (New-SubrecordBytes 'FULL' $effectDisplayName),
    (New-SubrecordBytes 'DATA' $effectSettings)
)
$effect = New-RecordBytes -Signature 'MGEF' -Flags 0 -FormID $effectFormID -Data $effectData

$launcherData = Join-Bytes @(
    (New-SubrecordBytes 'EDID' (Get-AsciiZ 'AIE_LauncherItem')),
    (New-SubrecordBytes 'OBND' ([byte[]]::new(12))),
    (New-SubrecordBytes 'FULL' $launcherDisplayName),
    (New-SubrecordBytes 'DATA' ([byte[]]::new(4))),
    (New-SubrecordBytes 'ENIT' ([byte[]]::new(20))),
    (New-SubrecordBytes 'EFID' (Get-UInt32Bytes $effectFormID)),
    (New-SubrecordBytes 'EFIT' ([byte[]](0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0)))
)
$launcher = New-RecordBytes -Signature 'ALCH' -Flags 0 -FormID $launcherFormID -Data $launcherData

$questData = Join-Bytes @(
    (New-SubrecordBytes 'EDID' (Get-AsciiZ 'AIE_ControllerGiveQuest')),
    (New-SubrecordBytes 'VMAD' (New-VmadObjectScript -ScriptName 'AIE_ControllerQuestScript' -ObjectFormID $launcherFormID -Quest)),
    (New-SubrecordBytes 'DNAM' (Join-Bytes @(
        (Get-UInt32Bytes 0x11),
        (Get-UInt32Bytes 0),
        (Get-UInt32Bytes 0)
    ))),
    (New-SubrecordBytes 'NEXT' ([byte[]]::new(0)))
)
$quest = New-RecordBytes -Signature 'QUST' -Flags 0 -FormID $questFormID -Data $questData

$pluginBytes = Join-Bytes @(
    $tes4,
    (New-GroupBytes -Signature 'MGEF' -Record $effect),
    (New-GroupBytes -Signature 'ALCH' -Record $launcher),
    (New-GroupBytes -Signature 'QUST' -Record $quest)
)

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
[IO.File]::WriteAllBytes($OutputPath, $pluginBytes)
Get-Item -LiteralPath $OutputPath

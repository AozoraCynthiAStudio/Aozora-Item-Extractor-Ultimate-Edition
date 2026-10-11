param(
    [string]$Path = (Join-Path (Split-Path -Parent $PSScriptRoot) 'Data\AozoraItemExtractor.esp')
)

$ErrorActionPreference = 'Stop'
$bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path))

function Read-Ascii([int]$Offset, [int]$Length) {
    return [Text.Encoding]::ASCII.GetString($bytes, $Offset, $Length)
}

function Read-U16([int]$Offset) { return [BitConverter]::ToUInt16($bytes, $Offset) }
function Read-U32([int]$Offset) { return [BitConverter]::ToUInt32($bytes, $Offset) }

function Get-Subrecords([int]$Offset, [int]$Length) {
    $result = @{}
    $end = $Offset + $Length
    while ($Offset -lt $end) {
        if ($Offset + 6 -gt $end) { throw 'Truncated subrecord header.' }
        $signature = Read-Ascii $Offset 4
        $size = Read-U16 ($Offset + 4)
        $dataOffset = $Offset + 6
        if ($dataOffset + $size -gt $end) { throw "Truncated $signature subrecord." }
        if (!$result.ContainsKey($signature)) { $result[$signature] = @() }
        $data = if ($size -eq 0) { [byte[]]::new(0) } else { [byte[]]$bytes[$dataOffset..($dataOffset + $size - 1)] }
        $result[$signature] += ,$data
        $Offset = $dataOffset + $size
    }
    return $result
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (!$Condition) { throw $Message }
}

Assert-True ((Read-Ascii 0 4) -eq 'TES4') 'Missing TES4 header.'
$headerSize = Read-U32 4
$headerFlags = Read-U32 8
Assert-True (($headerFlags -band 0x200) -ne 0) 'TES4 ESL flag is not set.'
$header = Get-Subrecords 24 $headerSize
Assert-True ($header.ContainsKey('HEDR')) 'Missing HEDR.'
Assert-True ($header.ContainsKey('MAST')) 'Missing Fallout4.esm master.'
$hedr = $header['HEDR'][0]
Assert-True ([BitConverter]::ToUInt32($hedr, 4) -eq 3) 'Unexpected record count.'
Assert-True ([BitConverter]::ToUInt32($hedr, 8) -eq 0x803) 'Unexpected next object ID.'
$master = [Text.Encoding]::ASCII.GetString($header['MAST'][0]).TrimEnd([char]0)
Assert-True ($master -eq 'Fallout4.esm') 'Unexpected master file.'

$expected = @{
    'MGEF' = [UInt32]0x01000801
    'ALCH' = [UInt32]0x01000800
    'QUST' = [UInt32]0x01000802
}
$recordData = @{}
$offset = 24 + $headerSize
while ($offset -lt $bytes.Length) {
    Assert-True ((Read-Ascii $offset 4) -eq 'GRUP') "Expected GRUP at offset $offset."
    $groupSize = Read-U32 ($offset + 4)
    $groupSignature = Read-Ascii ($offset + 8) 4
    Assert-True ($expected.ContainsKey($groupSignature)) "Unexpected group $groupSignature."
    $recordOffset = $offset + 24
    Assert-True ((Read-Ascii $recordOffset 4) -eq $groupSignature) "Group $groupSignature has no matching record."
    $dataSize = Read-U32 ($recordOffset + 4)
    $formID = Read-U32 ($recordOffset + 12)
    Assert-True ($formID -eq $expected[$groupSignature]) "Unexpected $groupSignature FormID."
    Assert-True ($groupSize -eq (24 + 24 + $dataSize)) "Unexpected $groupSignature group size."
    $recordData[$groupSignature] = Get-Subrecords ($recordOffset + 24) $dataSize
    $offset += $groupSize
}
Assert-True ($offset -eq $bytes.Length) 'Trailing or truncated plugin data.'

$launcherVmad = [Text.Encoding]::ASCII.GetString($recordData['MGEF']['VMAD'][0])
$questVmad = [Text.Encoding]::ASCII.GetString($recordData['QUST']['VMAD'][0])
Assert-True ($launcherVmad.Contains('AIE_LauncherScript')) 'Launcher effect script is not bound.'
Assert-True ($launcherVmad.Contains('ControllerItem')) 'Launcher effect property is not bound.'
Assert-True ($questVmad.Contains('AIE_ControllerQuestScript')) 'Controller quest script is not bound.'
Assert-True ($questVmad.Contains('ControllerItem')) 'Controller quest property is not bound.'
Assert-True ([BitConverter]::ToUInt32($recordData['ALCH']['EFID'][0], 0) -eq 0x01000801) 'Launcher effect reference is invalid.'
Assert-True ($recordData['ALCH']['DATA'][0].Length -eq 4) 'Launcher item DATA is invalid.'
Assert-True (($recordData['ALCH']['DATA'][0] | Where-Object { $_ -ne 0 }).Count -eq 0) 'Launcher item weight is not zero.'
Assert-True (($recordData['ALCH']['ENIT'][0] | Where-Object { $_ -ne 0 }).Count -eq 0) 'Launcher item value is not zero.'

Write-Output 'ESP validation successful.'
Write-Output 'ESL flag: set'
Write-Output 'Launcher: ALCH local FormID 0x800'
Write-Output 'Effect: MGEF local FormID 0x801'
Write-Output 'Auto-give quest: QUST local FormID 0x802'

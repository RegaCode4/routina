# Builds and inspects a universal APK locally. Never uploads or creates keys.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$AndroidSdk,
    [string]$BuildToolsVersion = '36.0.0',
    [string]$ExpectedApplicationId,
    [string]$ExpectedCertificateSha256,
    [int]$PreviousVersionCode = -1,
    [switch]$AuditUnsigned
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolsPath = Join-Path $AndroidSdk "build-tools/$BuildToolsVersion"
$aapt = Join-Path $toolsPath 'aapt.exe'
$apksigner = Join-Path $toolsPath 'apksigner.bat'
$zipalign = Join-Path $toolsPath 'zipalign.exe'
foreach ($tool in @($aapt, $apksigner, $zipalign)) {
    if (!(Test-Path -LiteralPath $tool -PathType Leaf)) { throw 'Android Build Tools missing.' }
}
if (!$AuditUnsigned) {
    if (!$ExpectedApplicationId -or $ExpectedApplicationId -match '(^|\.)example(\.|$)') {
        throw 'Owner-approved public ExpectedApplicationId required; example IDs are blocked.'
    }
    if ($ExpectedCertificateSha256 -notmatch '^[A-Fa-f0-9]{64}$') {
        throw 'ExpectedCertificateSha256 must be the 64 hex characters recorded by the owner.'
    }
    if ($PreviousVersionCode -lt 0) { throw 'PreviousVersionCode required (0 for first release).' }
}

function Invoke-Checked([string]$File, [string[]]$Arguments) {
    $output = & $File @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Tool failed: $(Split-Path -Leaf $File). Check local build output." }
    return $output
}

function Test-ElfAlignment([string]$Apk) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Apk)
    $checked = @()
    try {
        foreach ($entry in $archive.Entries) {
            if ($entry.FullName -notmatch '^lib/(arm64-v8a|x86_64)/[^/]+\.so$') { continue }
            $source = $entry.Open()
            $buffer = New-Object System.IO.MemoryStream
            try { $source.CopyTo($buffer); $bytes = $buffer.ToArray() }
            finally { $source.Dispose(); $buffer.Dispose() }
            if ($bytes.Length -lt 64 -or [BitConverter]::ToUInt32($bytes, 0) -ne 0x464c457f -or
                $bytes[4] -ne 2 -or $bytes[5] -ne 1) { throw 'Expected little-endian ELF64 library.' }
            $headerOffset = [BitConverter]::ToUInt64($bytes, 32)
            $headerSize = [BitConverter]::ToUInt16($bytes, 54)
            $headerCount = [BitConverter]::ToUInt16($bytes, 56)
            $loads = 0
            if ($headerSize -lt 56) { throw 'Invalid ELF program header size.' }
            for ($index = 0; $index -lt $headerCount; $index++) {
                $offset = [int]($headerOffset + $index * $headerSize)
                if ($offset -lt 0 -or $offset + 56 -gt $bytes.Length) { throw 'Invalid ELF header bounds.' }
                if ([BitConverter]::ToUInt32($bytes, $offset) -ne 1) { continue }
                $loads++
                $fileOffset = [BitConverter]::ToUInt64($bytes, $offset + 8)
                $virtualAddress = [BitConverter]::ToUInt64($bytes, $offset + 16)
                $alignment = [BitConverter]::ToUInt64($bytes, $offset + 48)
                if ($alignment -lt 16384 -or $fileOffset % 16384 -ne $virtualAddress % 16384) {
                    throw "ELF LOAD is not 16 KiB aligned: $($entry.FullName)"
                }
            }
            if ($loads -eq 0) { throw 'ELF contains no LOAD segment.' }
            $checked += $entry.FullName
        }
    } finally { $archive.Dispose() }
    if ($checked.Count -eq 0) { throw 'No ELF64 libraries checked.' }
    return $checked
}

$oldAuditSetting = $env:ROUTINA_ALLOW_UNSIGNED_RELEASE
Push-Location $projectRoot
try {
    # Normal mode must not inherit the unsigned audit bypass from a parent shell.
    $env:ROUTINA_ALLOW_UNSIGNED_RELEASE = if ($AuditUnsigned) { 'true' } else { $null }
    & flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'Flutter release build failed; no distribution output prepared.' }
    $apk = Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-release.apk'
    $badging = (Invoke-Checked $aapt @('dump', 'badging', $apk)) -join "`n"
    $manifest = (Invoke-Checked $aapt @('dump', 'xmltree', $apk, 'AndroidManifest.xml')) -join "`n"
    $resources = (Invoke-Checked $aapt @('dump', '--values', 'resources', $apk)) -join "`n"
    function Read-XmlResource([string]$Name) {
        # Release resource shrinking renames ZIP entries; resolve the resource table.
        $pattern = '(?m)^\s*resource \S+ \S+:xml/' + [regex]::Escape($Name) +
            ':.*\r?\n\s*\(string\d+\) "([^"]+)"'
        $resource = [regex]::Match($resources, $pattern)
        if (!$resource.Success) { throw "Cannot locate compiled XML resource: $Name" }
        return (Invoke-Checked $aapt @('dump', 'xmltree', $apk, $resource.Groups[1].Value)) -join "`n"
    }
    $legacyBackup = Read-XmlResource 'legacy_backup_rules'
    $extraction = Read-XmlResource 'data_extraction_rules'
    $sharePaths = Read-XmlResource 'flutter_share_file_paths'
    $identity = [regex]::Match($badging, "package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'")
    if (!$identity.Success) { throw 'Cannot read APK identity.' }
    $applicationId = $identity.Groups[1].Value
    $versionCode = [int]$identity.Groups[2].Value
    $versionName = $identity.Groups[3].Value
    if ($ExpectedApplicationId -and $applicationId -cne $ExpectedApplicationId) { throw 'ApplicationId mismatch.' }
    if (!$AuditUnsigned -and $versionCode -le $PreviousVersionCode) { throw 'Version code must increase.' }
    if ($badging -notmatch "sdkVersion:'24'" -or $badging -notmatch "targetSdkVersion:'36'") {
        throw 'SDK contract changed; review Android distribution requirements.'
    }
    $abis = [regex]::Match($badging, "(?m)^native-code: (.+)$").Groups[1].Value
    foreach ($abi in @('armeabi-v7a', 'arm64-v8a', 'x86_64')) {
        if (!$abis.Contains("'$abi'")) { throw "Universal APK is missing $abi." }
    }
    if ($badging -match 'android.permission.INTERNET' -or
        $manifest -notmatch 'android:allowBackup[^\r\n]*0x0\b' -or
        $manifest -match 'android:debuggable[^\r\n]*0xffffffff') {
        throw 'Release manifest violates offline, backup, or debuggability policy.'
    }
    $signatureLines = & $apksigner verify --verbose --print-certs $apk 2>&1
    $signatureExit = $LASTEXITCODE
    $signature = $signatureLines -join "`n"
    $fingerprint = $null
    if ($AuditUnsigned) {
        if ($signatureExit -eq 0 -or $signature -notmatch '(?i)(missing META-INF/MANIFEST.MF|no signatures|not signed|no certificates)') {
            throw 'AuditUnsigned expects an unsigned APK; inspect apksigner output manually.'
        }
        $signatureStatus = 'UNSIGNED_NOT_FOR_DISTRIBUTION'
    } else {
        if ($signatureExit -ne 0) { throw 'APK signature verification failed.' }
        if ($signature -match '(?i)Android Debug|CN=Android Debug|Number of signers: (?!1\b)') {
            throw 'Debug certificate or unexpected multiple signers forbidden.'
        }
        $match = [regex]::Match($signature, '(?im)^Signer #1 certificate SHA-256 digest: ([a-f0-9]{64})\s*$')
        if (!$match.Success -or $match.Groups[1].Value -ine $ExpectedCertificateSha256) {
            throw 'Owner signing certificate mismatch.'
        }
        $fingerprint = $match.Groups[1].Value.ToLowerInvariant()
        $signatureStatus = 'VERIFIED_OWNER_CERTIFICATE'
    }
    $alignment = (Invoke-Checked $zipalign @('-c', '-P', '16', '-v', '4', $apk)) -join "`n"
    $elfLibraries = @(Test-ElfAlignment $apk)
    $sha256 = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
    $directoryName = if ($AuditUnsigned) { 'audit-unsigned' } else { 'signed-candidate' }
    $outputDirectory = Join-Path $projectRoot "build/distribution/$directoryName"
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
    $suffix = if ($AuditUnsigned) { '-UNSIGNED-AUDIT' } else { '' }
    $fileName = "routina-$versionName-$versionCode-universal$suffix.apk"
    Copy-Item -LiteralPath $apk -Destination (Join-Path $outputDirectory $fileName) -Force
    $metadata = [ordered]@{
        fileName = $fileName
        applicationId = $applicationId
        versionName = $versionName
        versionCode = $versionCode
        sizeBytes = (Get-Item -LiteralPath $apk).Length
        sha256 = $sha256
        builtAtUtc = [DateTime]::UtcNow.ToString('o')
        minSdk = 24
        targetSdk = 36
        abis = @('armeabi-v7a', 'arm64-v8a', 'x86_64')
        signatureStatus = $signatureStatus
        certificateSha256 = $fingerprint
        zipAndElf16KiB = 'PASS_STATIC_CHECK_ONLY'
        checkedElfLibraries = $elfLibraries
        publicationStatus = 'PENDING_RELEASE_CHECKLIST'
    }
    $metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $outputDirectory "$fileName.json") -Encoding UTF8
    "$sha256  $fileName" | Set-Content -LiteralPath (Join-Path $outputDirectory "$fileName.sha256") -Encoding ascii
    $badging | Set-Content (Join-Path $outputDirectory 'badging.txt')
    $manifest | Set-Content (Join-Path $outputDirectory 'manifest.txt')
    $legacyBackup | Set-Content (Join-Path $outputDirectory 'legacy-backup.txt')
    $extraction | Set-Content (Join-Path $outputDirectory 'data-extraction.txt')
    $sharePaths | Set-Content (Join-Path $outputDirectory 'share-paths.txt')
    $signature | Set-Content (Join-Path $outputDirectory 'signature.txt')
    $alignment | Set-Content (Join-Path $outputDirectory 'alignment.txt')
    Write-Output "Prepared local $signatureStatus artifact: $outputDirectory/$fileName"
    Write-Output 'Publication still requires docs/ANDROID_DISTRIBUTION.md release checklist.'
} finally {
    $env:ROUTINA_ALLOW_UNSIGNED_RELEASE = $oldAuditSetting
    Pop-Location
}

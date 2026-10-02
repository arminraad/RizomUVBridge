$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

$requiredFiles = @(
    "src\RizomUVBridge.ms",
    "macros\AR_RizomUVBridge.mcr",
    "install.ms",
    "mzp.run",
    "build\package.ps1",
    "docs\TESTING.md"
)

foreach ($relativePath in $requiredFiles) {
    $fullPath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path $fullPath)) {
        throw "Missing required file: $relativePath"
    }
}

$core = Get-Content (Join-Path $repoRoot "src\RizomUVBridge.ms") -Raw
$macro = Get-Content (Join-Path $repoRoot "macros\AR_RizomUVBridge.mcr") -Raw
$installer = Get-Content (Join-Path $repoRoot "install.ms") -Raw

$coreRequired = @(
    'global RUVB_ShowDialog',
    'maxVersion()',
    'majorCode >= 29000',
    'snapshot sourceNode',
    'getAnimByHandle handleValue',
    'channelInfo.CopyChannel',
    'channelInfo.PasteChannel',
    'FBXExporterSetParam "TangentSpaceExport" false',
    'FBXImporterSetParam',
    'ZomLoad({File={Path=',
    'Prefs.FileSuffix',
    'shellLaunch exe args',
    'fn sourceHandleForImportedName',
    'fn pollOutputReady'
)

foreach ($token in $coreRequired) {
    if (-not $core.Contains($token)) {
        throw "Core script is missing expected token: $token"
    }
}

$macroRequired = @(
    'global RUVB_ShowDialog',
    'executeScriptFile bridgeScript errormessage:&loadError',
    'if RUVB_ShowDialog != undefined'
)

foreach ($token in $macroRequired) {
    if (-not $macro.Contains($token)) {
        throw "Macro is missing expected token: $token"
    }
}

$installerRequired = @(
    'fn RUVB_Install',
    'global RUVB_ShowDialog',
    'executeScriptFile targetScript errormessage:&coreError',
    'executeScriptFile targetMacro errormessage:&macroError',
    'RUVB_ShowDialog()'
)

foreach ($token in $installerRequired) {
    if (-not $installer.Contains($token)) {
        throw "Installer is missing expected token: $token"
    }
}

$forbidden = @{
    "dynamic rollout label caption" = 'label lbl_version ('
    "obsolete FBX parameter" = 'TangentsandBinormals'
    "integer reparse of animation handle" = 'parseImportedHandle'
}

foreach ($item in $forbidden.GetEnumerator()) {
    if ($core.Contains($item.Value)) {
        throw "Core script still contains forbidden pattern: $($item.Key)"
    }
}

if ($macro -match '(?s)fileIn\s+bridgeScript.*?RUVB_ShowDialog\(\)' -and $macro -notmatch 'global\s+RUVB_ShowDialog') {
    throw "Macro can shadow RUVB_ShowDialog as an implicit local."
}

# MAXScript structure member functions are lexically scoped. A call to a member
# declared later in the same struct can be captured as an implicit local and
# evaluate to undefined at runtime. Reject all such forward references.
$structStart = $core.IndexOf("struct RUVB2027Core")
$structEndMarker = "RUVB2027 = RUVB2027Core()"
$structEnd = $core.IndexOf($structEndMarker)

if ($structStart -lt 0 -or $structEnd -lt 0 -or $structEnd -le $structStart) {
    throw "Could not isolate RUVB2027Core for dependency-order validation."
}

$structSource = $core.Substring($structStart, $structEnd - $structStart)
$fnMatches = [regex]::Matches($structSource, '(?m)^\s*fn\s+([A-Za-z_][A-Za-z0-9_]*)\b')

for ($i = 0; $i -lt $fnMatches.Count; $i++) {
    $caller = $fnMatches[$i].Groups[1].Value
    $bodyStart = $fnMatches[$i].Index
    $bodyEnd = if ($i + 1 -lt $fnMatches.Count) { $fnMatches[$i + 1].Index } else { $structSource.Length }
    $body = $structSource.Substring($bodyStart, $bodyEnd - $bodyStart)

    for ($j = $i + 1; $j -lt $fnMatches.Count; $j++) {
        $callee = $fnMatches[$j].Groups[1].Value
        if ([regex]::IsMatch($body, ('\b' + [regex]::Escape($callee) + '\s*\('), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            throw "Forward struct-member reference detected: $caller -> $callee. Reorder the functions before packaging."
        }
    }
}

if (Get-ChildItem $repoRoot -Recurse -File -Filter "*.mse") {
    throw "Encrypted MSE files are not allowed in this repository."
}

Write-Host "Static compatibility validation passed."

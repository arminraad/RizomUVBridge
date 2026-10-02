$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

$requiredFiles = @(
    "src\RizomUVBridge.ms",
    "macros\AR_RizomUVBridge.mcr",
    "install.ms",
    "mzp.run",
    "build\package.ps1"
)

foreach ($relativePath in $requiredFiles) {
    $fullPath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path $fullPath)) {
        throw "Missing required file: $relativePath"
    }
}

$core = Get-Content (Join-Path $repoRoot "src\RizomUVBridge.ms") -Raw

$requiredTokens = @(
    "maxVersion()",
    "snapshot sourceNode",
    "channelInfo.CopyChannel",
    "channelInfo.PasteChannel",
    "FBXExporterSetParam",
    "FBXImporterSetParam",
    'ZomLoad({File={Path=',
    'Prefs.FileSuffix',
    'shellLaunch exe args'
)

foreach ($token in $requiredTokens) {
    if (-not $core.Contains($token)) {
        throw "Core script is missing expected token: $token"
    }
}

if (Get-ChildItem $repoRoot -Recurse -File -Filter "*.mse") {
    throw "Encrypted MSE files are not allowed in this repository."
}

Write-Host "Static validation passed."

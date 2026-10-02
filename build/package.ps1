param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\dist")
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$buildRoot = Join-Path $repoRoot ".build"
$stage = Join-Path $buildRoot "mzp"
$zipPath = Join-Path $buildRoot "RizomUVBridge-3dsMax2027.zip"
$mzpPath = Join-Path $OutputDirectory "RizomUVBridge-3dsMax2027.mzp"

if (Test-Path $stage) {
    Remove-Item $stage -Recurse -Force
}

New-Item -ItemType Directory -Path $stage -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stage "python") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stage "macros") -Force | Out-Null
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

Copy-Item (Join-Path $repoRoot "python\ar_rizomuv_bridge.py") (Join-Path $stage "python\ar_rizomuv_bridge.py")
Copy-Item (Join-Path $repoRoot "macros\AR_RizomUVBridge.mcr") (Join-Path $stage "macros\AR_RizomUVBridge.mcr")
Copy-Item (Join-Path $repoRoot "install.ms") (Join-Path $stage "install.ms")
Copy-Item (Join-Path $repoRoot "mzp.run") (Join-Path $stage "mzp.run")

if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

if (Test-Path $mzpPath) {
    Remove-Item $mzpPath -Force
}

Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zipPath -CompressionLevel Optimal
Copy-Item $zipPath $mzpPath

Write-Host "Created: $mzpPath"

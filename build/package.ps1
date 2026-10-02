param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\dist")
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$buildRoot = Join-Path $repoRoot ".build"
$stage = Join-Path $buildRoot "mzp"
$zipPath = Join-Path $buildRoot "RizomUVBridge-3dsMax2027.zip"
$mzpPath = Join-Path $OutputDirectory "RizomUVBridge-3dsMax2027.mzp"

# Official Rizom-Lab RizomUVLink source pinned for reproducible packaging.
$rizomUVLinkCommit = "b3be77f8777aea4c192d893d01380b4c989ccd6c"
$rizomUVLinkBaseUrl = "https://raw.githubusercontent.com/RemiArq/RizomUVLink/$rizomUVLinkCommit"

if (Test-Path $stage) {
    Remove-Item $stage -Recurse -Force
}

New-Item -ItemType Directory -Path $stage -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stage "python") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stage "macros") -Force | Out-Null
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$vendorRoot = Join-Path $stage "python\RizomUVBridgeVendor\RizomUVLink"
$vendorWin = Join-Path $vendorRoot "win"
New-Item -ItemType Directory -Path $vendorWin -Force | Out-Null

Copy-Item (Join-Path $repoRoot "python\ar_rizomuv_bridge.py") (Join-Path $stage "python\ar_rizomuv_bridge.py")
Copy-Item (Join-Path $repoRoot "macros\AR_RizomUVBridge.mcr") (Join-Path $stage "macros\AR_RizomUVBridge.mcr")
Copy-Item (Join-Path $repoRoot "install.ms") (Join-Path $stage "install.ms")
Copy-Item (Join-Path $repoRoot "mzp.run") (Join-Path $stage "mzp.run")

$vendorFiles = @(
    @{ Remote = "LICENSE.md"; Local = (Join-Path $vendorRoot "LICENSE.md") },
    @{ Remote = "RizomUVLink.py"; Local = (Join-Path $vendorRoot "RizomUVLink.py") },
    @{ Remote = "RizomUVLinkBase.py"; Local = (Join-Path $vendorRoot "RizomUVLinkBase.py") },
    @{ Remote = "win/__init__.py"; Local = (Join-Path $vendorWin "__init__.py") },
    @{ Remote = "win/rizomuvlink_python313.pyd"; Local = (Join-Path $vendorWin "rizomuvlink_python313.pyd") },
    @{ Remote = "win/libsodium.dll"; Local = (Join-Path $vendorWin "libsodium.dll") },
    @{ Remote = "win/libzmq-v142-mt-4_3_4.dll"; Local = (Join-Path $vendorWin "libzmq-v142-mt-4_3_4.dll") }
)

$headers = @{ "User-Agent" = "RizomUVBridge-3dsMax2027-Packager" }

foreach ($item in $vendorFiles) {
    $url = "$rizomUVLinkBaseUrl/$($item.Remote)"
    Write-Host "Vendoring official RizomUVLink: $($item.Remote)"
    Invoke-WebRequest -Uri $url -OutFile $item.Local -Headers $headers
    if (-not (Test-Path $item.Local) -or (Get-Item $item.Local).Length -le 0) {
        throw "Failed to vendor RizomUVLink file: $($item.Remote)"
    }
}

if ((Get-Item (Join-Path $vendorWin "rizomuvlink_python313.pyd")).Length -lt 100000) {
    throw "Bundled Python 3.13 RizomUVLink binary is unexpectedly small."
}

if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

if (Test-Path $mzpPath) {
    Remove-Item $mzpPath -Force
}

Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zipPath -CompressionLevel Optimal
Copy-Item $zipPath $mzpPath

Write-Host "Created: $mzpPath"

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

$requiredFiles = @(
    "python\ar_rizomuv_bridge.py",
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

$pythonCore = Get-Content (Join-Path $repoRoot "python\ar_rizomuv_bridge.py") -Raw
$macro = Get-Content (Join-Path $repoRoot "macros\AR_RizomUVBridge.mcr") -Raw
$installer = Get-Content (Join-Path $repoRoot "install.ms") -Raw
$package = Get-Content (Join-Path $repoRoot "build\package.ps1") -Raw

$requiredPythonTokens = @(
    'VERSION = "0.3.0-alpha"',
    'import RizomUVLink',
    'CRizomUVLink()',
    '"Data.PolySizes"',
    '"Data.PolyXYZIDs"',
    '"Data.CoordsXYZ"',
    '"Data.PolyUVWIDs"',
    '"Data.CoordsUVW"',
    'link.Load(params)',
    'link.Save({"Data": True})',
    'return float(point.x), float(point.z), float(-point.y)',
    'rt.ChannelInfo.CopyChannel',
    'rt.ChannelInfo.PasteChannel',
    'Geometry topology changed in RizomUV'
)

foreach ($token in $requiredPythonTokens) {
    if (-not $pythonCore.Contains($token)) {
        throw "Python core is missing expected token: $token"
    }
}

$forbiddenPythonTokens = @(
    'rt.snapshot',
    'snapshotAsMesh',
    'rt.exportFile',
    'rt.importFile',
    'FBXEXP',
    'FBXIMP',
    'ObjExp',
    'ObjImp'
)

foreach ($token in $forbiddenPythonTokens) {
    if ($pythonCore.Contains($token)) {
        throw "Direct-link core contains forbidden geometry transport: $token"
    }
}

if (-not $macro.Contains('python.Execute')) {
    throw "Macro does not launch the Python bridge."
}

if (-not $installer.Contains('legacyCore')) {
    throw "Installer does not remove the retired MAXScript core."
}

if ($package.Contains('src\RizomUVBridge.ms')) {
    throw "Package still includes the retired MAXScript geometry core."
}

python -m py_compile (Join-Path $repoRoot "python\ar_rizomuv_bridge.py")
if ($LASTEXITCODE -ne 0) {
    throw "Python syntax compilation failed."
}

Write-Host "Direct RizomUVLink static validation passed."

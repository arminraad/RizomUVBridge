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
    'VERSION = "0.3.2-alpha"',
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
    'Geometry topology changed in RizomUV',
    'SETTINGS_PATH = Path(__file__).resolve().parent / "RizomUVBridgeSettings.json"',
    'def _choose_rizom_exe',
    'def _resolve_rizom_exe',
    'settings["rizomuv_exe"] = str(exe)',
    'self.set_exe = QtWidgets.QPushButton("Set RizomUV EXE")'
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

$packageRequired = @(
    'b3be77f8777aea4c192d893d01380b4c989ccd6c',
    'RizomUVLink.py',
    'RizomUVLinkBase.py',
    'rizomuvlink_python313.pyd',
    'libsodium.dll',
    'libzmq-v142-mt-4_3_4.dll'
)

foreach ($token in $packageRequired) {
    if (-not $package.Contains($token)) {
        throw "Package script does not vendor required RizomUVLink token: $token"
    }
}

$installerRequiredVendor = @(
    'RizomUVBridgeVendor',
    'rizomuvlink_python313.pyd',
    'libsodium.dll',
    'libzmq-v142-mt-4_3_4.dll'
)

foreach ($token in $installerRequiredVendor) {
    if (-not $installer.Contains($token)) {
        throw "Installer does not install required bundled RizomUVLink token: $token"
    }
}

python -m py_compile (Join-Path $repoRoot "python\ar_rizomuv_bridge.py")
if ($LASTEXITCODE -ne 0) {
    throw "Python syntax compilation failed."
}

Write-Host "Direct RizomUVLink static validation passed."

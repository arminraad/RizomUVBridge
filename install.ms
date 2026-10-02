/*
RizomUVBridge installer for 3ds Max 2027.
Installs the bridge plus a pinned official MIT RizomUVLink Python 3.13 runtime.
*/

fn RUVB_Install =
(
    local packageRoot = getFilenamePath (getSourceFileName())
    local targetPythonDir = (getDir #userScripts) + "\\Python\\"
    local targetModule = targetPythonDir + "ar_rizomuv_bridge.py"
    local targetVendor = targetPythonDir + "RizomUVBridgeVendor\\RizomUVLink\\"
    local targetVendorWin = targetVendor + "win\\"
    local targetMacro = (getDir #userMacros) + "\\AR_RizomUVBridge.mcr"
    local legacyCore = (getDir #userScripts) + "\\RizomUVBridge\\RizomUVBridge.ms"
    local macroError = undefined

    fn copyReplacing sourcePath targetPath =
    (
        if doesFileExist targetPath do deleteFile targetPath
        copyFile sourcePath targetPath
    )

    makeDir targetPythonDir
    makeDir (targetPythonDir + "RizomUVBridgeVendor\\")
    makeDir targetVendor
    makeDir targetVendorWin

    local sourceModule = packageRoot + "python\\ar_rizomuv_bridge.py"
    local sourceMacro = packageRoot + "macros\\AR_RizomUVBridge.mcr"
    local sourceVendor = packageRoot + "python\\RizomUVBridgeVendor\\RizomUVLink\\"
    local sourceVendorWin = sourceVendor + "win\\"

    local vendorCopies = #(
        #(sourceVendor + "LICENSE.md", targetVendor + "LICENSE.md"),
        #(sourceVendor + "RizomUVLink.py", targetVendor + "RizomUVLink.py"),
        #(sourceVendor + "RizomUVLinkBase.py", targetVendor + "RizomUVLinkBase.py"),
        #(sourceVendorWin + "__init__.py", targetVendorWin + "__init__.py"),
        #(sourceVendorWin + "rizomuvlink_python313.pyd", targetVendorWin + "rizomuvlink_python313.pyd"),
        #(sourceVendorWin + "libsodium.dll", targetVendorWin + "libsodium.dll"),
        #(sourceVendorWin + "libzmq-v142-mt-4_3_4.dll", targetVendorWin + "libzmq-v142-mt-4_3_4.dll")
    )

    if not doesFileExist sourceModule then
    (
        messageBox ("Installer cannot find: " + sourceModule) title:"RizomUVBridge"
        return false
    )

    if not copyReplacing sourceModule targetModule then
    (
        messageBox ("Could not install: " + targetModule) title:"RizomUVBridge"
        return false
    )

    for pair in vendorCopies do
    (
        if not doesFileExist pair[1] then
        (
            messageBox ("Installer cannot find bundled RizomUVLink file:\n" + pair[1]) title:"RizomUVBridge"
            return false
        )

        if not copyReplacing pair[1] pair[2] then
        (
            messageBox ("Could not install RizomUVLink file:\n" + pair[2]) title:"RizomUVBridge"
            return false
        )
    )

    if not copyReplacing sourceMacro targetMacro then
    (
        messageBox ("Could not install: " + targetMacro) title:"RizomUVBridge"
        return false
    )

    if doesFileExist legacyCore do deleteFile legacyCore

    if not executeScriptFile targetMacro errormessage:&macroError then
    (
        messageBox ("Macro registration failed.\n\n" + (macroError as string)) title:"RizomUVBridge"
        return false
    )

    local initResult = python.Init throwOnError:false
    if initResult != #success then
    (
        messageBox ("Python initialization failed.\n\n" + python.GetLastError()) title:"RizomUVBridge"
        return false
    )

    local pyDir = substituteString targetPythonDir "\\" "/"
    local pyCmd = "import sys, importlib; p=r'" + pyDir + "'; sys.path.insert(0,p) if p not in sys.path else None; importlib.invalidate_caches(); old=sys.modules.get('ar_rizomuv_bridge'); old.shutdown() if old is not None and hasattr(old,'shutdown') else None; sys.modules.pop('ar_rizomuv_bridge',None); import ar_rizomuv_bridge; ar_rizomuv_bridge.show()"
    local pyResult = python.Execute pyCmd throwOnError:false

    if pyResult != #success then
    (
        messageBox ("RizomUVBridge Python validation failed.\n\n" + python.GetLastError()) title:"RizomUVBridge"
        return false
    )

    format "RizomUVBridge installed with bundled RizomUVLink to: %\n" targetPythonDir
    true
)

RUVB_Install()

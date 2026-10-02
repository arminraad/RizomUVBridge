/*
RizomUVBridge installer for 3ds Max 2027.
Installs a Python/PySide6 bridge backed by Rizom-Lab's installed RizomUVLink.
*/

fn RUVB_Install =
(
    local packageRoot = getFilenamePath (getSourceFileName())
    local targetPythonDir = (getDir #userScripts) + "\\Python\\"
    local targetModule = targetPythonDir + "ar_rizomuv_bridge.py"
    local targetMacro = (getDir #userMacros) + "\\AR_RizomUVBridge.mcr"
    local legacyCore = (getDir #userScripts) + "\\RizomUVBridge\\RizomUVBridge.ms"
    local macroError = undefined

    fn copyReplacing sourcePath targetPath =
    (
        if doesFileExist targetPath do deleteFile targetPath
        copyFile sourcePath targetPath
    )

    makeDir targetPythonDir

    local sourceModule = packageRoot + "python\\ar_rizomuv_bridge.py"
    local sourceMacro = packageRoot + "macros\\AR_RizomUVBridge.mcr"

    if not doesFileExist sourceModule then
    (
        messageBox ("Installer cannot find: " + sourceModule) title:"RizomUVBridge"
        return false
    )

    if not doesFileExist sourceMacro then
    (
        messageBox ("Installer cannot find: " + sourceMacro) title:"RizomUVBridge"
        return false
    )

    if not copyReplacing sourceModule targetModule then
    (
        messageBox ("Could not install: " + targetModule) title:"RizomUVBridge"
        return false
    )

    if not copyReplacing sourceMacro targetMacro then
    (
        messageBox ("Could not install: " + targetMacro) title:"RizomUVBridge"
        return false
    )

    -- Remove the retired MAXScript geometry-transport core from alpha 0.1/0.2.
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
    local pyCmd = "import sys, importlib; p=r'" + pyDir + "'; sys.path.insert(0,p) if p not in sys.path else None; importlib.invalidate_caches(); old=sys.modules.get('ar_rizomuv_bridge'); old.shutdown() if old is not None and hasattr(old,'shutdown') else None; import ar_rizomuv_bridge; importlib.reload(ar_rizomuv_bridge); ar_rizomuv_bridge.show()"
    local pyResult = python.Execute pyCmd throwOnError:false

    if pyResult != #success then
    (
        messageBox ("RizomUVBridge Python validation failed.\n\n" + python.GetLastError()) title:"RizomUVBridge"
        return false
    )

    format "RizomUVBridge Python module installed to: %\n" targetModule
    true
)

RUVB_Install()

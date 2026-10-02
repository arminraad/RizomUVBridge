/*
RizomUVBridge installer for 3ds Max 2027.
Keeps the installation source-readable and does not modify the CUI file directly.
*/

fn RUVB_Install =
(
    global RUVB_ShowDialog

    local packageRoot = getFilenamePath (getSourceFileName())
    local targetDir = (getDir #userScripts) + "\\RizomUVBridge\\"
    local targetScript = targetDir + "RizomUVBridge.ms"
    local targetMacro = (getDir #userMacros) + "\\AR_RizomUVBridge.mcr"
    local coreError = undefined
    local macroError = undefined

    fn copyReplacing sourcePath targetPath =
    (
        if doesFileExist targetPath do deleteFile targetPath
        copyFile sourcePath targetPath
    )

    makeDir targetDir

    local sourceScript = packageRoot + "src\\RizomUVBridge.ms"
    local sourceMacro = packageRoot + "macros\\AR_RizomUVBridge.mcr"

    if not doesFileExist sourceScript then
    (
        messageBox ("Installer cannot find: " + sourceScript) title:"RizomUVBridge"
        return false
    )

    if not doesFileExist sourceMacro then
    (
        messageBox ("Installer cannot find: " + sourceMacro) title:"RizomUVBridge"
        return false
    )

    if not copyReplacing sourceScript targetScript then
    (
        messageBox ("Could not install: " + targetScript) title:"RizomUVBridge"
        return false
    )

    if not copyReplacing sourceMacro targetMacro then
    (
        messageBox ("Could not install: " + targetMacro) title:"RizomUVBridge"
        return false
    )

    if not executeScriptFile targetScript errormessage:&coreError then
    (
        messageBox ("Core script validation failed.\n\n" + (coreError as string)) title:"RizomUVBridge"
        return false
    )

    if RUVB_ShowDialog == undefined then
    (
        messageBox "Core script loaded but did not expose RUVB_ShowDialog." title:"RizomUVBridge"
        return false
    )

    if not executeScriptFile targetMacro errormessage:&macroError then
    (
        messageBox ("Macro registration failed.\n\n" + (macroError as string)) title:"RizomUVBridge"
        return false
    )

    format "RizomUVBridge installed to: %\n" targetDir
    RUVB_ShowDialog()
    true
)

RUVB_Install()

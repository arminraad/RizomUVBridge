/*
RizomUVBridge installer for 3ds Max 2027.
Keeps the installation source-readable and does not modify the CUI file directly.
*/

(
    local packageRoot = getFilenamePath (getSourceFileName())
    local targetDir = (getDir #userScripts) + "\\RizomUVBridge\\"
    local targetScript = targetDir + "RizomUVBridge.ms"
    local targetMacro = (getDir #userMacros) + "\\AR_RizomUVBridge.mcr"

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

    copyReplacing sourceScript targetScript
    copyReplacing sourceMacro targetMacro

    fileIn targetMacro quiet:true

    try
    (
        macros.run "AR Tools" "RizomUVBridge2027"
    )
    catch
    (
        messageBox "Installed successfully. Open Customize User Interface and run 'RizomUV Bridge 2027' from the 'AR Tools' category." title:"RizomUVBridge"
    )

    format "RizomUVBridge installed to: %\n" targetDir
    true
)

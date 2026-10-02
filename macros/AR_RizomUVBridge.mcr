macroScript RizomUVBridge2027
category:"AR Tools"
buttonText:"RizomUV Bridge 2027"
toolTip:"RizomUV Bridge for 3ds Max 2027"
(
    local bridgeScript = (getDir #userScripts) + "\\RizomUVBridge\\RizomUVBridge.ms"

    if doesFileExist bridgeScript then
    (
        fileIn bridgeScript quiet:true
        RUVB_ShowDialog()
    )
    else
    (
        messageBox ("RizomUVBridge core script was not found:\n" + bridgeScript) title:"RizomUVBridge"
    )
)

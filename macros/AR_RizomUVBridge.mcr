macroScript RizomUVBridge2027
category:"AR Tools"
buttonText:"RizomUV Bridge 2027"
toolTip:"RizomUV Bridge for 3ds Max 2027"
(
    global RUVB_ShowDialog

    local bridgeScript = (getDir #userScripts) + "\\RizomUVBridge\\RizomUVBridge.ms"
    local loadError = undefined

    if doesFileExist bridgeScript then
    (
        if executeScriptFile bridgeScript errormessage:&loadError then
        (
            if RUVB_ShowDialog != undefined then
            (
                RUVB_ShowDialog()
            )
            else
            (
                messageBox "RizomUVBridge loaded, but its global dialog entry point is unavailable." title:"RizomUVBridge"
            )
        )
        else
        (
            messageBox ("RizomUVBridge failed to load.\n\n" + (loadError as string)) title:"RizomUVBridge"
        )
    )
    else
    (
        messageBox ("RizomUVBridge core script was not found:\n" + bridgeScript) title:"RizomUVBridge"
    )
)

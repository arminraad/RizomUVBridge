macroScript RizomUVBridge2027
category:"AR Tools"
buttonText:"RizomUV Bridge 2027"
toolTip:"RizomUV Bridge for 3ds Max 2027"
(
    local pyDir = substituteString ((getDir #userScripts) + "\\Python") "\\" "/"
    local cmd = "import sys; p=r'" + pyDir + "'; sys.path.insert(0,p) if p not in sys.path else None; import ar_rizomuv_bridge; ar_rizomuv_bridge.show()"

    local result = python.Execute cmd throwOnError:false

    if result != #success do
    (
        messageBox ("RizomUVBridge Python launch failed.\n\n" + python.GetLastError()) title:"RizomUVBridge"
    )
)

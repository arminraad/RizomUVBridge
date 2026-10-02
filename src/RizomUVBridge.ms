/*
RizomUVBridge 0.1.0-alpha
Target: Autodesk 3ds Max 2027 / 2027.1
Purpose: Non-destructive UV round-trip between 3ds Max and RizomUV.

This implementation was written separately for this repository.
*/

global RUVB2027
global RUVB2027_UI

struct RUVB2027SessionItem
(
    handle,
    tempName
)

struct RUVB2027Core
(
    version = "0.1.0-alpha",
    sessionItems = #(),
    sourceHandles = #(),
    waitingForResult = false,
    lastOutputSize = -1,
    stableTicks = 0,

    fn bridgeDir =
    (
        (getDir #userScripts) + "\\RizomUVBridge\\"
    ),

    fn iniPath =
    (
        (bridgeDir()) + "RizomUVBridge.ini"
    ),

    fn exchangeDir =
    (
        ensureConfig()
        local configured = getINISetting (iniPath()) "Bridge" "ExchangeFolder"

        if configured == "" then
        (
            configured = (sysInfo.tempDir) + "RizomUVBridge\\"
            makeDir configured
            setINISetting (iniPath()) "Bridge" "ExchangeFolder" configured
        )

        if (substring configured configured.count 1) != "\\" do configured += "\\"
        makeDir configured
        configured
    ),

    fn exchangeBase =
    (
        (exchangeDir()) + "RUVB_exchange"
    ),

    fn exchangeInput =
    (
        (exchangeBase()) + ".fbx"
    ),

    fn exchangeOutput =
    (
        (exchangeBase()) + "_out.fbx"
    ),

    fn luaPath =
    (
        (exchangeDir()) + "RUVB_launch.lua"
    ),

    fn ensureConfig =
    (
        makeDir (bridgeDir())

        if not doesFileExist (iniPath()) then
        (
            setINISetting (iniPath()) "Bridge" "RizomUVExe" ""
            setINISetting (iniPath()) "Bridge" "ExchangeFolder" ((sysInfo.tempDir) + "RizomUVBridge\\")
            setINISetting (iniPath()) "Bridge" "UVChannel" "1"
            setINISetting (iniPath()) "Bridge" "AutoImport" "1"
        )

        true
    ),

    fn isMax2027OrNewer =
    (
        local majorCode = (maxVersion())[1]
        majorCode >= 29000
    ),

    fn configuredUVChannel =
    (
        ensureConfig()
        local value = (getINISetting (iniPath()) "Bridge" "UVChannel") as integer
        if value == undefined or value < 1 then 1 else value
    ),

    fn setConfiguredUVChannel value =
    (
        ensureConfig()
        setINISetting (iniPath()) "Bridge" "UVChannel" (value as string)
    ),

    fn autoImportEnabled =
    (
        ensureConfig()
        (getINISetting (iniPath()) "Bridge" "AutoImport") == "1"
    ),

    fn setAutoImportEnabled state =
    (
        ensureConfig()
        setINISetting (iniPath()) "Bridge" "AutoImport" (if state then "1" else "0")
    ),

    fn rizomExe =
    (
        ensureConfig()
        getINISetting (iniPath()) "Bridge" "RizomUVExe"
    ),

    fn chooseRizomExe =
    (
        ensureConfig()

        local picked = getOpenFileName             caption:"Select RizomUV executable"             filename:"rizomuv.exe"             types:"Executable (*.exe)|*.exe|"

        if picked != undefined do
        (
            setINISetting (iniPath()) "Bridge" "RizomUVExe" picked
        )

        picked
    ),

    fn ensureRizomExe =
    (
        local exe = rizomExe()

        if exe == "" or not doesFileExist exe then
        (
            exe = chooseRizomExe()
        )

        exe != undefined and exe != "" and doesFileExist exe
    ),

    fn deleteIfPresent path =
    (
        if doesFileExist path do
        (
            try(deleteFile path)catch()
        )
    ),

    fn cleanupExchange =
    (
        deleteIfPresent (exchangeInput())
        deleteIfPresent (exchangeOutput())
        deleteIfPresent (luaPath())
        lastOutputSize = -1
        stableTicks = 0
    ),

    fn getNodeByHandle handleValue =
    (
        local found = undefined

        for n in objects while found == undefined do
        (
            if (getHandleByAnim n) == handleValue do found = n
        )

        found
    ),

    fn restoreSourceSelection =
    (
        local nodes = #()

        for h in sourceHandles do
        (
            local n = getNodeByHandle h
            if n != undefined do append nodes n
        )

        if nodes.count > 0 then select nodes else max select none
    ),

    fn createSnapshots =
    (
        sessionItems = #()
        sourceHandles = #()

        local tempNodes = #()
        local originalSelection = selection as array

        for sourceNode in originalSelection do
        (
            if superClassOf sourceNode == GeometryClass then
            (
                local sourceHandle = getHandleByAnim sourceNode
                local snap = undefined

                with undo off
                (
                    snap = snapshot sourceNode
                    convertToPoly snap
                    snap.name = "RUVB_" + (sourceHandle as string)
                )

                append sourceHandles sourceHandle
                append sessionItems (RUVB2027SessionItem handle:sourceHandle tempName:snap.name)
                append tempNodes snap
            )
        )

        tempNodes
    ),

    fn configureFBXExport =
    (
        try(pluginManager.loadClass FBXEXP)catch()

        try(FBXExporterSetParam "Animation" false)catch()
        try(FBXExporterSetParam "Cameras" false)catch()
        try(FBXExporterSetParam "Lights" false)catch()
        try(FBXExporterSetParam "EmbedTextures" false)catch()
        try(FBXExporterSetParam "GenerateLog" false)catch()
        try(FBXExporterSetParam "SmoothingGroups" true)catch()
        try(FBXExporterSetParam "SmoothMeshExport" true)catch()
        try(FBXExporterSetParam "TangentsandBinormals" false)catch()
        try(FBXExporterSetParam "Preserveinstances" false)catch()
        try(FBXExporterSetParam "Triangulate" false)catch()
        try(FBXExporterSetParam "UpAxis" "Y")catch()

        true
    ),

    fn configureFBXImport =
    (
        try(pluginManager.loadClass FBXIMP)catch()

        try(FBXImporterSetParam "Mode" #create)catch()
        try(FBXImporterSetParam "Animation" false)catch()
        try(FBXImporterSetParam "Cameras" false)catch()
        try(FBXImporterSetParam "Lights" false)catch()
        try(FBXImporterSetParam "GenerateLog" false)catch()
        try(FBXImporterSetParam "SmoothingGroups" true)catch()
        try(FBXImporterSetParam "UpAxis" "Y")catch()

        true
    ),

    fn exportSnapshots tempNodes =
    (
        if tempNodes.count == 0 then return false

        configureFBXExport()

        select tempNodes

        local ok = true
        try
        (
            exportFile (exchangeInput()) #noPrompt selectedOnly:true using:FBXEXP
        )
        catch
        (
            ok = false
        )

        with undo off
        (
            for n in tempNodes where isValidNode n do delete n
        )

        restoreSourceSelection()
        ok and doesFileExist (exchangeInput())
    ),

    fn luaSafePath pathValue =
    (
        substituteString pathValue "\\" "/"
    ),

    fn writeLaunchLua mode =
    (
        local pathForLua = luaSafePath (exchangeInput())
        local stream = createFile (luaPath()) writeBOM:false

        if stream == undefined then return false

        if mode == #edit then
        (
            format "ZomLoad({File={Path=\"%\", ImportGroups=true, XYZUVW=true, UVWProps=true}, NormalizeUVW=true})\n" pathForLua to:stream
        )
        else
        (
            format "ZomLoad({File={Path=\"%\", ImportGroups=true, XYZ=true}, NormalizeUVW=true})\n" pathForLua to:stream
        )

        format "ZomSet({Path=\"Prefs.FileSuffix\", Value=\"_out\"})\n" to:stream
        format "-- Edit UVs in RizomUV, then Save. The bridge watches for the _out FBX.\n" to:stream

        flush stream
        close stream
        true
    ),

    fn launchRizom =
    (
        if not ensureRizomExe() then return false

        local exe = rizomExe()
        local args = "-cfi \"" + (luaPath()) + "\""

        try
        (
            shellLaunch exe args
            true
        )
        catch
        (
            false
        )
    ),

    fn beginRoundTrip mode uvChannel =
    (
        if selection.count == 0 then
        (
            messageBox "Select at least one geometry object." title:"RizomUVBridge"
            return false
        )

        if not isMax2027OrNewer() then
        (
            local continueAnyway = queryBox                 "This build targets 3ds Max 2027 or newer. Continue anyway?"                 title:"RizomUVBridge"

            if not continueAnyway then return false
        )

        if not ensureRizomExe() then
        (
            messageBox "A valid RizomUV executable is required." title:"RizomUVBridge"
            return false
        )

        setConfiguredUVChannel uvChannel
        cleanupExchange()

        local tempNodes = createSnapshots()

        if tempNodes.count == 0 then
        (
            messageBox "No geometry objects were found in the selection." title:"RizomUVBridge"
            return false
        )

        if not exportSnapshots tempNodes then
        (
            messageBox "FBX export failed. Check that the Autodesk FBX plug-in is available." title:"RizomUVBridge"
            return false
        )

        if not writeLaunchLua mode then
        (
            messageBox "Could not create the RizomUV launch script." title:"RizomUVBridge"
            return false
        )

        if not launchRizom() then
        (
            messageBox "RizomUV could not be launched." title:"RizomUVBridge"
            return false
        )

        waitingForResult = true
        lastOutputSize = -1
        stableTicks = 0
        true
    ),

    fn parseImportedHandle nodeName =
    (
        if not matchPattern nodeName pattern:"RUVB_*" then return undefined

        local parts = filterString nodeName "_"
        if parts.count < 2 then return undefined

        try(parts[2] as integer)catch(undefined)
    ),

    fn topologyMatches importedNode sourceNode =
    (
        local probe = undefined
        local result = false

        with undo off
        (
            try
            (
                probe = snapshot sourceNode
                convertToPoly probe
                convertToPoly importedNode

                result =                     ((polyOp.getNumVerts probe) == (polyOp.getNumVerts importedNode)) and                     ((polyOp.getNumFaces probe) == (polyOp.getNumFaces importedNode))

                delete probe
                probe = undefined
            )
            catch
            (
                if probe != undefined and isValidNode probe do delete probe
                result = false
            )
        )

        result
    ),

    fn transferUVChannel importedNode sourceNode uvChannel =
    (
        if not topologyMatches importedNode sourceNode then return #topologyMismatch

        local mapVertCount = 0
        try(mapVertCount = polyOp.getNumMapVerts importedNode uvChannel)catch(mapVertCount = 0)

        if mapVertCount <= 0 then return #missingUV

        local beforeModifierCount = sourceNode.modifiers.count
        local pasted = true

        try
        (
            channelInfo.CopyChannel importedNode 3 uvChannel
            channelInfo.PasteChannel sourceNode 3 uvChannel

            if sourceNode.modifiers.count > beforeModifierCount do
            (
                try(sourceNode.modifiers[1].name = "RizomUV UV Channel " + (uvChannel as string))catch()
            )
        )
        catch
        (
            pasted = false
        )

        if pasted then #ok else #pasteFailed
    ),

    fn importResult uvChannel =
    (
        if not doesFileExist (exchangeOutput()) then
        (
            messageBox "No RizomUV output FBX was found yet. Save the model in RizomUV first." title:"RizomUVBridge"
            return false
        )

        configureFBXImport()

        local oldNodes = objects as array
        local importedNodes = #()
        local okCount = 0
        local mismatchCount = 0
        local missingCount = 0
        local failedCount = 0

        try
        (
            importFile (exchangeOutput()) #noPrompt using:FBXIMP
        )
        catch
        (
            messageBox "FBX import failed." title:"RizomUVBridge"
            return false
        )

        for n in objects where (findItem oldNodes n) == 0 do append importedNodes n

        undo "RizomUV UV Import" on
        (
            for importedNode in importedNodes do
            (
                local sourceHandle = parseImportedHandle importedNode.name

                if sourceHandle != undefined then
                (
                    local sourceNode = getNodeByHandle sourceHandle

                    if sourceNode != undefined and superClassOf importedNode == GeometryClass then
                    (
                        local transferResult = transferUVChannel importedNode sourceNode uvChannel

                        case transferResult of
                        (
                            #ok: okCount += 1
                            #topologyMismatch: mismatchCount += 1
                            #missingUV: missingCount += 1
                            default: failedCount += 1
                        )
                    )
                )
            )
        )

        with undo off
        (
            for n in importedNodes where isValidNode n do delete n
        )

        restoreSourceSelection()
        waitingForResult = false
        deleteIfPresent (exchangeOutput())

        format "RizomUVBridge import: ok:% topologyMismatch:% missingUV:% failed:%\n"             okCount mismatchCount missingCount failedCount

        if mismatchCount > 0 or missingCount > 0 or failedCount > 0 then
        (
            messageBox                 ("UV import completed with warnings.\n\nApplied: " + (okCount as string) +                 "\nTopology mismatch: " + (mismatchCount as string) +                 "\nMissing UV channel: " + (missingCount as string) +                 "\nFailed: " + (failedCount as string))                 title:"RizomUVBridge"
        )

        okCount > 0
    ),

    fn pollOutputReady =
    (
        if not waitingForResult then return false
        if not doesFileExist (exchangeOutput()) then return false

        local currentSize = getFileSize (exchangeOutput())

        if currentSize > 0 and currentSize == lastOutputSize then
        (
            stableTicks += 1
        )
        else
        (
            stableTicks = 0
            lastOutputSize = currentSize
        )

        stableTicks >= 2
    )
)

RUVB2027 = RUVB2027Core()

try(destroyDialog RUVB2027_UI)catch()

rollout RUVB2027_UI "RizomUV Bridge 2027"
(
    label lbl_version ("Version " + RUVB2027.version) align:#left
    label lbl_status "Ready" align:#left

    spinner spn_channel "UV channel:" range:[1,99,1] type:#integer fieldWidth:45

    button btn_new "Send New UV" width:130 height:30 across:2
    button btn_edit "Send Edit UV" width:130 height:30

    checkbox chk_auto "Import automatically after RizomUV Save" checked:true

    button btn_import "Import Result" width:130 height:28 across:2
    button btn_exe "Set RizomUV EXE" width:130 height:28

    timer resultTimer interval:700 active:false

    on RUVB2027_UI open do
    (
        RUVB2027.ensureConfig()
        spn_channel.value = RUVB2027.configuredUVChannel()
        chk_auto.checked = RUVB2027.autoImportEnabled()
        lbl_status.text = if RUVB2027.isMax2027OrNewer() then "Ready - 3ds Max 2027+" else "Compatibility warning"
    )

    on spn_channel changed value do
    (
        RUVB2027.setConfiguredUVChannel value
    )

    on chk_auto changed state do
    (
        RUVB2027.setAutoImportEnabled state
    )

    on btn_exe pressed do
    (
        local picked = RUVB2027.chooseRizomExe()
        lbl_status.text = if picked == undefined then "RizomUV path unchanged" else "RizomUV path updated"
    )

    on btn_new pressed do
    (
        lbl_status.text = "Exporting..."
        if RUVB2027.beginRoundTrip #new spn_channel.value then
        (
            lbl_status.text = "Waiting for RizomUV Save..."
            resultTimer.active = chk_auto.checked
        )
        else
        (
            lbl_status.text = "Send failed"
        )
    )

    on btn_edit pressed do
    (
        lbl_status.text = "Exporting..."
        if RUVB2027.beginRoundTrip #edit spn_channel.value then
        (
            lbl_status.text = "Waiting for RizomUV Save..."
            resultTimer.active = chk_auto.checked
        )
        else
        (
            lbl_status.text = "Send failed"
        )
    )

    on btn_import pressed do
    (
        resultTimer.active = false
        lbl_status.text = "Importing..."

        if RUVB2027.importResult spn_channel.value then
            lbl_status.text = "UV import complete"
        else
            lbl_status.text = "No UV data imported"
    )

    on resultTimer tick do
    (
        if RUVB2027.pollOutputReady() then
        (
            resultTimer.active = false
            lbl_status.text = "Importing..."

            if RUVB2027.importResult spn_channel.value then
                lbl_status.text = "UV import complete"
            else
                lbl_status.text = "Import finished with no applied UV"
        )
    )

    on RUVB2027_UI close do
    (
        resultTimer.active = false
    )
)

fn RUVB_ShowDialog =
(
    try(destroyDialog RUVB2027_UI)catch()
    createDialog RUVB2027_UI 290 190 style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
)

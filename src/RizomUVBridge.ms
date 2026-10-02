/*
RizomUVBridge 0.2.0-alpha
Target: Autodesk 3ds Max 2027 / 2027.1
Purpose: Topology-preserving UV round-trip between 3ds Max and RizomUV.

Transport:
- No snapshot/TriMesh conversion.
- No FBX geometry transport.
- No 3ds Max OBJ importer/exporter.
- The bridge writes polygonal OBJ itself and parses the returned OBJ itself.
*/

global RUVB2027
global RUVB2027_UI
global RUVB_ShowDialog

struct RUVB2027SessionItem
(
    handle = 0,
    tempName = "",
    vertexCount = 0,
    faceCount = 0,
    faceDegrees = #(),
    topologySignature = ""
)

struct RUVB2027ObjBlock
(
    name = "",
    faces = #()
)

struct RUVB2027Core
(
    version = "0.2.0-alpha",
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

        if configured.count == 0 or (substring configured configured.count 1) != "\\" do configured += "\\"
        makeDir configured
        configured
    ),

    fn exchangeBase =
    (
        (exchangeDir()) + "RUVB_exchange"
    ),

    fn exchangeInput =
    (
        (exchangeBase()) + ".obj"
    ),

    fn exchangeOutput =
    (
        (exchangeBase()) + "_out.obj"
    ),

    fn luaPath =
    (
        (exchangeDir()) + "RUVB_launch.lua"
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

        local picked = getOpenFileName caption:"Select RizomUV executable" filename:"rizomuv.exe" types:"Executable (*.exe)|*.exe|"

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

        try(found = getAnimByHandle handleValue)catch(found = undefined)

        if found != undefined and isValidNode found then found else undefined
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

    fn numberText value =
    (
        substituteString (value as string) "," "."
    ),

    fn faceArraysFromPoly polyValue =
    (
        local result = #()
        local faceCount = polyOp.getNumFaces polyValue

        for faceIndex = 1 to faceCount do
        (
            append result (polyOp.getFaceVerts polyValue faceIndex)
        )

        result
    ),

    fn topologySignature faceArrays =
    (
        local seen = #()
        local signature = ""

        for faceVerts in faceArrays do
        (
            signature += (faceVerts.count as string) + ":"

            for vertexIndex in faceVerts do
            (
                local mappedIndex = findItem seen vertexIndex

                if mappedIndex == 0 then
                (
                    append seen vertexIndex
                    mappedIndex = seen.count
                )

                signature += (mappedIndex as string) + ","
            )

            signature += ";"
        )

        signature
    ),

    fn makeExchangeClone sourceNode =
    (
        local tempNode = undefined

        try
        (
            tempNode = copy sourceNode
            convertToPoly tempNode
        )
        catch
        (
            if tempNode != undefined and isValidNode tempNode do delete tempNode
            tempNode = undefined
        )

        if tempNode != undefined and classOf tempNode.baseObject == Editable_Poly then tempNode else undefined
    ),

    fn createExchangeClones =
    (
        sessionItems = #()
        sourceHandles = #()

        local clones = #()
        local originalSelection = selection as array

        for sourceNode in originalSelection do
        (
            if superClassOf sourceNode == GeometryClass then
            (
                local sourceHandle = getHandleByAnim sourceNode
                local tempNode = makeExchangeClone sourceNode

                if tempNode != undefined then
                (
                    tempNode.name = "RUVB_" + (sourceHandle as string)

                    local polyValue = tempNode.baseObject
                    local faces = faceArraysFromPoly polyValue
                    local degrees = for f in faces collect f.count

                    append sourceHandles sourceHandle
                    append sessionItems (RUVB2027SessionItem                         handle:sourceHandle                         tempName:tempNode.name                         vertexCount:(polyOp.getNumVerts polyValue)                         faceCount:faces.count                         faceDegrees:degrees                         topologySignature:(topologySignature faces))

                    append clones tempNode
                )
            )
        )

        clones
    ),

    fn deleteExchangeClones clones =
    (
        with undo off
        (
            for n in clones where isValidNode n do delete n
        )

        restoreSourceSelection()
    ),

    fn hasUsableMap polyValue uvChannel =
    (
        local ok = false

        try
        (
            ok = (polyOp.getMapSupport polyValue uvChannel) and ((polyOp.getNumMapVerts polyValue uvChannel) > 0)
        )
        catch
        (
            ok = false
        )

        ok
    ),

    fn writeObjExchange clones mode uvChannel =
    (
        local stream = createFile (exchangeInput()) writeBOM:false
        if stream == undefined then return false

        format "# RizomUVBridge % - topology-preserving OBJ\n" version to:stream
        format "# Geometry is written as original polygon faces; no triangulation.\n" to:stream

        local vertexOffset = 0
        local mapOffset = 0
        local success = true

        try
        (
            for tempNode in clones do
            (
                local polyValue = tempNode.baseObject
                local vertexCount = polyOp.getNumVerts polyValue
                local faceCount = polyOp.getNumFaces polyValue
                local exportMap = false
                local mapCount = 0

                if mode == #edit do exportMap = hasUsableMap polyValue uvChannel
                if exportMap do mapCount = polyOp.getNumMapVerts polyValue uvChannel

                format "o %\n" tempNode.name to:stream
                format "g %\n" tempNode.name to:stream

                for vertexIndex = 1 to vertexCount do
                (
                    local p = (polyOp.getVert polyValue vertexIndex) * tempNode.objectTransform
                    format "v % % %\n" (numberText p.x) (numberText p.y) (numberText p.z) to:stream
                )

                if exportMap then
                (
                    for mapIndex = 1 to mapCount do
                    (
                        local uvw = polyOp.getMapVert polyValue uvChannel mapIndex
                        format "vt % % %\n" (numberText uvw.x) (numberText uvw.y) (numberText uvw.z) to:stream
                    )
                )

                for faceIndex = 1 to faceCount do
                (
                    local faceVerts = polyOp.getFaceVerts polyValue faceIndex
                    local mapFace = undefined
                    local writeMappedFace = false

                    if exportMap then
                    (
                        try
                        (
                            mapFace = polyOp.getMapFace polyValue uvChannel faceIndex
                            writeMappedFace = mapFace != undefined and mapFace.count == faceVerts.count
                        )
                        catch
                        (
                            writeMappedFace = false
                        )
                    )

                    local line = "f"

                    for corner = 1 to faceVerts.count do
                    (
                        local objVertexIndex = vertexOffset + faceVerts[corner]

                        if writeMappedFace then
                        (
                            local objMapIndex = mapOffset + mapFace[corner]
                            line += " " + (objVertexIndex as string) + "/" + (objMapIndex as string)
                        )
                        else
                        (
                            line += " " + (objVertexIndex as string)
                        )
                    )

                    format "%\n" line to:stream
                )

                vertexOffset += vertexCount
                if exportMap do mapOffset += mapCount
            )
        )
        catch
        (
            success = false
        )

        flush stream
        close stream

        success and doesFileExist (exchangeInput())
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
        format "-- Do not alter geometry topology. Edit UVs only, then Save.\n" to:stream

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
            local continueAnyway = queryBox "This build targets 3ds Max 2027 or newer. Continue anyway?" title:"RizomUVBridge"
            if not continueAnyway then return false
        )

        if not ensureRizomExe() then
        (
            messageBox "A valid RizomUV executable is required." title:"RizomUVBridge"
            return false
        )

        setConfiguredUVChannel uvChannel
        cleanupExchange()

        local clones = createExchangeClones()

        if clones.count == 0 then
        (
            messageBox "No compatible geometry objects were found in the selection." title:"RizomUVBridge"
            return false
        )

        local exported = writeObjExchange clones mode uvChannel
        deleteExchangeClones clones

        if not exported then
        (
            messageBox "Topology-preserving OBJ export failed." title:"RizomUVBridge"
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

    fn resolveObjIndex rawIndex currentCount =
    (
        if rawIndex > 0 then rawIndex else (currentCount + rawIndex + 1)
    ),

    fn parseFaceToken token vertexCount mapCount =
    (
        local firstSlash = findString token "/"
        local vertexText = token
        local mapText = ""

        if firstSlash != undefined then
        (
            vertexText = substring token 1 (firstSlash - 1)

            local restLength = token.count - firstSlash
            local rest = if restLength > 0 then substring token (firstSlash + 1) restLength else ""
            local secondSlash = if rest.count > 0 then findString rest "/" else undefined

            if secondSlash != undefined then
                mapText = if secondSlash > 1 then substring rest 1 (secondSlash - 1) else ""
            else
                mapText = rest
        )

        local vertexIndex = 0
        local mapIndex = 0

        try(vertexIndex = vertexText as integer)catch(vertexIndex = 0)
        if mapText != "" do try(mapIndex = mapText as integer)catch(mapIndex = 0)

        if vertexIndex != 0 do vertexIndex = resolveObjIndex vertexIndex vertexCount
        if mapIndex != 0 do mapIndex = resolveObjIndex mapIndex mapCount

        #(vertexIndex, mapIndex)
    ),

    fn readObjResult path =
    (
        local stream = openFile path
        if stream == undefined then return undefined

        local mapVerts = #()
        local blocks = #()
        local currentBlock = undefined
        local vertexCount = 0
        local usesObjectStatements = false

        while not eof stream do
        (
            local line = readLine stream

            if line != undefined and line.count > 1 then
            (
                if (substring line 1 2) == "v " then
                (
                    vertexCount += 1
                )
                else if line.count > 2 and (substring line 1 3) == "vt " then
                (
                    local parts = filterString line " \t"

                    if parts.count >= 3 then
                    (
                        local u = 0.0
                        local v = 0.0
                        local w = 0.0

                        try(u = parts[2] as float)catch()
                        try(v = parts[3] as float)catch()
                        if parts.count >= 4 do try(w = parts[4] as float)catch()

                        append mapVerts [u,v,w]
                    )
                )
                else if (substring line 1 2) == "o " then
                (
                    usesObjectStatements = true
                    local objectName = substring line 3 (line.count - 2)

                    if matchPattern objectName pattern:"RUVB_*" then
                    (
                        currentBlock = RUVB2027ObjBlock name:objectName faces:#()
                        append blocks currentBlock
                    )
                    else
                    (
                        currentBlock = undefined
                    )
                )
                else if (substring line 1 2) == "g " and not usesObjectStatements then
                (
                    local groupName = substring line 3 (line.count - 2)

                    if matchPattern groupName pattern:"RUVB_*" then
                    (
                        currentBlock = RUVB2027ObjBlock name:groupName faces:#()
                        append blocks currentBlock
                    )
                    else
                    (
                        currentBlock = undefined
                    )
                )
                else if (substring line 1 2) == "f " and currentBlock != undefined then
                (
                    local tokens = filterString line " \t"
                    local faceData = #()

                    for tokenIndex = 2 to tokens.count do
                    (
                        append faceData (parseFaceToken tokens[tokenIndex] vertexCount mapVerts.count)
                    )

                    append currentBlock.faces faceData
                )
            )
        )

        close stream
        #(mapVerts, blocks)
    ),

    fn findReturnedBlock blocks item =
    (
        local found = undefined

        for block in blocks while found == undefined do
        (
            if block.name == item.tempName or matchPattern block.name pattern:(item.tempName + "*") do found = block
        )

        found
    ),

    fn blockVertexFaces block =
    (
        local faces = #()

        for faceData in block.faces do
        (
            local verts = #()

            for corner in faceData do append verts corner[1]
            append faces verts
        )

        faces
    ),

    fn topologyMatchesSession item block =
    (
        if block == undefined then return false
        if block.faces.count != item.faceCount then return false

        local returnedFaces = blockVertexFaces block

        for faceIndex = 1 to returnedFaces.count do
        (
            if returnedFaces[faceIndex].count != item.faceDegrees[faceIndex] then return false
        )

        (topologySignature returnedFaces) == item.topologySignature
    ),

    fn buildUvData block mapVerts =
    (
        local usedGlobalMapIndices = #()
        local localMapVerts = #()
        local localMapFaces = #()

        for faceData in block.faces do
        (
            local localFace = #()

            for corner in faceData do
            (
                local globalMapIndex = corner[2]
                if globalMapIndex <= 0 or globalMapIndex > mapVerts.count then return undefined

                local localMapIndex = findItem usedGlobalMapIndices globalMapIndex

                if localMapIndex == 0 then
                (
                    append usedGlobalMapIndices globalMapIndex
                    append localMapVerts mapVerts[globalMapIndex]
                    localMapIndex = localMapVerts.count
                )

                append localFace localMapIndex
            )

            append localMapFaces localFace
        )

        #(localMapVerts, localMapFaces)
    ),

    fn makeApplyClone sourceNode =
    (
        local tempNode = undefined

        try
        (
            tempNode = copy sourceNode
            convertToPoly tempNode
        )
        catch
        (
            if tempNode != undefined and isValidNode tempNode do delete tempNode
            tempNode = undefined
        )

        if tempNode != undefined and classOf tempNode.baseObject == Editable_Poly then tempNode else undefined
    ),

    fn applyUvToClone tempNode item uvChannel uvData =
    (
        if tempNode == undefined or uvData == undefined then return false

        local polyValue = tempNode.baseObject
        local currentFaces = faceArraysFromPoly polyValue

        if currentFaces.count != item.faceCount then return false
        if (topologySignature currentFaces) != item.topologySignature then return false

        local uvVerts = uvData[1]
        local uvFaces = uvData[2]

        if uvFaces.count != currentFaces.count then return false

        local ok = true

        try
        (
            polyOp.setMapSupport polyValue uvChannel true
            polyOp.setNumMapVerts polyValue uvChannel uvVerts.count keep:false

            for mapIndex = 1 to uvVerts.count do
            (
                polyOp.setMapVert polyValue uvChannel mapIndex uvVerts[mapIndex]
            )

            for faceIndex = 1 to uvFaces.count do
            (
                if uvFaces[faceIndex].count != currentFaces[faceIndex].count then
                (
                    ok = false
                    exit
                )

                polyOp.setMapFace polyValue uvChannel faceIndex uvFaces[faceIndex]
            )
        )
        catch
        (
            ok = false
        )

        ok
    ),

    fn pasteUvFromClone tempNode sourceNode uvChannel =
    (
        local ok = true

        try
        (
            channelInfo.CopyChannel tempNode 3 uvChannel
            channelInfo.PasteChannel sourceNode 3 uvChannel

            if sourceNode.modifiers.count > 0 do
            (
                try(sourceNode.modifiers[1].name = "RizomUV UV Channel " + (uvChannel as string))catch()
            )
        )
        catch
        (
            ok = false
        )

        ok
    ),

    fn importResult uvChannel =
    (
        if not doesFileExist (exchangeOutput()) then
        (
            messageBox "No RizomUV OBJ result was found yet. Save the model in RizomUV first." title:"RizomUVBridge"
            return false
        )

        local parsed = readObjResult (exchangeOutput())

        if parsed == undefined then
        (
            messageBox "Could not parse the RizomUV OBJ result." title:"RizomUVBridge"
            return false
        )

        local mapVerts = parsed[1]
        local blocks = parsed[2]

        local okCount = 0
        local topologyMismatchCount = 0
        local missingUvCount = 0
        local missingObjectCount = 0
        local failedCount = 0

        undo "RizomUV UV Import" on
        (
            for item in sessionItems do
            (
                local sourceNode = getNodeByHandle item.handle
                local block = findReturnedBlock blocks item

                if sourceNode == undefined or block == undefined then
                (
                    missingObjectCount += 1
                )
                else if not topologyMatchesSession item block then
                (
                    topologyMismatchCount += 1
                )
                else
                (
                    local uvData = buildUvData block mapVerts

                    if uvData == undefined then
                    (
                        missingUvCount += 1
                    )
                    else
                    (
                        local tempNode = makeApplyClone sourceNode

                        if tempNode == undefined then
                        (
                            failedCount += 1
                        )
                        else
                        (
                            local applied = applyUvToClone tempNode item uvChannel uvData
                            local pasted = false

                            if applied do pasted = pasteUvFromClone tempNode sourceNode uvChannel

                            with undo off
                            (
                                if isValidNode tempNode do delete tempNode
                            )

                            if applied and pasted then okCount += 1 else failedCount += 1
                        )
                    )
                )
            )
        )

        restoreSourceSelection()
        waitingForResult = false
        deleteIfPresent (exchangeOutput())

        format "RizomUVBridge OBJ import: ok:% topologyMismatch:% missingUV:% missingObject:% failed:%\n"             okCount topologyMismatchCount missingUvCount missingObjectCount failedCount

        if topologyMismatchCount > 0 or missingUvCount > 0 or missingObjectCount > 0 or failedCount > 0 then
        (
            messageBox                 ("UV import completed with warnings.\n\nApplied: " + (okCount as string) +                 "\nTopology mismatch: " + (topologyMismatchCount as string) +                 "\nMissing UV: " + (missingUvCount as string) +                 "\nMissing object: " + (missingObjectCount as string) +                 "\nFailed: " + (failedCount as string))                 title:"RizomUVBridge"
        )

        okCount > 0
    ),

    fn pollOutputReady =
    (
        if not waitingForResult then return false
        if not doesFileExist (exchangeOutput()) then return false

        local currentSize = -1
        try(currentSize = getFileSize (exchangeOutput()))catch(currentSize = -1)

        if currentSize <= 0 then return false

        if currentSize == lastOutputSize then
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
    label lbl_version "" align:#left
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
        lbl_version.text = "Version " + RUVB2027.version
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
        lbl_status.text = "Writing polygon OBJ..."

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
        lbl_status.text = "Writing polygon OBJ..."

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
        lbl_status.text = "Reading UV result..."

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
            lbl_status.text = "Reading UV result..."

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

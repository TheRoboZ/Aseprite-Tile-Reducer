--Aseprite Tile Reducer v1.1 by TheRoboZ

local currentTileSet = app.layer.tileset

if currentTileSet then

    local bucketsPerPage = 16
    local numTiles = 0
    local imageCache = {}
    local byteCache = {}

    local threshold = 1
    local tileSize = currentTileSet.grid.tileSize

    local tileWidth = math.max(32, tileSize.width)
    local tileHeight = math.max(32, tileSize.height)
    local lastMaster = 0
    local lastSlave = 0

    local buckets = {}
    local master = {}
    local bucketIdx = {}
    local found = 0
    local selected = 0

    local canvasWidth = math.max(20, tileSize.width+4)  -- For bucket canvases
    local canvasHeight = math.max(20, tileSize.height+4)

    local page = 1
    local totPages = 0
    local setsDlg = nil

    function TilesCount()
        numTiles = 1
        local tile = currentTileSet:tile(numTiles)

        while tile do
            imageCache[numTiles] = tile.image
            byteCache[numTiles] = tile.image.bytes
            numTiles = numTiles+1
            tile = currentTileSet:tile(numTiles)
        end
        numTiles = numTiles-1
    end

    function MainDialog()
        local dlg = Dialog { title = "Tile Reducer" }

        dlg:label {
            id = "dl_layer",
            label = app.layer.name,
            text = currentTileSet.name
        }

        dlg:label {
            id = "dl_tottiles",
            label = "total tiles: ",
            text = numTiles
        }

        dlg:slider {
            id = "d_threshold",
            label = "threshold: ",
            value = 1,
            focus = true,
            min=1,
            max=tileSize.width*tileSize.height/2,
            onchange =  function()
                threshold = dlg.data.d_threshold
            end
        }

        dlg:check {
            id="chk_blend",
            label="Create Diff. Layer",
            --text="with diff blendMode"
        }

        dlg:button {
            id = "d_find",
            text = "FIND",
            focus = true,
            onclick = function() TilesFindDuplicates() end
        }

        dlg:button {
            id = "r_apply",
            text = "APPLY",
            onclick = function() TilesReplace() end
        }

        dlg:canvas {
            id="d_master",
            width=tileWidth,
            height=tileHeight,
            --autoscaling=false,
            onpaint = function(ev)
                local gc = ev.context -- gc is a GraphicsContext
                if lastMaster > 0 then
                gc:drawImage(imageCache[lastMaster], Rectangle(0, 0, tileSize.width, tileSize.height), Rectangle(0, 0, tileWidth, tileHeight))
                end
            end,
        }

        dlg:canvas {
            id="d_slave",
            width=tileWidth,
            height=tileHeight,
            --autoscaling=false,
            onpaint = function(ev)
                local gc = ev.context -- gc is a GraphicsContext
                if lastSlave > 0 then
                gc:drawImage(imageCache[lastSlave], Rectangle(0, 0, tileSize.width, tileSize.height), Rectangle(0, 0, tileWidth, tileHeight))
            end
            end,
        }

        dlg:canvas {
            id="d_diff",
            width=tileWidth,
            height=tileHeight,
            --autoscaling=false,
            onpaint = function(ev)
                if lastMaster > 0 and lastSlave > 0 then

                    local m_image = Image(imageCache[lastMaster])
                    local s_image = Image(imageCache[lastSlave])

                    for it in s_image:pixels() do
                        local pixelValue = it() -- get pixel
                        local masterValue = m_image:getPixel(it.x, it.y) -- get pixel
                        if (masterValue==pixelValue) then
                            it(0)          -- set pixel
                        elseif (pixelValue==0) then
                            it(masterValue)
                        end
                    end

                    local gc = ev.context -- gc is a GraphicsContext
                    gc.strokeWidth = 1
                    gc.color = Color {r = 0, g = 0, b = 0, a = 255}
                    gc:strokeRect(Rectangle(0, 0, tileWidth, tileHeight))
                    gc:drawImage(s_image, Rectangle(0, 0, tileSize.width, tileSize.height), Rectangle(0, 0, tileWidth, tileHeight))
                end
            end,
        }

        dlg:label {
            id = "dl_subst",
            label = "difference: "
        }

        dlg:label {
            id = "dl_found",
            label = "Tiles to be reduced: ",
            text = "0"
        }

        dlg:show { wait = false }

        return dlg

    end

    TilesCount()
    local dlg_main = MainDialog()

    function updateCountLabel()
        dlg_main:modify{ id="dl_subst", text = "from: "..lastMaster.." to "..lastSlave }
    end

    function stringDifference(str1, str2, maxDiff)
        local diff = 0
        local len = #str1
        for i = 1, len do
            if string.byte(str1, i) ~= string.byte(str2, i) then
                diff = diff + 1
                if diff > maxDiff then return diff end
            end
        end
        return diff
    end

    function TilesCompare(t1, t2, t1_bytes)
        --print("comparing tile "..t1.index.."and tile "..t2.index)
        if stringDifference(t1_bytes, byteCache[t2], threshold) <= threshold then
            --print("tile "..t1.index.." and tile "..t2.index.." difference within threshold")
            if  not buckets[t1] then
                for k, kv in pairs(buckets) do
                    for b, bv in pairs(kv) do
                        if (b==t1) then return end
                    end
                end
                --setsDlg:newrow()
                buckets[t1] = {}
                buckets[t1][t1] = 0
                master[t1]=t1
                found=found+1
                bucketIdx[found]=t1
                --print(found.." "..t1)
            end

            --print("     "..t2)
            buckets[t1][t2] = 0
            --byteCache[t1] = nil
        end
    end

    function DuplicateAddtoCanvas(dialog, k, b)
        dialog:canvas
        {
            id=b,
            width=canvasWidth,
            height=canvasHeight,
            --autoscaling=false,
            onpaint = function(ev)
                local gc = ev.context -- gc is a GraphicsContext
                gc.strokeWidth = 2
                gc.color = Color {r = 0, g = 0, b = 0, a = 255}
                gc:strokeRect(Rectangle(1, 1, math.max(19, tileSize.width+3), gc.height-1))

                if buckets[k][b] == 1 then
                    if lastSlave == b then
                        gc.color = Color {r = 0, g = 0, b = 255, a = 255}
                    else
                        gc.color = Color {r = 255, g = 0, b = 0, a = 255}
                    end
                    gc:strokeRect(Rectangle(1, 1, math.max(19, tileSize.width+3), gc.height-1))
                elseif lastSlave == b then
                    gc.color = Color {r = 0, g = 0, b = 255, a = 255}
                    gc:fillRect(Rectangle(0, 0, math.max(20, tileSize.width+4), 2))
                end

                if master[k] == b then
                    if lastMaster == b then
                        gc.color = Color {r = 0, g = 255, b = 0, a = 255}
                    else
                        gc.color = Color {r = 255, g = 255, b = 0, a = 255}
                    end
                    gc:fillRect(Rectangle(0, gc.height-2, math.max(20, tileSize.width+4), gc.height))
                end
                gc:drawImage(imageCache[b], Rectangle(0, 0, tileSize.width, tileSize.height), Rectangle(2, 2, 16, 16))
            end,

            onmousemove = function(ev)
                dialog:modify{ id="res_tile", text = b }
            end,

            ondblclick = function(ev)
                if buckets[k][b] == 1 then
                    buckets[k][b] = 0
                    selected = selected-1
                else
                    buckets[k][b] = 1
                    selected = selected+1
                    if b~=lastMaster then
                        lastSlave = b
                        lastMaster = master[k]
                        updateCountLabel()
                    end
                end
                dialog:repaint()
                --dlg_main:repaint()
                dlg_main:modify {
                    id = "dl_found",
                    text = selected
                }
            end,

            onmouseup = function(ev)
                if ev.button == MouseButton.RIGHT then
                    if b ~= master[k] then
                        master[k] = b
                        lastMaster = b
                        if b==lastSlave then
                            n = next(buckets[k], b)
                            if not n then n = next(buckets[k]) end
                            lastSlave = n
                        else
                            lastSlave = b
                        end
                        updateCountLabel()
                        dialog:repaint()
                        dlg_main:repaint()
                    end
                elseif ev.button == MouseButton.LEFT then
                    lastMaster = master[k]
                    if b==master[k] then
                        n = next(buckets[k], b)
                        if not n then n = next(buckets[k]) end
                        lastSlave = n
                    else
                        lastSlave = b
                    end
                    updateCountLabel()
                    dialog:repaint()
                    dlg_main:repaint()
                end
            end
        }
    end

    function ResultDialog()
        if setsDlg then
            setsDlg:close()
            setsDlg = nil
        end

        local results = Dialog
        {
            title = found.." Similar Sets",
            onclose = function()
            end
        }

        results:label{
            id = "pageLabel",
            text = page.." of "..totPages
        }

        results:button{
            id = "prev",
            text = "<",
            onclick = function()
                if page > 1 then
                    page = page-1
                    setsDlg=ResultDialog()
                    if setsDlg then setsDlg:show { wait = false } end
                end
            end
        }

        results:button{
            id = "next",
            text = ">",
            onclick = function()
                if page < totPages then
                    page = page+1
                    setsDlg=ResultDialog()
                    if setsDlg then setsDlg:show { wait = false } end
                end
            end
        }

        for i=(page-1)*bucketsPerPage+1, math.min(page*bucketsPerPage, found)  do
            local idx = bucketIdx[i]
            for b, bv in pairs(buckets[idx]) do
                DuplicateAddtoCanvas(results, idx, b)
            end
            results:newrow()
        end

        results:label{ id="res_tile", text = "-" }

        return results
    end

    function TilesFindDuplicates()

        found = 0
        page = 1
        buckets = {}
        bucketIdx = {}
        master = {}

        for i=1,numTiles-1 do
            local tileImage1 = byteCache[i]
            if tileImage1 then
                --print("t1 is "..tileImage.index)
                for j=i+1,numTiles do
                    --print("t2 is "..tileImage2.index)
                    --if tileImage1 and tileImage2 then
                    TilesCompare(i,j,tileImage1)
                    --end
                end
            --else
                --break
            end
        end

        if found>0 then
            totPages = math.ceil(found/bucketsPerPage)

            setsDlg = ResultDialog()
            if setsDlg then setsDlg:show { wait = false } end
            dlg_main:modify {
                id = "dl_found",
                text = 0
            }
        else
            dlg_main:modify {
            id = "dl_found",
            text = "No Matching Tiles found!"
            }
        end
    end

    function TilesReplace()
        if  selected > 0 then
            local currLayer = app.layer
            local newTileset = app.sprite:newTileset(currentTileSet)
            newTileset.name = currentTileSet.name .. " (copy)"
            currLayer.tileset = newTileset
            app.command.DuplicateLayer()
            currLayer.tileset = currentTileSet

            currLayer = app.layer
            currLayer.tileset = newTileset

            if dlg_main.data.chk_blend then
                currLayer.blendMode = BlendMode.DIFFERENCE
            end
            local substCount = 0

            for keyTile, bucketTiles in pairs(buckets) do
                local masterIdx = master[keyTile]
                local masterImg = imageCache[masterIdx]
                for t, isSelected  in pairs(bucketTiles) do
                    if isSelected  == 1 and t ~= masterIdx then
                        imageCache[t] = Image(masterImg)
                        newTileset:tile(t).image = Image(masterImg)
                        substCount = substCount+1
                    end
                end
            end

            if substCount > 0 then

            local gridRect = Rectangle(0, 0, tileSize.width, tileSize.height)
            app.sprite.gridBounds = gridRect

            app.command.ConvertLayer({
                ui = false,
                to = "layer"
            })

            app.command.ConvertLayer({
                ui = false,
                to = "tilemap"
            })

            app.refresh()
            setsDlg:close()
            --TilesFindDuplicates()
            end
        end
    end

else
    print("TileReducer ERROR: Selected Layer is not a TileMap!")
end
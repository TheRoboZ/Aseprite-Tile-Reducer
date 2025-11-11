--Aseprite Tile Reducer v1.2 by TheRoboZ

if not app.activeSprite then
  return app.alert("No active sprite.")
end

local currentTileSet = app.layer.tileset

if not currentTileSet then
 return app.alert("TileReducer ERROR: Selected Layer is not a TileMap!")
end

local bucketsPerPage = 16
local tileSize = currentTileSet.grid.tileSize
local tileWidth = math.max(32, tileSize.width)
local tileHeight = math.max(32, tileSize.height)
local canvasWidth = math.max(20, tileSize.width+4)  -- For bucket canvases
local canvasHeight = math.max(20, tileSize.height+4)

local threshold = 1

local numTiles = 0
local setsDlg = nil
local imageCache = nil
local byteCache = nil

local buckets = nil
local bucketIdx = nil
local master = nil
local instances = nil

local found = 0
local page = 1
local totPages = 0

local selected = 0
local lastMaster = 0
local lastSlave = 0
local onTile = 0

function TilesCount()
    imageCache = {}
    byteCache = {}
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

function CountInstances()
    instances = {}

    for i, cel in ipairs(app.layer.cels) do
        local image = cel.image

        -- Iterate over each tile (pixel) in row-major order
        for pixel in image:pixels() do

            local color = pixel()  -- Get the raw color value (unsigned int)
            -- Extract tile index (0 = empty/transparent, 1+ = index in tileset)
            local tile_index = app.pixelColor.tileI(color)
            if (tile_index>0) then
                if instances[tile_index] then
                    instances[tile_index] = instances[tile_index]+1
                else
                    instances[tile_index] = 1
                end
            end
        end
    end
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
        id="d_slave",
        width=tileWidth+2,
        height=tileHeight+2,
        --autoscaling=false,
        onpaint = function(ev)
            if lastSlave > 0 then
            local gc = ev.context -- gc is a GraphicsContext
            gc.strokeWidth = 1
            gc.color = Color {r = 0, g = 0, b = 255, a = 255}
            gc:strokeRect(Rectangle(0, 0, tileWidth+2, tileHeight+2))
            gc:drawImage(imageCache[lastSlave], Rectangle(0, 0, tileSize.width, tileSize.height), Rectangle(1, 1, tileWidth, tileHeight))
        end
        end,
    }

    dlg:canvas {
        id="d_diff",
        width=tileWidth+2,
        height=tileHeight+2,
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
                gc:strokeRect(Rectangle(0, 0, tileWidth+2, tileHeight+2))
                gc:drawImage(s_image, Rectangle(0, 0, tileSize.width, tileSize.height), Rectangle(1, 1, tileWidth, tileHeight))
            end
        end,
    }

    dlg:canvas {
        id="d_master",
        width=tileWidth+2,
        height=tileHeight+2,
        --autoscaling=false,
        onpaint = function(ev)
            if lastMaster > 0 then
            local gc = ev.context -- gc is a GraphicsContext
            gc.strokeWidth = 1
            gc.color = Color {r = 0, g = 255, b = 0, a = 255}
            gc:strokeRect(Rectangle(0, 0, tileWidth+2, tileHeight+2))
            gc:drawImage(imageCache[lastMaster], Rectangle(0, 0, tileSize.width, tileSize.height), Rectangle(1, 1, tileWidth, tileHeight))
            end
        end,
    }

    dlg:label {
        id = "dl_subst",
        label = "Will replace: "
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
CountInstances()
local dlg_main = MainDialog()

function updateCountLabel()
    dlg_main:modify{ id="dl_subst", text = lastSlave.." ["..instances[lastSlave].."]     with     "..lastMaster .." ["..instances[lastMaster].."]"}
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
    if stringDifference(t1_bytes, byteCache[t2], threshold) <= threshold then
        if  not buckets[t1] then
            for k, kv in pairs(buckets) do
                for b, bv in pairs(kv) do
                    if (b==t1) then return end
                end
            end

            buckets[t1] = {}
            buckets[t1][t1] = 0
            master[t1]=t1
            found=found+1
            bucketIdx[found]=t1
        end

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
            if onTile ~=b then
                dialog:modify{ id="res_tile", text = b.." ["..instances[b].."] instances" }
                highlightTiles(b)
                onTile = b
            end
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

function PageUpdate()
    local s = selected
    local ms = lastMaster
    local sl = lastSlave
    onTile = 0

    setsDlg=ResultDialog()
    if setsDlg then
        setsDlg:show { wait = false }
        selected = s
        lastMaster = ms
        lastSlave = sl
        dlg_main:modify {
            id = "dl_found",
            text = selected
        }
    end
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
            dlg_main:modify { id = "dl_tottiles", text = numTiles }
            dlg_main:modify{ id = "dl_found", text = 0 }
            dlg_main:modify{ id="dl_subst", text = "" }
            selected = 0
            lastMaster = 0
            lastSlave = 0
            dlg_main:repaint()
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
                PageUpdate()
            end
        end
    }

    results:button{
        id = "next",
        text = ">",
        onclick = function()
            if page < totPages then
                page = page+1
                PageUpdate()
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

    buckets = {}
    bucketIdx = {}
    master = {}
    found = 0
    page = 1
    totPages = 0

    selected = 0
    lastMaster = 0
    lastSlave = 0

    for i=1,numTiles-1 do
        local tileImage1 = byteCache[i]
        if tileImage1 then
            for j=i+1,numTiles do
                TilesCompare(i,j,tileImage1)
            end
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

function CreateResultLayer(tileset)
    local gridRect = Rectangle(0, 0, tileSize.width, tileSize.height)
    app.sprite.gridBounds = gridRect

    currLayer = app.layer

    app.command.ConvertLayer({
        ui = false,
        to = "layer"
    })

    currLayer = app.layer

    app.sprite.selection:selectAll()
    app.command.NewLayer
    {
        name = currLayer.name.." reduced",
        tilemap = true,
        viaCopy = true
    }

    app.sprite:deleteLayer(currLayer)

    currLayer = app.layer
    currLayer.tileset = tileset

    --app.sprite:newCel(currLayer, app.activeFrame)

    app.command.ConvertLayer({
        ui = false,
        to = "tilemap"
    })
        app.command.ConvertLayer({
        ui = false,
        to = "layer"
    })
        app.command.ConvertLayer({
        ui = false,
        to = "tilemap"
    })

    currLayer = app.layer

    currentTileSet = currLayer.tileset
    TilesCount()
    CountInstances()
    app.refresh()
end

function TilesReplace()
    if  selected > 0 then
        app.transaction("Create Reduced Layer", function()
        local sprite = app.sprite
        local currLayer = app.layer
        local newTileset = sprite:newTileset(currentTileSet)
        newTileset.name = currentTileSet.name .. " (copy)"
        local finalTileset = sprite:newTileset(currentTileSet)
        finalTileset.name = currentTileSet.name .. " (reduced)"

        app.command.DuplicateLayer()

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
                    sprite:deleteTile(finalTileset, t)
                    substCount = substCount+1
                end
            end
        end

        if substCount > 0 then
            CreateResultLayer(finalTileset)
            setsDlg:close()
        end
        end)
    end
end

function highlightTiles(tile)

    local sourceCel = app.layer:cel(frame)
    local sourceOrigin = sourceCel.bounds
    local mapImg = sourceCel.image

    local selection = app.sprite.selection
    selection:deselect()

    for mapY = 0, mapImg.height - 1 do
        local sourceYoff = sourceOrigin.y + mapY * tileSize.height
        for mapX = 0, mapImg.width - 1 do
            local tileColor = mapImg:getPixel(mapX, mapY)
            local tileIndex = app.pixelColor.tileI(tileColor)
            local sourceXoff = sourceOrigin.x + mapX * tileSize.width

            if tileIndex == tile then
                selection:add({sourceXoff, sourceYoff, tileSize.width-1, tileSize.height-1})
            end
        end
    end

    app.refresh()
end
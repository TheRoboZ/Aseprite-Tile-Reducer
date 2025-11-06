-- When using a 8bpp indexed image as input you can use the extra bits of palette to provide extra information for the TILEMAP data but you have to
-- ensure that all pixels from a same tile (block of 8x8 pixels) use the same value otherwise rescomp will generate an error.
--     bit 4-5: palette index (0-3) so it allows to use the 4 available palettes to draw the tilemap / MAP.
--     bit 6: not used (ignored)
--     bit 7: priority information (0=LOW 1=HIGH)

--TODO: get an image and a mask layer. every non 0 tile on the layer (8x8 grid) sets high priority on the til by pushing all pixel to +128 color index, otherwise mask the 7bit to push to low priority
--make sure to also 0 6th bit for safety

if not app.activeSprite then
  return app.alert("No active sprite.")
end

local sprite = app.activeSprite
if sprite.colorMode ~= ColorMode.INDEXED then
  return app.alert("Sprite must be in indexed color mode.")
end

-- Collect layer names
local layerNames = {}
for _, layer in ipairs(sprite.layers) do
  table.insert(layerNames, layer.name)
end

if #layerNames < 2 then
  return app.alert("You need at least 2 layers, a tilemap mask and a target image!")
end

local function findLayerByName(name)
  for _, layer in ipairs(sprite.layers) do
    if layer.name == name then
      return layer
    end
  end
  return nil
end

local function getBoundsText(layer, frame)
  if not layer then return "Layer not found" end
  local cel = layer:cel(frame)
  if not cel or not cel.image then return "No Cel in current frame" end
  local pos = cel.position
  local img = cel.image
  return string.format("Cel Pos: (%d,%d) Size: %dx%d", pos.x, pos.y, img.width, img.height)
end

-- Create dialog
local dlg = Dialog("SGDK Tile Priority Modifier")
dlg:combobox{
  id = "source",
  label = "Priority Layer:",
  options = layerNames,
  option = layerNames[#layerNames],
  onchange = function()
    dlg:modify{id = "sourceBounds",text = getBoundsText(findLayerByName(dlg.data.source), frame) }
  end
}
dlg:label{ id = "sourceBounds", text =  getBoundsText(findLayerByName(dlg.data.source), frame) }

dlg:newrow{always = false}

dlg:combobox{
  id = "target",
  label = "Target Layer:",
  options = layerNames,
  option = layerNames[1],
  onchange = function()
    dlg:modify{id = "targetBounds", text = getBoundsText(findLayerByName(dlg.data.target), frame) }
  end
}
dlg:label{ id = "targetBounds", text = getBoundsText(findLayerByName(dlg.data.target), frame) }
dlg:newrow{always = false}
dlg:separator()
dlg:newrow{always = false}
dlg:button{ id = "confirm", text = "&OK", focus = true }
   :button{ id = "cancel",  text = "&Cancel", onclick = function() dlg:close() end }

dlg:label{ id = "warn", text  = "Pay attention to layers/cels origins!"
}

dlg:show()

local data = dlg.data
if data.cancel or not data.confirm then
  return
end

app.transaction("Adjust Priority", function()

    -- Find selected layers
    local sourceLayer, targetLayer
    for _, layer in ipairs(sprite.layers) do
    if layer.name == data.source then
        sourceLayer = layer
    elseif layer.name == data.target then
        targetLayer = layer
    end
    end

    if not sourceLayer or not targetLayer then
    return app.alert("Selected layers not found.")
    end

    if not sourceLayer.isTilemap then
    return app.alert("Source layer must be a tilemap layer.")
    end

    if not targetLayer.isImage then
    return app.alert("Target layer must be an image layer.")
    end

    -- Duplicate the target layer
    local originalTarget = targetLayer
    app.activeLayer = originalTarget
    app.command.DuplicateLayer()
    targetLayer = app.layer
    targetLayer.name = originalTarget.name .. " (processed)"

    local frame = app.activeFrame

    local sourceCel = sourceLayer:cel(frame)
    if not sourceCel then
    return app.alert("No cel in source layer at current frame.")
    end

    local targetCel = targetLayer:cel(frame)
    if not targetCel then
    return app.alert("No cel in target layer at current frame.")
    end

    local tileset = sourceLayer.tileset
    if not tileset then
    return app.alert("No tileset in tilemap layer.")
    end

    local grid = tileset.grid
    local tileSize = grid.tileSize
    local tileW = tileSize.w
    local tileH = tileSize.h

    -- Iterate over tilemap cells
    local targetImg = targetCel.image
    local mapImg = sourceCel.image
    local modifiedCount = 0

    local sourceOrigin =  sourceCel.bounds
    local targetOrigin =  targetCel.bounds

    for mapY = 0, mapImg.height - 1 do
        local targetYoff = sourceOrigin.y + mapY * tileH - targetOrigin.y
        for mapX = 0, mapImg.width - 1 do

            local tileColor = mapImg:getPixel(mapX, mapY)
            local tileIndex = app.pixelColor.tileI(tileColor)
            local targetXoff = sourceOrigin.x + mapX * tileW - targetOrigin.x

            if tileIndex > 0 then
               --print("cel "..mapX.." "..mapY.." "..targetXoff.." "..targetYoff)
            -- For this tile position, process pixels in target layer
                for dy = 0, tileH - 1 do
                    for dx = 0, tileW - 1 do

                        local targetX = targetXoff + dx
                        local targetY = targetYoff + dy

                        if targetX < targetImg.width and targetY < targetImg.height then
                            local col = targetImg:getPixel(targetX, targetY)
                            if col ~= 0 then  -- Skip transparent pixels
                                -- Modify color index: set bit 7 (128) to 1, bit 6 (64) to 0

                                local newCol = col | 128
                                newCol = newCol & ~64

                                targetImg:putPixel(targetX, targetY, newCol)
                                modifiedCount = modifiedCount + 1
                            end
                        end
                    end
                end
            else
                for dy = 0, tileH - 1 do
                    for dx = 0, tileW - 1 do

                        local targetX = targetXoff + dx
                        local targetY = targetYoff + dy

                        if targetX < targetImg.width and targetY < targetImg.height then
                        local col = targetImg:getPixel(targetX, targetY)
                            if col ~= 0 then  -- Skip transparent pixels
                                -- Modify color index: set bit 7 (128) to 1, bit 6 (64) to 0
                                local newCol = col & ~128
                                newCol = newCol & ~64
                                targetImg:putPixel(targetX, targetY, newCol)
                                modifiedCount = modifiedCount + 1
                            end
                        end
                    end
                end

            end
        end
    end

end)

app.refresh()  -- Refresh the view

if (modifiedCount == 0) then
    app.alert(string.format("WARNING: No Pixels were modified!"))
end
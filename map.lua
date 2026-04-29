local map = {}
local assets = {}
local currentRoom = {x=3, y=3}
local rooms = {}
local tileSize = 32
local doorsOpen = false

-- Dungeon config
local DUNGEON_SIZE = 6
local ROOM_W = 45
local ROOM_H = 30

function map.init(a)
    assets = a
    rooms = {}
    currentRoom = {x=3, y=3}
    doorsOpen = false
    map.generateRoom(currentRoom.x, currentRoom.y)
end

function map.setDoorsOpen(open)
    doorsOpen = open
end

function map.clearStructures()
    local layout = rooms[currentRoom.y][currentRoom.x]
    for y, row in ipairs(layout) do
        for x, tile in ipairs(row) do
            if tile == "box" or tile == "box_part" then
                layout[y][x] = "floor"
            end
        end
    end
end

function map.areDoorsOpen()
    return doorsOpen
end

-- Structure templates (coordinates relative to placement origin)
-- Each template is a list of {dx, dy} offsets for box placements (each box = 2x2)
local structureTemplates = {
    -- L-shape
    {name="L", boxes={{0,0},{0,1},{1,1}}},
    -- T-shape
    {name="T", boxes={{0,0},{1,0},{2,0},{1,1}}},
    -- Line horizontal
    {name="lineH", boxes={{0,0},{1,0},{2,0}}},
    -- Line vertical
    {name="lineV", boxes={{0,0},{0,1},{0,2}}},
    -- Square 2x2
    {name="square", boxes={{0,0},{1,0},{0,1},{1,1}}},
    -- Corner
    {name="corner", boxes={{0,0},{1,0},{0,1}}},
    -- Cross/Plus
    {name="cross", boxes={{1,0},{0,1},{1,1},{2,1},{1,2}}},
    -- U-shape
    {name="U", boxes={{0,0},{0,1},{0,2},{1,2},{2,2},{2,1},{2,0}}},
    -- Single box
    {name="single", boxes={{0,0}}},
    -- Pair horizontal
    {name="pairH", boxes={{0,0},{1,0}}},
    -- Pair vertical
    {name="pairV", boxes={{0,0},{0,1}}},
    -- Z-shape
    {name="Z", boxes={{0,0},{1,0},{1,1},{2,1}}},
}

local function canPlaceBox(layout, gx, gy)
    -- Each box occupies 2x2 tiles
    if gx < 3 or gx + 1 > ROOM_W - 2 or gy < 3 or gy + 1 > ROOM_H - 2 then return false end
    for dy = 0, 1 do
        for dx = 0, 1 do
            local tile = layout[gy + dy] and layout[gy + dy][gx + dx]
            if not tile or tile ~= "floor" and tile ~= "floor_alt" then return false end
        end
    end
    return true
end

local function placeBox(layout, gx, gy)
    layout[gy][gx] = "box"
    layout[gy][gx+1] = "box_part"
    layout[gy+1][gx] = "box_part"
    layout[gy+1][gx+1] = "box_part"
end

local function placeStructure(layout, template, originX, originY)
    -- First check if all boxes can be placed
    for _, b in ipairs(template.boxes) do
        local gx = originX + b[1] * 2
        local gy = originY + b[2] * 2
        if not canPlaceBox(layout, gx, gy) then return false end
    end
    -- Place all boxes
    for _, b in ipairs(template.boxes) do
        local gx = originX + b[1] * 2
        local gy = originY + b[2] * 2
        placeBox(layout, gx, gy)
    end
    return true
end

function map.generateRoom(rx, ry)
    if rooms[ry] and rooms[ry][rx] then return end
    
    local layout = {}
    
    local midX = math.ceil(ROOM_W/2)
    local midY = math.ceil(ROOM_H/2)
    
    for y = 1, ROOM_H do
        layout[y] = {}
        for x = 1, ROOM_W do
            local tile = "floor"
            -- More varied floor with random alt tiles
            if love.math.random() < 0.12 then
                tile = "floor_alt"
            end
            
            -- Borders
            if x == 1 and y == 1 then tile = "corner_tl"
            elseif x == ROOM_W and y == 1 then tile = "corner_tr"
            elseif x == 1 and y == ROOM_H then tile = "corner_bl"
            elseif x == ROOM_W and y == ROOM_H then tile = "corner_br"
            elseif x == 1 or x == ROOM_W or y == 1 or y == ROOM_H then
                -- Doors on all sides (infinite map), now 4 tiles wide
                if x == 1 and (y >= midY - 1 and y <= midY + 2) then
                    tile = "door_left"
                elseif x == ROOM_W and (y >= midY - 1 and y <= midY + 2) then
                    tile = "door_right"
                elseif y == 1 and (x >= midX - 1 and x <= midX + 2) then
                    tile = "door_top"
                elseif y == ROOM_H and (x >= midX - 1 and x <= midX + 2) then
                    tile = "door_bottom"
                else
                    if y == 1 then tile = "wall_top"
                    elseif y == ROOM_H then tile = "wall_bottom"
                    elseif x == 1 then tile = "wall_left"
                    elseif x == ROOM_W then tile = "wall_right"
                    end
                end
            end
            
            layout[y][x] = tile
        end
    end
    
    -- Generate structures (not in starting room)
    if rx ~= 3 or ry ~= 3 then
        local numStructures = love.math.random(2, 5)
        local attempts = 0
        local placed = 0
        
        while placed < numStructures and attempts < 40 do
            attempts = attempts + 1
            local template = structureTemplates[love.math.random(1, #structureTemplates)]
            local ox = love.math.random(3, ROOM_W - 8)
            local oy = love.math.random(3, ROOM_H - 8)
            
            -- Keep door areas completely clear of structures
            local nearLeft = ox < 6 and math.abs(oy - midY) < 4
            local nearRight = ox > ROOM_W - 10 and math.abs(oy - midY) < 4
            local nearTop = oy < 5 and math.abs(ox - midX) < 5
            local nearBottom = oy > ROOM_H - 8 and math.abs(ox - midX) < 5
            local nearCenter = math.abs(ox - midX) < 4 and math.abs(oy - midY) < 3
            
            if not (nearLeft or nearRight or nearTop or nearBottom or nearCenter) then
                if placeStructure(layout, template, ox, oy) then
                    placed = placed + 1
                end
            end
        end
    end
    
    if not rooms[ry] then rooms[ry] = {} end
    rooms[ry][rx] = layout
end

function map.draw()
    local layout = rooms[currentRoom.y][currentRoom.x]
    local offsetX = 0
    local offsetY = 0
    
    local overlays = {}
    
    for y, row in ipairs(layout) do
        for x, tile in ipairs(row) do
            local img = assets.floor
            local r = 0
            local ox, oy = 0, 0
            local drawOverlay = nil
            
            if tile == "floor_alt" then img = assets.floor_alt
            elseif tile:sub(1, 4) == "wall" then 
                img = assets.corner_deco
                ox, oy = 16, 16
                if tile == "wall_right" then r = math.pi / 2
                elseif tile == "wall_bottom" then r = math.pi
                elseif tile == "wall_left" then r = 3 * math.pi / 2
                end
            elseif tile:sub(1, 6) == "corner" then 
                img = assets.corner
                ox, oy = 16, 16
                if tile == "corner_tr" then r = math.pi / 2
                elseif tile == "corner_br" then r = math.pi
                elseif tile == "corner_bl" then r = 3 * math.pi / 2
                end
            elseif tile:sub(1, 4) == "door" then 
                if not doorsOpen then
                    img = assets.corner_deco
                    ox, oy = 16, 16
                    if tile == "door_right" then r = math.pi / 2
                    elseif tile == "door_bottom" then r = math.pi
                    elseif tile == "door_left" then r = 3 * math.pi / 2
                    end
                else
                    img = assets.floor
                end
            elseif tile == "box" then
                drawOverlay = assets.box
            elseif tile == "box_part" then
                -- Just draw floor underneath
            end
            
            local drawX = offsetX + (x-1) * tileSize
            local drawY = offsetY + (y-1) * tileSize
            
            if ox > 0 then
                drawX = drawX + ox
                drawY = drawY + oy
            end
            
            -- Final safety check for img
            img = img or assets.floor
            
            love.graphics.draw(img, drawX, drawY, r, 1, 1, ox, oy)
            
            if drawOverlay then
                table.insert(overlays, {img = drawOverlay, x = offsetX + (x-1)*tileSize, y = offsetY + (y-1)*tileSize})
            end
            
            love.graphics.setColor(1, 1, 1)
        end
    end
    
    -- Draw 64x64 overlays last
    for _, ov in ipairs(overlays) do
        love.graphics.draw(ov.img, ov.x, ov.y)
    end
end

function map.getTileAt(px, py)
    local layout = rooms[currentRoom.y][currentRoom.x]
    if not layout then return "wall" end
    
    local offsetX = 0
    local offsetY = 0
    
    local tx = math.floor((px - offsetX) / tileSize) + 1
    local ty = math.floor((py - offsetY) / tileSize) + 1
    
    if layout[ty] and layout[ty][tx] then
        return layout[ty][tx], tx, ty
    end
    return "wall"
end

function map.isWalkable(px, py)
    local tile = map.getTileAt(px, py)
    if tile:sub(1, 4) == "door" and doorsOpen then return true end
    return tile:sub(1, 4) ~= "wall" and tile:sub(1, 6) ~= "corner" and tile:sub(1, 4) ~= "door" and tile:sub(1, 3) ~= "box"
end

function map.checkRoomTransition(px, py)
    if not doorsOpen then return nil end
    
    local mw, mh = ROOM_W * tileSize, ROOM_H * tileSize
    local midX, midY = (ROOM_W * tileSize) / 2, (ROOM_H * tileSize) / 2
    local doorWidth = 4 * tileSize
    local margin = 20
    
    -- Left Door
    if px < margin and math.abs(py - midY) < doorWidth/2 then return -1, 0
    -- Right Door
    elseif px > mw - margin and math.abs(py - midY) < doorWidth/2 then return 1, 0
    -- Top Door
    elseif py < margin and math.abs(px - midX) < doorWidth/2 then return 0, -1
    -- Bottom Door
    elseif py > mh - margin and math.abs(px - midX) < doorWidth/2 then return 0, 1
    end
    
    return nil
end

function map.changeRoom(dx, dy)
    currentRoom.x = currentRoom.x + dx
    currentRoom.y = currentRoom.y + dy
    map.generateRoom(currentRoom.x, currentRoom.y)
end

function map.getRoomSize()
    return ROOM_W, ROOM_H
end

function map.getCurrentRoom()
    return currentRoom.x, currentRoom.y
end

function map.getBounds()
    local layout = rooms[currentRoom.y][currentRoom.x]
    local offsetX = 0
    local offsetY = 0
    return offsetX + tileSize, offsetY + tileSize, offsetX + (#layout[1]-1)*tileSize, offsetY + (#layout-1)*tileSize
end

return map

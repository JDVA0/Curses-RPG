local enemy = {}
local enemies = {}
local assets = {}
local kills = 0
local map = require("map")
local pickup = require("pickup")
local bullet = require("bullet")
local player = require("player")
local juice = require("juice")

function enemy.init(a) assets = a; enemies = {}; kills = 0 end

function enemy.getBoss()
    for _, e in ipairs(enemies) do if e.isBoss then return e end end
    return nil
end

-- Check if a position is dangerously close to a hazard (like poison)
local function isHazardous(x, y, radius)
    if not _G.hazards then return false end
    local r = radius or 16
    for _, hz in ipairs(_G.hazards) do
        local dx, dy = x - hz.x, y - hz.y
        if dx*dx + dy*dy < (hz.r + r)^2 then return true end
    end
    return false
end

-- Smart movement: tries to move toward target, slides along walls, avoids hazards/boxes
local function smartMove(e, tx, ty, spd, dt)
    local dx = tx - e.x
    local dy = ty - e.y
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist < 1 then return end
    
    local vx = (dx / dist) * spd
    local vy = (dy / dist) * spd
    
    local candidates = {
        {vx, vy},           -- Direct
        {vx, 0},            -- X only
        {0, vy},            -- Y only
        {-vy, vx},          -- Perpendicular R (wider arc)
        {vy, -vx},          -- Perpendicular L (wider arc)
        {-vy*1.5, vx*1.5},  -- Wide slide
        {vy*1.5, -vx*1.5}   -- Wide slide
    }
    
    -- Stuck detection
    e.stuckTimer = (e.stuckTimer or 0)
    local lastX, lastY = e.x, e.y
    
    local moved = false
    for _, c in ipairs(candidates) do
        local mx, my = c[1] * dt, c[2] * dt
        local nx, ny = e.x + mx, e.y + my
        
        -- Enhanced check for boxes and hazards
        if map.isWalkable(nx, ny) then
            -- Avoid hazards more aggressively if not close to player
            local hazardRadius = dist < 80 and 8 or 22
            if not isHazardous(nx, ny, hazardRadius) then 
                e.x, e.y = nx, ny
                moved = true
                break
            end
        end
    end

    if not moved then
        e.stuckTimer = e.stuckTimer + dt
        if e.stuckTimer > 0.3 then
            -- Panic wiggle: try to find any free space
            local angle = love.math.random() * math.pi * 2
            local rx = e.x + math.cos(angle) * spd * 1.5 * dt
            local ry = e.y + math.sin(angle) * spd * 1.5 * dt
            if map.isWalkable(rx, ry) and not isHazardous(rx, ry, 10) then
                e.x, e.y = rx, ry
                e.stuckTimer = 0
            end
            if e.stuckTimer > 1.0 then e.stuckTimer = 0 end
        end
    else
        e.stuckTimer = math.max(0, e.stuckTimer - dt * 2)
    end
end

-- Find a flanking position around the player
local function getFlankTarget(e, px, py, i)
    local angle = math.atan2(py - e.y, px - e.x)
    local offset = ((i % 4) - 1.5) * 1.2  -- spread enemies around
    local flankAngle = angle + offset
    local flankDist = 50
    return px - math.cos(flankAngle) * flankDist, py - math.sin(flankAngle) * flankDist
end

function enemy.update(dt, px, py)
    local slowMod = 1 - (require("shop").getLevel("slowness") * 0.04)
    
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        if e.hitTimer > 0 then e.hitTimer = e.hitTimer - dt end
        e.animTimer = (e.animTimer or 0) + dt
        
        if e.fireTimer and e.fireTimer > 0 and e.state ~= "dying" then
            e.fireTimer = e.fireTimer - dt
            if love.timer.getTime() % 0.5 < dt then
                local killed = enemy.hit(i, 1)
                require("juice").spawnText(e.x, e.y-15, "-1", {1, 0.4, 0.1})
                if killed then require("juice").spawnExplosion(e.x, e.y, 0, 0, "gore") end
            end
        end
        if e.iceTimer and e.iceTimer > 0 then
            e.iceTimer = e.iceTimer - dt
            e.color = {0.5, 0.8, 1.0} -- Visual cue
        else
            -- Restore color based on type if needed, but hit flash overrides later anyway
            -- This is simple enough for now
        end
        
        if e.state == "spawning" then
            e.stateTimer = e.stateTimer - dt
            if e.stateTimer <= 0 then
                e.state = "chasing"
                require("juice").spawnExplosion(e.x, e.y, 0, 0, "spark_small")
            end
        elseif e.state == "dying" and not e.isBoss then
            e.stateTimer = e.stateTimer - dt
            -- Death animation: shake and shrink
            e.x = e.dieX + love.math.random(-4, 4)
            e.y = e.dieY + love.math.random(-4, 4)
            if e.stateTimer <= 0 then
                kills = kills + 1
                pickup.spawn(e.x, e.y, (e.isMiniBoss or e.subtype == "elite") and "gold_pile" or "gold")
                table.remove(enemies, i)
            end
        else
            -- Existing update logic for living enemies
            local dx = px - e.x
            local dy = py - e.y
            local dist = math.sqrt(dx*dx + dy*dy)
            
            -- Poison Hazard Damage
            for _, hz in ipairs(_G.hazards or {}) do
                if hz.type == "poison" then
                    local hdx = e.x - hz.x; local hdy = e.y - hz.y
                    if (hdx*hdx + hdy*hdy) < hz.r*hz.r then
                        e.hp = e.hp - 2.0 * dt -- Enemies take 2.0 damage per second in poison
                        if math.random() < 6 * dt then
                             require("juice").spawnExplosion(e.x, e.y, 0, 0, "dust")
                        end
                    end
                end
            end
            
            local rage = e.isBoss and (1 - (e.hp / e.maxHp)) or 0
            local curSpd = ((e.type == "oozel" and e.hitTimer > 0) and e.speed * 0.3 or e.speed) * slowMod
            if e.iceTimer and e.iceTimer > 0 then curSpd = curSpd * 0.4 end -- Ice slow
            if e.isBoss then curSpd = curSpd * (1 + rage * 0.8) end
            
            -- === BOSSES ===
            if e.isBoss then
            if e.state == "dying" then
                e.stateTimer = e.stateTimer - dt
                e.x = e.x + love.math.random(-5, 5)
                e.y = e.y + love.math.random(-5, 5)
                if love.math.random() < 0.35 then
                    require("juice").spawnExplosion(e.x + love.math.random(-60,60), e.y + love.math.random(-60,60), 0, 0, love.math.random() < 0.5 and "blood" or "spark")
                end
                if e.stateTimer <= 0 then
                    _G.slowMoTimer = 1.5 -- Dramatic slowmo on boss kill
                    for k=1,40 do pickup.spawn(e.x + love.math.random(-50,50), e.y + love.math.random(-50,50)) end
                    -- Boss death: kill ALL remaining enemies
                    for j=#enemies,1,-1 do
                        if not enemies[j].isBoss then
                            require("juice").spawnExplosion(enemies[j].x, enemies[j].y, 0, 0, "blood")
                            pickup.spawn(enemies[j].x, enemies[j].y, "gold")
                            kills = kills + 1
                        end
                    end
                    enemies = {}
                end
            else
                e.stateTimer = e.stateTimer - dt
                local hpRatio = e.hp / (e.maxHp or 1)
                local rage = 1 - hpRatio
                
                if e.type == "boss_slime" then
                    if e.state == "chasing" then
                        if e.stateTimer <= 0 then 
                            e.state = "preparing"; e.stateTimer = 0.6 * hpRatio
                        else 
                            smartMove(e, px, py, curSpd * (0.6 + rage*0.5), dt) 
                        end
                    elseif e.state == "preparing" then
                        e.x = e.x + love.math.random(-3, 3); e.y = e.y + love.math.random(-3, 3)
                        if e.stateTimer <= 0 then
                            e.state = "jumping"; e.stateTimer = 0.5
                            local jSpd = curSpd * (15 + rage*15)
                            if dist > 0 then e.jumpDx = (dx/dist)*jSpd; e.jumpDy = (dy/dist)*jSpd
                            else e.jumpDx = 0; e.jumpDy = 0 end
                        end
                    elseif e.state == "jumping" then
                        if e.stateTimer <= 0 then
                            e.state = "chasing"; e.stateTimer = 1.5 * hpRatio
                            -- Ring of bullets + Minions
                            local count = 8 + math.floor(rage*12)
                            for i=1,count do bullet.spawn(e.x, e.y, (i/count)*math.pi*2, true, 300) end
                            if love.math.random() < 0.4 + rage*0.4 then
                                enemy.spawn(10, "blob", {e.x, e.y})
                            end
                            juice.spawnExplosion(e.x, e.y, 0, 0, "spark")
                        else
                            local nx = e.x + e.jumpDx * dt; local ny = e.y + e.jumpDy * dt
                            if map.isWalkable(nx, e.y) then e.x = nx end
                            if map.isWalkable(e.x, ny) then e.y = ny end
                        end
                    end
                elseif e.type == "boss_idder" then
                    if e.state == "chasing" then
                        if e.stateTimer <= 0 then
                            e.state = love.math.random() > 0.5 and "spiral" or "preparing_laser"
                            e.stateTimer = e.state == "spiral" and 3 or 1.2
                            e.angle = math.atan2(dy, dx)
                        else smartMove(e, px, py, curSpd * (0.5 + rage*0.4), dt) end
                    elseif e.state == "spiral" then
                        e.angle = e.angle + dt * (3 + rage*4)
                        if math.floor(e.stateTimer * 15) % 2 == 0 then
                            bullet.spawn(e.x, e.y, e.angle, true, 400)
                            bullet.spawn(e.x, e.y, e.angle + math.pi, true, 400)
                        end
                        if e.stateTimer <= 0 then e.state = "chasing"; e.stateTimer = 2 end
                    elseif e.state == "preparing_laser" then
                        local ta = math.atan2(dy, dx)
                        local ad = (ta - e.angle + math.pi) % (math.pi*2) - math.pi
                        e.angle = e.angle + ad * dt * (2 + rage*4)
                        if math.floor(love.timer.getTime()*10)%2 == 0 then
                            juice.spawnText(e.x, e.y-40, "¡CARGANDO!", {1,0,0})
                        end
                        if e.stateTimer <= 0 then e.state = "laser"; e.stateTimer = 1.5 end
                    elseif e.state == "laser" then
                        local ta = math.atan2(dy, dx)
                        local ad = (ta - e.angle + math.pi) % (math.pi*2) - math.pi
                        e.angle = e.angle + ad * dt * (0.7 + rage * 0.8)
                        if math.floor(e.stateTimer*(30 + rage * 25)) % 2 == 0 then
                            bullet.spawn(e.x, e.y, e.angle + (love.math.random()-0.5)*0.06, true, 500, 1, 1.5)
                        end
                        if e.stateTimer <= 0 then e.state = "chasing"; e.stateTimer = 1.5 end
                    end
                end
            end
            
        -- Simple movement for non-bosses
        elseif not e.isBoss then
            if e.type == "dummy" then
                -- Dummies don't move, just wobble
                e.x = e.x + math.sin(love.timer.getTime()*10 + i)*0.2
            elseif e.type == "bomber" then
                e.stateTimer = e.stateTimer - dt
                if e.state == "chasing" then
                    if dist < 45 then
                        e.state = "exploding"; e.stateTimer = 0.6
                    else
                        smartMove(e, px, py, curSpd * 1.5, dt)
                    end
                elseif e.state == "exploding" then
                    -- Smoking effect as requested
                    local time = love.timer.getTime()
                    if math.floor(time*10)%2 == 0 then
                        require("juice").spawnExplosion(e.x, e.y, 0, 0, "spark") -- "bontando humo" effect
                    end
                    if e.stateTimer <= 0 then
                        -- EXPLODE
                        require("juice").spawnExplosion(e.x, e.y, 0, 0, "spark")
                        if dist < 70 then player.takeDamage(1) end
                        e.hp = 0 -- suicide
                    end
                end
            -- === IDDER: Ranged tank, retreats when player is close ===
            elseif e.type == "idder" then
                e.stateTimer = e.stateTimer - dt
                if e.state == "chasing" then
                    if e.stateTimer <= 0 then
                        e.state = "preparing"; e.stateTimer = 1.5; e.angle = math.atan2(dy, dx)
                    elseif dist < 80 then
                        -- Too close! Retreat to keep distance
                        smartMove(e, e.x - dx * 0.5, e.y - dy * 0.5, curSpd * 1.2, dt)
                    else
                        smartMove(e, px, py, curSpd, dt)
                    end
                elseif e.state == "preparing" then
                    local ta = math.atan2(dy, dx)
                    local ad = (ta - e.angle + math.pi) % (math.pi*2) - math.pi
                    e.angle = e.angle + ad * dt * 2
                    if e.stateTimer <= 0 then e.state = "laser"; e.stateTimer = 1.2 end
                elseif e.state == "laser" then
                    local ta = math.atan2(dy, dx)
                    local ad = (ta - e.angle + math.pi) % (math.pi*2) - math.pi
                    e.angle = e.angle + ad * dt * 0.5
                    if math.floor(e.stateTimer*25) % 2 == 0 then
                        bullet.spawn(e.x, e.y, e.angle + (love.math.random()-0.5)*0.04, true, 450, 1, 1.2)
                    end
                    if e.stateTimer <= 0 then e.state = "chasing"; e.stateTimer = love.math.random(2,4) end
                end
                
            -- === SITER: Uses walls but respects boxes ===
            elseif e.type == "siter" then
                e.stateTimer = e.stateTimer - dt
                if e.state == "chasing" then
                    if e.stateTimer <= 0 then
                        e.state = "charging"; e.stateTimer = 0.8; e.angle = math.atan2(dy, dx)
                    else
                        -- Smart chase: maintains distance ~120px, circles player
                        if dist > 150 then
                            smartMove(e, px, py, curSpd, dt)
                        elseif dist < 80 then
                            smartMove(e, e.x - dx*0.3, e.y - dy*0.3, curSpd * 0.8, dt)
                        else
                            -- Circle strafe
                            local circleX = e.x + (-dy/dist) * curSpd * dt
                            local circleY = e.y + (dx/dist) * curSpd * dt
                            if map.isWalkable(circleX, circleY) then
                                e.x = circleX; e.y = circleY
                            else
                                smartMove(e, px, py, curSpd * 0.5, dt)
                            end
                        end
                    end
                elseif e.state == "charging" then
                    e.x = e.x + love.math.random(-2, 2); e.y = e.y + love.math.random(-2, 2)
                    e.angle = math.atan2(dy, dx)
                    if e.stateTimer <= 0 then e.state = "firing"; e.stateTimer = 1.2 end
                elseif e.state == "firing" then
                    -- Predict where player is going based on movement
                    if math.floor(e.stateTimer*12) % 2 == 0 and e.stateTimer > 0.1 then
                        local leadAngle = e.angle + (love.math.random()-0.5) * 0.15
                        bullet.spawn(e.x, e.y, leadAngle, true, 400)
                        e.stateTimer = e.stateTimer - 0.08
                    end
                    if e.stateTimer <= 0 then e.state = "chasing"; e.stateTimer = love.math.random(2,4) end
                end
                
            -- === SLIME: Jumps, respects walls ===
            elseif e.type == "slime" then
                e.stateTimer = e.stateTimer - dt
                if e.state == "chasing" then
                    if e.stateTimer <= 0 then e.state = "preparing"; e.stateTimer = 0.4
                    elseif dist > 0 then smartMove(e, px, py, curSpd * 0.3, dt) end
                elseif e.state == "preparing" then
                    if e.stateTimer <= 0 then
                        e.state = "jumping"; e.stateTimer = 0.3
                        if dist > 0 then e.jumpDx = (dx/dist)*curSpd*12; e.jumpDy = (dy/dist)*curSpd*12
                        else e.jumpDx = 0; e.jumpDy = 0 end
                    end
                elseif e.state == "jumping" then
                    if e.stateTimer <= 0 then e.state = "chasing"; e.stateTimer = love.math.random(1,3)
                    else
                        local nx = e.x + e.jumpDx * dt; local ny = e.y + e.jumpDy * dt
                        if map.isWalkable(nx, e.y) then e.x = nx end
                        if map.isWalkable(e.x, ny) then e.y = ny end
                    end
                end
                
            -- === BLOB/OOZEL: Flanking and dodging ===
            else
                if dist > 0 then
                    -- Separation
                    for j, other in ipairs(enemies) do
                        if i ~= j then
                            local sx = e.x - other.x; local sy = e.y - other.y
                            local sd = math.sqrt(sx*sx + sy*sy)
                            if sd < 28 and sd > 0 then
                                local sepMx = (sx/sd) * 80 * dt; local sepMy = (sy/sd) * 80 * dt
                                if map.isWalkable(e.x + sepMx, e.y + sepMy) then
                                    e.x = e.x + sepMx; e.y = e.y + sepMy
                                end
                            end
                        end
                    end
                    
                    -- Oozel: smart dodge + flanking
                    if e.type == "oozel" then
                        -- Dodge incoming bullets
                        local dodgeX, dodgeY = 0, 0
                        for _, b in ipairs(bullet.getBullets()) do
                            if not b.isEnemy then
                                local bdx = b.x - e.x; local bdy = b.y - e.y
                                local bdist = math.sqrt(bdx*bdx + bdy*bdy)
                                if bdist < 60 then
                                    dodgeX = dodgeX - b.dy * 0.4
                                    dodgeY = dodgeY + b.dx * 0.4
                                end
                            end
                        end
                        if dodgeX ~= 0 or dodgeY ~= 0 then
                            local dmx = dodgeX * dt; local dmy = dodgeY * dt
                            if map.isWalkable(e.x + dmx, e.y + dmy) then
                                e.x = e.x + dmx; e.y = e.y + dmy
                            end
                        end
                        -- Dasher oozel: charge at player when close
                        if (e.subtype or "normal") == "dasher" and dist < 100 and not e.dashCharging then
                            e.dashCharging = true; e.dashTimer = 0.2
                            e.dashDx = (dx/dist)*curSpd*15; e.dashDy = (dy/dist)*curSpd*15
                        end
                        if e.dashCharging then
                            e.dashTimer = (e.dashTimer or 0) - dt
                            local nx = e.x + (e.dashDx or 0)*dt; local ny = e.y + (e.dashDy or 0)*dt
                            if map.isWalkable(nx, e.y) then e.x = nx end
                            if map.isWalkable(e.x, ny) then e.y = ny end
                            if e.dashTimer <= 0 then e.dashCharging = false end
                        else
                            local fx, fy = getFlankTarget(e, px, py, i)
                            smartMove(e, fx, fy, curSpd * 1.3, dt)
                        end
                    else
                        -- Blob: direct chase with wall sliding
                        smartMove(e, px, py, curSpd, dt)
                    end
                    
                    -- MiniBoss extra action (firing bullets)
                    if e.isMiniBoss and dist < 400 then
                        if (math.floor(e.animTimer * 2) % 6 == 0) and e.lastMiniFire ~= math.floor(e.animTimer * 2) then
                            e.lastMiniFire = math.floor(e.animTimer * 2)
                            bullet.spawn(e.x, e.y, math.atan2(dy, dx), true, 350)
                        end
                    end
                end
            end
        end
    end
end
end

function enemy.spawn(difficulty, forceType, forcePos, playerPosAvoid, roomsCleared)
    local diff = difficulty or 0
    local types = {"blob", "blob"}
    if diff > 1 then table.insert(types, "oozel") end
    if diff > 2 then table.insert(types, "blob") end
    if diff > 3 then table.insert(types, "bomber") end
    if diff > 4 then table.insert(types, "oozel") end
    if diff > 5 then table.insert(types, "idder") end
    if diff > 6 then table.insert(types, "bomber") end
    if diff > 7 then table.insert(types, "slime") end
    if diff > 8 then table.insert(types, "siter") end
    if (roomsCleared or 0) == 0 then
        table.insert(types, "dummy")
        table.insert(types, "dummy")
    end
    if diff > 10 then table.insert(types, "idder") end
    
    local t = forceType or types[love.math.random(1, #types)]
    local count = 6 + diff * 2.2
    if forceType == "bomber" then count = 5 + diff * 1.2 end
    
    for i = 1, count do
        local tries = 0
        local sx, sy
        repeat
            sx = love.math.random(100, 1340)
            sy = love.math.random(100, 860)
            tries = tries + 1
            -- Ensure not spawning near boxes
            local isNearBox = false
            for bx=-32,32,16 do
                for by=-32,32,16 do
                    if map.getTileAt(sx+bx, sy+by) and map.getTileAt(sx+bx, sy+by):sub(1,3) == "box" then isNearBox = true end
                end
            end
        until (not isNearBox and map.isWalkable(sx, sy) and (not playerPosAvoid or 
            math.sqrt((sx-(playerPosAvoid.x or playerPosAvoid[1] or 0))^2 + (sy-(playerPosAvoid.y or playerPosAvoid[2] or 0))^2) > 300)) or tries > 20
        
        if sx then
            enemy.spawnSpecific(sx, sy, forceType or types[love.math.random(1, #types)], diff)
        end
    end
end

function enemy.spawnSpecific(x, y, t, diff)
    local baseHp, baseSpeed = 5, 100
    if t == "oozel" then baseHp = 6; baseSpeed = 190
    elseif t == "idder" then baseHp = 18; baseSpeed = 110
    elseif t == "slime" then baseHp = 12; baseSpeed = 100
    elseif t == "siter" then baseHp = 28; baseSpeed = 120
    elseif t == "bomber" then baseHp = 7; baseSpeed = 160
    elseif t == "dummy" then baseHp = 35; baseSpeed = 0
    end
    
    local eHp = baseHp + math.floor(diff * 1.2)
    local eSpeed = baseSpeed + math.floor(diff * 4)
    local eScale = 1
    local colorSets = {
        blob = {{0.8,1,0.7},{0.7,0.9,0.6},{0.9,0.8,0.6},{0.6,1,0.8}},
        oozel = {{0.5,0.7,1},{0.4,0.9,1},{0.6,0.6,1},{0.3,0.8,0.9}},
        slime = {{0.3,1,0.4},{0.2,0.8,0.5},{0.5,1,0.3},{0.1,0.9,0.6}},
        idder = {{1,0.7,0.6},{0.9,0.6,0.7},{1,0.5,0.5},{0.8,0.7,0.8}},
        siter = {{0.9,0.4,0.9},{0.7,0.3,1},{1,0.5,0.7},{0.8,0.6,1}},
        bomber = {{1,0.3,0.3},{1,0.5,0},{1,0.1,0.1}},
    }
    local vars = colorSets[t] or {{1,1,1}}
    local eColor = vars[love.math.random(1, #vars)]
    
    -- Subtypes: special ability variations
    local subtype = "normal"
    if t == "blob" and diff > 3 and love.math.random() < 0.25 then
        subtype = "bomber"; eColor = {1, 0.6, 0.2} -- orange blob = explodes on death
    elseif t == "oozel" and diff > 4 and love.math.random() < 0.2 then
        subtype = "dasher"; eColor = {0.2, 1, 1}; eSpeed = eSpeed * 1.4 -- cyan oozel = charges at you
    elseif t == "slime" and diff > 5 and love.math.random() < 0.2 then
        subtype = "splitter"; eColor = {0.8, 1, 0.2} -- yellow slime = splits into 2 on death
    end
    
    local isMiniBoss = false
    if diff > 6 and love.math.random() < 0.15 then
        isMiniBoss = true; eHp = eHp * 7; eScale = 2.5; eSpeed = eSpeed * 1.1; eColor = {1,0,0}
    end
    
    -- Elite
    if not isMiniBoss and love.math.random() < math.min(0.35, diff * 0.025) then
        eHp = math.floor(eHp * 3.5); eScale = 1.6; eSpeed = eSpeed * 1.15; eColor = {1,0.3,0.3}; subtype = "elite"
    end
    if eScale == 1 then eScale = 0.85 + love.math.random() * 0.3 end
    
    local variations = assets[t]
    local varIdx = (variations and #variations > 0) and love.math.random(1, #variations) or 1
    table.insert(enemies, {x=x, y=y, type=t, subtype=subtype, hp=eHp, maxHp=eHp, speed=eSpeed, hitTimer=0,
        state="spawning", stateTimer=1.2, scale=eScale, color=eColor,
        animTimer=love.math.random()*10, isMiniBoss=isMiniBoss, variation=varIdx})
end

function enemy.spawnBoss(difficulty)
    local t = love.math.random() > 0.5 and "boss_slime" or "boss_idder"
    local diff = difficulty or 0
    local eHp = 150 + diff * 25
    local variations = assets[t]
    local varIdx = (variations and #variations > 0) and love.math.random(1, #variations) or 1
    table.insert(enemies, {x=720, y=480, type=t, hp=eHp, maxHp=eHp, speed=65, hitTimer=0,
        state="chasing", stateTimer=2, scale=(t=="boss_slime" and 4 or 3.2),
        color=(t=="boss_slime" and {0.4,1,0.4} or {1,0.4,1}), isBoss=true, animTimer=0, variation=varIdx})
end

function enemy.draw()
    local time = love.timer.getTime()
    for _, e in ipairs(enemies) do
        local baseType = e.type
        if e.type == "boss_slime" then baseType = "slime"
        elseif e.type == "boss_idder" then baseType = "idder" end
        
        -- Telegraph
        if (e.type == "idder" and e.state == "preparing") or (e.type == "boss_idder" and e.state == "preparing_laser") then
            local xVar = assets.x and assets.x[1]
            if xVar and math.sin(time * 12) > 0 then
                local alpha = 0.5 + math.sin(time * 8) * 0.3
                love.graphics.setColor(1, 0.2, 0.1, alpha)
                local xx, yy = e.x, e.y
                local ox, oy = xVar:getWidth()/2, xVar:getHeight()/2
                for d = 1, 30 do
                    xx = xx + math.cos(e.angle) * 32; yy = yy + math.sin(e.angle) * 32
                    love.graphics.draw(xVar, xx, yy, e.angle + time*3, 0.8+math.sin(time*10+d)*0.2, 0.8+math.sin(time*10+d)*0.2, ox, oy)
                end
                love.graphics.setColor(1,1,1,1)
            end
        end
        
        -- Laser beam visual
        if (e.type == "idder" and e.state == "laser") or (e.type == "boss_idder" and e.state == "laser") then
            local bw = e.isBoss and 8 or 5
            local bx2 = e.x + math.cos(e.angle)*1000; local by2 = e.y + math.sin(e.angle)*1000
            love.graphics.setColor(1,0.3,0.1, 0.12+math.sin(time*20)*0.08)
            love.graphics.setLineWidth(bw*5); love.graphics.line(e.x, e.y, bx2, by2)
            love.graphics.setColor(1,0.5,0.2, 0.35)
            love.graphics.setLineWidth(bw*2); love.graphics.line(e.x, e.y, bx2, by2)
            love.graphics.setColor(1,0.9,0.6, 0.55)
            love.graphics.setLineWidth(bw); love.graphics.line(e.x, e.y, bx2, by2)
            love.graphics.setLineWidth(1); love.graphics.setColor(1,1,1,1)
        end
        
        -- Siter charging glow
        if e.type == "siter" and e.state == "charging" then
            love.graphics.setColor(0.8, 0.2, 1, 0.2 + math.sin(time*15)*0.15)
            love.graphics.circle("fill", e.x, e.y, 40 + math.sin(time*10)*8)
            love.graphics.setColor(1,1,1,1)
        end
        
        if e.state == "spawning" then
            local p = 1 - (e.stateTimer / 1.2)
            love.graphics.setColor(1, 0.2, 0.2, 0.5 * p)
            love.graphics.circle("fill", e.x, e.y, 20 * (e.scale or 1) * p)
            love.graphics.setColor(1, 0.2, 0.2, 1)
            love.graphics.circle("line", e.x, e.y, 20 * (e.scale or 1))
        else
            local varList = assets[baseType]
            local img = varList and varList[e.variation or 1] or (varList and varList[1])
            if img then
            local fs = e.scale
            local ox = img:getWidth() / 2
            local oy = img:getHeight() / 2
            local anim = e.animTimer or 0
            local sx, sy, drawY, drawRot = fs, fs, e.y, 0
            
            if e.type == "blob" or e.type == "oozel" then
                local b = math.sin(anim * 7) * 0.1
                sx = fs * (1+b); sy = fs * (1-b); drawY = e.y + math.sin(anim*7)*2
                -- Oozel leans into movement direction
                if e.type == "oozel" then drawRot = math.sin(anim*5) * 0.15 end
            elseif e.type == "slime" or e.type == "boss_slime" then
                if e.state == "jumping" then sx=fs*0.65; sy=fs*1.5; drawY=e.y-10
                elseif e.state == "preparing" then sx=fs*1.35; sy=fs*0.65
                else local w=math.sin(anim*4)*0.07; sx=fs*(1+w); sy=fs*(1-w) end
            elseif e.type == "idder" or e.type == "boss_idder" then
                local p=math.sin(anim*3)*0.05; sx=fs*(1+p); sy=fs*(1-p)
                if e.state == "laser" or e.state == "preparing_laser" or e.state == "preparing" then
                    drawY = e.y + love.math.random(-2,2)
                end
            elseif e.type == "siter" then
                drawY = e.y + math.sin(anim*2.5)*8
                local p=math.sin(anim*5)*0.04; sx=fs*(1+p); sy=fs*(1-p)
                drawRot = math.sin(anim*1.5)*0.1
                            if e.state == "firing" then drawRot = drawRot + math.sin(time*30)*0.05 end
            end

            -- Apply shrinking during death
            if e.state == "dying" and not e.isBoss then
                local shrink = math.max(0, e.stateTimer / 0.4)
                sx = sx * shrink
                sy = sy * shrink
                drawRot = drawRot + (0.4 - e.stateTimer) * 20
            end
            
            -- Shadow
            love.graphics.setColor(0,0,0,0.2)
            love.graphics.ellipse("fill", e.x, e.y + oy*fs*0.5, ox*sx*1.2, 3*fs)
            
            -- Sprite
            -- Final safety check for img
            img = img or assets.floor
            
            if e.hitTimer > 0 or (e.type == "bomber" and e.state == "exploding" and math.floor(time*15)%2==0) then 
                love.graphics.setColor(1,0,0)
                sx = sx * 1.3
                sy = sy * 1.3
            elseif e.state == "dying" then love.graphics.setColor(e.color[1],e.color[2],e.color[3], 0.5+math.sin(time*30)*0.5)
            else love.graphics.setColor(e.color[1], e.color[2], e.color[3]) end
            
            love.graphics.draw(img, e.x, drawY, drawRot, sx, sy, ox, oy)
            end
        end
    end
    love.graphics.setColor(1,1,1)
end

function enemy.getEnemies() return enemies end

function enemy.hit(i, dmg)
    local e = enemies[i]
    if e.state == "dying" then return false end
    e.hp = e.hp - (dmg or 1); e.hitTimer = 0.12
    if e.hp <= 0 then
        if e.isBoss then e.hp = 1; e.state = "dying"; e.stateTimer = 3.0; return false end
        
        -- Start death animation instead of immediate removal
        e.state = "dying"
        e.stateTimer = 0.4
        e.dieX, e.dieY = e.x, e.y
        
        -- Blood explosion (refined radial effect)
        require("juice").spawnExplosion(e.x, e.y, 0, 0, "gore")
        
        -- Subtype death effects
        if e.subtype == "bomber" then
            -- Explode: shoot 8 bullets in a ring
            for a=0,7 do
                local ang = (a/8) * math.pi * 2
                bullet.spawn(e.x, e.y, ang, true, 250)
            end
            require("juice").spawnExplosion(e.x, e.y, 0, 0, "spark")
        elseif e.subtype == "splitter" then
            -- Split into 2 mini slimes
            for s=1,2 do
                local ox = (s==1 and -20 or 20)
                table.insert(enemies, {x=e.x+ox, y=e.y, type="slime", subtype="normal",
                    hp=3, maxHp=3, speed=e.speed*1.2, hitTimer=0, state="chasing", stateTimer=1,
                    scale=e.scale*0.6, color={0.6,1,0.3}, animTimer=0})
            end
        end
        if e.subtype == "elite" then
            for k=1, 5 do pickup.spawn(e.x + love.math.random(-15,15), e.y + love.math.random(-15,15), "gold") end
        end
        if love.math.random() < 0.25 and (e.type == "blob" or e.type == "slime") then
            if _G.spawnHazard then _G.spawnHazard("poison", e.x, e.y, 35 + e.scale*10, 6) end
        end
        return true
    end
    return false
end

function enemy.getEnemyCount() return #enemies end
function enemy.clear() enemies = {}; kills = 0 end
function enemy.getKills() return kills end
function enemy.reset() enemy.clear() end

return enemy

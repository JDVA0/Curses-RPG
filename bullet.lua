local bullet = {}
local map = require("map")
local bullets = {}
local speed = 800
local sprite

function bullet.init(s)
    bullets = {}; sprite = s
end

function bullet.spawn(x, y, angle, isEnemy, customSpeed, customDamage, customSize, customHoming, customSprite, customType)
    local s = customSpeed or speed
    local bType = customType
    if not bType and not isEnemy then
        local types = {"fire", "ice", "metal"}
        bType = types[love.math.random(1, #types)]
    end
    
    table.insert(bullets, {
        x = x,
        y = y,
        dx = math.cos(angle) * s,
        dy = math.sin(angle) * s,
        angle = angle,
        life = 3,
        isEnemy = isEnemy or false,
        damage = customDamage or 1,
        size = customSize or 1,
        homing = (not isEnemy) and (customHoming or 0) or 0,
        sprite = customSprite,
        type = bType or "default"
    })
end

function bullet.update(dt)
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        -- Homing logic
        if b.homing and b.homing > 0 then
            local enemy = require("enemy")
            local target = nil
            local minDist = 400
            for _, e in ipairs(enemy.getEnemies()) do
                if not e.isDead then
                    local d = math.sqrt((e.x-b.x)^2 + (e.y-b.y)^2)
                    if d < minDist then minDist = d; target = e end
                end
            end
            if target then
                local ta = math.atan2(target.y - b.y, target.x - b.x)
                local curA = b.angle
                local diff = ta - curA
                while diff > math.pi do diff = diff - math.pi*2 end
                while diff < -math.pi do diff = diff + math.pi*2 end
                
                local steerSpd = 1.5 + b.homing * 1.2
                b.angle = b.angle + diff * steerSpd * dt
                local s = math.sqrt(b.dx*b.dx + b.dy*b.dy)
                b.dx = math.cos(b.angle) * s
                b.dy = math.sin(b.angle) * s
            end
        end

        local nx = b.x + b.dx * dt
        local ny = b.y + b.dy * dt
        
        -- Bouncing logic (Room Mod)
        if _G.roomMod == "bouncing" then
            if not map.isWalkable(nx, b.y) then
                b.dx = -b.dx
                b.angle = math.atan2(b.dy, b.dx)
                nx = b.x + b.dx * dt
            end
            if not map.isWalkable(b.x, ny) then
                b.dy = -b.dy
                b.angle = math.atan2(b.dy, b.dx)
                ny = b.y + b.dy * dt
            end
        end

        b.x = nx
        b.y = ny
        b.life = b.life - dt
        
        -- Corrected bounds for 1440x960 map
        if b.life <= 0 or b.x < -400 or b.x > 1800 or b.y < -400 or b.y > 1300 then
            table.remove(bullets, i)
        end
    end
end

function bullet.draw()
    local time = love.timer.getTime()
    for _, b in ipairs(bullets) do
        local pulse = 1 + math.sin(time * 15 + b.x) * 0.15
        local r = (b.size or 1) * 4 * pulse
        local s_scale = (b.size or 1) * 0.7 * pulse
        
        -- Determine which sprite to use
        local drawImg = b.sprite
        if not drawImg then
            if type(sprite) == "table" then
                -- Match named variations if they exist
                if b.type == "ice" then drawImg = sprite.ice or sprite[1]
                elseif b.type == "fire" then drawImg = sprite.fire or sprite[1]
                elseif b.type == "metal" then drawImg = sprite.metal or sprite[1]
                else drawImg = sprite[1] end
            else
                drawImg = sprite
            end
        end

        if drawImg and type(drawImg) ~= "table" then
            if b.isEnemy then 
                love.graphics.setColor(1, 0.4, 0.4)
            else 
                love.graphics.setColor(1, 1, 1)
            end
            
            love.graphics.draw(drawImg, b.x, b.y, b.angle, s_scale, s_scale, drawImg:getWidth()/2, drawImg:getHeight()/2)
        else
            -- Fallback to circles
            if b.isEnemy then
                love.graphics.setColor(1, 0.4, 0.1, 0.3)
                love.graphics.circle("fill", b.x, b.y, r * 2)
                love.graphics.setColor(1, 0.15, 0.1)
                love.graphics.circle("fill", b.x, b.y, r)
            else
                love.graphics.setColor(0.3, 0.6, 1, 0.3)
                love.graphics.circle("fill", b.x, b.y, r * 2.5)
                love.graphics.setColor(0.5, 0.8, 1)
                love.graphics.circle("fill", b.x, b.y, r)
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
end

function bullet.getBullets()
    return bullets
end

function bullet.remove(index)
    table.remove(bullets, index)
end

function bullet.reset()
    bullets = {}
end

return bullet

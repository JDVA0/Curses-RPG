local pickup = {}
local pickups = {}
local sprite

function pickup.init(img)
    sprite = img
    pickups = {}
end

function pickup.spawn(x, y, type)
    table.insert(pickups, {
        x = x,
        y = y,
        type = type or "gold",
        timer = 0,
        vx = love.math.random(-80, 80),
        vy = love.math.random(-80, 80),
        collected = false
    })
end

function pickup.update(dt, px, py, magnetRadius)
    magnetRadius = magnetRadius or 24
    
    for i = #pickups, 1, -1 do
        local p = pickups[i]
        p.timer = p.timer + dt
        
        -- Initial burst velocity with friction + wall collision
        if p.timer < 0.5 then
            local map = require("map")
            local nx = p.x + p.vx * dt
            local ny = p.y + p.vy * dt
            if map.isWalkable(nx, p.y) then p.x = nx else p.vx = -p.vx * 0.3 end
            if map.isWalkable(p.x, ny) then p.y = ny else p.vy = -p.vy * 0.3 end
            p.vx = p.vx * 0.92
            p.vy = p.vy * 0.92
        end
        
        -- Magnet pull
        local dx = px - p.x
        local dy = py - p.y
        local dist = math.sqrt(dx*dx + dy*dy)
        
        if dist < magnetRadius and dist > 0 and p.timer > 0.3 then
            local pullSpeed = 300 * (1 - dist / magnetRadius)
            p.x = p.x + (dx / dist) * pullSpeed * dt
            p.y = p.y + (dy / dist) * pullSpeed * dt
            if love.math.random() < 0.1 then
                require("juice").spawnExplosion(p.x, p.y, 0, 0, "spark_small")
            end
        end
        
        -- Collection
        if dist < 18 and p.timer > 0.3 then
            require("juice").spawnExplosion(p.x, p.y, 0, 0, "spark")
            table.remove(pickups, i)
            return p.type
        end
    end
    return nil
end

function pickup.draw()
    local time = love.timer.getTime()
    for _, p in ipairs(pickups) do
        local floatY = math.sin(p.timer * 5 + p.x) * 3
        local pulse = 1 + math.sin(time * 6 + p.y) * 0.1
        
        -- Glow
        love.graphics.setColor(1, 0.85, 0.2, 0.15)
        love.graphics.circle("fill", p.x, p.y + floatY, 12 * pulse)
        
        local img = (type(sprite) == "table") and (sprite[1]) or sprite
        love.graphics.setColor(1, 1, 1)
        if img then
            love.graphics.draw(img, p.x, p.y + floatY, 0, pulse, pulse, img:getWidth()/2, img:getHeight()/2)
        end
    end
end

function pickup.clear()
    pickups = {}
end

function pickup.forceCollectAll()
    local count = #pickups
    pickups = {}
    return count
end

return pickup

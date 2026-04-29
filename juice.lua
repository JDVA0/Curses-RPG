local juice = {}
local particles = {}
local bloodDecals = {}
local screenBlood = {} -- Blood on the "camera"
local bloodImg = nil
local ironImg = nil
local floatingTexts = {}

function juice.init(blood, iron)
    particles = {}
    bloodDecals = {}
    floatingTexts = {}
    screenBlood = {}
    bloodImg = blood
    ironImg = iron
end

function juice.spawnScreenBlood()
    for i = 1, 5 do
        local var = (bloodImg and #bloodImg > 0) and love.math.random(1, #bloodImg) or 1
        table.insert(screenBlood, {
            x = love.math.random(0, 1280),
            y = love.math.random(0, 720),
            r = love.math.random() * math.pi * 2,
            s = love.math.random(15, 45) / 10,
            life = 4.5,
            alpha = love.math.random(0.5, 0.8),
            variation = var,
            vx = love.math.random(-20, 20),
            vy = love.math.random(20, 60) -- Slime down effect
        })
    end
end

function juice.spawnComboText(x, y, text, color)
    table.insert(floatingTexts, {
        x = x, y = y, text = text, color = color or {1, 1, 1},
        life = 1.5, dy = -80, scale = 0,
        isCombo = true,
        rot = love.math.random(-0.2, 0.2)
    })
end

function juice.spawnExplosion(x, y, impactDx, impactDy, pType)
    local ix = impactDx or 0
    local iy = impactDy or 0
    pType = pType or "blood"
    
    local len = math.sqrt(ix*ix + iy*iy)
    if len > 0 then ix = ix / len; iy = iy / len end

    local count = pType == "spark" and 8 or 12
    if pType == "spark_small" then count = 4 end
    if pType == "dust" then count = 6 end
    if pType == "gore" then count = 18 end

    for i = 1, count do
        local angle = math.atan2(iy, ix) + love.math.random(-1, 1) * 1.8
        if len == 0 then angle = love.math.random() * math.pi * 2 end
        
        local spd = love.math.random(60, 400) 
        if pType == "spark" then spd = love.math.random(80, 400) 
        elseif pType == "spark_small" then spd = love.math.random(30, 150)
        elseif pType == "dust" then spd = love.math.random(10, 40)
        elseif pType == "gore" then spd = love.math.random(100, 450) end
        
        -- Gore type variety: blood, gib, bone
        local particleType = pType
        if pType == "gore" then
            local roll = love.math.random()
            if roll < 0.35 then particleType = "gib"
            elseif roll < 0.5 then particleType = "bone"
            else particleType = "blood" end
        end
        
        local var = 1
        if particleType == "blood" and bloodImg then var = love.math.random(1, #bloodImg)
        elseif particleType == "spark" and ironImg then var = love.math.random(1, #ironImg) end

        table.insert(particles, {
            x = x + love.math.random(-4, 4), y = y + love.math.random(-4, 4),
            dx = math.cos(angle) * spd,
            dy = math.sin(angle) * spd,
            life = (pType == "spark" or pType == "spark_small") and love.math.random(3, 6) / 10 or love.math.random(6, 16) / 10,
            type = particleType,
            variation = var,
            size = particleType == "gib" and love.math.random(5, 10) or (particleType == "bone" and love.math.random(3, 6) or love.math.random(3, 7)),
            r = love.math.random() * math.pi * 2,
            vr = love.math.random(-15, 15),
            gravity = (particleType == "blood" or particleType == "gib" or particleType == "bone") and 700 or ((pType == "spark" or pType == "spark_small") and 250 or 0),
            friction = (pType == "spark" or pType == "spark_small") and 0.92 or (pType == "dust" and 0.8 or 0.86),
            bounces = (particleType == "gib" or particleType == "bone") and love.math.random(1, 3) or 0
        })
    end

    -- Blood explosion visual (radial blast streaks)
    if pType == "blood" or pType == "gore" then
        local streakCount = pType == "gore" and 8 or 3
        for i = 1, streakCount do
            local ang = love.math.random() * math.pi * 2
            -- Bias streaks in impact direction
            if len > 0 then ang = math.atan2(iy, ix) + (love.math.random() - 0.5) * 2.5 end
            local spd = love.math.random(350, 600)
            table.insert(particles, {
                x = x, y = y,
                dx = math.cos(ang) * spd,
                dy = math.sin(ang) * spd,
                life = love.math.random(8, 15) / 100,
                type = "blood_streak",
                size = love.math.random(2, 4)
            })
        end

        -- Blood mist cloud (soft, lingering)
        if pType == "gore" then
            for i = 1, 4 do
                table.insert(particles, {
                    x = x + love.math.random(-12, 12), y = y + love.math.random(-12, 12),
                    dx = love.math.random(-30, 30), dy = love.math.random(-50, -10),
                    life = love.math.random(8, 14) / 10,
                    type = "blood_mist",
                    size = love.math.random(15, 30),
                    r = 0, vr = 0, gravity = -20, friction = 0.95
                })
            end
        end

        -- Blood decals on floor
        local decalCount = pType == "gore" and 5 or 2
        for i = 1, decalCount do
            local spread = pType == "gore" and 50 or 30
            local var = (bloodImg and #bloodImg > 0) and love.math.random(1, #bloodImg) or 1
            table.insert(bloodDecals, {
                x = x + love.math.random(-spread, spread),
                y = y + love.math.random(-spread, spread),
                r = love.math.random() * math.pi * 2,
                s = love.math.random(6, 16) / 10,
                life = 5,
                alpha = love.math.random(4, 7) / 10,
                variation = var
            })
        end
    end
end

function juice.spawnMuzzleFlash(x, y, angle)
    -- Light flash
    table.insert(particles, {
        x = x, y = y,
        dx = 0, dy = 0,
        life = 0.05,
        type = "muzzle",
        size = 30,
        r = angle
    })
    
    -- Casing shell
    local cAngle = angle + math.pi/2 + love.math.random(-0.5, 0.5)
    local cSpd = love.math.random(150, 250)
    table.insert(particles, {
        x = x, y = y,
        dx = math.cos(cAngle) * cSpd,
        dy = math.sin(cAngle) * cSpd - 100,
        life = 1.0,
        type = "casing",
        size = 2,
        r = love.math.random() * 6.28,
        vr = love.math.random(10, 20),
        gravity = 600
    })
end

function juice.spawnText(x, y, text, color)
    table.insert(floatingTexts, {
        x = x, y = y, text = text,
        color = color or {1, 1, 1},
        life = 1.2, dy = -40, scale = 1.5
    })
end

function juice.update(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.dx * dt
        p.y = p.y + p.dy * dt
        p.dy = p.dy + (p.gravity or 0) * dt
        
        if p.type == "spark" or p.type == "spark_small" or p.type == "blood" or p.type == "gib" or p.type == "dust" or p.type == "bone" or p.type == "blood_mist" then
            p.dx = p.dx * (p.friction or 0.9)
            p.dy = p.dy * (p.friction or 0.9)
            
            if p.type == "dust" then p.size = p.size * 0.95 end
            if p.type == "blood_mist" then p.size = p.size * (1 + dt * 0.5) end -- Mist expands
            
            -- Simple floor bounce for gibs and bones
            if (p.type == "gib" or p.type == "bone") and p.dy > 0 and p.y > 680 then
                if (p.bounces or 0) > 0 then
                    p.dy = -p.dy * 0.45
                    p.dx = p.dx * 0.6
                    p.bounces = p.bounces - 1
                    p.y = 680
                    if p.type == "gib" then
                        table.insert(bloodDecals, {
                            x = p.x, y = p.y, r = love.math.random() * math.pi * 2,
                            s = p.size / 10, life = 8, alpha = 0.4
                        })
                    end
                end
            end
        end
        if p.vr then p.r = p.r + p.vr * dt end
        
        p.life = p.life - dt
        if p.life <= 0 then table.remove(particles, i) end
    end
    
    for i = #bloodDecals, 1, -1 do
        local d = bloodDecals[i]
        d.life = d.life - dt
        if d.life < 1 then d.alpha = d.alpha - dt * 2 end -- Fade fast
        if d.life <= 0 or d.alpha <= 0 then table.remove(bloodDecals, i) end
    end

    for i = #screenBlood, 1, -1 do
        local sb = screenBlood[i]
        sb.x = sb.x + (sb.vx or 0) * dt
        sb.y = sb.y + (sb.vy or 0) * dt
        sb.life = sb.life - dt
        if sb.life < 1 then sb.alpha = sb.alpha - dt * 2 end -- Fade fast
        if sb.life <= 0 or sb.alpha <= 0 then table.remove(screenBlood, i) end
    end
    
    for i = #floatingTexts, 1, -1 do
        local ft = floatingTexts[i]
        ft.y = ft.y + ft.dy * dt
        ft.dy = ft.dy * 0.9 -- Slow down
        ft.scale = ft.scale + (1.2 - ft.scale) * 10 * dt
        ft.life = ft.life - dt
        if ft.life <= 0 then table.remove(floatingTexts, i) end
    end
end

function juice.drawScreenBlood()
    for _, sb in ipairs(screenBlood) do
        if bloodImg then
            local img = bloodImg[sb.variation] or bloodImg[1]
            if img then
                love.graphics.setColor(0.5, 0, 0, sb.alpha)
                love.graphics.draw(img, sb.x, sb.y, sb.r, sb.s, sb.s, img:getWidth()/2, img:getHeight()/2)
            end
        end
    end
end

function juice.drawDecals()
    -- Persistent decals (on floor)
    for _, d in ipairs(bloodDecals) do
        if bloodImg then
            local img = bloodImg[d.variation] or bloodImg[1]
            if img then
                love.graphics.setColor(0.6, 0, 0, d.alpha)
                love.graphics.draw(img, d.x, d.y, d.r, d.s, d.s, img:getWidth()/2, img:getHeight()/2)
            end
        end
    end
end

function juice.draw()
    -- Retro pixel particles
    for _, p in ipairs(particles) do
        local alpha = math.min(1, p.life * 4)
        if p.type == "spark" or p.type == "spark_small" then
            if ironImg and p.type == "spark" then
                local img = ironImg[p.variation] or ironImg[1]
                if img then
                    love.graphics.setColor(1, 0.9, 0.7, alpha)
                    love.graphics.draw(img, math.floor(p.x), math.floor(p.y), p.r, p.size * 0.15, p.size * 0.15, img:getWidth()/2, img:getHeight()/2)
                end
            else
                love.graphics.setColor(1, 0.9, 0.2, alpha)
                love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), p.size, p.size)
            end
        elseif p.type == "dust" then
            love.graphics.setColor(0.8, 0.8, 0.8, alpha * 0.5)
            love.graphics.circle("fill", math.floor(p.x), math.floor(p.y), p.size)
        elseif p.type == "blood" then
            if bloodImg then
                local img = bloodImg[p.variation] or bloodImg[1]
                if img then
                    love.graphics.setColor(0.8, 0, 0, alpha)
                    love.graphics.draw(img, math.floor(p.x), math.floor(p.y), p.r, p.size * 0.2, p.size * 0.2, img:getWidth()/2, img:getHeight()/2)
                end
            else
                love.graphics.setColor(0.7, 0.05, 0.05, alpha)
                love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), p.size, p.size)
            end
        elseif p.type == "gib" then
            love.graphics.setColor(0.5, 0.0, 0.0, alpha)
            love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), p.size, p.size, 2, 2)
            love.graphics.setColor(0.85, 0.08, 0.08, alpha)
            love.graphics.rectangle("fill", math.floor(p.x)+1, math.floor(p.y)+1, p.size-2, p.size-2, 1, 1)
        elseif p.type == "bone" then
            love.graphics.setColor(0.9, 0.85, 0.7, alpha)
            love.graphics.push()
            love.graphics.translate(math.floor(p.x), math.floor(p.y))
            love.graphics.rotate(p.r)
            love.graphics.rectangle("fill", -p.size/2, -1, p.size, 2, 1, 1)
            love.graphics.pop()
        elseif p.type == "blood_mist" then
            local ma = alpha * 0.25
            love.graphics.setColor(0.6, 0.0, 0.0, ma)
            love.graphics.circle("fill", math.floor(p.x), math.floor(p.y), p.size)
        elseif p.type == "blood_streak" then
            love.graphics.setColor(0.9, 0, 0, alpha)
            love.graphics.setLineWidth(p.size)
            love.graphics.line(p.x, p.y, p.x - p.dx * 0.02, p.y - p.dy * 0.02)
            love.graphics.setLineWidth(1)
        elseif p.type == "muzzle" then
            love.graphics.setColor(1, 1, 0.5, alpha)
            love.graphics.circle("fill", p.x, p.y, p.size * alpha)
        elseif p.type == "casing" then
            love.graphics.setColor(0.8, 0.7, 0.2, alpha)
            love.graphics.rectangle("fill", p.x, p.y, 3, 1, p.r)
        end
    end
    
    -- Floating texts with retro pop-in
    for _, ft in ipairs(floatingTexts) do
        local a = math.min(1, ft.life * 2)
        local s = ft.scale
        if ft.isCombo then
            -- Anime style combo text
            love.graphics.push()
            love.graphics.translate(ft.x, ft.y)
            love.graphics.scale(s * 1.5, s * 1.5)
            love.graphics.rotate((ft.rot or 0) + math.sin(love.timer.getTime()*15)*0.1)
            
            -- Multi-layered thick shadow/outline
            for j=3, 1, -1 do
                love.graphics.setColor(0, 0, 0, a * (1 - j*0.2))
                local off = j * 2
                for ox = -off, off, off do
                    for oy = -off, off, off do
                        love.graphics.printf(ft.text, -100 + ox, oy, 200, "center")
                    end
                end
            end
            
            -- Vibrant color cycling for high combos
            local r, g, b = unpack(ft.color)
            if ft.text:find("COMBO") then
                local t = love.timer.getTime() * 20
                r = 0.5 + 0.5 * math.sin(t)
                g = 0.5 + 0.5 * math.sin(t + 2)
                b = 0.5 + 0.5 * math.sin(t + 4)
            end
            
            -- Main text
            love.graphics.setColor(r, g, b, a)
            love.graphics.printf(ft.text, -100, 0, 200, "center")
            
            -- Removed extra shine to prevent flickering
            
            love.graphics.pop()
        else
            -- Regular floating text
            love.graphics.push()
            love.graphics.translate(ft.x, ft.y)
            love.graphics.scale(s, s)
            love.graphics.setColor(0, 0, 0, a * 0.6)
            love.graphics.printf(ft.text, -100 + 1, 1, 200, "center")
            love.graphics.setColor(ft.color[1], ft.color[2], ft.color[3], a)
            love.graphics.printf(ft.text, -100, 0, 200, "center")
            love.graphics.pop()
        end
    end
    
    love.graphics.setColor(1, 1, 1)
end

function juice.clear()
    particles = {}
    floatingTexts = {}
end

return juice

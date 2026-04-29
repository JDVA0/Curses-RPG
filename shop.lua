local shop = {}

shop.assets = {}
shop.upgrades = {
    {id = "hp", level = 0, max = 5, cost = 80, name = "Vida Max", desc = "Aumenta tus contenedores de corazones iniciales."},
    {id = "speed", level = 0, max = 5, cost = 60, name = "Velocidad", desc = "Aumenta tu velocidad al caminar permanentemente."},
    {id = "fireRate", level = 0, max = 5, cost = 90, name = "Cadencia", desc = "Te permite disparar lágrimas mucho más rápido."},
    {id = "dashCD", level = 0, max = 5, cost = 70, name = "Carga Dash", desc = "Reduce el tiempo de espera para volver a usar el Dash."},
    {id = "bulletSpeed", level = 0, max = 5, cost = 65, name = "Vel. Bala", desc = "Tus proyectiles viajarán por el aire mucho más rápido."},
    {id = "multiShot", level = 0, max = 3, cost = 200, name = "Multitiro", desc = "Dispara varios proyectiles a la vez en forma de arco."},
    {id = "bulletDmg", level = 0, max = 5, cost = 120, name = "Daño", desc = "Tus proyectiles hacen más daño a los enemigos."},
    {id = "bulletSize", level = 0, max = 3, cost = 60, name = "Bala Grande", desc = "Tus proyectiles se vuelven gigantes y fáciles de acertar."},
    {id = "magnet", level = 0, max = 5, cost = 40, name = "Imán Oro", desc = "Atrae el oro caído desde mucha más distancia."},
    {id = "bounty", level = 0, max = 5, cost = 100, name = "Botín Extra", desc = "Cada moneda de oro que recojas te dará mucho más oro."},
    {id = "vampirism", level = 0, max = 5, cost = 180, name = "Vampirismo", desc = "Pequeña probabilidad de curarte 1 corazón al matar."},
    {id = "roomHeal", level = 0, max = 3, cost = 250, name = "Cura Sala", desc = "Te curas vida automáticamente al limpiar una habitación."},
    {id = "dashSpeed", level = 0, max = 5, cost = 60, name = "Paso Largo", desc = "Tu dash recorrerá mucha más distancia a gran velocidad."},
    {id = "iFrames", level = 0, max = 5, cost = 75, name = "Invencible", desc = "Te mantienes invencible más tiempo después de recibir daño."},
    {id = "slowness", level = 0, max = 5, cost = 130, name = "Congelar", desc = "Los enemigos serán permanentemente más lentos en combate."},
    {id = "homing", level = 0, max = 3, cost = 220, name = "Teledirigido", desc = "Tus balas persiguen a los enemigos automáticamente."},
    {id = "collector", level = 0, max = 1, cost = 300, name = "Cosechador", desc = "Recoge todo el oro de la sala al instante al limpiarla."},
    {id = "bow", level = 0, max = 1, cost = 400, name = "Arco Divino", desc = "Cambia tus balas por flechas poderosas y veloces."},
    {id = "critChance", level = 0, max = 5, cost = 110, name = "Critico %", desc = "Aumenta la probabilidad de asestar golpes críticos (x3 daño)."},
    {id = "shield", level = 0, max = 3, cost = 240, name = "Escudo", desc = "Probabilidad de ignorar el daño recibido al ser golpeado."},
    {id = "iceBullets", level = 0, max = 5, cost = 150, name = "Hielo", desc = "Desbloquea Balas de Hielo (Tecla 3). Ralentizan a los enemigos."},
    {id = "fireBullets", level = 0, max = 5, cost = 160, name = "Fuego", desc = "Desbloquea Balas de Fuego (Tecla 2). Queman a los enemigos."},
    {id = "comboMaster", level = 0, max = 5, cost = 85, name = "M. Combo", desc = "El multiplicador de combo tarda mucho más en desaparecer."},
    {id = "extraDash", level = 0, max = 2, cost = 350, name = "Dash Extra", desc = "Te permite realizar dashes consecutivos adicionales."},
    {id = "luck", level = 0, max = 5, cost = 100, name = "Suerte", desc = "Aumenta la probabilidad de que aparezcan cofres y mejores objetos."},
    {id = "vigor", level = 0, max = 5, cost = 140, name = "Vigor", desc = "Haces más daño conforme menos corazones te queden."},
    {id = "aura", level = 0, max = 3, cost = 280, name = "Aura Daño", desc = "Crea un campo de energía que daña a los enemigos cercanos."},
    {id = "berserk", level = 0, max = 3, cost = 320, name = "Frenesí", desc = "Tu velocidad de disparo aumenta enormemente al matar enemigos."},
}

shop.animTime = 0
shop.isActive = false
shop.flashTimer = 0
shop.flashMsg = ""

shop.scroll = 0
shop.targetScroll = 0
shop.maxScroll = 0

local shopParticles = {}
for i=1, 80 do
    table.insert(shopParticles, {
        x = love.math.random(2000),
        y = love.math.random(2000),
        speed = love.math.random(10, 50),
        size = love.math.random(1, 4),
        alpha = love.math.random(5, 15) / 100
    })
end

function shop.reset()
    for _, upg in ipairs(shop.upgrades) do
        upg.level = 0
    end
    shop.scroll = 0
    shop.targetScroll = 0
end

function shop.getLevel(id)
    for _, upg in ipairs(shop.upgrades) do
        if upg.id == id then return upg.level end
    end
    return 0
end

function shop.getTotalUpgradesLevel()
    local total = 0
    for _, upg in ipairs(shop.upgrades) do
        total = total + upg.level
    end
    return total
end

function shop.init(assets)
    shop.assets = assets
end

function shop.enter()
    shop.animTime = 0
    shop.isActive = true
end

function shop.update(dt)
    if shop.isActive and shop.animTime < 1 then
        shop.animTime = math.min(1, shop.animTime + dt * 2.5)
    end
    if shop.flashTimer > 0 then
        shop.flashTimer = shop.flashTimer - dt
    end
    
    -- Smooth scrolling
    shop.scroll = shop.scroll + (shop.targetScroll - shop.scroll) * dt * 10
end

function shop.wheelmoved(x, y)
    if not shop.isActive then return end
    shop.targetScroll = math.max(0, math.min(shop.maxScroll, shop.targetScroll - y * 60))
end

function shop.draw(zoom, goldCount, deathMsg, highScores, mx, my)
    local sw, sh = 1280, 720
    local cols = 3
    
    local spacingX = 360
    local spacingY = 220
    local totalW = cols * spacingX
    local startX = (sw - totalW) / 2 + (spacingX / 2)
    local startY = sh * 0.35
    
    local rowCount = math.ceil(#shop.upgrades / cols)
    shop.maxScroll = math.max(0, (startY + rowCount * spacingY) - (sh * 0.75))
    
    local time = love.timer.getTime()
    
    -- Mystical Medieval Background
    love.graphics.setColor(0.05, 0.02, 0.08, 0.98 * shop.animTime)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    
    -- Warm mystical ambient glow (candles/magic)
    love.graphics.setColor(0.4, 0.1, 0.6, 0.25 * shop.animTime)
    love.graphics.circle("fill", sw/2, sh, 600 + math.sin(time)*20)
    love.graphics.setColor(0.8, 0.4, 0.1, 0.15 * shop.animTime)
    love.graphics.circle("fill", sw/2, sh*0.8, 800 + math.sin(time*2)*40)
    
    -- Background particles (Mystic Runes / Embers)
    for i, p in ipairs(shopParticles) do
        p.y = p.y - p.speed * love.timer.getDelta() * 0.4
        p.x = p.x + math.sin(time + p.y*0.02) * 0.5
        if p.y < -10 then p.y = sh + 10; p.x = love.math.random(sw) end
        
        if i % 2 == 0 then
            love.graphics.setColor(0.8, 0.3, 1.0, p.alpha * shop.animTime * 2)
        else
            love.graphics.setColor(1.0, 0.6, 0.1, p.alpha * shop.animTime * 2)
        end
        love.graphics.rectangle("fill", p.x, p.y, p.size, p.size) 
    end
    
    -- Vignette borders
    love.graphics.setColor(0, 0, 0, 0.6 * shop.animTime)
    love.graphics.rectangle("line", 10, 10, sw-20, sh-20)
    love.graphics.setLineWidth(4)
    love.graphics.setColor(0.2, 0.1, 0.3, 0.4 * shop.animTime)
    love.graphics.rectangle("line", 14, 14, sw-28, sh-28)
    love.graphics.setLineWidth(1)
    
    -- Easing
    local t = shop.animTime
    local bounce = 1 + 2.70158 * math.pow(t - 1, 3) + 1.70158 * math.pow(t - 1, 2)
    if t == 0 then bounce = 0 end
    local floatY = math.sin(time * 2) * 6
    
    -- Funny Death Message (Mocking)
    if deathMsg then
        love.graphics.setColor(1, 0.1, 0.1, shop.animTime * (0.8 + math.sin(time*10)*0.2))
        love.graphics.push()
        love.graphics.translate(sw/2, sh * 0.06)
        love.graphics.scale(1.5, 1.5)
        love.graphics.printf(deathMsg, -250, 0, 500, "center")
        love.graphics.pop()
    end
    
    -- Title (Centered dynamically based on image size)
    love.graphics.setColor(1, 1, 1, shop.animTime)
    if shop.assets.shop_letter then
        local lw, lh = shop.assets.shop_letter:getWidth(), shop.assets.shop_letter:getHeight()
        love.graphics.draw(shop.assets.shop_letter, sw/2, (sh * 0.14) * bounce + floatY, 0, 2.5, 2.5, lw/2, lh/2)
    end
    
    -- Gold display (top-right corner)
    love.graphics.setColor(0, 0, 0, 0.6 * shop.animTime)
    love.graphics.rectangle("fill", sw - 220, 12, 205, 36, 8, 8)
    love.graphics.setColor(1, 0.85, 0.1, shop.animTime)
    love.graphics.printf("⬥ " .. math.floor(goldCount) .. " ORO", sw - 215, 20, 195, "center")
    
    local hoveredDesc = nil
    
    -- Clip shop items area
    love.graphics.setScissor(0, sh * 0.22, sw, sh * 0.68)
    
    for i, upg in ipairs(shop.upgrades) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        
        local bx = startX + col * spacingX
        local cardY = (startY + row * spacingY) - shop.scroll
        local isHovered = (mx >= bx - 132 and mx <= bx + 132 and my >= cardY - 88 and my <= cardY + 88)
        
        -- Uniform scaling exactly 5.5x (264x176). No size scaling on hover to prevent overlapping.
        local btnUniformScale = 5.5
        local floatBob = isHovered and math.sin(time * 8) * 4 or 0
        local drawY = cardY + floatBob
        
        -- Card Drawing
        if shop.assets.button then
            local bw, bh = shop.assets.button:getWidth(), shop.assets.button:getHeight()
            
            if isHovered then
                love.graphics.setColor(1, 0.9, 0.3, 0.5 * shop.animTime)
                love.graphics.draw(shop.assets.button, bx, drawY, 0, btnUniformScale, btnUniformScale, bw/2, bh/2)
            end
            
            if upg.level >= upg.max then love.graphics.setColor(0.4, 0.9, 0.6, shop.animTime)
            elseif goldCount < upg.cost then love.graphics.setColor(0.8, 0.3, 0.3, shop.animTime)
            else love.graphics.setColor(0.9 + (isHovered and 0.1 or 0), 0.9 + (isHovered and 0.1 or 0), 1.0, shop.animTime) end
            
            love.graphics.draw(shop.assets.button, bx, drawY, 0, btnUniformScale, btnUniformScale, bw/2, bh/2)
        else
            -- Fallback rects just in case
            love.graphics.setColor(0.2, 0.1, 0.3, 0.85 * shop.animTime)
            love.graphics.rectangle("fill", bx - 132, drawY - 88, 264, 176, 8)
        end
        
        -- Item Name
        love.graphics.setColor(1, 1, 1, shop.animTime)
        love.graphics.printf(upg.name, bx - 120, drawY - 50, 240, "center")
        
        -- Progress Pips
        local pipTotalW = upg.max * 15
        local pipStartX = bx - pipTotalW / 2
        for p = 1, upg.max do
            if p <= upg.level then love.graphics.setColor(0.4, 1.0, 0.8, shop.animTime)
            else love.graphics.setColor(0.1, 0.05, 0.2, 0.8 * shop.animTime) end
            love.graphics.rectangle("fill", pipStartX + (p-1) * 15, drawY - 5, 10, 10, 2, 2)
        end
        
        -- Cost
        if upg.level < upg.max then
            love.graphics.setColor(1, 0.8, 0.2, shop.animTime)
            love.graphics.printf(upg.cost .. " ORO", bx - 120, drawY + 25, 240, "center")
        else
            love.graphics.setColor(0.4, 0.9, 0.6, shop.animTime)
            love.graphics.printf("AL MAXIMO", bx - 120, drawY + 25, 240, "center")
        end
        
        if isHovered then
            hoveredDesc = upg.desc
        end
    end
    
    love.graphics.setScissor()
    
    -- Description tooltip
    if hoveredDesc then
        local tooltipW = math.min(650, sw - 40)
        local tooltipX = sw/2 - tooltipW/2
        local tooltipY = sh - 95
        love.graphics.setColor(0, 0, 0, 0.85 * shop.animTime)
        love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipW, 44, 8, 8)
        love.graphics.setColor(0.6, 0.3, 1, 0.5 * shop.animTime)
        love.graphics.rectangle("line", tooltipX, tooltipY, tooltipW, 44, 8, 8)
        love.graphics.setColor(1, 1, 1, shop.animTime)
        love.graphics.printf(hoveredDesc, tooltipX + 10, tooltipY + 12, tooltipW - 20, "center")
    end
    
    -- Flash message
    if shop.flashTimer > 0 then
        local fa = math.min(1, shop.flashTimer * 3)
        love.graphics.setColor(0.4, 1, 0.8, fa)
        love.graphics.printf(shop.flashMsg, 0, sh * 0.22, sw, "center")
    end
    
    -- Bottom instruction
    love.graphics.setColor(1, 1, 1, 0.4 * shop.animTime)
    love.graphics.printf("Presiona R para Volver a Jugar", 0, sh - 35, sw, "center")
    love.graphics.setColor(1, 1, 1)
end


function shop.mousepressed(x, y, zoom, goldCount)
    if not shop.isActive or shop.animTime < 0.5 then return goldCount end

    local sw, sh = 1280, 720
    local cols = 3
    
    local spacingX = 360
    local spacingY = 220
    local totalW = cols * spacingX
    local startX = (sw - totalW) / 2 + (spacingX / 2)
    local startY = sh * 0.35
    
    for i, upg in ipairs(shop.upgrades) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        
        local bx = startX + col * spacingX
        local by = (startY + row * spacingY) - shop.scroll
        local halfW = 132
        local halfH = 88
        
        if x >= bx - halfW and x <= bx + halfW and y >= by - halfH and y <= by + halfH then
            if upg.level < upg.max and goldCount >= upg.cost then
                goldCount = goldCount - upg.cost
                upg.level = upg.level + 1
                upg.cost = math.floor(upg.cost * 1.6)
                shop.applyUpgrades()
                shop.flashTimer = 1.5
                shop.flashMsg = "¡" .. upg.name .. " mejorado a Nivel " .. upg.level .. "!"
            end
        end
    end
    return goldCount
end

function shop.applyUpgrades()
    local player = require("player")
    player.applyPermanentUpgrades()
    
    -- Bullet unlocks
    if _G.bulletInventory then
        if shop.getLevel("fireBullets") > 0 then _G.bulletInventory.fire = true end
        if shop.getLevel("iceBullets") > 0 then _G.bulletInventory.ice = true end
    end
end


return shop

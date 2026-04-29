-- CURSES - Roguelike Dungeon
local player = require("player")
local enemy = require("enemy")
local bullet = require("bullet")
local map = require("map")
local juice = require("juice")
local pickup = require("pickup")
local shop = require("shop")
local leaderboard = require("leaderboard")

gameState = "intro"
local assets = {}
local introAlpha = 0
local introTimer = 0
local introPhase = 1
local introCharCount = 0
local introText = {
    "",
    "Hace eones, un mortal desafió a los Dioses Antiguos.",
    "Buscó el fuego prohibido de la inmortalidad.",
    "Los Dioses respondieron con crueldad infinita.",
    "Su castigo: vagar por siempre en la oscuridad.",
    "Fue arrojado al Laberinto de las Mil Maldiciones.",
    "Donde cada criatura es un eco de sus pecados.",
    "Donde cada puerta lleva a un infierno peor.",
    "No hay salida. No hay piedad. No hay final.",
    "Solo queda luchar... y morir... y volver a luchar.",
    "CURSES"
}
local introSprites = {
    "signature",
    "player",
    "dummy",
    "idder",
    "player",
    "dummy",
    "bomber",
    "slime",
    "siter",
    "player",
    "logo"
}
local shakeTime, shakeIntensity, maxShakeTime = 0, 0, 1
local goldCount = 0
local baseFireRate = 0.12 -- Faster
local fireRate = 0.12
local dx, dy = 0, 0 -- Current velocity for smooth feel
local roomsCleared = 0
local deathTimer = 0
local hitStop = 0
_G.slowMoTimer = 0
local screenGlitch = 0
local previousState = "playing"
local camX, camY = 720, 480
local gameZoom = 1.3
_G.hazards = {}
local interactables = {}
local comboCount, comboTimer = 0, 0
local critFlash = 0
local transitionAlpha = 0
local damageFlash = 0
local runTimer = 0
local transitionDir = 0
local score = 0
local bossIntroTimer = 0
local tutorialTimer = 0
local tutorialPhase = 0
local scoreSaved = false
local highScores = {}
-- Curse cinematic
local curses = {}
local curseList = {
    {id="fragile", name="FRAGILIDAD", desc="Recibes el doble de dano"},
    {id="slow_bullets", name="BALAS PESADAS", desc="Tus balas son 30% mas lentas"},
    -- Removed blind curse

    {id="swarm", name="ENJAMBRE", desc="+50% enemigos por sala"},
    {id="rust", name="OXIDACION", desc="Tu cadencia es 30% peor"},
    {id="weakness", name="DEBILIDAD", desc="Tus balas hacen menos dano"},
    {id="chaos", name="CAOS", desc="Tus balas van en direcciones erraticas"},
    {id="bleed", name="SANGRADO", desc="Pierdes vida lentamente"},
}
local curseAnim = {active=false, pending=false, timer=0, name="", desc="", alpha=0}
local roomModList = {"normal","normal","speed","regen","gold_rush","darkness","blessing","chaos","hazard_zone","elite","bouncing"}

local roulette = {
    active = false,
    timer = 0,
    items = {
        {name="CURA MAXIMA", color={0.2,1,0.2}},
        {name="+150 ORO", color={1,0.8,0.2}},
        {name="+1000 PTS", color={0.5,0.5,1}},
        {name="+3 MAX HP", color={1,0.3,0.3}},
        {name="FULL HEAL", color={0.2,1,0.5}}
    },
    index = 1,
    speed = 0,
    finishTimer = 0
}

local crtShader
local gameCanvas
local showOverlay = false
local overlayAlpha = 0
local showSettings = false
local settingsAlpha = 0
local useCRT = false
local menuParticles = {}
local deathMsg = ""
local deathMessages = {
    "¿Eso es todo? Patético.",
    "Mi abuela esquiva mejor que tú.",
    "El abismo se ríe de tu ineptitud.",
    "Vaya... otra mancha de sangre en el suelo.",
    "¿Has probado a no morir?",
    "Ese enemigo era un becario y te ha humillado.",
    "Tu leyenda acaba aquí... y nadie la recordará.",
    "¿Tanto oro para morir así? Qué desperdicio.",
    "El Infierno está lleno de gente como tú.",
    "¿Seguro que tienes las manos en el teclado?",
    "RIP. No te echaremos de menos.",
    "Game Over. Inserte cerebro para continuar."
}

local function getCanvasMouse()
    local sw, sh = love.graphics.getDimensions()
    local scale = math.min(sw / 1280, sh / 720)
    local mx, my = love.mouse.getPosition()
    return mx / scale, my / scale
end

local function resetGame()
    -- Reset all necessary game variables
    goldCount = 0 -- Gold is reset for the new run
    score = 0
    scoreSaved = false
    roomX, roomY = 3, 3
    enemies = {}
    bullets = {}
    eBullets = {}
    coins = {}
    shrineActive = false
    introTimer = 0
    gameState = "playing" -- Skip intro
    roomsCleared = 0
    _G.hazards = {}
    interactables = {}
    comboCount = 0
    comboTimer = 0
    curses = {}
    curseAnim = {active=false, pending=false, timer=0, name="", desc="", alpha=0}
    roulette.active = false
    tutorialPhase = 6 -- Skip tutorial
    
    -- Re-initialize modules to a clean state
    player.init(assets)
    map.init(assets)
    -- shop.reset() -- REMOVED: keep upgrades
    enemy.init({blob=assets.blob,oozel=assets.oozel,idder=assets.idder,slime=assets.slime,siter=assets.siter,bomber=assets.bomber,dummy=assets.dummy,x=assets.x})
    bullet.init(assets.bullet)
    pickup.init(assets.gold)
    juice.init(assets.blood, assets.iron)
    
    addShake(0.5, 15)
    juice.spawnText(400, 272, "SOBREVIVE", {1,0,0})
    if _G.gameMusic and not _G.gameMusic:isPlaying() then
        _G.gameMusic:play()
    end
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    gameCanvas = love.graphics.newCanvas(1280, 720)

    local function loadAsset(name, fallbackName)
        local dirPath = "assets/" .. name
        local info = love.filesystem.getInfo(dirPath)
        local variations = {}
        if info and info.type == "directory" then
            local files = love.filesystem.getDirectoryItems(dirPath)
            table.sort(files) -- Consistent order
            for _, file in ipairs(files) do
                if file:match("%.png$") then
                    table.insert(variations, love.graphics.newImage(dirPath .. "/" .. file))
                end
            end
        end
        
        -- If no directory variations, try single file
        if #variations == 0 then
            local filePath = "assets/" .. (fallbackName or name) .. ".png"
            if love.filesystem.getInfo(filePath) then
                table.insert(variations, love.graphics.newImage(filePath))
            end
        end
        
        return variations
    end

    assets.player = loadAsset("player")[1] -- Player usually doesn't have variations in this game's logic
    assets.box = loadAsset("box")[1]
    assets.floor = loadAsset("floor")[1]
    assets.floor_alt = loadAsset("floor_alt")[1]
    assets.corner = loadAsset("corner")[1]
    assets.corner_deco = loadAsset("corner_deco")[1]
    assets.door = loadAsset("door")[1]
    assets.blob = loadAsset("blob")
    assets.oozel = loadAsset("oozel")
    assets.idder = loadAsset("idder")
    assets.heart = loadAsset("heart")
    if love.filesystem.getInfo("assets/heart/heart_broken.png") then assets.heart.broken = love.graphics.newImage("assets/heart/heart_broken.png") end
    if love.filesystem.getInfo("assets/heart/heart.png") then assets.heart.full = love.graphics.newImage("assets/heart/heart.png") end
    
    assets.gold = loadAsset("coin")
    assets.bullet = loadAsset("bullet")
    -- Explicitly load named variations
    if love.filesystem.getInfo("assets/bullet/bullet_ice.png") then assets.bullet.ice = love.graphics.newImage("assets/bullet/bullet_ice.png") end
    if love.filesystem.getInfo("assets/bullet/bullet_fire.png") then assets.bullet.fire = love.graphics.newImage("assets/bullet/bullet_fire.png") end
    if love.filesystem.getInfo("assets/bullet/bullet_metal.png") then assets.bullet.metal = love.graphics.newImage("assets/bullet/bullet_metal.png") end
    
    assets.logo = loadAsset("logo")[1]
    assets.blood = loadAsset("blood")
    assets.shop_letter = loadAsset("shop", "shop_letter")[1]
    assets.button = loadAsset("button")[1]
    assets.slime = loadAsset("slime")
    assets.siter = loadAsset("siter")
    assets.bomber = loadAsset("bomber")
    assets.iron = loadAsset("smoke", "iron")
    assets.poison = loadAsset("poison")
    assets.dummy = loadAsset("dummy")
    assets.x = loadAsset("x")
    assets.bow = loadAsset("bow")
    assets.signature = loadAsset("dev")[1]
    assets.arrow = loadAsset("arrow")
    assets.curses_logo = love.graphics.newImage("curses.png")
    
    -- Bullet System
    _G.bulletInventory = {metal = true, fire = false, ice = false}
    _G.currentBulletType = "metal"
    
    if love.filesystem.getInfo("sounds/game.ogg") then
        _G.gameMusic = love.audio.newSource("sounds/game.ogg", "stream")
        _G.gameMusic:setLooping(true)
        _G.gameMusic:setVolume(0.5)
        -- Don't play yet; starts when entering the first room
    end
    
    map.init(assets)
    player.init(assets)
    enemy.init({blob=assets.blob,oozel=assets.oozel,idder=assets.idder,slime=assets.slime,siter=assets.siter,bomber=assets.bomber,dummy=assets.dummy,x=assets.x})
    bullet.init(assets.bullet); juice.init(assets.blood, assets.iron)
    pickup.init(assets.gold)
    shop.init({shop_letter=assets.shop_letter, button=assets.button})
    goldCount=0; roomsCleared=0; score=0
    map.setDoorsOpen(true)
    gameState = "menu"
    
    -- Init menu particles
    for i=1, 80 do
        table.insert(menuParticles, {
            x = math.random(0, 1280),
            y = math.random(0, 720),
            s = math.random(2, 5),
            sp = math.random(10, 40),
            ang = math.random() * math.pi * 2,
            rot = math.random() - 0.5
        })
    end
end


function isCurseActive(id)
    for _, c in ipairs(curses) do if c.id == id then return true end end
    return false
end

function love.update(dt)
    local sw, sh = love.graphics.getDimensions()
    if gameState == "intro" then
        introTimer = introTimer + dt
        if introPhase <= #introText then
            introCharCount = introCharCount + dt * 22
            if introTimer > 3.2 then
                introAlpha = math.max(0, introAlpha - dt * 2.5)
                if introAlpha <= 0 then
                    introPhase = introPhase + 1
                    introTimer = 0
                    introAlpha = 1
                    introCharCount = 0
                    if introPhase > #introText then
                        gameState = "menu"
                        introTimer = 0
                        introAlpha = 0
                    end
                end
            else
                introAlpha = math.min(1, introAlpha + dt * 3)
            end
        end
        
        if (love.keyboard.isDown("space") or love.keyboard.isDown("return") or love.keyboard.isDown("z") or love.mouse.isDown(1)) and introPhase > 2 then
            introPhase = #introText + 1
            gameState = "menu"
            introTimer = 0
            introAlpha = 0
        end
        
        if introPhase > 2 then
            love.graphics.setColor(1,1,1, introAlpha * 0.4)
            love.graphics.printf("PULSA 'Z' PARA SALTAR", 0, sh - 40, sw, "center")
        end
        return
    end

    if gameState == "menu" then
        introTimer = introTimer + dt
        introAlpha = math.min(1, introAlpha + dt * 1.5)
        if love.keyboard.isDown("space") or love.keyboard.isDown("return") or love.mouse.isDown(1) then
            gameState = "starting"
            introTimer = 0
            addShake(2, 40)
        end
        return
    end

    if gameState == "starting" then
        introTimer = introTimer + dt
        if introTimer > 2.2 then
            gameState = "tutorial"
            tutorialTimer = 0
            tutorialPhase = 1
        end
        if introTimer < 0.3 then
            for i=1,5 do juice.spawnExplosion(love.math.random(0,800), love.math.random(0,544), 0,0, "spark") end
        end
        return
    end

    if gameState == "tutorial" then
        tutorialTimer = tutorialTimer + dt
        if tutorialTimer > 2.8 then
            tutorialPhase = tutorialPhase + 1
            tutorialTimer = 0
        end
        if tutorialPhase > 5 then
            gameState = "playing"
            addShake(0.5, 15)
            juice.spawnText(400, 272, "SOBREVIVE", {1,0,0})
            -- Start music when gameplay begins
            if _G.gameMusic and not _G.gameMusic:isPlaying() then
                _G.gameMusic:play()
            end
        end
        return
    end

    if gameState == "dead" then
        deathTimer = deathTimer + dt
        if deathTimer > 2.2 then
            gameState = "shop"
            shop.enter()
        end
        return
    end

    -- Update overlay alpha
    overlayAlpha = overlayAlpha + ((showOverlay and 1 or 0) - overlayAlpha) * dt * 10

    -- Curse cinematic
    if curseAnim.active then
        curseAnim.timer = curseAnim.timer - dt
        if curseAnim.timer > 2.5 then
            curseAnim.alpha = math.min(1, curseAnim.alpha + dt * 3)
        elseif curseAnim.timer < 0.5 then
            curseAnim.alpha = math.max(0, curseAnim.alpha - dt * 3)
        end
        if curseAnim.timer <= 0 then curseAnim.active = false end
        return
    end
    
    if roulette.active then
        roulette.timer = roulette.timer + dt
        if roulette.speed > 0 then
            roulette.speed = math.max(0, roulette.speed - dt * 5)
            roulette.timer = roulette.timer + roulette.speed * dt
            roulette.index = math.floor(roulette.timer) % #roulette.items + 1
            if roulette.speed <= 0 then 
                roulette.finishTimer = 1.5
                -- Apply reward
                local item = roulette.items[roulette.index]
                if item.name == "CURA MAXIMA" then player.heal(5)
                elseif item.name == "+150 ORO" then goldCount = goldCount + 150
                elseif item.name == "+1000 PTS" then score = score + 1000
                elseif item.name == "+3 MAX HP" then player.addMaxHp(3); player.heal(3)
                elseif item.name == "FULL HEAL" then player.heal(10) end
                juice.spawnText(400, 240, "RECOMPENSA: "..item.name, item.color)
                addShake(0.3, 10)
            end
        elseif roulette.finishTimer > 0 then
            roulette.finishTimer = roulette.finishTimer - dt
            if roulette.finishTimer <= 0 then roulette.active = false end
        end
        return
    end
    
    -- Room transition
    if transitionDir ~= 0 then
        transitionAlpha = transitionAlpha + transitionDir * dt * 2.5 -- Smoother for cartoon feel
        if transitionDir == 1 and transitionAlpha >= 1 then
            transitionAlpha = 1; transitionDir = -1; doRoomSwitch()
        elseif transitionDir == -1 and transitionAlpha <= 0 then
            transitionAlpha = 0; transitionDir = 0
            if curseAnim.pending then
                curseAnim.pending = false
                curseAnim.active = true
            end
        end
        return
    end
    
    if hitStop > 0 then hitStop = hitStop - dt; return end
    
    local actualDt = dt
    if _G.slowMoTimer and _G.slowMoTimer > 0 then
        _G.slowMoTimer = _G.slowMoTimer - actualDt
        dt = actualDt * 0.2
    end
    
    if screenGlitch > 0 then
        screenGlitch = screenGlitch - actualDt
    end
    
    if damageFlash > 0 then
        damageFlash = damageFlash - actualDt * 4
    end
    
    -- Speedrun timer
    if gameState == "playing" then
        runTimer = runTimer + dt
    end

    if bossIntroTimer and bossIntroTimer > 0 then
        bossIntroTimer = bossIntroTimer - dt
        addShake(0.1, 10)
        return
    end

    if gameState == "playing" then
        player.update(dt); enemy.update(dt, player.getPos())
        bullet.update(dt); juice.update(dt); player.updateFireTimer(dt)
        local px, py = player.getPos()
        camX = camX + (px - camX) * dt * 6
        camY = camY + (py - camY) * dt * 6
        
        if player.getHp() <= 0 then
            gameState = "dead"
            deathTimer = 0
            deathMsg = deathMessages[math.random(#deathMessages)]
            scoreSaved = false
            highScores = leaderboard.load()
            leaderboard.save(score, roomsCleared)
            addShake(1.2, 30)
            juice.spawnExplosion(px, py, 0, 0, "blood")
            return
        end

        -- Combo master: slower decay
        local comboDecayMult = 1 - (shop.getLevel("comboMaster") * 0.12)
        if comboTimer > 0 then comboTimer = comboTimer - dt * comboDecayMult; if comboTimer <= 0 then comboCount = 0 end end
        if critFlash > 0 then critFlash = critFlash - dt end
        if _G.roomMod == "regen" and love.timer.getTime() % 5 < dt then player.heal(1) end
        if isCurseActive("bleed") and love.timer.getTime() % 4 < dt then player.takeDamage(1) end
        
        -- Berserk: temporary fire rate boost after kills (decays)
        if _G.berserkTimer and _G.berserkTimer > 0 then
            _G.berserkTimer = _G.berserkTimer - dt
        end
        
        -- Aura damage: hurt nearby enemies passively
        local auraLevel = shop.getLevel("aura")
        if auraLevel > 0 then
            local auraRadius = 60 + auraLevel * 20
            local auraDmg = auraLevel * 0.5
            local auraTickOk = love.timer.getTime() % 0.5 < dt
            if auraTickOk then
                local enms = enemy.getEnemies()
                for j = #enms, 1, -1 do
                    local e = enms[j]
                    local adx, ady = px - e.x, py - e.y
                    local adist = math.sqrt(adx*adx + ady*ady)
                    if adist < auraRadius and e.state ~= "dying" then
                        enemy.hit(j, auraDmg)
                    end
                end
            end
        end
        
        -- Pickups
        local collected = pickup.update(dt, px, py, player.getMagnetRadius())
        if collected == "gold" then
            local comboMult = 1 + math.min(comboCount, 15) * 0.15
            local goldMult = _G.roomMod == "gold_rush" and 2 or 1
            local gain = math.floor((5 + player.getBounty()) * comboMult * goldMult)
            goldCount = goldCount + gain; score = score + gain
            addShake(0.05, 1); juice.spawnText(px, py-10, "+"..gain, {1,0.8,0.2})
        end
        
        -- Hazards (Using global _G.hazards)
        for i = #_G.hazards, 1, -1 do
            local hz = _G.hazards[i]
            hz.life = hz.life - dt
            if hz.life <= 0 then table.remove(_G.hazards, i)
            elseif math.sqrt((px - hz.x)^2 + (py - hz.y)^2) < hz.r then
                if hz.type == "poison" and love.timer.getTime() % 0.5 < dt then
                    player.takeDamage(1)
                    juice.spawnText(px, py-10, "VENENO", {0.3, 1, 0.3})
                end
            end
        end
        
        -- Interactables (Shrines/Chests)
        for i = #interactables, 1, -1 do
            local int = interactables[i]
            local distToInt = math.sqrt((px - int.x)^2 + (py - int.y)^2)
            if distToInt < 40 and enemy.getEnemyCount() == 0 then
                -- Show interaction prompt
                int.showPrompt = true
            else
                int.showPrompt = false
            end
        end
        
        -- Room clear
        if enemy.getEnemyCount() == 0 and not map.areDoorsOpen() then
            map.setDoorsOpen(true)
            juice.spawnText(400, 200, "¡SALA LIMPIA!", {0.2,1,0.2})
            local bonusGold = 3 + roomsCleared
            local luckLvl = shop.getLevel("luck")
            if luckLvl > 0 and love.math.random() < (0.1 + luckLvl * 0.1) then
                juice.spawnText(400, 250, "¡SUERTE EXTRA!", {1,1,0})
                bonusGold = bonusGold + 15
                addShake(0.3, 10)
            end
            for k=1, bonusGold do pickup.spawn(400+love.math.random(-60,60), 272+love.math.random(-60,60)) end
            score = score + 100 + roomsCleared * 20
            juice.spawnText(400, 230, "+"..(100+roomsCleared*20).." PTS", {0.8,0.8,1})
            if player.getRoomHeal() > 0 then player.heal(player.getRoomHeal()); juice.spawnText(px,py-30,"+CURA",{0.2,1,0.2}) end
            
            -- Cosechador: Collect all gold instantly
            if player.hasCollector() then
                local collectedCount = pickup.forceCollectAll()
                if collectedCount > 0 then
                    local gain = collectedCount * (5 + player.getBounty())
                    goldCount = goldCount + gain; score = score + gain
                    juice.spawnText(px, py-60, "COSECHADO: +"..gain, {1,0.8,0.2})
                end
            end
        end
        
        -- Shooting (with camera lerp and zoom)
        if love.mouse.isDown(1) then
            local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
            local mx, my = love.mouse.getPosition()
            -- camera clamp bounds with zoom
            local mw, mh = 45 * 32, 30 * 32
            local vsw, vsh = sw / gameZoom, sh / gameZoom
            local clampX = math.max(vsw/2, math.min(mw - vsw/2, camX))
            local clampY = math.max(vsh/2, math.min(mh - vsh/2, camY))
            
            -- inverse camera transform (account for zoom and translation)
            local wx = (mx / gameZoom) - (vsw/2 - clampX)
            local wy = (my / gameZoom) - (vsh/2 - clampY)
            local angle = math.atan2(wy - py, wx - px)
            
            -- Chaos room mod: erratic bullet direction
            if _G.roomMod == "chaos" then
                angle = angle + (love.math.random() - 0.5) * 0.4
            end
            
            player.shoot(angle, isCurseActive("slow_bullets"), isCurseActive("rust"))
        end
        
        checkCollisions(); checkRoomTransition()
    end
    if gameState == "shop" then
        shop.update(dt)
    end
    
    -- Menus visibility
    if showSettings then settingsAlpha = math.min(1, settingsAlpha + dt * 6)
    else settingsAlpha = math.max(0, settingsAlpha - dt * 6) end
    
    if showOverlay then overlayAlpha = math.min(1, overlayAlpha + dt * 6)
    else overlayAlpha = math.max(0, overlayAlpha - dt * 6) end

    -- Update menu particles
    for _, p in ipairs(menuParticles) do
        p.y = p.y - p.sp * dt
        p.x = p.x + math.sin(love.timer.getTime() + p.ang) * 5 * dt
        if p.y < -10 then p.y = 730; p.x = math.random(0, 1280) end
    end

    if shakeTime > 0 then 
        shakeTime = shakeTime - dt 
    else 
        shakeIntensity = 0 
    end
    
    -- Removed shader updates
end

function love.draw()
    local sw, sh = 1280, 720 -- Internal Virtual Resolution
    local realW, realH = love.graphics.getDimensions()
    local utf8 = require("utf8")
    
    -- Safe UTF-8 substring (never breaks mid-character)
    local function utf8sub(s, maxchars)
        if maxchars <= 0 then return "" end
        local len = utf8.len(s)
        if not len then return s end
        if maxchars >= len then return s end
        local ok, offset = pcall(utf8.offset, s, maxchars + 1)
        if ok and offset then return string.sub(s, 1, offset - 1) end
        return s
    end
    
    -- Helper: draw centered text with proper scaling (UTF-8 safe)
    local function drawCentered(text, cy, scale, r, g, b, a)
        if not text or text == "" then return end
        love.graphics.push()
        love.graphics.translate(sw/2, cy)
        love.graphics.scale(scale, scale)
        love.graphics.setColor(r or 1, g or 1, b or 1, a or 1)
        local font = love.graphics.getFont()
        local ok, tw = pcall(font.getWidth, font, text)
        if not ok then tw = 100 end
        love.graphics.print(text, -tw/2, 0)
        love.graphics.pop()
    end
    
    love.graphics.setCanvas({gameCanvas, stencil=true})
    love.graphics.clear()
    
    -- === SCREAM removed - story goes directly to menu ===
    
    -- === INTRO (Story crawl) ===
    if gameState == "intro" then
        love.graphics.clear(0, 0, 0)
        
        if introPhase <= #introText then
            local txt = introText[introPhase]
            local sub = utf8sub(txt, math.floor(introCharCount))
            local time = love.timer.getTime()
            
            -- Draw sprite above text (Undertale style) with glow
            local sname = introSprites[introPhase]
            if sname and assets[sname] then
                local isSig = (sname == "signature")
                local isPlayer = (sname == "player")
                local isDummy = (sname == "dummy")
                local sprScale = isSig and 10 or (sname == "logo" and 5 or (sname == "siter" or isPlayer or isDummy) and 2 or 6)
                local ox = (isSig or sname == "logo" or sname == "siter" or isPlayer or isDummy) and 32 or 16
                local oy = (isSig or sname == "logo" or isPlayer or isDummy) and 16 or (sname == "siter" and 32 or 16)
                local posY = isSig and sh/2 or (sh/2 - 80 + math.sin(time * 2) * 6)
                
                -- Sprite
                local img = assets[sname]
                if type(img) == "table" then img = img[1] end
                
                local ox = img:getWidth() / 2
                local oy = img:getHeight() / 2
                
                love.graphics.setColor(1, 1, 1, introAlpha * 0.9)
                love.graphics.draw(img, sw/2, posY, 0, sprScale, sprScale, ox, oy)
            end
            
            -- Text with proper centering
            local isSpecial = (introPhase == 1 or introPhase == #introText)
            local scale = isSpecial and 2.5 or 1.5
            local r, g, b = 1, 1, 1
            if introPhase == 1 then r, g, b = 0.6, 0.6, 0.7 end
            if introPhase == #introText then r, g, b = 1, 0.1, 0.1 end
            drawCentered(sub, sh/2 + 50, scale, r, g, b, introAlpha)
            
            -- Cinematic bars (Keeping for style if needed elsewhere)
            love.graphics.setColor(0, 0, 0, 0.95)
            love.graphics.rectangle("fill", 0, 0, sw, 80)
            love.graphics.rectangle("fill", 0, sh - 80, sw, 80)
        end
    elseif gameState == "menu" or gameState == "starting" then
        love.graphics.clear(0.01, 0.005, 0.02)
        local a = introAlpha
        local t = love.timer.getTime()
        
        -- Particles
        for _, p in ipairs(menuParticles) do
            love.graphics.setColor(1, 0.1, 0.1, a * 0.1)
            love.graphics.circle("fill", p.x, p.y, p.s)
        end

        -- Centered Logo (Main Title)
        if assets.curses_logo then
            local lw, lh = assets.curses_logo:getDimensions()
            local lscale = 0.4 * a
            local offX = 0
            local offY = 0
            
            -- Ghost effect for "Entry" feel
            love.graphics.setColor(0.5, 0, 0, a * 0.2)
            love.graphics.draw(assets.curses_logo, sw/2 + offX * 1.5, sh/2 - 80 + offY * 1.5, 0, lscale * 1.1, lscale * 1.1, lw/2, lh/2)
            
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.draw(assets.curses_logo, sw/2 + offX, sh/2 - 80 + offY, 0, lscale, lscale, lw/2, lh/2)
            
            -- Red ghost effect (intensified)
            if math.random() > 0.90 then
                love.graphics.setColor(1, 0, 0, a * 0.5)
                love.graphics.draw(assets.curses_logo, sw/2 + 6, sh/2 - 80, 0, lscale, lscale, lw/2, lh/2)
            end
        end

        if gameState == "menu" then
            local pulse = 0.8 + math.sin(t * 3) * 0.2
            drawCentered("PRESIONA ESPACIO PARA CONTINUAR", sh/2 + 150, 1.2, 1, 1, 1, a * pulse)
        end
    elseif gameState == "starting" then
        local t = introTimer
        local time = love.timer.getTime()
        
        if t < 1.0 then
            -- ZOOM INTO LOGO PHASE (Enhanced "Entry")
            love.graphics.clear(0.01, 0.005, 0.02)
            
            -- Start showing speed lines early for blending
            for i = 1, 15 do
                local lx = love.math.random(0, sw)
                local ly = (i * 80 + t * 3000) % (sh + 100) - 50
                love.graphics.setColor(1, 0, 0, t * 0.2)
                love.graphics.line(lx, ly, lx, ly + 40)
            end
            
            local a = 1
            -- Draw menu particles behind
            for _, p in ipairs(menuParticles) do
                love.graphics.setColor(1, 0.1, 0.1, a * 0.1 * (1 - t))
                love.graphics.circle("fill", p.x, p.y, p.s)
            end
            
            if assets.curses_logo then
                local lw, lh = assets.curses_logo:getDimensions()
                -- Massive exponential zoom
                local zoom = 0.4 + math.pow(t, 4) * 60 
                -- Fade out as it gets too close
                local logoAlpha = 1 - math.pow(t, 8)
                
                -- Glitch effect
                local gx = (love.math.random()-0.5) * t * 100
                local gy = (love.math.random()-0.5) * t * 100
                
                love.graphics.setColor(1, 0, 0, logoAlpha * 0.5)
                love.graphics.draw(assets.curses_logo, sw/2 + gx, sh/2 - 80 + gy, 0, zoom * 1.05, zoom * 1.05, lw/2, lh/2)
                
                love.graphics.setColor(1, 1, 1, logoAlpha)
                love.graphics.draw(assets.curses_logo, sw/2, sh/2 - 80, 0, zoom, zoom, lw/2, lh/2)
                
                -- Add some shake during the zoom
                if t > 0.3 then addShake(0.1, (t-0.3)*25) end
            end
            
            -- Flash toward the end of zoom
            if t > 0.8 then
                local flash = (t - 0.8) / 0.2
                love.graphics.setColor(1, 1, 1, flash)
                love.graphics.rectangle("fill", 0, 0, sw, sh)
            end
        else
            -- FALLING PHASE (Existing)
            love.graphics.clear(0, 0, 0)
            local ft = t - 1.0
            
            -- Speed lines falling effect
            for i = 1, 30 do
                local lx = love.math.random(0, sw)
                local ly = (i * 40 + ft * 2000) % (sh + 100) - 50
                local slen = 20 + ft * 80
                love.graphics.setColor(0.15, 0, 0, 0.4)
                love.graphics.line(lx, ly, lx, ly + slen)
            end
            
            -- Player falling
            local playerY = sh/2 - 50 + math.sin(ft * 15) * 3
            local playerRot = math.sin(ft * 8) * 0.15
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(assets.player, sw/2, playerY, playerRot, 5, 5, 16, 16)
            
            -- Trail behind player
            for i = 1, 4 do
                love.graphics.setColor(1, 1, 1, 0.15 - i * 0.03)
                love.graphics.draw(assets.player, sw/2, playerY - i * 25, playerRot, 5 - i*0.3, 5 - i*0.3, 16, 16)
            end
            
            -- Depth indicator text
            local depth = math.floor(ft * 500)
            drawCentered("PROFUNDIDAD: " .. depth .. "m", sh - 80, 1.2, 0.5, 0.1, 0.1, math.min(1, ft*2))
            
            -- Falling text phases
            if ft < 0.5 then
                drawCentered("CAYENDO AL ABISMO", sh/2 - 150, 2, 1, 0.2, 0.1, 1 - ft*2)
            elseif ft < 0.9 then
                drawCentered("MAS PROFUNDO", sh/2 - 150, 2, 0.8, 0, 0, math.min(1, (ft-0.5)*3))
            end
            -- Flash at impact
            if ft > 0.6 then
                local flash = (ft - 0.6) * 5
                love.graphics.setColor(1, 0.3, 0, math.min(1, flash))
                love.graphics.rectangle("fill", 0, 0, sw, sh)
            end
            if ft > 1.0 then
                drawCentered("NO HAY VUELTA ATRAS", sh/2 + 80, 2, 1, 0, 0, (ft-1.0)*2)
            end
        end
    elseif gameState == "tutorial" then
        love.graphics.clear(0, 0, 0)
        
        local time = love.timer.getTime()
        local ta = math.min(1, tutorialTimer * 3)
        
        if tutorialPhase == 1 then
            -- Movement
            love.graphics.setColor(1, 1, 1, ta)
            love.graphics.draw(assets.player, sw/2, sh/2 - 80, 0, 2.2, 2.2, 32, 32)
            local bo = math.sin(time * 4) * 15
            love.graphics.setColor(1, 1, 1, ta * 0.3)
            love.graphics.draw(assets.player, sw/2 + bo, sh/2 - 80, 0, 2, 2, 32, 32)
            love.graphics.draw(assets.player, sw/2 - bo, sh/2 - 80, 0, 2, 2, 32, 32)
            drawCentered("WASD para moverte", sh/2 + 10, 2, 1, 1, 1, ta)
            drawCentered("Nunca dejes de moverte o moriras", sh/2 + 50, 1, 0.6, 0.3, 0.3, ta * 0.7)
        elseif tutorialPhase == 2 then
            -- Shooting
            love.graphics.setColor(1, 1, 1, ta)
            love.graphics.draw(assets.player, sw/2 - 80, sh/2 - 60, 0, 2, 2, 32, 32)
            for i=1,3 do
                local bx = sw/2 - 50 + (time * 200 + i * 40) % 200
                love.graphics.setColor(1, 0.8, 0.2, ta * (1 - (bx - sw/2 + 50)/200))
                love.graphics.circle("fill", bx, sh/2 - 60, 4)
            end
            love.graphics.setColor(0.5, 0.5, 0.5, ta)
            love.graphics.draw(assets.blob[1], sw/2 + 100, sh/2 - 60 + math.sin(time*3)*5, 0, 2, 2, 16, 16)
            drawCentered("MOUSE para disparar", sh/2 + 10, 2, 1, 0.8, 0.3, ta)
            drawCentered("Apunta a los monstruos", sh/2 + 50, 1, 0.6, 0.4, 0.2, ta * 0.7)
        elseif tutorialPhase == 3 then
            -- Dash
            local dx = (time * 300) % 200 - 100
            local trail = math.abs(dx) < 50
            if trail then
                for i=1,3 do
                    love.graphics.setColor(0.3, 0.6, 1, ta * (0.3 - i*0.08))
                    love.graphics.draw(assets.player, sw/2 + dx - i*15, sh/2 - 60, 0, 2, 2, 32, 32)
                end
            end
            love.graphics.setColor(1, 1, 1, ta)
            love.graphics.draw(assets.player, sw/2 + dx, sh/2 - 60, 0, 2, 2, 32, 32)
            drawCentered("ESPACIO para dash", sh/2 + 10, 2, 0.4, 0.7, 1, ta)
            drawCentered("Eres invencible durante el dash", sh/2 + 50, 1, 0.3, 0.4, 0.6, ta * 0.7)
        elseif tutorialPhase == 4 then
            -- Enemies
            local enemies = {{assets.blob[1],"Blob",16},{assets.bomber[1],"Bomber",16},{assets.idder[1],"Idder",16},{assets.dummy[1],"Dummy",32}}
            for i, e in ipairs(enemies) do
                local ex = sw/2 - 200 + (i-1) * 130
                local ey = sh/2 - 70 + math.sin(time*3 + i)*10
                love.graphics.setColor(1, 0.3, 0.3, ta)
                love.graphics.draw(e[1], ex, ey, 0, 2, 2, e[3], e[3])
            end
            drawCentered("Cada enemigo es diferente", sh/2 + 20, 1.5, 1, 0.3, 0.2, ta)
            drawCentered("Cuidado con los Bombers", sh/2 + 55, 1, 0.8, 0.2, 0.1, ta * 0.7)
        elseif tutorialPhase == 5 then
            -- Final warning
            local pulse = 0.7 + math.sin(time * 6) * 0.3
            drawCentered("NO HAY PIEDAD", sh/2 - 40, 3, pulse, 0, 0, ta)
            drawCentered("Cada sala es peor que la anterior", sh/2 + 30, 1.2, 0.7, 0.2, 0.2, ta * 0.8)
            drawCentered("Buena suerte...", sh/2 + 65, 1, 0.5, 0.5, 0.5, ta * 0.6)
        end
    elseif gameState == "dead" then
        love.graphics.clear(0.05, 0, 0)
        local a = math.min(1, deathTimer)
        local time = love.timer.getTime()
        local pulse = 0.8 + math.sin(time * 4) * 0.2
        drawCentered("MALDITO", sh/2 - 60, 5, pulse, 0, 0, a)
        if deathTimer > 1.5 then
            drawCentered("PULSA 'R' PARA REINTENTAR", sh/2 + 220, 1.2, 1, 1, 1, math.min(1, deathTimer - 1.5))
            
            -- Draw Leaderboard
            love.graphics.setColor(1, 0.9, 0.3, a * 0.8)
            drawCentered("-- MEJORES PUNTUACIONES --", sh/2 - 190, 1.5, 1, 0.9, 0.3, a)
            
            local scores = highScores or {}
            for i, s in ipairs(scores) do
                if i <= 5 then
                    local y = sh/2 - 140 + (i-1) * 35
                    local txt = i .. ". " .. s.score .. " PTS (" .. s.rooms .. " SALAS)"
                    drawCentered(txt, y, 1.2, 1, 1, 1, a * (1 - (i-1)*0.15))
                end
            end
        end
    else
    love.graphics.push()
    
    -- Apply Global Zoom
    love.graphics.scale(gameZoom, gameZoom)
    
    if shakeTime > 0 and maxShakeTime > 0 then
        local currentIntensity = shakeIntensity * (shakeTime / maxShakeTime)
        -- Spring-like shake instead of linear uniform shake
        local time = love.timer.getTime() * 40
        local sx = math.sin(time) * currentIntensity
        local sy = math.cos(time * 1.2) * currentIntensity
        love.graphics.translate(math.floor(sx), math.floor(sy))
    end
    -- Camera lerp bounds (Map is 1440x960) with zoom compensation
    local mw, mh = 45 * 32, 30 * 32
    local vsw, vsh = sw / gameZoom, sh / gameZoom
    local clampX = math.max(vsw/2, math.min(mw - vsw/2, camX))
    local clampY = math.max(vsh/2, math.min(mh - vsh/2, camY))
    
    love.graphics.translate(math.floor(vsw/2 - clampX), math.floor(vsh/2 - clampY))
    
    
    map.draw()
    
    -- Draw hazards
    for _, hz in ipairs(_G.hazards) do
        if hz.type == "poison" then
            local alpha = math.min(1, hz.life) * 0.7
            love.graphics.setColor(1, 1, 1, alpha)
            if assets.poison then
                local scale = (hz.r * 2) / 64
                love.graphics.draw(assets.poison[1], hz.x, hz.y, 0, scale, scale, 32, 32)
            else
                love.graphics.setColor(0.3, 0.8, 0.2, alpha * 0.8)
                love.graphics.ellipse("fill", hz.x, hz.y, hz.r, hz.r * 0.6)
            end
        end
    end
    
    -- Draw interactables
    for _, int in ipairs(interactables) do
        if int.type == "blood_shrine" then
            love.graphics.setColor(0.8, 0, 0)
            love.graphics.draw(assets.iron[1], int.x, int.y + math.sin(love.timer.getTime()*5)*4, 0, 2, 2, 8, 8)
            love.graphics.setColor(1, 0.3, 0.3, 0.5)
            love.graphics.ellipse("fill", int.x, int.y + 16, 16, 8)
        end
    end
    love.graphics.setColor(1, 1, 1)
    juice.drawDecals() -- Blood on the floor
    pickup.draw(); bullet.draw(); enemy.draw(); player.draw(); juice.draw()
    
    -- Draw prompts
    for _, int in ipairs(interactables) do
        if int.showPrompt then
            -- Draw world-space prompt
            love.graphics.setColor(0, 0, 0, 0.7)
            local txt = "Presiona 'E' para Sacrificio"
            local tw = love.graphics.getFont():getWidth(txt) * 0.8
            love.graphics.rectangle("fill", int.x - tw/2 - 5, int.y - 45, tw + 10, 20, 4)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(txt, int.x - tw/2, int.y - 45, 0, 0.8, 0.8)
        end
    end
    
    love.graphics.pop()
    
    
    
    -- Exit Arrows (Pointing to doors)
    if map.areDoorsOpen() and assets.arrow then
        local time = love.timer.getTime()
        local px, py = player.getPos()
        local mw, mh = 45 * 32, 30 * 32
        local doors = {
            {x = mw/2, y = 32, ang = -math.pi/2}, -- Top
            {x = mw/2, y = mh-32, ang = math.pi/2}, -- Bottom
            {x = 32, y = mh/2, ang = math.pi}, -- Left
            {x = mw-32, y = mh/2, ang = 0} -- Right
        }
        
        for _, d in ipairs(doors) do
            local dx, dy = d.x - px, d.y - py
            local dist = math.sqrt(dx*dx + dy*dy)
            local angle = math.atan2(dy, dx)
            
            -- Draw arrow near player pointing to door
            local distLimit = 100
            local ax = px + math.cos(angle) * distLimit
            local ay = py + math.sin(angle) * distLimit
            
            -- In screen space (relative to camera)
            local vsw, vsh = sw / gameZoom, sh / gameZoom
            local clampX = math.max(vsw/2, math.min(mw - vsw/2, camX))
            local clampY = math.max(vsh/2, math.min(mh - vsh/2, camY))
            
            love.graphics.push()
            love.graphics.scale(gameZoom, gameZoom)
            love.graphics.translate(math.floor(vsw/2 - clampX), math.floor(vsh/2 - clampY))
            
            love.graphics.setColor(1, 1, 1, 0.4 + math.sin(time*8)*0.3)
            love.graphics.draw(assets.arrow[1], ax, ay, angle, 1.2, 1.2, 16, 16)
            love.graphics.pop()
        end
    end
    
    -- Sacrifice Roulette UI
    if roulette.active then
        local rx, ry = sw/2, sh/2 - 100
        local time = love.timer.getTime()
        
        local item = roulette.items[roulette.index]
        -- Large bold text for roulette
        local pulse = 1 + math.sin(time * 20) * 0.1
        love.graphics.setColor(0,0,0,0.8)
        drawCentered(item.name, ry + 4, 3 * pulse, 0, 0, 0, 0.7)
        love.graphics.setColor(item.color[1], item.color[2], item.color[3], 1)
        drawCentered(item.name, ry, 3 * pulse, item.color[1], item.color[2], item.color[3], 1)
        
        if roulette.speed > 0 then
            drawCentered("SORTEANDO...", ry - 60, 1.2, 1, 1, 1, 0.5 + math.sin(time*10)*0.3)
        end
    end
    
    -- Removed blind and darkness overlays

    
    -- Aura visual ring around player
    local auraLvl = shop.getLevel("aura")
    if auraLvl > 0 and gameState == "playing" then
        local px, py = player.getPos()
        local aR = 60 + auraLvl * 20
        local vsw2, vsh2 = sw / gameZoom, sh / gameZoom
        local clampX2 = math.max(vsw2/2, math.min(45*32 - vsw2/2, camX))
        local clampY2 = math.max(vsh2/2, math.min(30*32 - vsh2/2, camY))
        love.graphics.push()
        love.graphics.scale(gameZoom, gameZoom)
        love.graphics.translate(math.floor(vsw2/2 - clampX2), math.floor(vsh2/2 - clampY2))
        love.graphics.setColor(0.3, 0.8, 1.0, 0.15 + math.sin(love.timer.getTime()*6)*0.05)
        love.graphics.circle("line", px, py, aR)
        love.graphics.setColor(0.3, 0.6, 1.0, 0.05)
        love.graphics.circle("fill", px, py, aR)
        love.graphics.pop()
    end
    

    
    -- Removed boss red overlay

    
    if critFlash > 0 then
        love.graphics.setColor(1,1,0.5,critFlash*0.15); love.graphics.rectangle("fill",0,0,sw,sh); love.graphics.setColor(1,1,1)
    end
    
    -- Cartoon Circle Transition (Iris Wipe)
    if transitionAlpha > 0 then
        local centerX, centerY = sw/2, sh/2
        local maxRadius = math.sqrt(sw*sw + sh*sh) / 1.5
        local radius = 0
        
        if transitionDir == 1 then -- Closing
            radius = maxRadius * (1 - transitionAlpha)
        else -- Opening
            radius = maxRadius * (1 - transitionAlpha)
        end
        
        -- Use stencil to draw the "hole"
        love.graphics.stencil(function()
            love.graphics.circle("fill", centerX, centerY, math.max(0, radius))
        end, "replace", 1)
        
        love.graphics.setStencilTest("notequal", 1)
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
        love.graphics.setStencilTest()
        love.graphics.setColor(1, 1, 1)
    end

    
    -- CURSE CINEMATIC
    if curseAnim.active then
        local a = curseAnim.alpha
        local time = love.timer.getTime()
        -- Anime Speed Lines
        love.graphics.setColor(1, 1, 1, a * 0.3)
        love.graphics.setLineWidth(2)
        for i=1, 24 do
            local ang = (i/24) * math.pi * 2 + time * 5
            local r1, r2 = 50 + (1-a)*300, 1000
            love.graphics.line(sw/2 + math.cos(ang)*r1, sh/2 + math.sin(ang)*r1, sw/2 + math.cos(ang)*r2, sh/2 + math.sin(ang)*r2)
        end
        love.graphics.setLineWidth(1)
        
        -- Flashy background pulse
        love.graphics.setColor(1, 0, 0, a * 0.15 * math.abs(math.sin(time*20)))
        love.graphics.rectangle("fill", 0, 0, sw, sh)

        
        -- Curse-specific visual effects
        if curseAnim.id == "fragile" then
            love.graphics.setColor(0.8, 0.1, 0.1, a * 0.4)
            for i=1,10 do
                love.graphics.line(love.math.random(sw), 0, love.math.random(sw), sh)
            end
        elseif curseAnim.id == "rust" then
            love.graphics.setColor(0.6, 0.3, 0.1, a * 0.5)
            for i=1, 50 do
                love.graphics.circle("fill", love.math.random(sw), love.math.random(sh), love.math.random(2, 5))
            end
        elseif curseAnim.id == "slow_bullets" then
            love.graphics.setColor(0.4, 0.4, 0.8, a * 0.4)
            love.graphics.rectangle("fill", 0, sh/2 - 20, sw, 40)
        end
        
        -- Title & Text animation
        love.graphics.push()
        love.graphics.translate(sw/2, sh/2)
        -- Pop-in scaling animation based on alpha
        local scaleAnim = 1 + (1 - a) * 5 -- Explosive pop-in anime style
        local s = 2.5 * scaleAnim + math.sin(time * 3) * 0.1
        love.graphics.scale(s, s)
        
        local shk = a > 0.5 and love.math.random(-1,1) or 0
        love.graphics.setColor(1, 0.15, 0.1, a)
        love.graphics.printf("- - M A L D I C I O N - -", -200 + shk, -30 + math.sin(time*4)*2, 400, "center")
        
        -- Curse name
        love.graphics.setColor(1, 0.3, 0.2, a)
        love.graphics.printf(curseAnim.name, -200 + shk, -10, 400, "center")
        
        -- Description
        love.graphics.setColor(0.8, 0.6, 0.5, a * 0.8)
        love.graphics.printf(curseAnim.desc, -200, 15, 400, "center")
        love.graphics.pop()
        -- Removed scan lines
        love.graphics.setColor(1,1,1)
    end
    end
    
    love.graphics.setCanvas()
    
    local isRetroState = (gameState ~= "intro")
    
    -- Scale and Center the Canvas to the Screen
    local scale = math.min(realW / 1280, realH / 720)
    local ox = (realW - 1280 * scale) / 2
    local oy = (realH - 720 * scale) / 2
    
    love.graphics.draw(gameCanvas, ox, oy, 0, scale, scale)
    
    -- DRAW UI (Outside the shader for sharp text)
    love.graphics.push()
    love.graphics.translate(ox, oy)
    love.graphics.scale(scale, scale)
    
    if gameState == "shop" then
        local mx, my = getCanvasMouse()
        shop.draw(1, goldCount, deathMsg, highScores, mx, my)
    elseif gameState == "manual" then
        drawManual()
    elseif gameState == "playing" or gameState == "dead" then
        drawHUD()
    end
    
    love.graphics.pop()
    
    if overlayAlpha > 0 then
        drawOverlayMenu()
    end
    
    if settingsAlpha > 0 then
        drawSettingsMenu()
    end
end

function drawManual()
    local sw, sh = 1280, 720
    love.graphics.setColor(0,0,0,0.95); love.graphics.rectangle("fill",0,0,sw,sh)
    love.graphics.setColor(1,0.9,0.3); love.graphics.printf("MANUAL DE MONSTRUOS", 0, 40, sw, "center")
    local m = {
        {img=assets.blob[1], name="BLOB", desc="Persigue en grupo. Variante Bomber explota al morir.", color={0.6,0.8,0.6}},
        {img=assets.oozel[1], name="OOZEL", desc="Rápido, esquiva balas. Variante Dasher embiste.", color={0.4,0.7,1}},
        {img=assets.slime[1], name="SLIME", desc="Salta hacia ti. Variante Splitter se divide al morir.", color={0.2,0.9,0.3}},
        {img=assets.idder[1], name="IDDER", desc="Tanque. Marca con X y dispara láser.", color={0.9,0.5,0.5}},
        {img=assets.siter[1], name="SITER", desc="Ojo volador. Circula y ráfagas rápidas.", color={0.8,0.3,0.8}}
    }
    for i, mon in ipairs(m) do
        local y = 90+(i-1)*90; local s = mon.name=="SITER" and 2 or 3
        love.graphics.setColor(mon.color[1],mon.color[2],mon.color[3],0.15)
        love.graphics.rectangle("fill",sw/2-350,y-10,700,70,6,6)
        love.graphics.setColor(1,1,1)
        love.graphics.draw(mon.img, sw/2-300, y+15, 0, s, s, mon.img:getWidth()/2, mon.img:getHeight()/2)
        love.graphics.setColor(mon.color[1],mon.color[2],mon.color[3]); love.graphics.printf(mon.name, sw/2-220, y, 500, "left")
        love.graphics.setColor(0.8,0.8,0.8); love.graphics.printf(mon.desc, sw/2-220, y+20, 500, "left")
    end
    love.graphics.setColor(1,1,1,0.4); love.graphics.printf("Presiona M para volver", 0, sh-40, sw, "center"); love.graphics.setColor(1,1,1)
end

function drawHUD()
    local sw, sh = 1280, 720
    love.graphics.push()
    local s = 1.5
    love.graphics.scale(s, s)
    
    local hsw = sw / s
    local hsh = sh / s
    
    local t = love.timer.getTime()
    
    -- --- HUD PANELS (Anime Style) ---
    -- Top Left Panel (HP)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.polygon("fill", 0, 0, 250, 0, 220, 50, 0, 50)
    love.graphics.setColor(1, 0.2, 0.2, 0.8)
    love.graphics.line(0, 48, 218, 48)
    
    -- Top Right Panel (Stats)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.polygon("fill", hsw - 180, 0, hsw, 0, hsw, 80, hsw - 210, 80)
    love.graphics.setColor(0.3, 0.8, 1, 0.8)
    love.graphics.line(hsw - 208, 78, hsw, 78)

    -- --- HP HUD ---
    local hp, maxHp = player.getHp(), player.getMaxHp()
    for i=1,maxHp do
        local isLow = (hp <= 1)
        local pulse = 1.0
        if i <= hp then
            local speed = isLow and 12 or 4
            pulse = 1.1 + math.sin(t * speed + i*0.5) * 0.1
            love.graphics.setColor(1, 1, 1)
            local img = assets.heart.full or (type(assets.heart) == "table" and assets.heart[1])
            if img then
                love.graphics.draw(img, 35+(i-1)*32, 25, math.sin(t*3 + i)*0.1, 1.3 * pulse, 1.3 * pulse, 16, 16)
            end
        else
            love.graphics.setColor(1, 1, 1)
            local img = assets.heart.broken or (type(assets.heart) == "table" and assets.heart[1])
            if img then
                love.graphics.draw(img, 35+(i-1)*32, 25, math.sin(t*3 + i)*0.05, 1.3, 1.3, 16, 16)
            end
        end
    end
    
    -- --- DASH HUD ---
    local dashC, maxDashC = player.getDashCharges()
    local dashCD = player.getDashCooldown()
    local maxCD = math.max(0.15, 0.6 - (shop.getLevel("dashCD")*0.08))
    for i=1, maxDashC do
        local r, g, b = 0.2, 0.2, 0.2
        local alpha = 0.6
        if i <= dashC then
            r, g, b = 0.3, 0.8, 1.0
            alpha = 1.0
        elseif i == dashC + 1 then
            r, g, b = 0.3, 0.5, 0.8
            alpha = math.max(0, 1 - (dashCD / maxCD))
        end
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.rectangle("fill", 20 + (i-1)*20, 42, 16, 4)
    end

    -- --- BULLET HUD (Moved to Bottom Left) ---
    local bx, by = 20, hsh - 50
    local bulletTypes = {"metal", "fire", "ice"}
    local bulletColors = {metal = {0.7, 0.7, 0.7}, fire = {1, 0.3, 0.1}, ice = {0.3, 0.6, 1}}
    for i, bt in ipairs(bulletTypes) do
        local unlocked = _G.bulletInventory[bt]
        local active = (_G.currentBulletType == bt)
        if unlocked then
            local c = bulletColors[bt]
            love.graphics.setColor(c[1], c[2], c[3], active and 1 or 0.3)
            love.graphics.rectangle("fill", bx + (i-1)*20, by, 16, 8, 2, 2)
            if active then
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.rectangle("line", bx + (i-1)*20 - 1, by - 1, 18, 10, 2, 2)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print(bt:upper(), bx, by + 12, 0, 0.5, 0.5)
            end
        end
    end

    -- --- SPEEDRUN TIMER (Moved to Bottom Left, above bullets) ---
    local mins = math.floor(runTimer / 60)
    local secs = math.floor(runTimer % 60)
    love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
    love.graphics.print(string.format("%02d:%02d", mins, secs), bx, by - 25)

    -- --- GOLD & SCORE HUD (Right Aligned) ---
    love.graphics.setColor(1, 1, 1)
    
    -- Gold Text Only
    local gx, gy = hsw - 130, 22
    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.print("ORO: " .. tostring(goldCount), gx - 20, gy - 8)
    
    -- Score Text Only
    local sx, sy = hsw - 130, 45
    love.graphics.setColor(0.6, 0.6, 1)
    love.graphics.print("PTS: " .. tostring(score), sx - 20, sy - 8)
    
    -- KO Count Text Only
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.print("KILLS: " .. tostring(enemy.getKills()), sx - 20, sy + 15)
    
    -- Enemy count (during combat)
    local ec = enemy.getEnemyCount()
    if ec > 0 then
        love.graphics.setColor(1, 0.4, 0.3, 0.9)
        love.graphics.printf(ec .. " ENEMIGOS", 0, hsh - 55, hsw - 20, "right")
    end

    -- --- COMBO HUD (Anime Style) ---
    if comboCount >= 2 and comboTimer > 0 then
        local ca = math.min(1, comboTimer)
        local cc = comboCount>=10 and {1,0,0.5} or comboCount>=5 and {1,0.4,0} or {1,0.8,0}
        
        love.graphics.push()
        love.graphics.translate(35, 80)
        local comboPulse = 1 + math.abs(math.sin(t*12))*0.15
        love.graphics.scale(comboPulse, comboPulse)
        love.graphics.rotate(-0.05)
        
        -- Flashy Background for Combo
        love.graphics.setColor(cc[1], cc[2], cc[3], ca * 0.3)
        love.graphics.polygon("fill", -10, -10, 160, -10, 150, 35, -20, 35)
        
        -- Shadow/Glow
        love.graphics.setColor(0, 0, 0, ca)
        for ox=-2,2,2 do for oy=-2,2,2 do
            love.graphics.print("COMBO x"..comboCount, ox, oy)
        end end
        
        -- Main Text
        love.graphics.setColor(cc[1], cc[2], cc[3], ca)
        love.graphics.print("COMBO x"..comboCount, 0, 0)
        
        -- Animated Bar
        love.graphics.setColor(0, 0, 0, ca * 0.5)
        love.graphics.rectangle("fill", 0, 22, 120, 6)
        love.graphics.setColor(cc[1], cc[2], cc[3], ca)
        love.graphics.rectangle("fill", 0, 22, 120 * (comboTimer/3), 6)
        
        -- Bar Glow (Static)
        love.graphics.setColor(1, 1, 1, ca * 0.2)
        love.graphics.rectangle("fill", 0, 22, 120 * (comboTimer/3), 2)
        
        love.graphics.pop()
    end

    -- --- ROOM INFO & MODS ---
    if roomsCleared > 0 then
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.printf("SALA " .. roomsCleared, 0, hsh - 35, hsw - 20, "right")
    end
    
    if _G.roomMod and _G.roomMod ~= "normal" then
        local mn = ({speed="VELOCIDAD",regen="REGEN",gold_rush="ORO x2",darkness="OSCURIDAD",blessing="BENDICION"})[_G.roomMod] or _G.roomMod
        local mc = ({speed={0.3,0.8,1},regen={0.3,1,0.3},gold_rush={1,0.8,0.2},darkness={0.6,0.4,0.8},blessing={1,0.9,0.3}})[_G.roomMod] or {1,1,1}
        love.graphics.setColor(mc[1],mc[2],mc[3],1)
        love.graphics.printf("MOD: "..mn, 0, 85, hsw-20, "right")
    end

    if #curses > 0 then 
        for ci,c in ipairs(curses) do
            love.graphics.setColor(1,0.1,0.1,1)
            love.graphics.printf("MALDICIÓN: "..c.name:upper(), 0, 85+ci*18, hsw-20, "right")
        end 
    end

    -- --- BOSS BAR ---
    local boss = enemy.getBoss()
    local mini = nil
    if not boss then
        for _,e in ipairs(enemy.getEnemies()) do if e.isMiniBoss then mini = e; break end end
    end
    local target = boss or mini
    if target then
        local bw = math.min(400,hsw*0.6); local bx,by = hsw/2-bw/2, hsh-45
        -- Boss Bar BG
        love.graphics.setColor(0,0,0,0.8); love.graphics.polygon("fill", bx-20, by, bx+bw+20, by, bx+bw+10, by+25, bx-10, by+25)
        
        local ratio = math.max(0,target.hp/(target.maxHp or 10))
        -- Main HP Bar
        love.graphics.setColor(0.1, 0.1, 0.1, 1)
        love.graphics.rectangle("fill", bx, by+5, bw, 12)
        love.graphics.setColor(0.8*(1-ratio)+0.2,0.8*ratio,0.1); 
        love.graphics.rectangle("fill", bx, by+5, bw*ratio, 12)
        
        -- Rage/Special bar if boss
        if target.isBoss then
            local rage = 1 - ratio
            love.graphics.setColor(1,0,0, 0.6 * math.abs(math.sin(t*10)))
            love.graphics.rectangle("fill",bx,by+18,bw*rage,4)
        end
        
        local name = target.isBoss and (target.type=="boss_slime" and "REY SLIME" or "MADRE IDDER") or "MINI-JEFE "..target.type:upper()
        love.graphics.setColor(0,0,0,0.5); love.graphics.printf(name,bx+2,by-16,bw,"center")
        love.graphics.setColor(1,1,1); love.graphics.printf(name,bx,by-18,bw,"center")
    end
    
    love.graphics.pop()
    
    -- DRAW SCREEN BLOOD (THE WINDOW)
    juice.drawScreenBlood()
    
    -- Retro scanlines over HUD
    love.graphics.setColor(0,0,0,0.05)
    for sl=0,sh,4 do love.graphics.line(0,sl,sw,sl) end
    love.graphics.setColor(1,1,1)
end



function love.keypressed(key)
    if key == "tab" then showOverlay = not showOverlay end
    if key == "escape" and gameState ~= "dead" and gameState ~= "shop" then 
        showSettings = not showSettings 
    end
    
    if showSettings then
        if key == "1" or key == "p" then useCRT = not useCRT end
        if key == "r" then resetGame(); showSettings = false end
    elseif gameState == "playing" then 
        -- Bullet Switching
        if key == "1" and _G.bulletInventory.metal then _G.currentBulletType = "metal"
        elseif key == "2" and _G.bulletInventory.fire then _G.currentBulletType = "fire"
        elseif key == "3" and _G.bulletInventory.ice then _G.currentBulletType = "ice"
        end
        
        if key == "m" then previousState=gameState; gameState="manual" end
        -- Shrine Interaction
        if key == "e" then
            local px, py = player.getPos()
            for i = #interactables, 1, -1 do
                local int = interactables[i]
                local distToInt = math.sqrt((px - int.x)^2 + (py - int.y)^2)
                if distToInt < 45 and enemy.getEnemyCount() == 0 then
                    if int.type == "blood_shrine" then
                        player.takeDamage(1)
                        juice.spawnText(int.x, int.y - 20, "SACRIFICIO", {1, 0.2, 0.2})
                        roulette.active = true
                        roulette.speed = 12 + love.math.random() * 8
                        roulette.timer = 0
                        roulette.finishTimer = 0
                        table.remove(interactables, i)
                        addShake(0.2, 5)
                        break
                    end
                end
            end
        end
    elseif gameState == "manual" then 
        if key == "m" or key == "escape" then gameState=previousState end 
    elseif gameState == "shop" or gameState == "dead" then
        if key == "r" then resetGame() end
    end
end

function love.wheelmoved(x, y)
    if gameState == "shop" then
        shop.wheelmoved(x, y)
    end
end

function love.mousepressed(x, y, button)
    if curseAnim.active then return end
    local mx, my = getCanvasMouse()
    if gameState == "shop" and button == 1 then 
        goldCount = shop.mousepressed(mx, my, 1, goldCount) 
    end
end

function checkCollisions()
    local bullets = bullet.getBullets()
    local enms = enemy.getEnemies()
    local px, py = player.getPos()
    
    for i=#bullets,1,-1 do
        local b = bullets[i]
        local tile = map.getTileAt(b.x, b.y)
        local isWall = tile and (tile:sub(1,4)=="wall" or tile:sub(1,6)=="corner" or tile:sub(1,3)=="box")
        
        if isWall then 
            bullet.remove(i); juice.spawnExplosion(b.x,b.y,-b.dx,-b.dy,"spark")
        elseif b.isEnemy then
            -- Player Hitbox (Favor player: slightly smaller than sprite center)
            local dist = math.sqrt((b.x-px)^2+(b.y-py)^2)
            local playerRadius = 18 -- More accurate hitbox for 64x64 sprite
            if dist < playerRadius then
                local dmg = isCurseActive("fragile") and 2 or 1
                -- Shield: chance to block
                local shieldLvl = shop.getLevel("shield")
                local shieldChance = shieldLvl * 0.12
                if shieldLvl > 0 and love.math.random() < shieldChance then
                    juice.spawnText(px,py-20,"¡BLOQUEADO!",{0.3,0.7,1})
                    addShake(0.15, 5)
                else
                    if player.takeDamage(dmg) then 
                        addShake(0.3,10); juice.spawnExplosion(px,py,b.dx,b.dy,"blood")
                        juice.spawnScreenBlood()
                        juice.spawnText(px,py-20,"-"..dmg.." HP",{1,0.2,0.2}) 
                    end
                end
                bullet.remove(i)
            end
        else
            for j=#enms,1,-1 do
                local e = enms[j]
                local dist = math.sqrt((b.x-e.x)^2+(b.y-e.y)^2)
                -- Enemy Hitbox (Easier to hit: matched to 64x64 sprite)
                local enemyRadius = (e.type=="siter" and 32 or 24)
                if e.isBoss then enemyRadius = enemyRadius * (e.scale or 1) * 0.7 end
                
                if dist < enemyRadius + (b.size or 1) * 4 then
                    local dmg = b.damage
                    -- Vigor: more damage when low HP
                    local vigorLvl = shop.getLevel("vigor")
                    if vigorLvl > 0 then
                        local hpRatio = player.getHp() / player.getMaxHp()
                        dmg = dmg * (1 + vigorLvl * 0.2 * (1 - hpRatio))
                    end
                    -- Check for crits
                    local critChance = 0.05 + shop.getLevel("critChance") * 0.05
                    local luckLvl = shop.getLevel("luck")
                    critChance = critChance + luckLvl * 0.02
                    local isCrit = love.math.random() < critChance
                    if isCrit then dmg = dmg * 3; critFlash = 0.3 end
                    
                    local killed = enemy.hit(j, dmg)
                    -- Damage numbers always shown
                    local dmgText = string.format("%.0f", dmg)
                    if isCrit then 
                        juice.spawnText(e.x,e.y-30,"¡CRÍTICO! "..dmgText,{1,1,0}); addShake(0.15,8) 
                    else
                        juice.spawnText(e.x,e.y-20, dmgText, {1,0.8,0.6})
                    end
                    
                    if killed then
                        hitStop = 0.1; comboCount=comboCount+1; comboTimer=3.0
                        score = score + 50 + comboCount*10
                        juice.spawnExplosion(e.x, e.y, b.dx, b.dy, "gore")
                        if comboCount > 8 then juice.spawnScreenBlood() end
                        addShake(0.35, 20)
                        local cc = comboCount>=10 and {1,0.2,0.8} or comboCount>=5 and {1,0.3,0} or {1,0.6,0}
                        if comboCount>=2 then juice.spawnComboText(e.x,e.y-40,"x"..comboCount, cc) end
                        -- Kill streak milestones
                        local totalKills = enemy.getKills()
                        if totalKills%10==0 then player.heal(1); juice.spawnText(e.x,e.y-50,"¡RACHA x"..totalKills.."!",{0.2,1,0.5}) end
                        if totalKills%25==0 then goldCount = goldCount + 50; juice.spawnText(e.x,e.y-60,"+50 ORO RACHA",{1,0.9,0.3}); score = score + 250 end
                        if love.math.random()<player.getVampChance() then player.heal(1); juice.spawnText(e.x,e.y-20,"¡VAMP!",{0.8,0.2,0.2}) end
                        -- Berserk: boost fire rate temporarily
                        local berserkLvl = shop.getLevel("berserk")
                        if berserkLvl > 0 then
                            _G.berserkTimer = 2.0 + berserkLvl
                        end
                    else
                        -- Apply elemental effects
                        local iceLvl = shop.getLevel("iceBullets")
                        if iceLvl > 0 and love.math.random() < (0.1 + iceLvl * 0.1) then
                            e.iceTimer = 3.0
                        end
                        local fireLvl = shop.getLevel("fireBullets")
                        if fireLvl > 0 and love.math.random() < (0.15 + fireLvl * 0.1) then
                            e.fireTimer = 4.0
                        end
                        juice.spawnExplosion(e.x, e.y, b.dx, b.dy, "blood")
                    end
                    bullet.remove(i); 
                    addShake(isCrit and 0.15 or 0.08, isCrit and 8 or 4); break
                end
            end
        end
    end
    
    -- Enemy vs Player contact damage
    for i=#enms,1,-1 do
        local e = enms[i]
        if e.state == "dying" then goto continue_contact end
        local dist = math.sqrt((px-e.x)^2+(py-e.y)^2)
        local contactRadius = (e.type=="siter" and 32 or 22)
        if e.isBoss then contactRadius = contactRadius * (e.scale or 1) * 0.6 end
        
        if dist < contactRadius then
            local dmg = isCurseActive("fragile") and 2 or 1
            -- Shield on contact
            local shieldLvl = shop.getLevel("shield")
            if shieldLvl > 0 and love.math.random() < shieldLvl * 0.12 then
                juice.spawnText(px,py-20,"¡BLOQUEADO!",{0.3,0.7,1})
                addShake(0.1, 3)
                goto continue_contact
            end
            if player.takeDamage(dmg) then 
                addShake(0.4,12); juice.spawnExplosion(px,py,0,0,"blood")
                hitStop = 0.08
                damageFlash = 1.0 -- Red flash on hit
            end
        end
        ::continue_contact::
    end
end

local pendingRdx, pendingRdy, pendingPx, pendingPy = 0,0,0,0

local function findSafePos(sx, sy)
    -- Check a larger area and avoid walls/boxes
    if map.isWalkable(sx, sy) then
        local tile = map.getTileAt(sx, sy)
        if tile == "floor" or tile == "floor_alt" then return sx, sy end
    end
    for r=1,12 do for _,o in ipairs({{r*32,0},{-r*32,0},{0,r*32},{0,-r*32},{r*24,r*24},{-r*24,r*24},{r*24,-r*24},{-r*24,-r*24}}) do
        local tx, ty = sx+o[1], sy+o[2]
        if map.isWalkable(tx, ty) then
            local tile = map.getTileAt(tx, ty)
            if tile == "floor" or tile == "floor_alt" then return tx, ty end
        end
    end end
    return sx, sy
end

function checkRoomTransition()
    local px,py = player.getPos()
    local rdx,rdy = map.checkRoomTransition(px, py)
    if rdx or rdy then
        pendingRdx=rdx or 0; pendingRdy=rdy or 0; pendingPx=px; pendingPy=py
        transitionDir=1; transitionAlpha=0
    end
end

function doRoomSwitch()
    map.changeRoom(pendingRdx, pendingRdy)
    map.setDoorsOpen(false)
    enemy.clear(); bullet.reset(); pickup.clear(); juice.clear()
    curses = {} -- Curses are now per-room as requested
    comboCount=0; comboTimer=0
    roomsCleared = roomsCleared + 1
    
    local totalLevels = shop.getTotalUpgradesLevel() or 0
    local difficulty = roomsCleared + math.floor(totalLevels/2)
    local isBossRoom = roomsCleared > 0 and roomsCleared % 5 == 0
    
    _G.roomMod = roomModList[love.math.random(1,#roomModList)]
    if isBossRoom then _G.roomMod = "normal" end
    
    if _G.roomMod == "blessing" then
        player.heal(1)
        for i=1, 5 do pickup.spawn(400+love.math.random(-50,50), 272+love.math.random(-50,50)) end
        juice.spawnText(400, 272, "BENDICION", {1,0.9,0.3})
    end
    
    -- Curse (45% chance after any room to see it, max 2 curses)
    if roomsCleared > 0 and #curses < 2 and love.math.random() < 0.45 then
        local available = {}
        for _,cl in ipairs(curseList) do
            local found = false
            for _,ac in ipairs(curses) do if ac.id==cl.id then found=true end end
            if not found then table.insert(available, cl) end
        end
        if #available > 0 then
            local c = available[love.math.random(1,#available)]
            table.insert(curses, {id=c.id, name=c.name})
            -- Trigger cinematic after transition!
            curseAnim.pending = true; curseAnim.timer = 3.5
            curseAnim.id = c.id; curseAnim.name = c.name; curseAnim.desc = c.desc; curseAnim.alpha = 0
        end
    end
    
    local spX,spY
    if pendingRdx==1 then spX,spY=findSafePos(96,pendingPy)
    elseif pendingRdx==-1 then spX,spY=findSafePos(1440-96,pendingPy)
    elseif pendingRdy==1 then spX,spY=findSafePos(pendingPx,96)
    elseif pendingRdy==-1 then spX,spY=findSafePos(pendingPx,960-96) end
    if spX then player.setPos(spX, spY); camX, camY = spX, spY; player.triggerEntrance() end
    
    _G.hazards = {}
    interactables = {}
    
    if _G.roomMod == "hazard_zone" then
        for i=1, 8 do
            local sx2, sy2 = findSafePos(love.math.random(200,1200), love.math.random(200,700))
            if sx2 then table.insert(_G.hazards, {type="poison", x=sx2, y=sy2, r=35+love.math.random(10,20), life=9999}) end
        end
        juice.spawnText(400, 300, "ZONA PELIGROSA", {0.3, 1, 0.3})
    elseif _G.roomMod == "elite" then
        enemy.spawnBoss(difficulty, true)
        juice.spawnText(400, 300, "SALA ELITE", {1, 0.5, 0})
    elseif _G.roomMod == "chaos" then
        juice.spawnText(400, 300, "SALA CAOS", {1, 0.2, 1})
    elseif _G.roomMod == "bouncing" then
        juice.spawnText(400, 300, "SALA REBOTE", {0.3, 0.6, 1})
    end
    
    -- Spawn Blood Shrine randomly
    if not isBossRoom and love.math.random() < 0.25 then
        local sx, sy = findSafePos(1440/2, 960/2)
        if sx then table.insert(interactables, {type="blood_shrine", x=sx, y=sy}) end
    end

    -- Spawn enemies AWAY from player spawn
    local swarmMult = isCurseActive("swarm") and 1.5 or 1
    if isBossRoom then 
        map.clearStructures(); enemy.spawnBoss(difficulty)
        -- Boss entrance animation
        bossIntroTimer = 1.2
        addShake(1.2, 20)
        juice.spawnText(400, 240, "¡¡ JEFE !!", {1,0,0})
        juice.spawnText(400, 280, (roomsCleared == 5 and "REY SLIME" or "MADRE IDDER"), {1,0.2,0.2})
        juice.spawnText(400, 320, "PREPÁRATE", {1,0.5,0})
    else
        enemy.spawn(difficulty, nil, nil, {x = spX or 720, y = spY or 480}, roomsCleared)
    end
end

function addShake(t, i) 
    shakeTime = t
    maxShakeTime = t
    shakeIntensity = i 
end

function _G.spawnHazard(htype, hx, hy, hr, hlife)
    table.insert(hazards, {type=htype, x=hx, y=hy, r=hr, life=hlife})
end

function restartGame()
    map.init(assets); player.init(assets.player); shop.applyUpgrades()
    enemy.init({blob=assets.blob,oozel=assets.oozel,idder=assets.idder,slime=assets.slime,siter=assets.siter,bomber=assets.bomber,dummy=assets.dummy,x=assets.x})
    bullet.reset(); pickup.init(assets.gold); juice.init(assets.blood, assets.iron)
    roomsCleared=0; score=0; comboCount=0; comboTimer=0; curses={}; _G.roomMod=nil; _G.berserkTimer=0
    transitionAlpha=0; transitionDir=0; curseAnim.active=false; bossIntroTimer=0
    gameState="playing"; map.setDoorsOpen(true)
    
    -- Spawn dummy at the start
    enemy.spawnSpecific(720, 600, "dummy", 0)
end

function drawOverlayMenu()
    local a = overlayAlpha
    local sw, sh = 1280, 720
    
    -- Center Menu Overlay
    love.graphics.setColor(0, 0, 0, 0.9 * a)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    
    love.graphics.push()
    love.graphics.translate(sw/2, sh/2)
    love.graphics.scale(1 + (1-a)*0.1, 1 + (1-a)*0.1)
    
    -- Retro Frame
    love.graphics.setColor(1, 0.8, 0.2, 0.3 * a)
    love.graphics.rectangle("line", -300, -200, 600, 400, 10)
    love.graphics.setColor(1, 0.9, 0.3, a)
    love.graphics.printf("- ESTADISTICAS DEL ABISMO -", -300, -170, 600, "center")
    love.graphics.rectangle("fill", -100, -145, 200, 2)
    
    local py = -110
    local function stat(label, val, color)
        love.graphics.setColor(0.7, 0.7, 0.7, a)
        love.graphics.printf(label, -250, py, 250, "left")
        love.graphics.setColor(color[1], color[2], color[3], a)
        love.graphics.printf(tostring(val), 0, py, 250, "right")
        py = py + 35
    end
    
    stat("Salas Limpias", roomsCleared, {1,1,1})
    stat("Puntuacion", score, {1,0.8,0.2})
    stat("Oro Actual", goldCount, {1,1,0.4})
    py = py + 15
    
    stat("Vida Maxima", player.getMaxHp(), {1,0.3,0.3})
    stat("Poder de Fuego", (1 + (shop.getLevel("bulletDmg") or 0)), {1,0.5,0.5})
    stat("Cadencia (Seg)", string.format("%.2f", (0.12 - (shop.getLevel("fireRate") or 0)*0.012)), {0.5,1,0.5})
    stat("Velocidad Mov.", math.floor(260 + (shop.getLevel("speed") or 0)*20), {0.5,0.8,1})
    
    py = py + 30
    love.graphics.setColor(0.8, 0.2, 0.2, a)
    love.graphics.printf("MALDICIONES ACTIVAS", -300, py, 600, "center")
    py = py + 30
    
    if #curses == 0 then
        love.graphics.setColor(0.4, 0.4, 0.4, a)
        love.graphics.printf("Ninguna", -300, py, 600, "center")
    else
        for _, c in ipairs(curses) do
            love.graphics.setColor(1, 0.3, 0.3, a)
            love.graphics.printf("- " .. c.name, -300, py, 600, "center")
            py = py + 25
        end
    end
    
    love.graphics.setColor(0.5, 0.5, 0.5, a * 0.7)
    love.graphics.printf("TAB PARA CERRAR", -300, 160, 600, "center")
    
    -- Scanlines only for the menu
    love.graphics.setColor(0,0,0, a * 0.1)
    for sl=-200, 200, 4 do love.graphics.line(-300, sl, 300, sl) end
    
    love.graphics.pop()
end

function drawSettingsMenu()
    local a = settingsAlpha
    local sw, sh = 1280, 720
    local t = love.timer.getTime()
    
    love.graphics.push()
    love.graphics.translate(sw/2, sh/2)
    
    -- Undertale Style: Black Box, White Border
    love.graphics.setColor(0, 0, 0, 0.95 * a)
    love.graphics.rectangle("fill", -250, -180, 500, 360)
    
    love.graphics.setLineWidth(3)
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.rectangle("line", -250, -180, 500, 360)
    
    -- Header
    love.graphics.printf("AJUSTES", -250, -150, 500, "center")
    love.graphics.rectangle("fill", -100, -120, 200, 2)
    
    local function option(key, label, value, y, selected)
        love.graphics.setColor(1, 1, 1, a)
        
        -- Heart cursor (Undertale style)
        if selected then
            local pulse = 1 + math.sin(t * 8) * 0.1
            love.graphics.setColor(1, 0, 0, a)
            love.graphics.draw(assets.heart[1], -220, y + 10, 0, 0.4 * pulse, 0.4 * pulse, 32, 32)
            love.graphics.setColor(1, 1, 1, a)
        end
        
        love.graphics.printf(key .. " " .. label, -180, y, 400, "left")
        if value ~= nil then
            love.graphics.printf(value and "ON" or "OFF", 50, y, 150, "right")
        end
    end
    
    option("[1]", "PROCESADOR CRT", useCRT, -50, true)
    option("[R]", "REINICIAR PARTIDA", nil, 10, false)
    option("[ESC]", "SALIR", nil, 70, false)
    
    love.graphics.pop()
    love.graphics.setLineWidth(1)
end




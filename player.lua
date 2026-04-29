local bullet = require("bullet")
local map = require("map")
local juice = require("juice")
local player = {}

local x, y
local speed = 260
local sprite
local dashCooldown = 0
local dashTime = 0
local dashSpeed = 950
local isDashing = false
local dashDirX, dashDirY = 0, 0
local dashCharges = 1
local maxDashCharges = 1
local assets = {}
local fireTimer = 0
local baseFireRate = 0.1
local fireRate = 0.1
local dx, dy = 0, 0 -- Current velocity for smooth feel

-- Permanent Upgrades
local bonusHp = 0
local bonusSpeed = 0
local bonusFire = 0
local bonusDashCD = 0
local bonusBulletSpeed = 0

local shop = require("shop")

-- Health system
local baseMaxHp = 3
local maxHp = 3
local hp = 3
local iFrames = 0
local iFramesDuration = 1.0
local trail = {}
local tilt, scaleX, scaleY = 0, 1, 1

-- Cached upgrade values
local bonusMultiShot = 0
local bonusDamage = 0
local bonusSize = 0
local bonusMagnet = 0
local bonusBounty = 0
local bonusHoming = 0
local bonusCollector = 0
local hasBow = false
local bonusVamp = 0
local bonusRoomHeal = 0

function player.init(a)
    assets = a
    sprite = assets.player
    x = 720
    y = 480
    dashCooldown = 0
    dashTime = 0
    isDashing = false
    maxDashCharges = 1 + (shop and shop.getLevel("extraDash") or 0)
    dashCharges = maxDashCharges
    
    maxHp = baseMaxHp + bonusHp
    hp = maxHp
    
    speed = 400 + bonusSpeed
    fireRate = baseFireRate - bonusFire
    
    iFrames = 0
    trail = {}
    player.triggerEntrance()
end

local entranceTimer = 0
function player.triggerEntrance()
    entranceTimer = 0.35
end

function player.applyPermanentUpgrades()
    bonusHp = shop.getLevel("hp")
    bonusSpeed = shop.getLevel("speed") * 50
    bonusFire = shop.getLevel("fireRate") * 0.005
    bonusDashCD = shop.getLevel("dashCD") * 0.08
    bonusBulletSpeed = shop.getLevel("bulletSpeed") * 80
    
    dashSpeed = 800 + shop.getLevel("dashSpeed") * 100
    iFramesDuration = 1.0 + shop.getLevel("iFrames") * 0.3
    
    bonusMultiShot = shop.getLevel("multiShot")
    bonusDamage = shop.getLevel("bulletDmg")
    bonusSize = shop.getLevel("bulletSize")
    bonusMagnet = shop.getLevel("magnet") * 20
    bonusBounty = shop.getLevel("bounty") * 3
    bonusVamp = shop.getLevel("vampirism") * 0.015
    bonusRoomHeal = shop.getLevel("roomHeal")
    bonusHoming = shop.getLevel("homing")
    bonusCollector = shop.getLevel("collector")
    hasBow = shop.getLevel("bow") > 0
    maxDashCharges = 1 + shop.getLevel("extraDash")
    
    maxHp = baseMaxHp + bonusHp
    speed = 480 + bonusSpeed
    fireRate = math.max(0.04, baseFireRate - bonusFire)
end

function player.heal(amount)
    hp = math.min(maxHp, hp + amount)
end

function player.addMaxHp(amount)
    maxHp = maxHp + amount
end

function player.getMagnetRadius() return 70 + bonusMagnet end
function player.getBounty() return bonusBounty end
function player.getVampChance() return bonusVamp end
function player.getRoomHeal() return bonusRoomHeal end
function player.getMaxHp() return maxHp end
function player.getDashCooldown() return dashCooldown end
function player.getDashCharges() return dashCharges, maxDashCharges end
function player.hasCollector() return bonusCollector > 0 end

function player.update(dt)
    local tx, ty = 0, 0
    if love.keyboard.isDown("a") or love.keyboard.isDown("left") then tx = -1
    elseif love.keyboard.isDown("d") or love.keyboard.isDown("right") then tx = 1 end
    if love.keyboard.isDown("w") or love.keyboard.isDown("up") then ty = -1
    elseif love.keyboard.isDown("s") or love.keyboard.isDown("down") then ty = 1 end

    -- Tight movement with acceleration/damping
    local acc = 28; local dmp = 22
    if tx ~= 0 or ty ~= 0 then
        local len = math.sqrt(tx*tx + ty*ty)
        tx, ty = tx/len, ty/len
        dx = dx + (tx - dx) * acc * dt
        dy = dy + (ty - dy) * acc * dt
    else
        dx = dx - dx * dmp * dt
        dy = dy - dy * dmp * dt
    end
    
    local curSpd = speed + bonusSpeed
    local moveX, moveY = dx * curSpd * dt, dy * curSpd * dt
    local len = math.sqrt(dx*dx + dy*dy)
    
    -- Dash logic
    local currentDashCooldown = math.max(0.15, 0.6 - bonusDashCD)
    
    -- Recharge dashes
    if dashCharges < maxDashCharges then
        dashCooldown = dashCooldown - dt
        if dashCooldown <= 0 then
            dashCharges = dashCharges + 1
            if dashCharges < maxDashCharges then
                dashCooldown = currentDashCooldown
            end
        end
    end
    
    if love.keyboard.isDown("space") and dashCharges > 0 and len > 0.1 and not isDashing and entranceTimer <= 0 then
        isDashing = true
        dashTime = 0.15
        dashCharges = dashCharges - 1
        if dashCooldown <= 0 then dashCooldown = currentDashCooldown end
        dashDirX, dashDirY = dx, dy
        addShake(0.3, 12)
    end
    
    if isDashing then
        moveX = dashDirX * dashSpeed * dt
        moveY = dashDirY * dashSpeed * dt
        dashTime = dashTime - dt
        if dashTime <= 0 then isDashing = false end
    end
    
    -- Collision with walls (check 4 points for better physics)
    local r = 18 -- Precise collision radius for 64x64 sprite
    local function canMove(nx, ny)
        return map.isWalkable(nx-r, ny-r) and map.isWalkable(nx+r, ny-r) and
               map.isWalkable(nx-r, ny+r) and map.isWalkable(nx+r, ny+r)
    end
    
    if canMove(x + moveX, y) then x = x + moveX end
    if canMove(x, y + moveY) then y = y + moveY end
    
    if isDashing then
        table.insert(trail, {x = x, y = y, alpha = 0.5})
    end
    
    for i = #trail, 1, -1 do
        trail[i].alpha = trail[i].alpha - dt * 3
        if trail[i].alpha <= 0 then
            table.remove(trail, i)
        end
    end
    
    if iFrames > 0 then
        iFrames = iFrames - dt
    end
    
    if entranceTimer > 0 then
        entranceTimer = math.max(0, entranceTimer - dt)
    end
end

function player.shoot(angle, slowBullets, rustCurse)
    local curseFireDelay = rustCurse and (fireRate * 1.3) or fireRate
    -- Berserk: faster fire rate when active
    if _G.berserkTimer and _G.berserkTimer > 0 then
        curseFireDelay = curseFireDelay * 0.5
    end
    if fireTimer <= 0.001 then -- Small epsilon to be more forgiving
        local currentBulletSpeed = (hasBow and 750 or 500) + bonusBulletSpeed
        if slowBullets then currentBulletSpeed = currentBulletSpeed * 0.7 end
        local damage = (hasBow and 2.5 or 1) + bonusDamage
        local size = 1 + bonusSize * 0.4
        local bSprite = hasBow and assets.bow or nil
        
        -- Spawn bullet from the hands/body instead of the head
        local spawnY = y + 8
        bullet.spawn(x, spawnY, angle, false, currentBulletSpeed, damage, size, bonusHoming, bSprite, _G.currentBulletType)
        
        -- Juice: Muzzle flash and slight screenshake
        juice.spawnMuzzleFlash(x + math.cos(angle) * 20, spawnY + math.sin(angle) * 20, angle)
        addShake(0.1, 4)
        
        for i = 1, bonusMultiShot do
            bullet.spawn(x, spawnY, angle + (i * 0.15), false, currentBulletSpeed, damage, size, bonusHoming, bSprite, _G.currentBulletType)
            bullet.spawn(x, spawnY, angle - (i * 0.15), false, currentBulletSpeed, damage, size, bonusHoming, bSprite, _G.currentBulletType)
        end
        
        -- Reset timer but don't let it accumulate too much delay if clicking fast
        fireTimer = curseFireDelay
        return true
    end
    return false
end

function player.updateFireTimer(dt)
    if fireTimer > 0 then
        fireTimer = fireTimer - dt
    else
        fireTimer = 0 -- Keep it at 0 so the next shot is instant
    end
end

function player.takeDamage(dmg)
    if iFrames <= 0 and not isDashing then
        hp = hp - (dmg or 1)
        iFrames = iFramesDuration
        addShake(0.5, 20)
        return true
    end
    return false
end

function player.draw()
    local time = love.timer.getTime()
    
    -- Improved animations: Squash and Stretch
    local speedLen = math.sqrt(dx*dx + dy*dy)
    local sX, sY = 1, 1
    local r = dx * 0.15 -- Smooth tilt based on movement
    local bob = 0
    
    if isDashing then
        sX, sY = 1.4, 0.7 -- Softened dash stretch
        r = math.atan2(dashDirY, dashDirX)
    else
        -- Breathing/Idle bob
        local idleSpeed = 6
        local idleAmount = 2
        if speedLen > 0.1 then
            idleSpeed = 22 -- Faster run bob
            idleAmount = 6
            -- Stretch while running (dynamic based on velocity)
            sX = 1 + math.abs(dx) * 0.0005
            sY = 1 - math.abs(dx) * 0.0002
            -- Slight rotation oscillation when running
            r = r + math.sin(time * 20) * 0.12
        end
        bob = math.sin(time * idleSpeed) * idleAmount
        
        -- Shooting recoil (Subtle squash/stretch)
        if fireTimer > 0 then
            local recoil = fireTimer / fireRate
            sX = sX + recoil * 0.1
            sY = sY - recoil * 0.1
            r = r + (math.random() - 0.5) * 0.05
        end
    end
    
    -- Heartbeat pulse when low health (subtle)
    if hp <= 1 then
        local pulse = 1 + math.sin(time * 15) * 0.08
        sX, sY = sX * pulse, sY * pulse
        love.graphics.setColor(1, 0, 0, 0.2) -- Red tint when dying
    end

    -- Dynamic shadow (squashes with animation)
    love.graphics.setColor(0, 0, 0, 0.2)
    local shw = 22 * sX
    local shh = 7 * sY
    love.graphics.ellipse("fill", x, y + 22, shw, shh)
    
    -- Dash ghost trail (Better colors and rotation)
    for i, t in ipairs(trail) do
        love.graphics.setColor(0.2, 0.6, 1.0, t.alpha * 0.4)
        love.graphics.draw(sprite, t.x, t.y, r, sX, sY, 32, 32)
    end

    -- Flashing during i-frames or shooting blink
    if iFrames > 0 then
        if math.floor(time * 25) % 2 == 0 then
            love.graphics.setColor(1, 0.2, 0.2, 0.8) -- Bright damage flash
        else
            love.graphics.setColor(1, 1, 1, 0.2) -- More transparent blink
        end
    elseif fireTimer > 0.04 then
        love.graphics.setColor(1, 1, 0.8) -- Muzzle flash color
    else
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Entrance animation (falling from sky)
    local drawY = y - bob
    if entranceTimer > 0 then
        -- Squash on impact when timer is near zero
        if entranceTimer < 0.2 then
            local impact = entranceTimer / 0.2
            sX = 1.2 - impact * 0.2
            sY = 0.8 + impact * 0.2
            drawY = y
        else
            drawY = y - (entranceTimer * 1200)
            sX = 0.8 + (1 - (entranceTimer/0.35)) * 0.2
            sY = 1.2 - (1 - (entranceTimer/0.35)) * 0.2
            r = entranceTimer * 6
        end
    end

    -- Apply extra juice to drawing
    love.graphics.draw(sprite, x, drawY, r, sX, sY, 32, 32)
    
    -- Enhanced movement particles
    if speedLen > 180 and math.floor(time*20)%3 == 0 then
        juice.spawnExplosion(x + math.random(-15,15), y + 20, 0, 0, "spark")
    end
    
    love.graphics.setColor(1, 1, 1)
end

function player.getHp() return hp end
function player.getPos() return x, y end
function player.setPos(nx, ny) x, y = nx, ny end
function player.isDashing() return isDashing end

return player

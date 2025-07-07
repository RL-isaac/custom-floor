local myMod = RegisterMod("RestartMod", 1)
local frameCounter = 0
local effectiveReadFrameCounter = 0
local isFileRead = false
local report = ""
local deathFrame = 0
local ignoreIf = false
local episodes = 0
local episodeFrameLimit = 420 * 60 -- 10 seconds
local roomsCompleted = {0, 0, 0, 0}
local startFrame = 0
local actions = {-1, -1, -1}
local socket = require("socket")

-- Socket configuration
local client = nil
local SERVER_HOST = "127.0.0.1"
local SERVER_PORT = 12345
local isConnected = false

local lastConnectionAttempt = 0
local connectionRetryDelay = 300 -- Try every 5 seconds (60fps * 5)

local function connectToServer()
    if not isConnected then
        -- Only attempt connection every few seconds
        local currentFrame = Isaac.GetFrameCount()
        if currentFrame - lastConnectionAttempt < connectionRetryDelay then
            return false
        end
        
        lastConnectionAttempt = currentFrame
        client = socket.tcp()
        if client then
            client:settimeout(0) -- Non-blocking
            local result, err = client:connect(SERVER_HOST, SERVER_PORT)
            if result == 1 then
                isConnected = true
                Isaac.DebugString("Connected to server at " .. SERVER_HOST .. ":" .. SERVER_PORT)
                return true
            elseif result == nil and err == "timeout" then
                -- For non-blocking sockets, "timeout" might mean connection in progress
                -- Try a quick check to see if we're actually connected
                client:settimeout(2) -- Very short timeout
                local testResult = client:send("")
                if testResult then
                    isConnected = true
                    Isaac.DebugString("Connected to server (delayed connection)")
                    client:settimeout(0) -- Back to non-blocking
                    return true
                end
                client:settimeout(0) -- Back to non-blocking
            end
            
            -- Only log failures occasionally to reduce spam
            if currentFrame % 1800 == 0 then -- Every 30 seconds
                Isaac.DebugString("Server not available - will retry in 5 seconds")
            end
            client:close()
            client = nil
        end
    end
    return isConnected
end


local function disconnectFromServer()
    if client then
        client:close()
        client = nil
        isConnected = false
        Isaac.DebugString("Disconnected from server")
    end
end

local horizontalMovementMapping = {
    [0] = -1,
    [1] = ButtonAction.ACTION_LEFT,
    [2] = ButtonAction.ACTION_RIGHT
}

local verticalMovementMapping = {
    [0] = -1,
    [1] = ButtonAction.ACTION_UP,
    [2] = ButtonAction.ACTION_DOWN
}

local attackMapping = {
    [0] = -1,
    [1] = ButtonAction.ACTION_SHOOTUP,
    [2] = ButtonAction.ACTION_SHOOTDOWN,
    [3] = ButtonAction.ACTION_SHOOTRIGHT,
    [4] = ButtonAction.ACTION_SHOOTLEFT
}

local function handleNewActions(readActions)
    if #readActions >= 3 then
        for i = 1, #readActions do
            if readActions[i] ~= actions[i] then
                actions[i] = readActions[i]
            end
        end
    end
end

local function serializeDataSimple(data)
    local result = {}
    
    -- 0-11: Player tears (position X, Y, velocity X, Y for up to 3 tears)
    for i = 1, 3 do
        local tear = data.tears[i]
        if tear then
            table.insert(result, tostring(tear[1])) -- position X
            table.insert(result, tostring(tear[2])) -- position Y
            table.insert(result, tostring(tear[3])) -- velocity X
            table.insert(result, tostring(tear[4])) -- velocity Y
        else
            -- If no tear at this position, add 0s
            table.insert(result, "0")
            table.insert(result, "0")
            table.insert(result, "0")
            table.insert(result, "0")
        end
    end
    
    -- 12-23: Enemy bullets (position X, Y, velocity X, Y for up to 3 bullets)
    for i = 1, 3 do
        local bullet = data.b[i]
        if bullet then
            table.insert(result, tostring(bullet[1])) -- position X
            table.insert(result, tostring(bullet[2])) -- position Y
            table.insert(result, tostring(bullet[3])) -- velocity X
            table.insert(result, tostring(bullet[4])) -- velocity Y
        else
            -- If no bullet at this position, add 0s
            table.insert(result, "0")
            table.insert(result, "0")
            table.insert(result, "0")
            table.insert(result, "0")
        end
    end
    
    -- 24-27: Enemy positions (X, Y for up to 2 enemies)
    for i = 1, 2 do
        local enemy = data.e[i]
        if enemy then
            table.insert(result, tostring(enemy[2])) -- position X
            table.insert(result, tostring(enemy[3])) -- position Y
        else
            -- If no enemy at this position, add 0s
            table.insert(result, "0")
            table.insert(result, "0")
        end
    end
    
    -- 28-30: Player (position X, Y, health)
    table.insert(result, tostring(data.p[1])) -- position X
    table.insert(result, tostring(data.p[2])) -- position Y
    table.insert(result, tostring(data.p[3])) -- health
    
    -- 31: Total enemy health
    local totalEnemyHealth = 0
    for i = 1, #data.e do
        totalEnemyHealth = totalEnemyHealth + data.e[i][4]
    end
    table.insert(result, tostring(totalEnemyHealth))
    
    -- 32: Current room ID
    table.insert(result, tostring(data.r[2]))
    
    -- 33-36: Room completion booleans (4 rooms)
    local rooms = data.roomsCompleted or {0, 0, 0, 0}
    while #rooms < 4 do
        table.insert(rooms, 0)
    end
    table.insert(result, tostring(rooms[1]))
    table.insert(result, tostring(rooms[2]))
    table.insert(result, tostring(rooms[3]))
    table.insert(result, tostring(rooms[4]))
    
    -- 37-39: Bullet indices
    table.insert(result, data.b[1] and tostring(data.b[1][5]) or "0") -- First bullet index
    table.insert(result, data.b[2] and tostring(data.b[2][5]) or "0") -- Second bullet index
    table.insert(result, data.b[3] and tostring(data.b[3][5]) or "0") -- Third bullet index
    
    return table.concat(result, "|")
end

-- SEPARATE FUNCTION: Send game state data
local function sendGameState(gameData)
    if not connectToServer() then
        return false
    end
    
    local dataString = serializeDataSimple(gameData)
    local message = "FRAME: " .. frameCounter .. " DATA:" .. dataString .. "\n"
    
    local bytes, err = client:send(message)
    if not bytes then
        Isaac.DebugString("Failed to send data: " .. (err or "unknown error"))
        disconnectFromServer()
        return false
    end
    
    -- Only log successful sends occasionally to reduce spam
    if frameCounter % 60 == 0 then -- Every second
        Isaac.DebugString("Sent frame " .. frameCounter .. " data successfully")
    end
    return true
end

-- SEPARATE FUNCTION: Receive actions from server
local function receiveActions()
    if not isConnected then
        return false
    end
    
    local response, err = client:receive("*l") -- Read line
    if response then
        Isaac.DebugString("Received: " .. response)
        
        -- Parse response (expecting format: "1,2,3")
        local parts = {}
        for part in response:gmatch("[^,]+") do
            table.insert(parts, part)
        end
        
        if #parts >= 3 then
            -- Trim whitespace and convert to numbers
            local num1 = tonumber(parts[1]:match("%S+"))
            local num2 = tonumber(parts[2]:match("%S+"))
            local num3 = tonumber(parts[3]:match("%S+"))
                   
            if num1 and num2 and num3 then
                parts[1] = horizontalMovementMapping[num1] or -1
                parts[2] = verticalMovementMapping[num2] or -1
                parts[3] = attackMapping[num3] or -1
                
                handleNewActions(parts)
                isFileRead = true -- Keep this for compatibility with existing logic
                return true
            end
        end
    elseif err == "timeout" then
        return false  -- Normal timeout, don't disconnect
    elseif err == "closed" then
        Isaac.DebugString("Connection closed by server")
        disconnectFromServer()
        return false
    else
        -- Only disconnect on serious errors, not timeouts
        Isaac.DebugString("Error receiving data: " .. (err or "unknown error"))
        -- Don't immediately disconnect, try a few more times
        return false
    end
end

local function roomComplete()
    local rooms = {97, 110, 109, 122}
    local currentRoom = Game():GetRoom()
    local roomIndex = Game():GetLevel():GetCurrentRoomIndex()
    for i = 1, #rooms do
        if roomIndex == rooms[i] and roomsCompleted[i] == 0 and currentRoom:IsClear() and currentRoom:IsFirstVisit() then
            Isaac.DebugString("Room " .. rooms[i] .. " completed!")
            roomsCompleted[i] = 1
        end
    end
end

local function collectFastData() 
    local player = Isaac.GetPlayer(0)
    local room = Game():GetRoom()

    roomComplete()

    local enemiesData = Isaac.FindByType(EntityType.ENTITY_HORF)
    local tearsData = Isaac.FindByType(EntityType.ENTITY_TEAR)
    local projectileData = Isaac.FindByType(EntityType.ENTITY_PROJECTILE)

    local enemies = {}
    local tears = {}
    local bullets = {}

    for i = 1, #enemiesData do
        local entity = enemiesData[i]
        if entity and entity.Type >= 10 then
            local npc = entity:ToNPC()
            if npc then
                table.insert(enemies, {
                    entity.Type,
                    entity.Position.X,
                    entity.Position.Y,
                    entity.HitPoints
                })
            end
        end
    end

    for i = 1, #tearsData do
        local entity = tearsData[i]
        if entity and entity.Type == EntityType.ENTITY_TEAR then
            local tear = entity:ToTear()
            if tear then
                table.insert(tears, {
                    tear.Position.X,
                    tear.Position.Y,
                    tear.Velocity.X,
                    tear.Velocity.Y,
                    tear.Index
                })
            end
        end
    end

    for i = 1, #projectileData do
        local entity = projectileData[i]
        if entity and entity.Type == EntityType.ENTITY_PROJECTILE then
            local projectile = entity:ToProjectile()
            if projectile then
                table.insert(bullets, {
                    projectile.Position.X,
                    projectile.Position.Y,
                    projectile.Velocity.X,
                    projectile.Velocity.Y,
                    projectile.Index
                })
            end
        end
    end

    return {
        p = {
            player.Position.X,
            player.Position.Y,
            player:GetHearts(),
            player.Size
        },
        e = enemies,
        b = bullets,
        r = {frameCounter, room:GetType()},
        t = Isaac.GetTime(),
        tears = tears,
        roomsCompleted = roomsCompleted
    }    
end

-- Modified to only send data
local function writeDataOptimized()
    if Game():IsPaused() then
        return
    end
    
    local data = collectFastData()
    sendGameState(data)
end

function myMod:PostGameFinished()
    effectiveReadFrameCounter = 0
    episodes = episodes + 1
    if episodes < 100 then
        episodeFrameLimit = 3 * 60
    end
    if episodes >= 100 and episodes < 200 then
        episodeFrameLimit = 4 * 60
    end
    if episodes >= 200 and episodes < 300 then
        episodeFrameLimit = 5 * 60
    end
    if episodes >= 300 and episodes < 400 then
        episodeFrameLimit = 6 * 60
    end
    if episodes >= 400 and episodes < 500 then
        episodeFrameLimit = 8 * 60
    end
    if episodes >= 500 and episodes < 600 then
        episodeFrameLimit = 10 * 60
    end
    if episodes >= 600 and episodes < 700 then
        episodeFrameLimit = 12 * 60
    end
    if episodes >= 700 and episodes < 800 then
        episodeFrameLimit = 14 * 60
    end
    if episodes >= 800 and episodes < 900 then
        episodeFrameLimit = 18 * 60
    end
    if episodes >= 900 and episodes < 1000 then
        episodeFrameLimit = 22 * 60
    end
    if episodes >= 1000 and episodes < 1100 then
        episodeFrameLimit = 26 * 60
    end
    if episodes >= 1100 and episodes < 1200 then
        episodeFrameLimit = 30 * 60
    end
    if episodes >= 1200 and episodes < 1300 then
        episodeFrameLimit = 35 * 60
    end
    if episodes >= 1300 and episodes < 1400 then
        episodeFrameLimit = 40 * 60
    end
    if episodes >= 1400 and episodes < 1500 then
        episodeFrameLimit = 45 * 60
    end
    if episodes >= 1500 then
        episodeFrameLimit = 60 * 60
    end
    
    -- Disconnect before restarting
    -- disconnectFromServer()
    Isaac.ExecuteCommand("restart")
end

function myMod:FrameHandler(entity, inputHook, buttonAction)
    if (inputHook == InputHook.IS_ACTION_TRIGGERED) and (buttonAction == ButtonAction.ACTION_FULLSCREEN) and not Game():IsPaused() then
        report = report .. " se entra al frame handler. "
        frameCounter = frameCounter + 1
        startFrame = startFrame + 1
        
        -- Try to receive actions every frame
        receiveActions()

        -- Send data every 3 frames
        if frameCounter % 3 == 0 then
            writeDataOptimized()
        end

        if (startFrame > episodeFrameLimit) and not ignoreIf then
            Isaac.GetPlayer():AddHearts(-6)
            deathFrame = frameCounter
            ignoreIf = true
        end
        if (frameCounter > deathFrame + 2) and (deathFrame ~= 0) then
            deathFrame = 0
            frameCounter = 0
            ignoreIf = false
            myMod:PostGameFinished()
        end
    end

    -- Check if any action should be triggered
    for i = 1, #actions do
        if actions[i] ~= -1 and (buttonAction == actions[i]) then
            return 1
        end
    end
    
    return nil
end

local function onRender(t)
    if isFileRead then
        isFileRead = false
        effectiveReadFrameCounter = 1 + effectiveReadFrameCounter
    end
end

function myMod:setTimer()
    startFrame = 0
    actions = {-1, -1, -1}
    -- Try to connect when game starts
    connectToServer()
end

myMod:AddCallback(ModCallbacks.MC_POST_GAME_END, myMod.PostGameFinished)
myMod:AddCallback(ModCallbacks.MC_INPUT_ACTION, myMod.FrameHandler)
myMod:AddCallback(ModCallbacks.MC_POST_RENDER, onRender)
myMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, myMod.setTimer)
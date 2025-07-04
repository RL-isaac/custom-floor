local myMod = RegisterMod("RestartMod", 1)
local game = Game()
local frameCounter = 0
local lastLogPos = 0
local movementFrames = 9
local tearFrames = 23

local horizontalMovementMapping = {
    [0] = 0,
    [1] = ButtonAction.LEFT,
    [2] = ButtonAction.RIGHT
}

local verticalMovementMapping = {
    [0] = 0,
    [1] = ButtonAction.UP,
    [2] = ButtonAction.DOWN
}

local attackMapping = {
    [0] = 0,
    [1] = ButtonAction.SHOOT_UP,
    [2] = ButtonAction.SHOOT_DOWN,
    [3] = ButtonAction.SHOOT_RIGHT,
    [4] = ButtonAction.SHOOT_LEFT
}

local actions = {0, 0, 0}

local function handleNewActions(readActions)
    if #readActions >= 3 then
        for i = 1, #readActions do
            if readActions[i] ~= actions[i] then
                actions[i] = readActions[i]
            end
        end
    end
end

local function readFile() -- every frame
    local log = io.open("log.txt", "r")
    if log then
        -- Get current file size
        log:seek("end")
        local fileSize = log:seek()
        
        -- Check if file was truncated or is new
        if fileSize < lastLogPos then
            lastLogPos = 0
        end
        
        -- Only proceed if file has grown
        if fileSize > lastLogPos then
            -- Read only last 10 bytes to get the last line
            local readSize = math.min(10, fileSize)
            local startPos = fileSize - readSize
            
            log:seek("set", startPos)
            local chunk = log:read(readSize)
            
            if chunk then
                -- Extract everything after the last newline
                local lastLine = chunk:match("([^\r\n]*)$")
                
                if lastLine and lastLine ~= "" then
                    local parts = {}
                    for part in lastLine:gmatch("[^,]+") do
                        table.insert(parts, part)
                    end

                    if #parts >= 3 then
                        parts[1] = horizontalMovementMapping[tonumber(parts[1])] or 0
                        parts[2] = verticalMovementMapping[tonumber(parts[2])] or 0
                        parts[3] = attackMapping[tonumber(parts[3])] or 0
                    end
                    handleNewActions(parts)
                end
            end
            
            lastLogPos = fileSize  -- Always update to end
        end
        log:close()
    end
end

function myMod:PostGameFinished()
    Isaac.ExecuteCommand("restart")
    -- delete contents of the file
end

function myMod:FrameHandler(entity, inputHook, buttonAction)
    if (inputHook == InputHook.IS_ACTION_TRIGGERED) and (buttonAction == ButtonAction.FULLSCREEN) and not game.IsPaused() then
        readFile()
        frameCounter = frameCounter + 1
    end

    for i = 1, #actions do
        if actions[i] ~= 0 and (buttonAction == actions[i]) then
            return 1;
        end
    end

    return nil

end

myMod:AddCallback(ModCallbacks.MC_POST_GAME_END , myMod.PostGameFinished)
myMod:AddCallback(ModCallbacks.MC_INPUT_ACTION, myMod.FrameHandler)
local myMod = RegisterMod("RestartMod", 1)
local game = Game()
isInputOn = false
frameCounter = 0
lastLogPos = 0

function myMod:PostGameFinished()
    Isaac.ExecuteCommand("restart")
end

function myMod:ReadInput(entity, inputHook, buttonAction)
    isInputOn = true
    if (inputHook == InputHook.IS_ACTION_TRIGGERED) then
        if (buttonAction == ButtonAction.FULLSCREEN) then
            if not game.IsPaused() then
                frameCounter = frameCounter + 1
                isInputOn = false
            end
        end
    end

    if (isInputOn) then
        if (frameCounter > 8 and frameCounter % 8 == 0) then

        end

    end
end

function readFile()
    local log = io.open("log.txt", "r")
    if log then
        log:seek("set", lastLogPos)
        local line = log:read("*l")
        if line then
            -- Si hay una línea, separarla por comas
            local parts = {}
            for part in line:gmatch("[^,]+") do
                table.insert(parts, part)
            end
        lastLogPos = log:seek()  -- Actualizar la posición del archivo
        log:close()
        end
    end
end



myMod:AddCallback(ModCallbacks.MC_POST_GAME_END , myMod.PostGameFinished)
myMod:AddCallback(ModCallbacks.MC_INPUT_ACTION, myMod.ReadInput)
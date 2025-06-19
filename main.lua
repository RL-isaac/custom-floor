local mod = RegisterMod("Custom Seed Setter", 1)
Isaac.DebugString("Hello, World!");


local player = Isaac.GetPlayer()
local game = Game()
local seeds = game:GetSeeds()

Isaac.DebugString("Seed" .. tostring(seeds))

mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function()
    -- Obtener el jugador actual
    local player = Isaac.GetPlayer(0)
    
    -- Verificar si el jugador tiene un seed personalizado
    if player:GetSeed() == 0 then
        -- Establecer un seed personalizado
        local customSeed = 123456789  -- Cambia este número por el seed que desees
        seeds:SetSeed(customSeed)
        Isaac.DebugString("Custom Seed Set: " .. tostring(customSeed))
    else
        Isaac.DebugString("Player already has a custom seed: " .. tostring(player:GetSeed()))
    end
end)
-- Registrar el callback para cuando inicie el juego
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.OnGameStart)
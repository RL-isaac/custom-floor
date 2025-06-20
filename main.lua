local myMod = RegisterMod("RestartMod", 1)


function myMod:PostGameStarted()
    Isaac.DebugString("[LA MEDIA VOLA] Empezo el juego");
    Isaac.ExecuteCommand("restart") -- Replace with your desired seed
    
end

myMod:AddCallback(ModCallbacks.MC_POST_GAME_END , myMod.PostGameStarted)
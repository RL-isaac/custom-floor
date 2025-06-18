if debug then -- reload mod if luadebug is enabled, fixes luamod
    package.loaded["scripts.stageapi.mod"] = false
end

Isaac.DebugString("=== INICIANDO CONFIGURACION FORZADA ===\n")

-- INTERCEPTAR Y BLOQUEAR COMANDOS GOTO AUTOMÁTICOS
local originalExecuteCommand = Isaac.ExecuteCommand
Isaac.ExecuteCommand = function(cmd)
    if cmd and type(cmd) == "string" then
        if cmd:match("^goto d%.") or cmd:match("^goto s%.") then
            Isaac.DebugString("BLOQUEADO comando automático: " .. cmd .. "\n")
            return "Comando bloqueado para evitar crash"
        end
    end
    
    if originalExecuteCommand then
        return originalExecuteCommand(cmd)
    end
end

Isaac.DebugString("Sistema de bloqueo de comandos goto instalado\n")

require("scripts.stageapi.mod")

if not StageAPI then
    StageAPI = {}
else
    Isaac.DebugString("StageAPI cargado correctamente\n")
end

local loadOrder = include("scripts.stageapi.loadOrder")

if not loadOrder then
    Isaac.DebugString("ERROR: loadOrder es nil\n")
    return
end

StageAPI.Enum = {}

for i, module in ipairs(loadOrder) do
    local success, err = pcall(include, module)
    if not success then
        Isaac.DebugString("ERROR cargando módulo " .. module .. ": " .. tostring(err) .. "\n")
        return
    end
end

StageAPI.LogMinor("Fully Loaded, loading dependent mods.")
StageAPI.MarkLoaded("StageAPI", "2.30", true, true)

StageAPI.Loaded = true
if StageAPI.ToCall then
    for i, fn in ipairs(StageAPI.ToCall) do
        local success, err = pcall(fn)
        if not success then
            Isaac.DebugString("ERROR en callback " .. i .. ": " .. tostring(err) .. "\n")
        end
    end
end

Isaac.DebugString("Definiendo layouts CORRECTOS con todas las propiedades...\n")

-- FUNCIÓN HELPER para crear layouts completos
local function CreateCompleteLayout(name, doors, spawns, variant)
    variant = variant or 0
    
    local layout = StageAPI.CreateEmptyRoomLayout(RoomShape.ROOMSHAPE_1x1)
    
    -- ESTABLECER TODAS LAS PROPIEDADES REQUERIDAS
    layout.Name = name
    layout.Type = RoomType.ROOM_DEFAULT
    layout.Variant = variant
    layout.Subtype = 0
    layout.Shape = RoomShape.ROOMSHAPE_1x1
    layout.WIDTH = 13  -- CRÍTICO: Esta propiedad debe estar en MAYÚSCULAS
    layout.HEIGHT = 7  -- CRÍTICO: Esta propiedad debe estar en MAYÚSCULAS
    layout.Doors = doors
    layout.Spawns = spawns or {}
    layout.Weight = 1.0
    layout.Difficulty = 1
    
    Isaac.DebugString("Layout " .. name .. " creado con WIDTH=" .. layout.WIDTH .. ", HEIGHT=" .. layout.HEIGHT .. "\n")
    return layout
end

-- CREAR LAYOUTS CON TODAS LAS PROPIEDADES
Isaac.DebugString("Creando layout Home...\n")
local homeLayout = CreateCompleteLayout("Home", "1111", {}, 0)

Isaac.DebugString("Creando layout primero...\n")
local primeroLayout = CreateCompleteLayout("primero", "1010", {
    {Type = EntityType.ENTITY_POOTER, Variant = 0, SubType = 0, GridX = 3, GridY = 1},
    {Type = EntityType.ENTITY_POOTER, Variant = 0, SubType = 0, GridX = 9, GridY = 1}
}, 1)

Isaac.DebugString("Creando layout segundo...\n")
local segundoLayout = CreateCompleteLayout("segundo", "0101", {
    {Type = EntityType.ENTITY_POOTER, Variant = 0, SubType = 0, GridX = 8, GridY = 1},
    {Type = EntityType.ENTITY_POOTER, Variant = 0, SubType = 0, GridX = 4, GridY = 5}
}, 2)

Isaac.DebugString("Creando layout tercero...\n")
local terceroLayout = CreateCompleteLayout("tercero", "1111", {
    {Type = EntityType.ENTITY_PICKUP, Variant = PickupVariant.PICKUP_COLLECTIBLE, SubType = 340, GridX = 6, GridY = 3}
}, 3)

Isaac.DebugString("Definiendo Test_rl...\n")

-- Crear Test_rl con el formato correcto
local testRlLayout = StageAPI.CreateEmptyRoomLayout(RoomShape.ROOMSHAPE_1x1)
testRlLayout.Name = "Test_rl"
testRlLayout.Type = RoomType.ROOM_DEFAULT
testRlLayout.Variant = 4
testRlLayout.Subtype = 0
testRlLayout.Shape = RoomShape.ROOMSHAPE_1x1
testRlLayout.WIDTH = 13  -- CRÍTICO: En MAYÚSCULAS
testRlLayout.HEIGHT = 7  -- CRÍTICO: En MAYÚSCULAS
testRlLayout.Doors = "1011"  -- Formato string de puertas
testRlLayout.Spawns = {
    -- Añadir las entidades que quieras en tu room
    {Type = EntityType.ENTITY_GAPER, Variant = 0, SubType = 0, GridX = 6, GridY = 3},
    {Type = EntityType.ENTITY_PICKUP, Variant = PickupVariant.PICKUP_HEART, SubType = 0, GridX = 8, GridY = 3}
}
testRlLayout.Weight = 1.0
testRlLayout.Difficulty = 1

Isaac.DebugString("Registrando layouts individuales...\n")
-- Registrar cada layout individualmente con verificación
local layouts = {
    {name = "Home", layout = homeLayout},
    {name = "primero", layout = primeroLayout},
    {name = "segundo", layout = segundoLayout},
    {name = "tercero", layout = terceroLayout},
    {name = "Test_rl", layout = testRlLayout}
}

for _, layoutData in ipairs(layouts) do
    local success, err = pcall(StageAPI.RegisterLayout, layoutData.name, layoutData.layout)
    if success then
        Isaac.DebugString("Layout " .. layoutData.name .. " registrado correctamente\n")
    else
        Isaac.DebugString("ERROR registrando layout " .. layoutData.name .. ": " .. tostring(err) .. "\n")
        return
    end
end

Isaac.DebugString("Todos los layouts registrados correctamente\n")

Isaac.DebugString("Creando RoomsList con layouts registrados...\n")
-- Crear RoomsList usando los nombres registrados (incluyendo Test_rl)
local rlRoomsListSuccess, rlRoomsList = pcall(StageAPI.RoomsList, "RLFloorRooms", {
    {Name = "Home", Type = RoomType.ROOM_DEFAULT, Weight = 10, Difficulty = 1},
    {Name = "primero", Type = RoomType.ROOM_DEFAULT, Weight = 10, Difficulty = 1},
    {Name = "segundo", Type = RoomType.ROOM_DEFAULT, Weight = 10, Difficulty = 1},
    {Name = "tercero", Type = RoomType.ROOM_DEFAULT, Weight = 10, Difficulty = 1},
    {Name = "Test_rl", Type = RoomType.ROOM_DEFAULT, Weight = 10, Difficulty = 1}
})

if not rlRoomsListSuccess then
    Isaac.DebugString("ERROR creando RoomsList: " .. tostring(rlRoomsList) .. "\n")
    return
end

Isaac.DebugString("RoomsList creado correctamente\n")

-- CREAR CUSTOM STAGE
Isaac.DebugString("Creando CustomStage...\n")
local stageSuccess, rlFloor = pcall(StageAPI.CustomStage, "RLFloor")
if not stageSuccess then
    Isaac.DebugString("ERROR creando CustomStage: " .. tostring(rlFloor) .. "\n")
    return
end

local setRoomsSuccess, setRoomsErr = pcall(function() rlFloor:SetRooms(rlRoomsList) end)
if not setRoomsSuccess then
    Isaac.DebugString("ERROR en SetRooms: " .. tostring(setRoomsErr) .. "\n")
    return
end

local setDisplaySuccess, setDisplayErr = pcall(function() rlFloor:SetDisplayName("RL Training Floor") end)
if not setDisplaySuccess then
    Isaac.DebugString("ERROR en SetDisplayName: " .. tostring(setDisplayErr) .. "\n")
    return
end

-- CONFIGURAR MÚSICA Y BACKDROP
rlFloor:SetMusic(Music.MUSIC_BASEMENT)
rlFloor:SetBackdrop(BackdropType.BASEMENT)

Isaac.DebugString("CustomStage configurado correctamente\n")

-- FORZAR REPLACE USANDO StageOverride
Isaac.DebugString("FORZANDO replace usando StageOverride...\n")
StageAPI.StageOverride.BasementOne = {
    OverrideStage = LevelStage.STAGE1_1,
    OverrideStageType = StageType.STAGETYPE_ORIGINAL,
    ReplaceWith = rlFloor
}

Isaac.DebugString("StageOverride.BasementOne configurado\n")

-- Variables globales
_G.rlFloor = rlFloor
_G.rlRoomsList = rlRoomsList

-- Comando de consola
Isaac.ExecuteCommand = function(cmd)
    if cmd and type(cmd) == "string" then
        if cmd:match("^goto d%.") or cmd:match("^goto s%.") then
            Isaac.DebugString("BLOQUEADO comando automático: " .. cmd .. "\n")
            return "Comando bloqueado para evitar crash"
        end
    end
    
    if cmd == "rlfloor" then
        Isaac.DebugString("COMANDO: Forzando ir al RL Floor...\n")
        StageAPI.GotoCustomStage(rlFloor, true)
        return "Going to RL Floor"
        
    elseif cmd == "testlayouts" then
        Isaac.DebugString("=== VERIFICANDO LAYOUTS ===\n")
        local layoutNames = {"Home", "primero", "segundo", "tercero", "Test_rl"}
        for _, name in ipairs(layoutNames) do
            local layout = StageAPI.GetLayout(name)
            if layout then
                Isaac.DebugString("Layout " .. name .. ": OK (WIDTH=" .. tostring(layout.WIDTH) .. ", HEIGHT=" .. tostring(layout.HEIGHT) .. ", spawns=" .. #layout.Spawns .. ")\n")
            else
                Isaac.DebugString("Layout " .. name .. ": MISSING!\n")
            end
        end
        return "Layout check completed"
        
    elseif cmd == "forcerestart" then
        Isaac.DebugString("COMANDO: Forzando restart con RL Floor...\n")
        if originalExecuteCommand then
            originalExecuteCommand("restart")
        end
        return "Forced restart"
        
    elseif cmd == "gototest" then
        Isaac.DebugString("COMANDO: Yendo directamente al room Test_rl...\n")
        -- Ir a un room específico
        local levelMap = StageAPI.GetDefaultLevelMap()
        local room = StageAPI.LevelRoom{
            LayoutName = "Test_rl",
            RoomType = RoomType.ROOM_DEFAULT,
            Shape = RoomShape.ROOMSHAPE_1x1,
            IsExtraRoom = true
        }
        local addedRoomData = levelMap:AddRoom(room, {RoomID = "Test_rl"}, true)
        StageAPI.ExtraRoomTransition(addedRoomData.MapID, nil, nil, StageAPI.DefaultLevelMapID)
        return "Going to Test_rl room"
    end
    
    if originalExecuteCommand then
        return originalExecuteCommand(cmd)
    end
end

Isaac.DebugString("=== CONFIGURACION COMPLETADA CON TEST_RL INTEGRADO ===\n")
Isaac.DebugString("Layouts incluidos: Home, primero, segundo, tercero, Test_rl\n")
Isaac.DebugString("Comandos disponibles:\n")
Isaac.DebugString("- rlfloor: Ir al RL Floor\n")
Isaac.DebugString("- testlayouts: Verificar layouts registrados\n")
Isaac.DebugString("- forcerestart: Reiniciar con RL Floor\n")
Isaac.DebugString("- gototest: Ir directamente al room Test_rl\n")
Isaac.DebugString("=== LISTO ===\n")
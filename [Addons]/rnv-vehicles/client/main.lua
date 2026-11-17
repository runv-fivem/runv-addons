-- Parking Terminal prompts, lock toggle (L), engine off without a key. Trunks are rnv-inventory's

local props = {}
local promptAt = {} -- terminal id -> placed prop coords

local function notify(text, kind)
    exports['rnv-interface']:Notify({ text = text, type = kind or 'inform', duration = 4000 })
end

-- TERMINALS

local function useTerminal(t)
    if LocalPlayer.state['rnv:rental'] then
        local ok, why = lib.callback.await('rnv-vehicles:park', false, t.id)
        if not ok and why == 'far' then notify('Bring your vehicle to the [[terminal]] first', 'error') end
        if not ok and why == 'trunk' then notify('Empty the [[trunk]] first', 'error') end
    else
        local ok, why = lib.callback.await('rnv-vehicles:rent', false, t.id)
        if not ok and why == 'active' then notify('You already have an [[active vehicle]]', 'error') end
    end
end

local function refreshPrompts()
    local renting = LocalPlayer.state['rnv:rental'] and true or false
    for _, t in ipairs(Config.Terminals) do
        local p = promptAt[t.id] or t.prop
        exports['rnv-interface']:AddPrompt({
            id = 'terminal_' .. t.id,
            coords = vec3(p.x, p.y, p.z + 1.0),
            title = 'PARKING TERMINAL',
            label = renting and 'Park' or 'Rent',
            distance = Config.UseDistance,
            onSelect = function() useTerminal(t) end,
        })
    end
end

AddStateBagChangeHandler('rnv:rental', ('player:%s'):format(GetPlayerServerId(PlayerId())), function()
    Wait(0)
    refreshPrompts()
end)

CreateThread(function()
    local hash = joaat(Config.TerminalProp)
    lib.requestModel(hash)
    for _, t in ipairs(Config.Terminals) do
        local p = t.prop
        local obj = CreateObject(hash, p.x, p.y, p.z, false, false, false)
        SetEntityHeading(obj, p.w)
        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
        props[#props + 1] = obj
        promptAt[t.id] = GetEntityCoords(obj)
    end
    SetModelAsNoLongerNeeded(hash)
    refreshPrompts()
end)

-- LOCKS (doorslockstate state bag)

AddStateBagChangeHandler('doorslockstate', nil, function(bagName, _, value)
    local veh = GetEntityFromStateBagName(bagName)
    if veh ~= 0 then SetVehicleDoorsLocked(veh, value) end
end)

-- A vehicle that streamed in after the change gets its lock when someone tries to enter it
CreateThread(function()
    while true do
        Wait(100)
        local veh = GetVehiclePedIsTryingToEnter(PlayerPedId())
        local state = veh ~= 0 and Entity(veh).state.doorslockstate
        if state and GetVehicleDoorLockStatus(veh) ~= state then
            SetVehicleDoorsLocked(veh, state)
        end
    end
end)

RegisterNetEvent('rnv-vehicles:client:lockChanged', function(locked)
    local ped = PlayerPedId()
    lib.playAnim(ped, 'anim@mp_player_intmenu@key_fob@', 'fob_click', 3.0, 3.0, -1, 49)
    notify(locked and 'Vehicle [[locked]]' or 'Vehicle [[unlocked]]')
    Wait(700)
    ClearPedTasks(ped)
end)

lib.addKeybind({
    name = 'rnv_togglelocks',
    description = 'Lock / unlock your vehicle',
    defaultKey = Config.LockKey,
    onPressed = function()
        local veh = lib.getClosestVehicle(GetEntityCoords(PlayerPedId()), Config.LockDistance, true)
        if veh and Entity(veh).state['rnv:owner'] then
            TriggerServerEvent('rnv-vehicles:server:toggleLock', NetworkGetNetworkIdFromEntity(veh))
        end
    end,
})

-- ENGINE: a rental only runs for someone with its key

CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and Entity(veh).state['rnv:owner'] then
            if lib.callback.await('rnv-vehicles:hasKey', false, NetworkGetNetworkIdFromEntity(veh)) then
                while GetVehiclePedIsIn(ped, false) == veh do Wait(500) end
            else
                while GetVehiclePedIsIn(ped, false) == veh and GetPedInVehicleSeat(veh, -1) == ped do
                    SetVehicleEngineOn(veh, false, true, true)
                    DisableControlAction(0, 71, true) -- accelerate
                    Wait(0)
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, obj in ipairs(props) do DeleteEntity(obj) end
    for _, t in ipairs(Config.Terminals) do exports['rnv-interface']:RemovePrompt('terminal_' .. t.id) end
end)

-- Prison: arrive in the yard, JAIL TIME banner, "EXIT / E Escape" at the toilet, then the city

local inPrison = false
local exitProp = nil

local function leavePrison()
    inPrison = false
    exports['rnv-interface']:RemovePrompt('prison_exit')
    exports['rnv-interface']:SetJailTime(nil)
    if exitProp then DeleteEntity(exitProp) end
    exitProp = nil
end

local function escape()
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end

    TriggerServerEvent('rnv-prison:server:escape')
    Wait(200)
    leavePrison()

    -- First escape goes to the Motel (rnv-world); EscapeTo is the fallback
    if GetResourceState('rnv-world') == 'started' then
        exports['rnv-world']:GoToMotel()
    else
        local ped = PlayerPedId()
        local to = Config.EscapeTo
        SetEntityCoords(ped, to.x, to.y, to.z, false, false, false, false)
        SetEntityHeading(ped, to.w)
    end
    DoScreenFadeIn(500)
end

local function enterPrison(years)
    inPrison = true
    exports['rnv-interface']:SetJailTime(years)

    local e = Config.Exit
    lib.requestModel(Config.ExitProp)
    exitProp = CreateObject(joaat(Config.ExitProp), e.x, e.y, e.z, false, false, false)
    SetEntityHeading(exitProp, e.w)
    PlaceObjectOnGroundProperly(exitProp)
    FreezeEntityPosition(exitProp, true)
    SetModelAsNoLongerNeeded(joaat(Config.ExitProp))

    exports['rnv-interface']:AddPrompt({
        id = 'prison_exit',
        coords = vec3(e.x, e.y, e.z + 0.6),
        title = 'EXIT',
        label = 'Escape',
        distance = 1.5,
        onSelect = escape,
    })
end

---Called by rnv-login when the player enters the world
---Returns the prison spawn if the player still has to escape, otherwise nil
local function admit()
    local status = lib.callback.await('rnv-prison:status', false)
    if not status or status.done then return nil end
    enterPrison(status.years)
    return Config.Spawn
end

exports('Admit', admit)
exports('IsInPrison', function() return inPrison end)

-- Dev: restarting this resource while in prison sets the prison up again (no teleport)
AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if not LocalPlayer.state['rnv:spawned'] then return end
    local status = lib.callback.await('rnv-prison:status', false)
    if status and not status.done then enterPrison(status.years) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and inPrison then leavePrison() end
end)

-- Hold F mask -> Criminal, weapon block for non-armed roles, death -> respawn at the Motel

local function role()
    return LocalPlayer.state['rnv:role'] or 'civilian'
end

local function inCity()
    return LocalPlayer.state['rnv:notoriety'] and true or false
end

-- MASK

local function putMaskOn()
    local ok = exports['rnv-interface']:Progress({
        label = Config.MaskLabel,
        duration = Config.MaskTime,
        cancel = function() return not IsControlPressed(0, Config.MaskKey) end,
    })
    if not ok then return end
    TriggerServerEvent('rnv-combat:server:mask') -- in a party the others are asked first
end

-- The server makes us Criminal (alone, or the whole party): kneel, take the mask out of the bag and put it on,
-- stand up, then draw the weapon in slot 1 (or slot 2 when slot 1 is empty)
RegisterNetEvent('rnv-combat:client:mask', function()
    local ped = PlayerPedId()
    local mask = Config.Mask[GetEntityModel(ped) == joaat('mp_f_freemode_01') and 'mp_f_freemode_01' or 'mp_m_freemode_01']
    local a = Config.MaskAnim
    lib.requestAnimDict(a.dict)
    TaskPlayAnim(ped, a.dict, a.clip, 3.0, 3.0, -1, 1, 0, false, false, false)
    Wait(a.maskAt)
    SetPedComponentVariation(ped, 1, mask.drawable, mask.texture, 0)
    Wait(a.duration - a.maskAt)
    StopAnimTask(ped, a.dict, a.clip, 2.0)
    RemoveAnimDict(a.dict)
    Wait(600)
    local items = exports['rnv-inventory']:GetPlayerItems()
    local slot = items[55] and 55 or items[56] and 56
    if slot then exports['rnv-inventory']:useSlot(slot) end
end)

CreateThread(function()
    while true do
        local wait = 500
        if role() == 'civilian' and inCity() and LocalPlayer.state['rnv:lifeState'] == 'alive' then
            wait = 0
            local ped = PlayerPedId()
            if IsControlPressed(0, Config.MaskKey) and not IsPedInAnyVehicle(ped, true) and GetVehiclePedIsTryingToEnter(ped) == 0 then
                local held = GetGameTimer()
                while IsControlPressed(0, Config.MaskKey) and GetGameTimer() - held < Config.MaskHold do Wait(0) end
                if IsControlPressed(0, Config.MaskKey) and GetVehiclePedIsTryingToEnter(ped) == 0 then
                    putMaskOn()
                end
                while IsControlPressed(0, Config.MaskKey) do Wait(0) end
            end
        end
        Wait(wait)
    end
end)

-- WEAPON BLOCK

local unarmed = joaat('WEAPON_UNARMED')

CreateThread(function()
    while true do
        if Config.Armed[role()] or not LocalPlayer.state['rnv:spawned'] then
            Wait(500)
        else
            local ped = PlayerPedId()
            if GetSelectedPedWeapon(ped) ~= unarmed then
                TriggerEvent('rnv-inventory:disarm', true)
                SetCurrentPedWeapon(ped, unarmed, true)
            end
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 24, true)  -- attack
            DisableControlAction(0, 25, true)  -- aim
            DisableControlAction(0, 37, true)  -- weapon wheel
            DisableControlAction(0, 140, true) -- melee light
            DisableControlAction(0, 141, true) -- melee heavy
            DisableControlAction(0, 142, true) -- melee alternate
            DisableControlAction(0, 257, true) -- attack 2
            DisableControlAction(0, 263, true) -- melee attack 1
            DisableControlAction(0, 264, true) -- melee attack 2
            Wait(0)
        end
    end
end)

-- DEATH + RESPAWN

local function respawn()
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end

    local ped = PlayerPedId()
    local at = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local toMotel = GetResourceState('rnv-world') == 'started'
        and not (GetResourceState('rnv-prison') == 'started' and exports['rnv-prison']:IsInPrison())
    local base = toMotel and GetResourceState('rnv-housing') == 'started' and exports['rnv-housing']:GetRespawn()
    if base then
        toMotel = false
        at, heading = vec3(base.x, base.y, base.z), base.w
    elseif toMotel then
        local m = exports['rnv-world']:GetMotelArrival()
        at, heading = vec3(m.x, m.y, m.z), m.w
    end

    NetworkResurrectLocalPlayer(at.x, at.y, at.z, heading, 0, false)
    ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    SetPedComponentVariation(ped, 1, 0, 0, 0)
    if toMotel then exports['rnv-world']:GoToMotel() end
    TriggerServerEvent('rnv-combat:server:respawned')

    Wait(500)
    DoScreenFadeIn(500)
end

CreateThread(function()
    while true do
        Wait(250)
        if LocalPlayer.state['rnv:spawned'] and IsEntityDead(PlayerPedId()) then
            local killer = GetPedSourceOfDeath(PlayerPedId())
            local killerId = killer ~= 0 and IsPedAPlayer(killer) and GetPlayerServerId(NetworkGetPlayerIndexFromPed(killer)) or nil
            TriggerServerEvent('rnv-combat:server:died', killerId)
            Wait(Config.RespawnTime * 1000)
            respawn()
        end
    end
end)

-- DAMAGE NUMBERS (white number at the hit point, only the shooter sees it)
-- The hurt player measures what it really lost (health + armour) and tells the server who did it
local lastHp = 0
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        lastHp = GetEntityHealth(ped) + GetPedArmour(ped)
        Wait(250)
    end
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local ped = PlayerPedId()
    if args[1] ~= ped then return end
    local now = GetEntityHealth(ped) + GetPedArmour(ped)
    local lost = lastHp - now
    lastHp = now
    local attacker = args[2]
    if lost <= 0 or not attacker or attacker == 0 or attacker == ped or not IsPedAPlayer(attacker) then return end
    TriggerServerEvent('rnv-combat:server:damaged', GetPlayerServerId(NetworkGetPlayerIndexFromPed(attacker)), lost)
end)

RegisterNetEvent('rnv-combat:client:hitNumber', function(victimId, amount)
    local player = GetPlayerFromServerId(victimId)
    if player == -1 then return end
    local pos = GetPedBoneCoords(GetPlayerPed(player), 24818, 0.0, 0.0, 0.0) -- SKEL_Spine3 (chest)
    exports['rnv-interface']:DamageNumber(pos, amount)
end)

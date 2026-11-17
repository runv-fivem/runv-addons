-- Station menu (Join / Go Off Duty), uniform, Q surrender (hands up), cop arrest prompts, Y/N bribe questions

local onDuty = false
local savedLook = nil
local pending = false

local function notify(text, kind)
    exports['rnv-interface']:Notify({ text = text, type = kind or 'error', duration = 4000 })
end

-- UNIFORM

local function wearUniform(on)
    local ped = PlayerPedId()
    if on then
        savedLook = exports['rnv-appearance']:getPedAppearance(ped)
        local model = GetEntityModel(ped) == joaat('mp_f_freemode_01') and 'mp_f_freemode_01' or 'mp_m_freemode_01'
        for component, v in pairs(Config.Uniform[model]) do
            SetPedComponentVariation(ped, component, v[1], v[2], 0)
        end
    elseif savedLook then
        exports['rnv-appearance']:setPedAppearance(ped, savedLook)
        savedLook = nil
    end
end

-- STATION

local function refreshStation()
    local options
    if onDuty then
        options = { { label = 'Go Off Duty', icon = 'card', onSelect = function() lib.callback.await('rnv-police:leave', false) end } }
    else
        options = { { label = 'Join', icon = 'card', onSelect = function()
            local ok, why, who = lib.callback.await('rnv-police:join', false)
            local name = who and ('[[' .. who .. ']] ') or ''
            if not ok and why == 'full' then notify('No free [[police slot]] right now') end
            if not ok and why == 'role' then notify(who and (name .. 'is not a Civilian') or 'Only a [[Civilian]] can join') end
            if not ok and why == 'far' then notify(name .. 'must be at the station') end
            if not ok and why == 'salary' then notify(who and (name .. 'must empty the Salary stash first') or 'Empty your [[Salary]] stash first') end
        end }, { label = 'Salary', icon = 'cash', onSelect = function()
            exports['rnv-inventory']:openInventory('stash', Config.Salary.id)
        end } }
    end
    exports['rnv-interface']:AddPrompt({ id = 'police_station', coords = Config.Duty + vec3(0.0, 0.0, 0.6), title = 'POLICE STATION', distance = Config.UseDistance, options = options })
end

RegisterNetEvent('rnv-police:client:duty', function(state)
    onDuty = state
    wearUniform(state)
    refreshStation()
    notify(state and 'You are now [[on duty]]' or 'You are [[off duty]]', 'inform')
end)

CreateThread(function()
    while not LocalPlayer.state['rnv:spawned'] do Wait(1000) end
    refreshStation()
end)

-- SURRENDER (criminal, Q)

RegisterCommand('rnv_surrender', function()
    if LocalPlayer.state['rnv:role'] == 'criminal' and not LocalPlayer.state['rnv:surrender'] then
        TriggerServerEvent('rnv-police:server:surrender')
    end
end, false)
RegisterKeyMapping('rnv_surrender', 'Surrender to the police', 'keyboard', Config.SurrenderKey)

CreateThread(function()
    while true do
        if LocalPlayer.state['rnv:surrender'] then
            local ped = PlayerPedId()
            if not IsEntityPlayingAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 3) then
                lib.requestAnimDict('missminuteman_1ig_2')
                TaskPlayAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 8.0, 8.0, -1, 49, 0, false, false, false)
            end
            DisableControlAction(0, 21, true)  -- sprint
            DisableControlAction(0, 22, true)  -- jump
            DisableControlAction(0, 24, true)  -- attack
            DisableControlAction(0, 25, true)  -- aim
            DisableControlAction(0, 30, true)  -- move left/right
            DisableControlAction(0, 31, true)  -- move forward/back
            DisableControlAction(0, 23, true)  -- enter vehicle
            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddStateBagChangeHandler('rnv:surrender', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    if not value then ClearPedTasks(PlayerPedId()) end
end)

RegisterNetEvent('rnv-police:client:arrested', function()
    ClearPedTasks(PlayerPedId())
    exports['rnv-world']:GoToMotel()
end)

-- ARREST PROMPTS (cop sees surrendering suspects)

CreateThread(function()
    local shown = {}
    while true do
        Wait(500)
        local now = {}
        if onDuty then
            local myPos = GetEntityCoords(PlayerPedId())
            for _, player in ipairs(GetActivePlayers()) do
                local sid = GetPlayerServerId(player)
                if player ~= PlayerId() and Player(sid).state['rnv:surrender'] then
                    local pos = GetEntityCoords(GetPlayerPed(player))
                    if #(pos - myPos) < 10.0 then
                        now[sid] = true
                        exports['rnv-interface']:AddPrompt({
                            id = 'arrest_' .. sid, coords = pos + vec3(0.0, 0.0, 0.4), title = 'SUSPECT', distance = Config.ArrestRange,
                            options = { { label = 'Arrest', icon = 'card', onSelect = function() TriggerServerEvent('rnv-police:server:arrest', sid) end } },
                        })
                    end
                end
            end
        end
        for sid in pairs(shown) do
            if not now[sid] then exports['rnv-interface']:RemovePrompt('arrest_' .. sid) end
        end
        shown = now
    end
end)

-- Y / N QUESTIONS (bribe offer for the suspect, bribe answer for the cop)

RegisterNetEvent('rnv-police:client:question', function(text)
    pending = true
    exports['rnv-interface']:Notify({
        id = 'police-question', text = text, type = 'warning', duration = Config.AnswerTime * 1000, countdown = Config.AnswerTime,
        keys = { { key = 'Y', label = 'YES' }, { key = 'N', label = 'NO' } },
    })
    SetTimeout(Config.AnswerTime * 1000, function() pending = false end)
end)

local function answer(yes)
    if not pending then return end
    pending = false
    exports['rnv-interface']:RemoveNotify('police-question')
    TriggerServerEvent('rnv-police:server:answer', yes)
end

RegisterCommand('police_yes', function() answer(true) end, false)
RegisterCommand('police_no', function() answer(false) end, false)
RegisterKeyMapping('police_yes', 'Police: answer yes', 'keyboard', 'Y')
RegisterKeyMapping('police_no', 'Police: answer no', 'keyboard', 'N')

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    exports['rnv-interface']:RemovePrompt('police_station')
    if onDuty then wearUniform(false) end
end)

-- RESTOCK: prompt at the back of the own patrol car while on duty
local function ownPatrolCar()
    local me, pos = GetPlayerServerId(PlayerId()), GetEntityCoords(PlayerPedId())
    local best, bestDist = nil, 30.0
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if GetEntityModel(veh) == joaat(Config.CarModel) and Entity(veh).state['rnv:owner'] == me then
            local d = #(GetEntityCoords(veh) - pos)
            if d < bestDist then best, bestDist = veh, d end
        end
    end
    return best
end

local function restock(car)
    local ped = PlayerPedId()
    local a = Config.Restock.anim
    TaskTurnPedToFaceEntity(ped, car, 800)
    Wait(800)
    SetVehicleDoorOpen(car, 5, false, false)
    lib.requestAnimDict(a.dict)
    TaskPlayAnim(ped, a.dict, a.clip, 3.0, 3.0, -1, 1, 0, false, false, false)
    local ok = exports['rnv-interface']:Progress({ label = 'RESTOCKING...', duration = Config.Restock.time, canCancel = true })
    StopAnimTask(ped, a.dict, a.clip, 1.0)
    RemoveAnimDict(a.dict)
    SetVehicleDoorShut(car, 5, false)
    if ok and lib.callback.await('rnv-police:restock', false) then
        local vest = exports['rnv-inventory']:GetVest()
        if vest then SetPedArmour(ped, vest.max) end
        notify('Gear [[restocked]]', 'success')
    end
end

CreateThread(function()
    local shown = false
    while true do
        Wait(1000)
        local car = onDuty and ownPatrolCar()
        if car then
            local rear = GetOffsetFromEntityInWorldCoords(car, 0.0, -2.9, 0.4)
            exports['rnv-interface']:AddPrompt({ id = 'police_restock', coords = rear, title = 'POLICE CAR', label = 'Restock', distance = Config.Restock.distance, onSelect = function() restock(car) end })
            shown = true
        elseif shown then
            exports['rnv-interface']:RemovePrompt('police_restock')
            shown = false
        end
    end
end)

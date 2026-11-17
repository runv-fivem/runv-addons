-- Tutorial state from the server, NPC dialogue (camera on the NPC + subtitle/reply UI). The motel owner lives in rnv-motel

local state = { stage = 1, done = false }
local talking = nil -- { id, step, ped, cam }

local function notifyObjective()
    if state.done or not LocalPlayer.state['rnv:spawned'] then return end
    local s = Config.Tutorial[state.stage]
    if s then
        exports['rnv-interface']:Notify({ text = s.objective, type = 'inform', duration = 9000 })
    end
end

local function hasDialogue(id)
    local d = Config.Dialogues[id]
    local s = Config.Tutorial[state.stage]
    return d ~= nil and s ~= nil and s.fact == d.fact
end

RegisterNetEvent('rnv-missions:client:state', function(s)
    local changed = s.stage ~= state.stage
    state = s
    if changed then notifyObjective() end
end)

-- DIALOGUE

local function showStep()
    local d = Config.Dialogues[talking.id]
    local step = d.steps[talking.step]
    SendNUIMessage({ action = 'line', speaker = d.speaker, line = step.line, reply = step.reply })
end

local function endDialogue(stopped)
    local id = talking.id
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    RenderScriptCams(false, true, 400, true, true)
    DestroyCam(talking.cam, false)
    FreezeEntityPosition(PlayerPedId(), false)
    LocalPlayer.state:set('rnv:screen', false, false)
    DisplayRadar(true)
    talking = nil
    if not stopped then TriggerServerEvent('rnv-missions:server:dialogueDone', id) end
end

local function startDialogue(id, ped)
    if talking or not Config.Dialogues[id] or not ped or not DoesEntityExist(ped) then return end
    local player = PlayerPedId()
    FreezeEntityPosition(player, true)
    TaskTurnPedToFaceEntity(player, ped, 1000)
    LocalPlayer.state:set('rnv:screen', true, false)
    DisplayRadar(false)

    -- Close-up on the NPC
    local from = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.25, 0.65)
    local to = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.0, 0.55)
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', from.x, from.y, from.z, 0.0, 0.0, 0.0, 45.0, true, 2)
    PointCamAtCoord(cam, to.x, to.y, to.z)
    RenderScriptCams(true, true, 400, true, true)

    talking = { id = id, step = 1, ped = ped, cam = cam }
    showStep()
    SetNuiFocus(true, true)
end

local function nextStep()
    if not talking then return end
    local d = Config.Dialogues[talking.id]
    if talking.step < #d.steps then
        talking.step = talking.step + 1
        showStep()
    else
        endDialogue()
    end
end

RegisterNUICallback('next', function(_, cb)
    cb(1)
    nextStep()
end)

-- SETUP

CreateThread(function()
    TriggerServerEvent('rnv-missions:server:request')
end)

-- Show the current objective once the player is in the world
CreateThread(function()
    while not LocalPlayer.state['rnv:spawned'] do Wait(1000) end
    Wait(3000)
    notifyObjective()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if talking then endDialogue(true) end
end)

exports('StartDialogue', startDialogue)
exports('HasDialogue', hasDialogue)
exports('NextDialogue', nextStep) -- tests

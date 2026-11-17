-- Clan screens (intro / creation / search / clan tabs), invite Y/N card, district claim boards

local isOpen = false
local inviteOpen = false

local function result(view, why)
    if view then return { view = view } end
    return { why = why }
end

-- SCREEN

local function open()
    if isOpen then return end
    local view = lib.callback.await('rnv-clans:view', false)
    if not view then return end
    isOpen = true
    LocalPlayer.state:set('rnv:screen', true, false)
    TriggerScreenblurFadeIn(200)
    DisplayRadar(false)
    SendNUIMessage({ action = 'open', view = view })
    SetNuiFocus(true, true)
end

local function close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerScreenblurFadeOut(200)
    DisplayRadar(true)
    LocalPlayer.state:set('rnv:screen', false, false)
end

RegisterNUICallback('close', function(_, cb) cb(1) close() end)

RegisterNUICallback('search', function(data, cb)
    cb(lib.callback.await('rnv-clans:search', false, data.query, data.openOnly, data.language) or {})
end)

RegisterNUICallback('create', function(data, cb)
    cb(result(lib.callback.await('rnv-clans:create', false, data)))
end)

RegisterNUICallback('join', function(data, cb)
    cb(result(lib.callback.await('rnv-clans:join', false, data.id)))
end)

-- one NUI callback for the clan-page actions: { name, a, b }
local actions = { transfer = true, leave = true, kick = true, setRank = true, answerRequest = true, edit = true, invite = true }
RegisterNUICallback('action', function(data, cb)
    if not actions[data.name] then return cb({}) end
    local ok, why = lib.callback.await('rnv-clans:' .. data.name, false, data.a, data.b)
    if data.name == 'invite' then return cb({ ok = ok == true, why = why }) end
    cb(result(ok, why))
end)

-- live refresh while open (timers, members coming online)
CreateThread(function()
    while true do
        Wait(5000)
        if isOpen then
            local view = lib.callback.await('rnv-clans:view', false)
            if view and isOpen then SendNUIMessage({ action = 'update', view = view }) end
        end
    end
end)

exports('Open', open)
exports('Close', close)
exports('SetTab', function(tab) SendNUIMessage({ action = 'tab', tab = tab }) end) -- tests/screenshots

-- INVITE (Y / N like party invites)

RegisterNetEvent('rnv-clans:client:invite', function(text, seconds)
    inviteOpen = true
    exports['rnv-interface']:Notify({
        id = 'clan-invite', text = text, type = 'inform', duration = seconds * 1000, countdown = seconds,
        keys = { { key = 'Y', label = 'ACCEPT' }, { key = 'N', label = 'DECLINE' } },
    })
    SetTimeout(seconds * 1000, function() inviteOpen = false end)
end)

local function answer(yes)
    if not inviteOpen then return end
    inviteOpen = false
    exports['rnv-interface']:RemoveNotify('clan-invite')
    TriggerServerEvent('rnv-clans:server:inviteAnswer', yes)
end

RegisterCommand('clan_accept', function() answer(true) end, false)
RegisterCommand('clan_decline', function() answer(false) end, false)
RegisterKeyMapping('clan_accept', 'Accept clan invite', 'keyboard', 'Y')
RegisterKeyMapping('clan_decline', 'Decline clan invite', 'keyboard', 'N')

-- DISTRICT BOARDS

CreateThread(function()
    while not LocalPlayer.state['rnv:spawned'] do Wait(1000) end
    for id, d in pairs(Config.Districts) do
        exports['rnv-interface']:AddPrompt({
            id = 'district_' .. id, coords = d.board + vec3(0.0, 0.0, 0.6), title = d.label, distance = 2.0,
            options = { { label = 'Claim District', icon = 'card', onSelect = function()
                local ok, why = lib.callback.await('rnv-clans:claim', false, id)
                local text = ok and (why == 'conflict' and 'Conflict for [[' .. d.label .. ']] scheduled' or 'Claim for [[' .. d.label .. ']] started')
                    or (why == 'rank' and 'Only a clan [[Leader]] or [[Officer]] can claim')
                    or (why == 'owned' and 'Your clan already controls [[' .. d.label .. ']]')
                    or (why == 'busy' and 'A claim or conflict is already running here') or nil
                if text then exports['rnv-interface']:Notify({ text = text, type = ok and 'success' or 'error', duration = 5000 }) end
            end } },
        })
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    close()
    for id in pairs(Config.Districts) do exports['rnv-interface']:RemovePrompt('district_' .. id) end
end)

-- House robbery client: furniture + NPCs (local, spawned while the interior is loaded), door locks, prompts (Criminal only),
-- NPC eye meter / hands up / death, alarm siren + countdown banner, police blip

local houses = {}       -- key -> config
local hstate = {}       -- key -> state from the server
local spawned = {}      -- key -> { interior, objs = { [id] = obj }, all = { obj }, peds = { ped }, phones = {}, applied = {}, sent = {} }
local meters = {}       -- key .. i -> 0..1 (how much this NPC has seen of you)
local alarmEnd = {}     -- key -> GetGameTimer() when the alarm reaches the police
local sounds = {}       -- key -> sound id
local busy = false

for _, h in ipairs(Config.Houses) do houses[h.key] = h end

local function isCriminal()
    return LocalPlayer.state['rnv:role'] == 'criminal'
end

local function notify(text)
    exports['rnv-interface']:Notify({ text = text, type = 'error', duration = 4000 })
end

local function loadModel(model)
    local hash = joaat(model)
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
    return hash
end

local function loadDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(0) end
end

-- DOORS (the map leaves these four homes to us)

local function applyDoors(key)
    local h, s = houses[key], hstate[key] or {}
    for _, d in ipairs(h.doors) do
        local hash = joaat(d[1])
        if not IsDoorRegisteredWithSystem(hash) then
            AddDoorToSystem(hash, joaat(d[2]), d[3].x, d[3].y, d[3].z, false, false, false)
        end
        DoorSystemSetDoorState(hash, s.open and 0 or 1, false, true)
    end
end

-- NPC STATE (idle / call / called / hands / dead)

local function dropPhone(sp, i)
    if sp.phones[i] and DoesEntityExist(sp.phones[i]) then DeleteEntity(sp.phones[i]) end
    sp.phones[i] = nil
end

local function applyNpc(key, i)
    local sp, s = spawned[key], hstate[key] or {}
    local ped = sp and sp.peds[i]
    if not ped or not DoesEntityExist(ped) then return end
    local st = s.npcs and s.npcs[i] or 'idle'
    if sp.applied[i] == st then return end
    sp.applied[i] = st
    if st == 'dead' then
        dropPhone(sp, i)
        FreezeEntityPosition(ped, false)
        if not IsEntityDead(ped) then SetEntityHealth(ped, 0) end
    elseif st == 'hands' then
        dropPhone(sp, i)
        exports['rnv-robbase']:HandsUp(ped)
    elseif st == 'call' then
        loadDict('cellphone@')
        TaskPlayAnim(ped, 'cellphone@', 'cellphone_call_listen_base', 8.0, 8.0, -1, 49, 0, false, false, false)
        local phone = CreateObject(loadModel('prop_npc_phone'), 0.0, 0.0, 0.0, false, false, false)
        AttachEntityToEntity(phone, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, false, 2, true)
        sp.phones[i] = phone
    else
        dropPhone(sp, i)
        ClearPedTasks(ped)
    end
end

-- SPAWN / DESPAWN

local function spawnObject(model, p)
    local hash = loadModel(model)
    local obj = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, false)
    SetEntityHeading(obj, p.w or 0.0)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

local function despawn(key)
    local sp = spawned[key]
    if not sp then return end
    for _, obj in ipairs(sp.all) do if DoesEntityExist(obj) then DeleteEntity(obj) end end
    for i, ped in ipairs(sp.peds) do
        dropPhone(sp, i)
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    spawned[key] = nil
end

local function spawn(key, interior)
    local h, s = houses[key], hstate[key] or {}
    local L = Config.Layouts[h.layout]
    local sp = { interior = interior, objs = {}, all = {}, peds = {}, phones = {}, applied = {}, sent = {} }
    spawned[key] = sp
    local function add(obj, id, room)
        sp.all[#sp.all + 1] = obj
        if id then sp.objs[id] = obj end
        if room then ForceRoomForEntity(obj, interior, L.rooms[room]) end   -- else it takes the player's room and may not draw
    end
    add(spawnObject('prop_elecbox_20', HousePoint(h, L.box)))
    add(spawnObject('prop_ld_alarm_01', HousePoint(h, vec4(L.alarm.x, L.alarm.y, L.alarm.z, 0.0))), nil, 'ground')
    for _, it in ipairs(L.items) do
        local taken = it.id and s.taken and s.taken[it.id]
        if it.kind == 'safe' then
            local safe = spawnObject(it.model, HousePoint(h, it.pos))
            add(safe, it.id, it.room or 'ground')
            if taken then exports['rnv-robbase']:ShowSafeOpen(safe) end
        elseif not taken then
            add(spawnObject(it.model, HousePoint(h, it.pos)), it.id, it.room or 'ground')
        end
    end
    for i, n in ipairs(L.npcs) do
        local p = HousePoint(h, n.pos)
        local ped = CreatePed(4, loadModel(n.model), p.x, p.y, p.z, p.w, false, false)
        SetEntityHeading(ped, p.w)
        FreezeEntityPosition(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCanBeTargetted(ped, true)
        SetModelAsNoLongerNeeded(joaat(n.model))
        ForceRoomForEntity(ped, interior, L.rooms[n.room or 'ground'])
        sp.peds[i] = ped
        applyNpc(key, i)
    end
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        for key, h in pairs(houses) do
            local d = #(me - h.origin)
            if d < 50.0 then
                local id = GetInteriorAtCoords(h.origin.x, h.origin.y, h.origin.z + 1.0)
                if id ~= 0 and IsInteriorReady(id) and (not spawned[key] or spawned[key].interior ~= id) then
                    despawn(key)
                    spawn(key, id)
                end
            elseif d > 70.0 and spawned[key] then
                despawn(key)
            end
        end
        Wait(1000)
    end
end)

-- ACTIONS

local labels = { box = 'DISABLING ALARM...', door = 'BREAKING IN...', grab = 'TAKING...' }
local anims = {
    box = { 'mini@repair', 'fixing_a_ped' },
    door = { 'mini@repair', 'fixing_a_ped' },
    grab = { 'anim@heists@ornate_bank@grab_cash', 'grab' },
}

local function act(key, action, id)
    if busy then return end
    local time, why = lib.callback.await('rnv-houserob:start', false, key, action, id)
    if not time then
        if why == 'tool' then notify('You need a [[Mini Drill]]')
        elseif why == 'busy' then notify('Someone is already [[on it]]') end
        return
    end
    busy = true
    local h, sp = houses[key], spawned[key]
    local ok
    if action == 'painting' then
        local p = HousePoint(h, HouseItem(h, id).pos)
        local r = math.rad(p.w)
        local scene = vec3(p.x + 0.48 * math.sin(r), p.y - 0.48 * math.cos(r), p.z)   -- 0.48 m in front of the canvas
        ok = exports['rnv-robbase']:StealPainting({ coords = scene, heading = p.w, entity = sp and sp.objs[id], label = 'STEALING...', canCancel = true })
    elseif action == 'safe' then
        ok = exports['rnv-robbase']:CrackSafe({ entity = sp and sp.objs[id], label = 'DRILLING...', canCancel = true })
    else
        local ped = PlayerPedId()
        local a = anims[action]
        loadDict(a[1])
        TaskPlayAnim(ped, a[1], a[2], 8.0, 8.0, -1, 1, 0, false, false, false)
        ok = exports['rnv-interface']:Progress({ label = labels[action], duration = time, canCancel = true })
        ClearPedTasks(ped)
    end
    busy = false
    if not ok then return TriggerServerEvent('rnv-houserob:server:cancel', key, action, id) end
    local result = lib.callback.await('rnv-houserob:finish', false, key, action, id)
    if type(result) == 'table' and result.stash then exports['rnv-inventory']:openInventory('stash', result.stash) end
end

-- PROMPTS (Criminal only)

local function prompt(id, coords, title, label, fn)
    exports['rnv-interface']:AddPrompt({ id = id, coords = coords, title = title, label = label, distance = Config.UseDistance, onSelect = fn })
end

local function unprompt(id)
    exports['rnv-interface']:RemovePrompt(id)
end

local itemText = { grab = { 'VALUABLES', 'Take' }, painting = { 'PAINTING', 'Steal' }, safe = { 'SAFE', 'Crack' } }

local function refreshPrompts(key)
    local h, s = houses[key], hstate[key] or {}
    local L = Config.Layouts[h.layout]
    local crim = isCriminal()
    local p = 'hr_' .. key .. '_'
    if crim and not s.alarmOff then
        prompt(p .. 'box', HouseWorld(h, L.box.x, L.box.y, L.box.z + 0.2), 'ELECTRIC BOX', 'Disable Alarm', function() act(key, 'box') end)
    else
        unprompt(p .. 'box')
    end
    if crim and not s.open then
        prompt(p .. 'door', HouseWorld(h, L.door.x, L.door.y, 1.1), 'FRONT DOOR', 'Break In', function() act(key, 'door') end)
    else
        unprompt(p .. 'door')
    end
    for _, it in ipairs(L.items) do
        if it.id then
            local taken = s.taken and s.taken[it.id]
            local at = HouseWorld(h, it.pos.x, it.pos.y, it.pos.z + (it.kind == 'safe' and 0.8 or 0.15))
            if crim and s.open and not taken then
                prompt(p .. it.id, at, itemText[it.kind][1], itemText[it.kind][2], function() act(key, it.kind, it.id) end)
            elseif crim and it.kind == 'safe' and taken then
                prompt(p .. it.id, at, 'SAFE', 'Open', function() exports['rnv-inventory']:openInventory('stash', 'houserob_' .. key) end)
            else
                unprompt(p .. it.id)
            end
        end
    end
end

local function refreshAll()
    for key in pairs(houses) do refreshPrompts(key) end
end

-- STATE

local function applyState(key, s)
    local old = hstate[key]
    hstate[key] = s
    alarmEnd[key] = s.alarmLeft and GetGameTimer() + s.alarmLeft or nil
    local sp = spawned[key]
    if old and (old.open or old.alarmOff or next(old.taken or {})) and not s.open and not next(s.taken or {}) then
        despawn(key)    -- the house reset: fresh furniture and NPCs on the next spawn pass
        for i = 1, 4 do meters[key .. i] = nil end
        sp = nil
    end
    if sp then
        for id, taken in pairs(s.taken or {}) do
            local it = HouseItem(houses[key], id)
            local obj = sp.objs[id]
            if taken and obj and DoesEntityExist(obj) then
                if it.kind == 'safe' then exports['rnv-robbase']:ShowSafeOpen(obj) else DeleteEntity(obj); sp.objs[id] = nil end
            end
        end
        for i = 1, #sp.peds do applyNpc(key, i) end
    end
    applyDoors(key)
    refreshPrompts(key)
end

RegisterNetEvent('rnv-houserob:client:house', applyState)

AddStateBagChangeHandler('rnv:role', ('player:%s'):format(GetPlayerServerId(PlayerId())), function()
    Wait(0)
    refreshAll()
end)

CreateThread(function()
    local all = lib.callback.await('rnv-houserob:state', false)
    for key, s in pairs(all or {}) do applyState(key, s) end
end)

-- NPC EYES: a Criminal an idle NPC can see fills its meter in SpotTime; full = it calls the police. Aiming at an
-- idle or calling NPC puts its hands up (a call is stopped). Every frame while a house with NPCs is spawned

CreateThread(function()
    local showing = false
    while true do
        local sleep = 500
        local me, pid = PlayerPedId(), PlayerId()
        local crim = isCriminal() and not IsEntityDead(me)
        local myPos = GetEntityCoords(me)
        local eyes = {}
        local aiming, aimed = false, 0
        if crim and IsPlayerFreeAiming(pid) then aiming, aimed = GetEntityPlayerIsFreeAimingAt(pid) end
        for key, sp in pairs(spawned) do
            local s = hstate[key] or {}
            for i, ped in ipairs(sp.peds) do
                if DoesEntityExist(ped) then
                    sleep = 0
                    local st = s.npcs and s.npcs[i] or 'idle'
                    local mk = key .. i
                    if IsEntityDead(ped) then
                        if st ~= 'dead' and not sp.sent['dead' .. i] then
                            sp.sent['dead' .. i] = true
                            FreezeEntityPosition(ped, false)
                            TriggerServerEvent('rnv-houserob:server:dead', key, i)
                        end
                    elseif crim and (st == 'idle' or st == 'call') then
                        if aiming and aimed == ped and not sp.sent['aim' .. i] then
                            sp.sent['aim' .. i] = true
                            TriggerServerEvent('rnv-houserob:server:aim', key, i)
                        end
                        if st == 'idle' then
                            local sees = #(GetEntityCoords(ped) - myPos) < Config.SpotDistance and HasEntityClearLosToEntityInFront(ped, me)
                            local m = (meters[mk] or 0.0) + (sees and 1.0 or -1.0) * GetFrameTime() * 1000.0 / Config.SpotTime
                            m = math.max(0.0, math.min(1.0, m))
                            meters[mk] = m
                            if m >= 1.0 and not sp.sent['spot' .. i] then
                                sp.sent['spot' .. i] = true
                                TriggerServerEvent('rnv-houserob:server:spotted', key, i)
                            end
                            if m > 0.0 then eyes[#eyes + 1] = { ped = ped, v = m } end
                        else
                            eyes[#eyes + 1] = { ped = ped, v = 1.0, call = true }
                        end
                    else
                        meters[mk] = 0.0
                    end
                end
            end
        end
        if #eyes > 0 then
            local list = {}
            for _, e in ipairs(eyes) do
                local head = GetPedBoneCoords(e.ped, 31086, 0.0, 0.0, 0.0)
                local onScreen, x, y = GetScreenCoordFromWorldCoord(head.x, head.y, head.z + 0.45)
                if onScreen then list[#list + 1] = { x = x, y = y, v = e.v, call = e.call } end
            end
            SendNUIMessage({ action = 'eyes', list = list })
            showing = true
        elseif showing then
            SendNUIMessage({ action = 'eyes', list = {} })
            showing = false
        end
        Wait(sleep)
    end
end)

-- ALARM: siren from the alarm box while it rings; countdown banner for players inside the house

local function inside(h)
    local L = Config.Layouts[h.layout]
    local p = GetEntityCoords(PlayerPedId())
    local r = math.rad(h.heading)
    local dx, dy = p.x - h.origin.x, p.y - h.origin.y
    local lx, ly, lz = dx * math.cos(r) + dy * math.sin(r), -dx * math.sin(r) + dy * math.cos(r), p.z - h.origin.z
    return lx > L.inside.min.x and lx < L.inside.max.x and ly > L.inside.min.y and ly < L.inside.max.y and lz > L.inside.min.z and lz < L.inside.max.z
end

CreateThread(function()
    local shown = nil
    while true do
        local banner = nil
        for key, h in pairs(houses) do
            local s = hstate[key] or {}
            local ring = s.ringing and not s.alarmOff and spawned[key] ~= nil
            if ring and not sounds[key] then
                local a = HouseWorld(h, Config.Layouts[h.layout].alarm.x, Config.Layouts[h.layout].alarm.y, Config.Layouts[h.layout].alarm.z)
                sounds[key] = GetSoundId()
                PlaySoundFromCoord(sounds[key], 'Alarm_Interior', a.x, a.y, a.z, 'DLC_H3_FM_FIB_Raid_Sounds', false, 0, false)
            elseif not ring and sounds[key] then
                StopSound(sounds[key])
                ReleaseSoundId(sounds[key])
                sounds[key] = nil
            end
            local left = alarmEnd[key] and alarmEnd[key] - GetGameTimer()
            if ring and left and left > 0 and inside(h) then banner = math.ceil(left / 1000) end
        end
        if banner ~= shown then
            SendNUIMessage({ action = 'alarm', left = banner, total = Config.AlarmTime })
            shown = banner
        end
        Wait(100)
    end
end)

-- POLICE BLIP

RegisterNetEvent('rnv-houserob:client:blip', function(coords, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 40)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.1)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
    SetTimeout(Config.BlipTime * 1000, function() RemoveBlip(blip) end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for key in pairs(houses) do
        despawn(key)
        unprompt('hr_' .. key .. '_box')
        unprompt('hr_' .. key .. '_door')
        for _, it in ipairs(Config.Layouts[houses[key].layout].items) do
            if it.id then unprompt('hr_' .. key .. '_' .. it.id) end
        end
        if sounds[key] then StopSound(sounds[key]) ReleaseSoundId(sounds[key]) end
    end
end)

-- Store robbery client: clerk (local ped), back door / safe / poster props (spawned while the interior is loaded),
-- prompts (Criminal only), clerk eye meter / hands up / death, police blip

local stores = {}       -- id -> store
local sstate = {}       -- id -> state from the server
local spawned = {}      -- id -> { interior, shopRoom, officeRoom, clerk, phone, applied, sent, door, safe, poster }
local meters = {}       -- id -> 0..1
local busy = false

for _, s in ipairs(Stores) do stores[s.id] = s end

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

-- DOORS: liquor stores lock their own back doors in the door system; 24/7 / LTD get a new door (spawn())

local function applyDoors(id)
    local st, s = stores[id], sstate[id] or {}
    for i, d in ipairs(st.doors or {}) do
        local hash = joaat('rnv_mr_' .. id .. '_' .. i)
        if not IsDoorRegisteredWithSystem(hash) then
            AddDoorToSystem(hash, joaat(d[1]), d[2].x, d[2].y, d[2].z, false, false, false)
        end
        DoorSystemSetDoorState(hash, s.open and 0 or 1, false, true)
    end
    local sp = spawned[id]
    if sp and sp.door and s.open then
        if DoesEntityExist(sp.door) then DeleteEntity(sp.door) end     -- the added door is taken out once broken open
        sp.door = nil
    end
end

-- CLERK STATE (idle / call / called / hands / dead)

local function dropPhone(sp)
    if sp.phone and DoesEntityExist(sp.phone) then DeleteEntity(sp.phone) end
    sp.phone = nil
end

local function applyClerk(id)
    local sp, s = spawned[id], sstate[id] or {}
    local ped = sp and sp.clerk
    if not ped or not DoesEntityExist(ped) then return end
    local st = s.npcs and s.npcs[1] or 'idle'
    if sp.applied == st then return end
    sp.applied = st
    dropPhone(sp)
    if st == 'dead' then
        FreezeEntityPosition(ped, false)
        if not IsEntityDead(ped) then SetEntityHealth(ped, 0) end
    elseif st == 'hands' then
        exports['rnv-robbase']:HandsUp(ped)
    elseif st == 'call' then
        loadDict('cellphone@')
        TaskPlayAnim(ped, 'cellphone@', 'cellphone_call_listen_base', 8.0, 8.0, -1, 49, 0, false, false, false)
        sp.phone = CreateObject(loadModel('prop_npc_phone'), 0.0, 0.0, 0.0, false, false, false)
        AttachEntityToEntity(sp.phone, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, false, 2, true)
    else
        ClearPedTasks(ped)
    end
end

-- SHELF STAGES: a searched spot swaps every staged prop on it (StageModels, e.g. both halves of a back-to-back shelf)
-- to <model>_s2/_s3/_s4 (rnv-storeprops: the same model with fewer items). The vanilla prop is hidden with a model
-- hide; its spot / rotation / room are read once while it still exists
local STAGE_HASH = {}
for _, m in ipairs(StageModels) do STAGE_HASH[m] = joaat(m) end

local function stageOrigins(sp, i, pt)
    if sp.origins[i] then return sp.origins[i] end
    local list = {}
    for m, hash in pairs(STAGE_HASH) do
        local obj = GetClosestObjectOfType(pt.pos.x, pt.pos.y, pt.pos.z, 0.6, hash, false, false, false)
        if obj ~= 0 then
            list[#list + 1] = { model = m, hash = hash, pos = GetEntityCoords(obj), rot = GetEntityRotation(obj, 2), room = GetRoomKeyFromEntity(obj) }
        end
    end
    if #list > 0 then sp.origins[i] = list end
    return list
end

-- FRIDGES: static interior entities (not in the object pool). The first search hides the vanilla fridge and puts the
-- door-less body <model>_sN plus its glass doors (<model>_d<n>, origin on the hinge) in its place; the doors swing
-- open over DOOR_MS and stay open. Later searches only swap the body. A reset brings the vanilla fridge back
local DOOR_MS, DOOR_ANGLE = 700, 100.0

local function fridgePoint(pt, lx, ly, lz)
    local r = math.rad(pt.heading)
    return vec3(pt.pos.x + lx * math.cos(r) - ly * math.sin(r), pt.pos.y + lx * math.sin(r) + ly * math.cos(r), pt.pos.z + lz)
end

local function placeObject(model, at, heading, sp)
    local obj = CreateObjectNoOffset(loadModel(model), at.x, at.y, at.z, false, false, false)
    SetEntityHeading(obj, heading)
    FreezeEntityPosition(obj, true)
    if sp.shopRoom and sp.shopRoom ~= 0 then ForceRoomForEntity(obj, sp.interior, sp.shopRoom) end
    SetModelAsNoLongerNeeded(joaat(model))
    return obj
end

local function swingDoors(doors)
    CreateThread(function()
        local start = GetGameTimer()
        while true do
            local t = math.min(1.0, (GetGameTimer() - start) / DOOR_MS)
            local e = 1 - (1 - t) * (1 - t)     -- ease out
            for _, d in ipairs(doors) do
                if DoesEntityExist(d.obj) then SetEntityHeading(d.obj, d.from + (d.to - d.from) * e) end
            end
            if t >= 1.0 then return end
            Wait(0)
        end
    end)
end

local function applyFridge(sp, i, pt, stage)
    sp.fridges = sp.fridges or {}
    local cur = sp.fridges[i]
    if stage <= 1 then
        if cur then
            for _, obj in ipairs({ cur.body }) do if DoesEntityExist(obj) then DeleteEntity(obj) end end
            for _, d in ipairs(cur.doors) do if DoesEntityExist(d.obj) then DeleteEntity(d.obj) end end
            RemoveModelHide(pt.pos.x, pt.pos.y, pt.pos.z, 0.5, joaat(pt.model), false)
            sp.fridges[i] = nil
        end
        return
    end
    if not IsModelInCdimage(joaat(pt.model .. '_s' .. stage)) then return end
    local animate = false
    if not cur then
        CreateModelHide(pt.pos.x, pt.pos.y, pt.pos.z, 0.5, joaat(pt.model), true)
        cur = { doors = {} }
        sp.fridges[i] = cur
        animate = sp.seen and sp.seen[i] == 1          -- watched it being opened; arriving later = already open
        for _, d in ipairs(FridgeDoors[pt.model] or {}) do
            local to = pt.heading + (d.left and -DOOR_ANGLE or DOOR_ANGLE)
            local obj = placeObject(d.model, fridgePoint(pt, d.hinge.x, d.hinge.y, d.hinge.z), animate and pt.heading or to, sp)
            cur.doors[#cur.doors + 1] = { obj = obj, from = pt.heading, to = to }
        end
        if animate then swingDoors(cur.doors) end
    end
    if cur.stage ~= stage then
        if cur.body and DoesEntityExist(cur.body) then DeleteEntity(cur.body) end
        cur.body = placeObject(pt.model .. '_s' .. stage, pt.pos, pt.heading, sp)
        cur.stage = stage
    end
end

local function clearFridges(id)
    local st, sp = stores[id], spawned[id]
    if not sp or not sp.fridges then return end
    for i in pairs(sp.fridges) do applyFridge(sp, i, st.points[i], 1) end
end

local function applyStages(id)
    local st, sp, s = stores[id], spawned[id], sstate[id] or {}
    if not sp then return end
    sp.stages, sp.origins = sp.stages or {}, sp.origins or {}
    sp.seen = sp.seen or {}
    for i, pt in ipairs(st.points) do
        local stage = (s.stage or {})['point' .. i] or 1
        local cur = sp.stages[i]
        if pt.kind == 'fridge' then
            applyFridge(sp, i, pt, stage)
        elseif (cur and cur.stage or 1) ~= stage then
            for _, obj in ipairs(cur and cur.objs or {}) do
                if DoesEntityExist(obj) then DeleteEntity(obj) end
            end
            sp.stages[i] = nil
            local origins = stageOrigins(sp, i, pt)
            if stage > 1 then
                local objs = {}
                for _, o in ipairs(origins) do
                    local variant = o.model .. '_s' .. stage
                    if IsModelInCdimage(joaat(variant)) then
                        CreateModelHide(o.pos.x, o.pos.y, o.pos.z, 0.3, o.hash, true)
                        local obj = CreateObjectNoOffset(loadModel(variant), o.pos.x, o.pos.y, o.pos.z, false, false, false)
                        SetEntityRotation(obj, o.rot.x, o.rot.y, o.rot.z, 2, true)
                        FreezeEntityPosition(obj, true)
                        if o.room ~= 0 then ForceRoomForEntity(obj, sp.interior, o.room) end
                        SetModelAsNoLongerNeeded(joaat(variant))
                        objs[#objs + 1] = obj
                    end
                end
                sp.stages[i] = { stage = stage, objs = objs }
            else
                for _, o in ipairs(origins) do RemoveModelHide(o.pos.x, o.pos.y, o.pos.z, 0.3, o.hash, false) end
            end
        end
    end
end

local function rememberStages(id)
    local st, sp, s = stores[id], spawned[id], sstate[id] or {}
    if not sp then return end
    sp.seen = sp.seen or {}
    for i in ipairs(st.points) do sp.seen[i] = (s.stage or {})['point' .. i] or 1 end
end

local function clearStages(id)
    clearFridges(id)
    local sp = spawned[id]
    if not sp or not sp.stages then return end
    for i, cur in pairs(sp.stages) do
        for _, obj in ipairs(cur.objs or {}) do
            if DoesEntityExist(obj) then DeleteEntity(obj) end
        end
        for _, o in ipairs(sp.origins[i] or {}) do RemoveModelHide(o.pos.x, o.pos.y, o.pos.z, 0.3, o.hash, false) end
    end
    sp.stages = {}
end

-- SPAWN / DESPAWN

local function spawnObject(model, p, interior, room, door)
    local hash = loadModel(model)
    local obj = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, door == true)   -- door models need doorFlag
    SetEntityHeading(obj, p.w or 0.0)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    if room and room ~= 0 then ForceRoomForEntity(obj, interior, room) end   -- else it takes the player's room and may not draw
    return obj
end

local function despawn(id)
    local sp = spawned[id]
    if not sp then return end
    clearStages(id)
    dropPhone(sp)
    for _, e in ipairs({ sp.clerk, sp.door, sp.safe, sp.poster }) do
        if e and DoesEntityExist(e) then DeleteEntity(e) end
    end
    spawned[id] = nil
end

-- room keys are taken from the store's own props: the till stands on the shop floor, the office PC in the back room
local function roomOf(model, pos)
    local obj = GetClosestObjectOfType(pos.x, pos.y, pos.z, 1.0, joaat(model), false, false, false)
    if obj == 0 then return 0 end
    return GetRoomKeyFromEntity(obj)
end

local function spawn(id, interior)
    local st, s = stores[id], sstate[id] or {}
    local sp = { interior = interior, applied = nil, sent = {} }
    sp.shopRoom = roomOf('prop_till_01', st.tills[1])
    if sp.shopRoom == 0 then sp.shopRoom = roomOf('p_till_01_s', st.tills[1]) end   -- RobTill swaps the till model
    if sp.shopRoom == 0 then return false end
    sp.officeRoom = st.office and (roomOf('prop_dyn_pc', st.office) ~= 0 and roomOf('prop_dyn_pc', st.office) or roomOf('prop_monitor_01a', st.office)) or 0
    spawned[id] = sp
    if st.door and not s.open then sp.door = spawnObject(Config.DoorModel, st.door, interior, sp.shopRoom, true) end
    if st.safe then
        sp.safe = spawnObject(Config.SafeModel, st.safe, interior, sp.officeRoom)
        if s.taken and s.taken.safe then exports['rnv-robbase']:ShowSafeOpen(sp.safe) end
    end
    if st.poster and not (s.taken and s.taken.poster) then sp.poster = spawnObject(Config.PosterModel, st.poster, interior, sp.officeRoom) end
    local c = ClerkSpot(st)
    local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.5, false)
    local ped = CreatePed(4, loadModel(Config.ClerkModel), c.x, c.y, found and gz or c.z, c.w, false, false)
    SetEntityHeading(ped, c.w)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedRandomComponentVariation(ped, 1)
    SetModelAsNoLongerNeeded(joaat(Config.ClerkModel))
    ForceRoomForEntity(ped, interior, sp.shopRoom)
    sp.clerk = ped
    applyClerk(id)
    applyStages(id)
    rememberStages(id)
    return true
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        for id, st in pairs(stores) do
            local d = #(me - st.center)
            if d < 40.0 then
                local int = GetInteriorAtCoords(st.center.x, st.center.y, st.center.z)
                if int ~= 0 and IsInteriorReady(int) and (not spawned[id] or spawned[id].interior ~= int) then
                    despawn(id)
                    spawn(id, int)
                end
            elseif d > 60.0 and spawned[id] then
                despawn(id)
            end
        end
        Wait(1000)
    end
end)

-- ACTIONS

local function act(id, action, idx)
    if busy then return end
    local time, why = lib.callback.await('rnv-marketrob:start', false, id, action, idx)
    if not time then
        if why == 'tool' then notify('You need a [[Mini Drill]]')
        elseif why == 'locked' then notify('Open the [[back door]] first')
        elseif why == 'busy' then notify('Someone is already [[on it]]') end
        return
    end
    busy = true
    local st, sp = stores[id], spawned[id]
    local ped = PlayerPedId()
    local ok
    if action == 'safe' and st.safe then
        ok = exports['rnv-robbase']:CrackSafe({ entity = sp and sp.safe, label = 'DRILLING...', canCancel = true })
    elseif action == 'poster' then
        local p = st.poster
        local r = math.rad(p.w)
        local scene = vec3(p.x + 0.48 * math.sin(r), p.y - 0.48 * math.cos(r), p.z)   -- 0.48 m in front of the canvas
        ok = exports['rnv-robbase']:StealPainting({ coords = scene, heading = p.w, entity = sp and sp.poster, label = 'STEALING...', canCancel = true })
    elseif action == 'till' and idx == 1 and (sstate[id].npcs or {})[1] == 'hands' and sp and sp.clerk and DoesEntityExist(sp.clerk) then
        local till = GetClosestObjectOfType(st.tills[1].x, st.tills[1].y, st.tills[1].z, 1.0, joaat('prop_till_01'), false, false, false)
        ok = exports['rnv-robbase']:RobTill({ ped = sp.clerk, till = till, label = 'EMPTYING TILL...' })
        if sp.clerk and DoesEntityExist(sp.clerk) then
            local c = ClerkSpot(st)
            SetEntityCoords(sp.clerk, c.x, c.y, GetEntityCoords(sp.clerk).z, false, false, false, false)   -- back on the spot, facing the shop
            SetEntityHeading(sp.clerk, c.w)
            FreezeEntityPosition(sp.clerk, true)
            exports['rnv-robbase']:HandsUp(sp.clerk)
        end
    else
        local labels = { till = 'EMPTYING TILL...', door = 'BREAKING IN...', safe = 'DRILLING...' }
        local label = labels[action] or Config.PointText[st.points[idx].kind][3]
        local dict, clip = 'anim@heists@ornate_bank@grab_cash', 'grab'
        if action == 'door' or action == 'safe' then dict, clip = 'mini@repair', 'fixing_a_ped' end
        loadDict(dict)
        TaskPlayAnim(ped, dict, clip, 8.0, 8.0, -1, 1, 0, false, false, false)
        ok = exports['rnv-interface']:Progress({ label = label, duration = time, canCancel = true })
        ClearPedTasks(ped)
    end
    busy = false
    if not ok then return TriggerServerEvent('rnv-marketrob:server:cancel', id, action, idx) end
    local result = lib.callback.await('rnv-marketrob:finish', false, id, action, idx)
    if type(result) == 'table' and result.stash then exports['rnv-inventory']:openInventory('stash', result.stash) end
end

-- PROMPTS (Criminal only)

local function prompt(pid, coords, title, label, fn)
    exports['rnv-interface']:AddPrompt({ id = pid, coords = coords, title = title, label = label, distance = Config.UseDistance, onSelect = fn })
end

local function unprompt(pid)
    exports['rnv-interface']:RemovePrompt(pid)
end

local function refreshPrompts(id)
    local st, s = stores[id], sstate[id] or {}
    local taken = s.taken or {}
    local crim = isCriminal()
    local p = 'mr_' .. id .. '_'
    for i, t in ipairs(st.tills) do
        if crim and not taken['till' .. i] then
            prompt(p .. 'till' .. i, t.xyz + vec3(0.0, 0.0, 0.15), 'REGISTER', 'Rob', function() act(id, 'till', i) end)
        else
            unprompt(p .. 'till' .. i)
        end
    end
    for i, pt in ipairs(st.points) do
        local text = Config.PointText[pt.kind]
        if crim and not taken['point' .. i] then
            prompt(p .. 'point' .. i, pt.pos + vec3(0.0, 0.0, 0.3), text[1], text[2], function() act(id, 'point', i) end)
        else
            unprompt(p .. 'point' .. i)
        end
    end
    local door = BackDoorSpot(st)
    if door and crim and not s.open then
        local at = st.door and vec3(st.door.x - 0.65 * math.cos(math.rad(st.door.w)), st.door.y - 0.65 * math.sin(math.rad(st.door.w)), st.door.z) or door
        prompt(p .. 'door', at, 'BACK DOOR', 'Break In', function() act(id, 'door') end)
    else
        unprompt(p .. 'door')
    end
    local safe = SafeSpot(st)
    if safe and crim and (s.open or not door) then
        if taken.safe then
            prompt(p .. 'safe', safe.xyz + vec3(0.0, 0.0, 0.8), 'SAFE', 'Open', function() exports['rnv-inventory']:openInventory('stash', 'marketrob_' .. id) end)
        else
            prompt(p .. 'safe', safe.xyz + vec3(0.0, 0.0, 0.8), 'SAFE', 'Crack', function() act(id, 'safe') end)
        end
    else
        unprompt(p .. 'safe')
    end
    if st.poster and crim and s.open and not taken.poster then
        prompt(p .. 'poster', st.poster.xyz + vec3(0.0, 0.0, 0.15), 'POSTER', 'Steal', function() act(id, 'poster') end)
    else
        unprompt(p .. 'poster')
    end
end

local function refreshAll()
    for id in pairs(stores) do refreshPrompts(id) end
end

-- STATE

local function applyState(id, s)
    local old = sstate[id]
    sstate[id] = s
    if old and (old.open or next(old.taken or {}) or (old.npcs or {})[1] ~= 'idle') and not s.open and not next(s.taken or {}) and s.npcs[1] == 'idle' then
        despawn(id)         -- the store reset: fresh clerk, door, safe and poster on the next spawn pass
        meters[id] = nil
    end
    local sp = spawned[id]
    if sp then
        if s.taken.poster and sp.poster and DoesEntityExist(sp.poster) then DeleteEntity(sp.poster) sp.poster = nil end
        if s.taken.safe and sp.safe and DoesEntityExist(sp.safe) then exports['rnv-robbase']:ShowSafeOpen(sp.safe) end
        applyClerk(id)
        applyStages(id)
        rememberStages(id)
    end
    applyDoors(id)
    refreshPrompts(id)
end

RegisterNetEvent('rnv-marketrob:client:store', applyState)

AddStateBagChangeHandler('rnv:role', ('player:%s'):format(GetPlayerServerId(PlayerId())), function()
    Wait(0)
    refreshAll()
end)

CreateThread(function()
    local all = lib.callback.await('rnv-marketrob:state', false)
    for id, s in pairs(all or {}) do applyState(id, s) end
end)

-- CLERK EYES: a Criminal the idle clerk can see fills the meter in SpotTime; full = phone call. Aiming at an idle or
-- calling clerk = hands up for good

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
        for id, sp in pairs(spawned) do
            local ped = sp.clerk
            if ped and DoesEntityExist(ped) then
                sleep = 0
                local st = (sstate[id] or {}).npcs and sstate[id].npcs[1] or 'idle'
                if IsEntityDead(ped) then
                    if st ~= 'dead' and not sp.sent.dead then
                        sp.sent.dead = true
                        FreezeEntityPosition(ped, false)
                        TriggerServerEvent('rnv-marketrob:server:dead', id)
                    end
                elseif crim and (st == 'idle' or st == 'call') then
                    if aiming and aimed == ped and not sp.sent.aim then
                        sp.sent.aim = true
                        TriggerServerEvent('rnv-marketrob:server:aim', id)
                    end
                    if st == 'idle' then
                        local sees = #(GetEntityCoords(ped) - myPos) < Config.SpotDistance and HasEntityClearLosToEntityInFront(ped, me)
                        local m = (meters[id] or 0.0) + (sees and 1.0 or -1.0) * GetFrameTime() * 1000.0 / Config.SpotTime
                        m = math.max(0.0, math.min(1.0, m))
                        meters[id] = m
                        if m >= 1.0 and not sp.sent.spot then
                            sp.sent.spot = true
                            TriggerServerEvent('rnv-marketrob:server:spotted', id)
                        end
                        if m > 0.0 then eyes[#eyes + 1] = { ped = ped, v = m } end
                    else
                        eyes[#eyes + 1] = { ped = ped, v = 1.0, call = true }
                    end
                else
                    meters[id] = 0.0
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

-- POLICE BLIP

RegisterNetEvent('rnv-marketrob:client:blip', function(coords, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 52)
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
    for id, st in pairs(stores) do
        despawn(id)
        for i = 1, #st.tills do unprompt('mr_' .. id .. '_till' .. i) end
        for i = 1, #st.points do unprompt('mr_' .. id .. '_point' .. i) end
        for _, k in ipairs({ 'door', 'safe', 'poster' }) do unprompt('mr_' .. id .. '_' .. k) end
    end
end)

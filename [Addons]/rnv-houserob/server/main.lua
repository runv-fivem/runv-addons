-- House robbery: Criminal only. Electric box (alarm off) -> front door (hold E) -> loot. NPCs spot Criminals and call
-- the police unless someone aims at them. The alarm reaches the police AlarmTime s after a break-in unless the box is off

local core = exports['rnv-core']
local inv = exports['rnv-inventory']

local houses = {}   -- key -> config
local state = {}    -- key -> house state

local function newState(h)
    local s = { npcs = {}, taken = {}, busy = {} }
    for i = 1, #Config.Layouts[h.layout].npcs do s.npcs[i] = 'idle' end
    return s
end

for _, h in ipairs(Config.Houses) do
    houses[h.key] = h
    state[h.key] = newState(h)
end

local function publicState(key)
    local s = state[key]
    return {
        open = s.open == true, alarmOff = s.alarmOff == true, ringing = s.ringing == true,
        alarmLeft = s.alarmEnd and math.max(0, s.alarmEnd - GetGameTimer()) or nil,
        npcs = s.npcs, taken = s.taken,
    }
end

local function broadcast(key)
    TriggerClientEvent('rnv-houserob:client:house', -1, key, publicState(key))
end

local function isCriminal(src)
    return core:GetRole(src) == 'criminal'
end

local function near(src, coords, distance)
    return #(GetEntityCoords(GetPlayerPed(src)) - coords) <= distance
end

local function touch(s)
    s.robbedAt = s.robbedAt or os.time()
end

local function points(src, n)
    if GetResourceState('rnv-progression') == 'started' then exports['rnv-progression']:AddNotoriety(src, n or 0) end
end

-- POLICE (one alert per break-in: the call or the alarm, whichever comes first; the location LocationDelay ms later)

local function alertPolice(key, why)
    local s, h = state[key], houses[key]
    if s.alerted then return end
    s.alerted = true
    if GetResourceState('rnv-police') ~= 'started' then return end
    local cops = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if exports['rnv-police']:IsCop(src) then cops[#cops + 1] = src end
    end
    local text = why == 'call' and '911 call: a resident reports a [[break-in]]' or 'House alarm: [[break-in]] reported'
    for _, src in ipairs(cops) do exports['rnv-interface']:Notify(src, { text = text, type = 'warning', duration = 8000 }) end
    SetTimeout(Config.LocationDelay, function()
        local spot = HouseWorld(h, 0.0, 0.0, 0.0)
        for _, src in ipairs(cops) do
            exports['rnv-interface']:Notify(src, { text = 'Location: [[' .. h.label .. ']]', type = 'warning', duration = 8000 })
            TriggerClientEvent('rnv-houserob:client:blip', src, spot, h.label)
        end
    end)
end

-- SAFE (one stash per house, opens only while that safe is cracked)

CreateThread(function()
    for _, h in ipairs(Config.Houses) do
        local safe = HouseItem(h, 'safe')
        inv:RegisterStash('houserob_' .. h.key, 'SAFE', 10, 1000000000, false, nil, HouseWorld(h, safe.pos.x, safe.pos.y, safe.pos.z))
    end
end)

inv:registerHook('openInventory', function(payload)
    local key = payload.inventoryId:match('^houserob_(.+)$')
    return key ~= nil and state[key] ~= nil and state[key].taken.safe == true
end, { inventoryFilter = { '^houserob_' } })

-- LOOT

local function pick(list)
    local total = 0
    for _, l in ipairs(list) do if not l[3] then total = total + l[2] end end
    local r = math.random() * total
    for _, l in ipairs(list) do
        if not l[3] then
            r = r - l[2]
            if r <= 0 then return l[1] end
        end
    end
end

local function give(src, item, count)
    if inv:CanCarryItem(src, item, count) then inv:AddItem(src, item, count) return true end
    exports['rnv-interface']:Notify(src, { text = 'No room in your [[bag]]', type = 'error', duration = 4000 })
    return false
end

-- START / FINISH

local minTime = { box = Config.BoxTime, door = Config.DoorTime, grab = 2000, painting = 10000, safe = 10000 }

local function target(h, action, id)
    local L = Config.Layouts[h.layout]
    if action == 'box' then return HouseWorld(h, L.box.x, L.box.y, L.box.z) end
    if action == 'door' then return HouseWorld(h, L.door.x, L.door.y, L.door.z) end
    local it = HouseItem(h, id)
    return it and it.kind == action and HouseWorld(h, it.pos.x, it.pos.y, it.pos.z)
end

lib.callback.register('rnv-houserob:start', function(src, key, action, id)
    local h, s = houses[key], state[key]
    if not h or not isCriminal(src) then return false end
    local spot = target(h, action, id)
    if not spot or not near(src, spot, 4.0) then return false end
    local slot = action .. (id or '')
    if s.busy[slot] then return false, 'busy' end
    if action == 'box' and s.alarmOff then return false end
    if action == 'door' and s.open then return false end
    if (action == 'grab' or action == 'painting' or action == 'safe') and (not s.open or s.taken[id]) then return false end
    if action == 'safe' and inv:GetItemCount(src, Config.SafeTool) < 1 then return false, 'tool' end
    s.busy[slot] = { src = src, at = GetGameTimer() }
    return minTime[action]
end)

lib.callback.register('rnv-houserob:finish', function(src, key, action, id)
    local h, s = houses[key], state[key]
    if not h then return false end
    local slot = action .. (id or '')
    local b = s.busy[slot]
    s.busy[slot] = nil
    if not b or b.src ~= src or GetGameTimer() - b.at < minTime[action] - 500 then return false end
    if not near(src, target(h, action, id), 4.0) then return false end

    touch(s)
    local result = true
    if action == 'box' then
        s.alarmOff, s.alarmEnd, s.ringing = true, nil, false
    elseif action == 'door' then
        s.open = true
        if not s.alarmOff then s.alarmEnd, s.ringing = GetGameTimer() + Config.AlarmTime * 1000, true end
    elseif action == 'safe' then
        s.taken[id] = true
        local stash = 'houserob_' .. key
        inv:ClearInventory(stash)
        for _, l in ipairs(Config.Loot.safe) do
            if l[3] then inv:AddItem(stash, l[1], math.random(l[3], l[4])) end
        end
        inv:AddItem(stash, pick(Config.Loot.safe), 1)
        result = { stash = stash }
    else
        local it = HouseItem(h, id)
        if not give(src, pick(Config.Loot[it.loot]), 1) then return false end
        s.taken[id] = true
    end
    points(src, Config.Points[action])
    broadcast(key)
    return result
end)

RegisterNetEvent('rnv-houserob:server:cancel', function(key, action, id)
    local s = state[key]
    local b = s and s.busy[action .. (id or '')]
    if b and b.src == source then s.busy[action .. (id or '')] = nil end
end)

-- NPCS

local function npcSpot(key, i)
    local h = houses[key]
    local n = h and Config.Layouts[h.layout].npcs[i]
    return n and HouseWorld(h, n.pos.x, n.pos.y, n.pos.z)
end

RegisterNetEvent('rnv-houserob:server:spotted', function(key, i)
    local src, s, spot = source, state[key], npcSpot(key, i)
    if not spot or not isCriminal(src) or not near(src, spot, Config.SpotDistance + 3.0) then return end
    if s.npcs[i] ~= 'idle' then return end
    touch(s)
    s.npcs[i], s['callEnd' .. i] = 'call', GetGameTimer() + Config.CallTime
    broadcast(key)
end)

RegisterNetEvent('rnv-houserob:server:aim', function(key, i)
    local src, s, spot = source, state[key], npcSpot(key, i)
    if not spot or not isCriminal(src) or not near(src, spot, 25.0) then return end
    if s.npcs[i] ~= 'idle' and s.npcs[i] ~= 'call' then return end
    touch(s)
    s.npcs[i] = 'hands'
    broadcast(key)
end)

RegisterNetEvent('rnv-houserob:server:dead', function(key, i)
    local src, s, spot = source, state[key], npcSpot(key, i)
    if not spot or not near(src, spot, 80.0) or s.npcs[i] == 'dead' then return end
    touch(s)
    s.npcs[i] = 'dead'
    broadcast(key)
end)

-- TICK: finished calls, alarm countdown, reset

CreateThread(function()
    while true do
        Wait(250)
        local now = GetGameTimer()
        for key, s in pairs(state) do
            local changed = false
            for i, st in ipairs(s.npcs) do
                if st == 'call' and now >= s['callEnd' .. i] then
                    s.npcs[i] = 'called'
                    alertPolice(key, 'call')
                    changed = true
                end
            end
            if s.alarmEnd and now >= s.alarmEnd then
                s.alarmEnd = nil
                alertPolice(key, 'alarm')
                changed = true
            end
            if s.robbedAt and os.time() - s.robbedAt >= Config.Reset then
                state[key] = newState(houses[key])
                inv:ClearInventory('houserob_' .. key)
                changed = true
            end
            if changed then broadcast(key) end
        end
    end
end)

-- admin: reset every house now
lib.addCommand('rnv_houserob_reset', { help = 'Reset every robbery house', restricted = 'group.admin' }, function()
    for key in pairs(state) do
        state[key] = newState(houses[key])
        inv:ClearInventory('houserob_' .. key)
        broadcast(key)
    end
end)

lib.callback.register('rnv-houserob:state', function()
    local all = {}
    for key in pairs(state) do all[key] = publicState(key) end
    return all
end)

AddEventHandler('playerDropped', function()
    for _, s in pairs(state) do
        for slot, b in pairs(s.busy) do
            if b.src == source then s.busy[slot] = nil end
        end
    end
end)

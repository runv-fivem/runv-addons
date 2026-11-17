-- Store robbery (24/7, LTD, Rob's Liquor, Binco, Discount, Suburban, Ponsonbys). Criminal only, server memory
-- Tills, shelves and displays on the shop floor; the back door (hold E) leads to the safe and the poster
-- The clerk is the alarm: a Criminal in sight fills the eye meter, then a phone call reaches the police unless
-- someone aims at the clerk (hands up for good; a clerk with hands up empties the till for you)

local core = exports['rnv-core']
local inv = exports['rnv-inventory']

local stores = {}   -- id -> store
local state = {}    -- id -> state

local function newState()
    return { npcs = { 'idle' }, taken = {}, busy = {}, stage = {} }   -- stage: loot point -> 1 full .. 4 empty
end

for _, s in ipairs(Stores) do
    stores[s.id] = s
    state[s.id] = newState()
end

local function publicState(id)
    local s = state[id]
    return { npcs = s.npcs, taken = s.taken, stage = s.stage, open = s.open == true }
end

local function broadcast(id)
    TriggerClientEvent('rnv-marketrob:client:store', -1, id, publicState(id))
end

local function isCriminal(src)
    return core:GetRole(src) == 'criminal'
end

local function near(src, coords, distance)
    return coords ~= nil and #(GetEntityCoords(GetPlayerPed(src)) - coords) <= distance
end

local function touch(s)
    s.robbedAt = s.robbedAt or os.time()
end

-- POLICE (one alert per robbery: the clerk's call; location LocationDelay ms later)

local function alertPolice(id)
    local s, st = state[id], stores[id]
    if s.alerted then return end
    s.alerted = true
    if GetResourceState('rnv-police') ~= 'started' then return end
    local cops = {}
    for _, p in ipairs(GetPlayers()) do
        local src = tonumber(p)
        if exports['rnv-police']:IsCop(src) then cops[#cops + 1] = src end
    end
    for _, src in ipairs(cops) do
        exports['rnv-interface']:Notify(src, { text = '911 call: a clerk reports a [[robbery]]', type = 'warning', duration = 8000 })
    end
    SetTimeout(Config.LocationDelay, function()
        for _, src in ipairs(cops) do
            exports['rnv-interface']:Notify(src, { text = 'Location: [[' .. st.label .. ']]', type = 'warning', duration = 8000 })
            TriggerClientEvent('rnv-marketrob:client:blip', src, st.center, st.label)
        end
    end)
end

-- SAFE STASH (opens only while that store's safe is cracked; stashes open within 10 m of their coords)

CreateThread(function()
    for _, st in ipairs(Stores) do
        local spot = SafeSpot(st)
        if spot then inv:RegisterStash('marketrob_' .. st.id, 'SAFE', 10, 1000000000, false, nil, spot.xyz) end
    end
end)

inv:registerHook('openInventory', function(payload)
    local id = payload.inventoryId:match('^marketrob_(.+)$')
    return id ~= nil and state[id] ~= nil and state[id].taken.safe == true
end, { inventoryFilter = { '^marketrob_' } })

-- LOOT

local function pick(list)
    local total = 0
    for _, l in ipairs(list) do if not l[3] then total = total + l[2] end end
    if total == 0 then return nil end
    local r = math.random() * total
    for _, l in ipairs(list) do
        if not l[3] then
            r = r - l[2]
            if r <= 0 then return l[1] end
        end
    end
end

local function give(src, list)
    local items = {}
    for _, l in ipairs(list) do
        if l[3] then items[#items + 1] = { l[1], math.random(l[3], l[4]) } end
    end
    local one = pick(list)
    if one then items[#items + 1] = { one, 1 } end
    for _, it in ipairs(items) do
        if not inv:CanCarryItem(src, it[1], it[2]) then
            exports['rnv-interface']:Notify(src, { text = 'No room in your [[bag]]', type = 'error', duration = 4000 })
            return false
        end
    end
    for _, it in ipairs(items) do inv:AddItem(src, it[1], it[2]) end
    return true
end

-- TARGETS: action -> world spot, time, whether the back door must be open first

local function spotOf(st, action, idx)
    if action == 'till' then return st.tills[idx] and st.tills[idx].xyz end
    if action == 'point' then return st.points[idx] and st.points[idx].pos end
    if action == 'door' then return BackDoorSpot(st) end
    if action == 'safe' then local s = SafeSpot(st) return s and s.xyz end
    if action == 'poster' then return st.poster and st.poster.xyz end
end

local function slotOf(action, idx)
    if action == 'till' or action == 'point' then return action .. idx end
    return action
end

local function timeOf(st, s, action, idx)
    if action == 'till' then
        return (idx == 1 and s.npcs[1] == 'hands') and Config.Time.clerktill or Config.Time.till
    end
    if action == 'safe' and st.wallsafe then return Config.Time.wallsafe end
    return Config.Time[action]
end

lib.callback.register('rnv-marketrob:start', function(src, id, action, idx)
    local st, s = stores[id], state[id]
    if not st or not isCriminal(src) then return false end
    local spot = spotOf(st, action, idx)
    if not near(src, spot, 4.0) then return false end
    local slot = slotOf(action, idx)
    if s.busy[slot] then return false, 'busy' end
    if action == 'door' then
        if s.open then return false end
    else
        if s.taken[slot] then return false end
        if (action == 'safe' or action == 'poster') and BackDoorSpot(st) and not s.open then return false, 'locked' end
        if action == 'safe' and inv:GetItemCount(src, Config.SafeTool) < 1 then return false, 'tool' end
    end
    local time = timeOf(st, s, action, idx)
    s.busy[slot] = { src = src, at = GetGameTimer(), time = time }
    return time
end)

lib.callback.register('rnv-marketrob:finish', function(src, id, action, idx)
    local st, s = stores[id], state[id]
    if not st then return false end
    local slot = slotOf(action, idx)
    local b = s.busy[slot]
    s.busy[slot] = nil
    if not b or b.src ~= src or GetGameTimer() - b.at < b.time - 500 then return false end
    if not near(src, spotOf(st, action, idx), 4.0) then return false end

    touch(s)
    local result = true
    if action == 'door' then
        s.open = true
    elseif action == 'safe' then
        local stash = 'marketrob_' .. id
        inv:ClearInventory(stash)
        for _, l in ipairs(Config.Loot.safe) do
            if l[3] then inv:AddItem(stash, l[1], math.random(l[3], l[4])) end
        end
        local one = pick(Config.Loot.safe)
        if one then inv:AddItem(stash, one, 1) end
        s.taken.safe = true
        result = { stash = stash }
    else
        local list = action == 'till' and Config.Loot.till or action == 'poster' and Config.Loot.poster or Config.Loot[st.points[idx].kind]
        if not give(src, list) then return false end
        if action == 'point' then
            -- shelves empty a bit per search: 1 full -> 2 -> 3 -> 4 empty (rnv-storeprops models)
            s.stage[slot] = (s.stage[slot] or 1) + 1
            if s.stage[slot] >= Config.PointStages then s.taken[slot] = true end
        else
            s.taken[slot] = true
        end
    end
    if GetResourceState('rnv-progression') == 'started' then
        exports['rnv-progression']:AddNotoriety(src, Config.Points[action] or 0)
    end
    broadcast(id)
    return result
end)

RegisterNetEvent('rnv-marketrob:server:cancel', function(id, action, idx)
    local s = state[id]
    local slot = slotOf(action, idx)
    if s and s.busy[slot] and s.busy[slot].src == source then s.busy[slot] = nil end
end)

-- CLERK

local function clerkSpot(id)
    local st = stores[id]
    return st and ClerkSpot(st).xyz
end

RegisterNetEvent('rnv-marketrob:server:spotted', function(id)
    local src, s, spot = source, state[id], clerkSpot(id)
    if not spot or not isCriminal(src) or not near(src, spot, Config.SpotDistance + 3.0) then return end
    if s.npcs[1] ~= 'idle' then return end
    touch(s)
    s.npcs[1], s.callEnd = 'call', GetGameTimer() + Config.CallTime
    broadcast(id)
end)

RegisterNetEvent('rnv-marketrob:server:aim', function(id)
    local src, s, spot = source, state[id], clerkSpot(id)
    if not spot or not isCriminal(src) or not near(src, spot, 25.0) then return end
    if s.npcs[1] ~= 'idle' and s.npcs[1] ~= 'call' then return end
    touch(s)
    s.npcs[1] = 'hands'
    broadcast(id)
end)

RegisterNetEvent('rnv-marketrob:server:dead', function(id)
    local src, s, spot = source, state[id], clerkSpot(id)
    if not spot or not near(src, spot, 80.0) or s.npcs[1] == 'dead' then return end
    touch(s)
    s.npcs[1] = 'dead'
    broadcast(id)
end)

-- TICK: finished calls, reset

CreateThread(function()
    while true do
        Wait(250)
        local now = GetGameTimer()
        for id, s in pairs(state) do
            local changed = false
            if s.npcs[1] == 'call' and now >= s.callEnd then
                s.npcs[1] = 'called'
                alertPolice(id)
                changed = true
            end
            if s.robbedAt and os.time() - s.robbedAt >= Config.Reset then
                state[id] = newState()
                inv:ClearInventory('marketrob_' .. id)
                changed = true
            end
            if changed then broadcast(id) end
        end
    end
end)

lib.addCommand('rnv_marketrob_reset', { help = 'Reset every robbery store', restricted = 'group.admin' }, function()
    for id in pairs(state) do
        state[id] = newState()
        inv:ClearInventory('marketrob_' .. id)
        broadcast(id)
    end
end)

lib.callback.register('rnv-marketrob:state', function()
    local all = {}
    for id in pairs(state) do all[id] = publicState(id) end
    return all
end)

AddEventHandler('playerDropped', function()
    for _, s in pairs(state) do
        for slot, b in pairs(s.busy) do
            if b.src == source then s.busy[slot] = nil end
        end
    end
end)

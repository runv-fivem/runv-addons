-- Robberies: Criminal only. start (checks + alarm) -> client progress bar -> finish (tool use, loot, Notoriety)
-- Safes / vault / armory put the loot in a container (stash crime_<id>) that opens while the target is open

local core = exports['rnv-core']
local inv = exports['rnv-inventory']

local targets = {}       -- id -> config
local state = {}         -- id -> { robbedAt, open, busy, startedAt }

for _, t in ipairs(Config.Targets) do
    targets[t.id] = t
    state[t.id] = {}
end

local function notifyAll(text, kind)
    for _, src in ipairs(GetPlayers()) do
        exports['rnv-interface']:Notify(tonumber(src), { text = text, type = kind or 'warning', duration = 8000 })
    end
end

local function publicState()
    local list = {}
    for id, s in pairs(state) do
        list[id] = { robbed = s.robbedAt ~= nil, open = s.open == true }
    end
    return { targets = list }
end

local function broadcast()
    TriggerClientEvent('rnv-crime:client:state', -1, publicState())
end

local function near(src, coords, distance)
    return #(GetEntityCoords(GetPlayerPed(src)) - coords) <= (distance or Config.UseDistance + 2.0)
end

local function isCriminal(src)
    return core:GetRole(src) == 'criminal'
end

-- STASHES (one container per target that has one)

CreateThread(function()
    for _, t in ipairs(Config.Targets) do
        if Config.Containers[t.kind] then
            inv:RegisterStash('crime_' .. t.id, t.title, 20, 1000000000, false, nil, t.coords)
        end
    end
end)

inv:registerHook('openInventory', function(payload)
    local id = payload.inventoryId:match('^crime_(.+)$')
    return id ~= nil and state[id] ~= nil and state[id].open == true
end, { inventoryFilter = { '^crime_' } })

-- LOOT

local function roll(loot)
    local out = {}
    for _, l in ipairs(loot or {}) do
        if not l.chance or math.random() < l.chance then
            out[#out + 1] = { item = l.item, count = math.random(l.min, l.max) }
        end
    end
    return out
end

local function giveLoot(src, t)
    local items = roll(t.loot)
    if Config.Containers[t.kind] then
        local stash = 'crime_' .. t.id
        inv:ClearInventory(stash)
        for _, l in ipairs(items) do inv:AddItem(stash, l.item, l.count) end
        return stash
    end
    for _, l in ipairs(items) do
        if inv:CanCarryItem(src, l.item, l.count) then inv:AddItem(src, l.item, l.count) end
    end
end

-- START / FINISH

lib.callback.register('rnv-crime:start', function(src, id)
    local t, s = targets[id], state[id]
    if not t or not isCriminal(src) or not near(src, t.coords) then return false, 'role' end
    if s.robbedAt or s.busy then return false, 'robbed' end
    if t.room and not state[t.room].open then return false, 'locked' end
    if t.tool and inv:GetItemCount(src, t.tool) < 1 then return false, 'tool' end

    s.busy, s.startedAt = src, os.time()
    if t.kind == 'vault' then
        notifyAll('The [[Bank Vault]] is being drilled!', 'error')
    end
    return t.time
end)

lib.callback.register('rnv-crime:finish', function(src, id)
    local t, s = targets[id], state[id]
    if not t or s.busy ~= src then return false end
    s.busy = nil
    if not near(src, t.coords) or os.time() - s.startedAt < math.floor(t.time / 1000) - 1 then return false end
    if t.tool then
        if inv:GetItemCount(src, t.tool) < 1 then return false end
        if t.consume or (t.tool == 'lockpick' and math.random() < Config.LockpickBreak) then
            inv:RemoveItem(src, t.tool, 1)
        end
    end

    s.robbedAt = os.time()
    if t.kind == 'room' or Config.Containers[t.kind] then s.open = true end
    local stash = giveLoot(src, t)
    if GetResourceState('rnv-progression') == 'started' then
        exports['rnv-progression']:AddNotoriety(src, t.points or 0)
    end
    if t.kind == 'vault' then notifyAll('[[Bank Vault]] has been cracked', 'error') end
    broadcast()
    return { stash = stash }
end)

RegisterNetEvent('rnv-crime:server:cancel', function(id)
    local s = state[id]
    if s and s.busy == source then s.busy = nil end
end)

-- REFILL after the cooldown

CreateThread(function()
    while true do
        Wait(30000)
        local changed = false
        for id, s in pairs(state) do
            if s.robbedAt and os.time() - s.robbedAt >= Config.Cooldown then
                state[id] = {}
                if Config.Containers[targets[id].kind] then inv:ClearInventory('crime_' .. id) end
                changed = true
            end
        end
        if changed then broadcast() end
    end
end)

lib.callback.register('rnv-crime:state', function()
    return publicState()
end)

AddEventHandler('playerDropped', function()
    for _, s in pairs(state) do
        if s.busy == source then s.busy = nil end
    end
end)

-- Plots: rent with a Land Plot Title, install structure items, enter the main building (
-- shared GTA interiors, players of other plots concealed, cabinet stash only for whoever entered that plot)

local core = exports['rnv-core']
local inv = exports['rnv-inventory']

local plots = {}    -- id -> { owner = citizenid, main = item, extra = { item, item } }
local entered = {}  -- src -> plot id
local inside = {}   -- plot id -> { src, ... }

local function plotConfig(id)
    for _, p in ipairs(Config.Plots) do
        if p.id == id then return p end
    end
end

-- World position of a layout offset on a plot (same math on the client)
local function plotPoint(p, offset)
    local c = p.center
    local r = math.rad(c.w)
    local x = c.x + offset.x * math.cos(r) - offset.y * math.sin(r)
    local y = c.y + offset.x * math.sin(r) + offset.y * math.cos(r)
    return vec3(x, y, c.z + offset.z)
end

local function near(src, point, distance)
    local pos = GetEntityCoords(GetPlayerPed(src))
    return #(vec2(pos.x, pos.y) - vec2(point.x, point.y)) <= distance
end

local function citizenid(src)
    local player = core:GetPlayer(src)
    return player and player.citizenid
end

local function plotOf(cid)
    for id, data in pairs(plots) do
        if data.owner == cid then return id end
    end
end

local function save(id)
    local d = plots[id]
    MySQL.update.await('UPDATE runv_plots SET main = ?, extra = ? WHERE plot = ?', { d.main, json.encode(d.extra), id })
end

local function broadcast()
    TriggerClientEvent('rnv-housing:client:plots', -1, plots)
end

-- LOAD

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS runv_plots (
        plot VARCHAR(50) NOT NULL PRIMARY KEY,
        citizenid VARCHAR(50) NOT NULL,
        cycle_id INT NOT NULL,
        main VARCHAR(50) NULL,
        extra LONGTEXT NULL
    )]])
    while not GlobalState.rnvCycle do Wait(100) end
    local cycle = GlobalState.rnvCycle
    for _, row in ipairs(MySQL.query.await('SELECT * FROM runv_plots WHERE cycle_id = ?', { cycle }) or {}) do
        plots[row.plot] = { owner = row.citizenid, main = row.main, extra = row.extra and json.decode(row.extra) or {} }
    end
    for _, p in ipairs(Config.Plots) do
        inv:RegisterStash('plot_' .. p.id, Config.Stash.label, Config.Stash.slots, 1000000000, false)
    end
    broadcast()
end)

lib.callback.register('rnv-housing:plots', function()
    return plots
end)

-- RENT

lib.callback.register('rnv-housing:rentInfo', function(src, id)
    local p = plotConfig(id)
    if not p then return false end
    return { name = p.name, free = plots[id] == nil, has = math.min(inv:GetItemCount(src, Config.TitleItem), 1), owns = plotOf(citizenid(src)) ~= nil }
end)

lib.callback.register('rnv-housing:rent', function(src, id)
    local p = plotConfig(id)
    local cid = citizenid(src)
    if not p or not cid or plots[id] or plotOf(cid) then return false end
    if not near(src, plotPoint(p, Config.Layout.sign), Config.UseDistance + 2.0) then return false end
    if not inv:RemoveItem(src, Config.TitleItem, 1) then return false, 'title' end
    MySQL.insert.await('INSERT INTO runv_plots (plot, citizenid, cycle_id, extra) VALUES (?, ?, ?, ?)', { id, cid, GlobalState.rnvCycle, '[]' })
    plots[id] = { owner = cid, extra = {} }
    broadcast()
    return true
end)

-- PLOT PLAN (install a structure item from the bag)

lib.callback.register('rnv-housing:planData', function(src, id)
    local d = plots[id]
    if not d or d.owner ~= citizenid(src) then return false end
    return { mode = 'plot', plot = id, main = d.main, extra = d.extra }
end)

lib.callback.register('rnv-housing:install', function(src, id, slotKey, invSlot)
    local p, d = plotConfig(id), plots[id]
    if not p or not d or d.owner ~= citizenid(src) then return false end
    if not near(src, plotPoint(p, Config.Layout.plan), Config.UseDistance + 2.0) then return false end
    local item = inv:GetSlot(src, invSlot)
    local structure = item and Config.Structures[item.name]
    if not structure then return false end

    if slotKey == 'main' then
        if structure.slot ~= 'main' or d.main then return false end
        d.main = item.name
    else
        local index = tonumber(tostring(slotKey):match('^extra(%d)$'))
        if not index or index > Config.ExtraSlots or structure.slot ~= 'extra' or d.extra[index] then return false end
        for _, other in pairs(d.extra) do
            if other == item.name then return false end -- one of each additional structure
        end
        d.extra[index] = item.name
    end
    inv:RemoveItem(src, item.name, 1, nil, invSlot)
    save(id)
    broadcast()
    return { mode = 'plot', plot = id, main = d.main, extra = d.extra }
end)

-- INTERIOR

local function concealUpdate()
    TriggerClientEvent('rnv-housing:client:conceal', -1, entered)
end

lib.callback.register('rnv-housing:enter', function(src, id)
    local p, d = plotConfig(id), plots[id]
    if not p or not d or not d.main then return false end
    if d.owner ~= citizenid(src) then return false end
    if not near(src, plotPoint(p, Config.Layout.door), Config.UseDistance + 2.0) then return false end
    local interior = Config.Interiors[Config.Structures[d.main].interior]
    entered[src] = id
    inside[id] = inside[id] or {}
    inside[id][#inside[id] + 1] = src
    concealUpdate()
    return { plot = id, interior = interior }
end)

local function exitPlot(src)
    local id = entered[src]
    if not id then return end
    entered[src] = nil
    for i, s in ipairs(inside[id] or {}) do
        if s == src then table.remove(inside[id], i) break end
    end
    concealUpdate()
end

RegisterNetEvent('rnv-housing:server:exit', function()
    exitPlot(source)
end)

AddEventHandler('playerDropped', function()
    exitPlot(source)
end)

-- The cabinet stash opens only for a player inside that plot (openInventory hook)
inv:registerHook('openInventory', function(payload)
    local id = payload.inventoryId:match('^plot_(.+)$')
    return id ~= nil and entered[payload.source] == id
end, { inventoryFilter = { '^plot_' } })

-- RESIDENCE (other systems ask through these)

local function hasResidence(src)
    local id = plotOf(citizenid(src))
    return id ~= nil and plots[id].main ~= nil
end

-- Machines (rnv-production): which structures a plot has and where a layout point is
exports('HasStructure', function(id, item)
    local d = plots[id]
    if not d then return false end
    for _, name in pairs(d.extra or {}) do
        if name == item then return true end
    end
    return false
end)
exports('GetPoint', function(id, key)
    local p = plotConfig(id)
    return p and plotPoint(p, Config.Layout[key])
end)

exports('GetOwner', function(id) return plots[id] and plots[id].owner end)
exports('HasResidence', hasResidence)
exports('GetPlot', function(src) return plotOf(citizenid(src)) end)
exports('IsInside', function(src) return entered[src] end)

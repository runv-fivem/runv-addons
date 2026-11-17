-- Plot machines: Cargo / Contraband Workbench (one job at a time, server time, works offline) and the Grow Table pots
-- State per plot machine in table runv_machines (id = plot:kind, data JSON)

local inv = exports['rnv-inventory']
local housing = exports['rnv-housing']

local machines = {} -- 'plot:kind' -> { readyAt, output = { {item,count} } }  or grow: { pots = { { readyAt } } }

local function save(id)
    MySQL.update.await('INSERT INTO runv_machines (id, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)', { id, json.encode(machines[id]) })
end

CreateThread(function()
    MySQL.query.await('CREATE TABLE IF NOT EXISTS runv_machines (id VARCHAR(80) NOT NULL PRIMARY KEY, data LONGTEXT NOT NULL)')
    for _, row in ipairs(MySQL.query.await('SELECT * FROM runv_machines') or {}) do
        machines[row.id] = json.decode(row.data)
    end
end)

-- The player's own plot, if it has this structure and the player stands at it
local function access(src, structure, at)
    local plot = housing:GetPlot(src)
    if not plot or not housing:HasStructure(plot, structure) then return end
    local point = housing:GetPoint(plot, at)
    local pos = GetEntityCoords(GetPlayerPed(src))
    if not point or #(vec2(pos.x, pos.y) - vec2(point.x, point.y)) > Config.UseDistance + 2.0 then return end
    return plot
end

local function roll(list)
    local out = {}
    for _, o in ipairs(list) do out[#out + 1] = { item = o.item, count = math.random(o.min, o.max) } end
    return out
end

-- STATUS for the client prompts (all machines on the player's plot)

lib.callback.register('rnv-production:status', function(src)
    local plot = housing:GetPlot(src)
    if not plot then return false end
    local now, list = os.time(), {}
    for kind, m in pairs(Config.Machines) do
        if housing:HasStructure(plot, m.structure) then
            local s = machines[plot .. ':' .. kind]
            list[kind] = {
                point = housing:GetPoint(plot, m.at),
                state = not s and 'idle' or (s.readyAt > now and 'busy' or 'ready'),
                left = s and math.max(0, s.readyAt - now) or 0,
                hasInput = inv:GetItemCount(src, m.input) > 0,
            }
        end
    end
    local g = Config.Grow
    if housing:HasStructure(plot, g.structure) then
        list.grow = { point = housing:GetPoint(plot, g.at), hasInput = inv:GetItemCount(src, g.input) > 0 }
    end
    return list
end)

-- WORKBENCHES

lib.callback.register('rnv-production:start', function(src, kind)
    local m = Config.Machines[kind]
    local plot = m and access(src, m.structure, m.at)
    if not plot then return false end
    local id = plot .. ':' .. kind
    if machines[id] then return false end
    if not inv:RemoveItem(src, m.input, 1) then return false, 'input' end
    machines[id] = { readyAt = os.time() + m.time, output = roll(m.output) }
    save(id)
    return true
end)

lib.callback.register('rnv-production:take', function(src, kind)
    local m = Config.Machines[kind]
    local plot = m and access(src, m.structure, m.at)
    if not plot then return false end
    local id = plot .. ':' .. kind
    local s = machines[id]
    if not s or s.readyAt > os.time() then return false end
    for _, o in ipairs(s.output) do
        if not inv:CanCarryItem(src, o.item, o.count) then return false, 'space' end
    end
    for _, o in ipairs(s.output) do inv:AddItem(src, o.item, o.count) end
    machines[id] = nil
    MySQL.update.await('DELETE FROM runv_machines WHERE id = ?', { id })
    return true
end)

-- GROW TABLE

local function growData(plot)
    local g, now = Config.Grow, os.time()
    local s = machines[plot .. ':grow'] or { pots = {} }
    local pots = {}
    for i = 1, g.pots do
        local p = s.pots[i] or s.pots[tostring(i)]
        if not p then
            pots[i] = { state = 'empty' }
        elseif p.readyAt > now then
            pots[i] = { state = 'growing', progress = 1 - (p.readyAt - now) / g.time }
        else
            pots[i] = { state = 'ready', progress = 1 }
        end
    end
    return { mode = 'grow', title = g.title, pots = pots, plant = g.input, product = g.output }
end

lib.callback.register('rnv-production:growData', function(src)
    local plot = access(src, Config.Grow.structure, Config.Grow.at)
    return plot and growData(plot) or false
end)

-- Called by rnv-inventory's marketAction (target 'grow'): { kind = 'plant' | 'take', index }
lib.callback.register('rnv-production:growAction', function(src, data)
    local g = Config.Grow
    local plot = access(src, g.structure, g.at)
    if not plot or type(data) ~= 'table' then return false end
    local id = plot .. ':grow'
    machines[id] = machines[id] or { pots = {} }
    local pots = machines[id].pots
    local index = math.floor(tonumber(data.index) or 0)
    if index < 1 or index > g.pots then return false end
    local key = tostring(index)

    if data.kind == 'plant' then
        if pots[key] or not inv:RemoveItem(src, g.input, 1) then return false end
        pots[key] = { readyAt = os.time() + g.time }
    elseif data.kind == 'take' then
        local p = pots[key]
        if not p or p.readyAt > os.time() or not inv:CanCarryItem(src, g.output, 1) then return false end
        inv:AddItem(src, g.output, 1)
        pots[key] = nil
    else
        return false
    end
    save(id)
    return growData(plot)
end)

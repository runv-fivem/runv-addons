-- Laundering Desk per plot: cash storage -> laundering (server ticks) -> output -> Transfer to My Account (Core bank)
-- Storage, output and bank balance stay three separate numbers

local core = exports['rnv-core']
local inv = exports['rnv-inventory']

local desks = {} -- plot -> { stored, output, running }

local function save(plot)
    local d = desks[plot]
    MySQL.update.await('INSERT INTO runv_desks (plot, cash, output, running) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE cash = VALUES(cash), output = VALUES(output), running = VALUES(running)',
        { plot, d.stored, d.output, d.running and 1 or 0 })
end

local function desk(plot)
    desks[plot] = desks[plot] or { stored = 0, output = 0, running = false }
    return desks[plot]
end

-- The player must be inside their own plot (rnv-housing)
local function myDesk(src)
    if GetResourceState('rnv-housing') ~= 'started' then return end
    local plot = exports['rnv-housing']:IsInside(src)
    if plot and exports['rnv-housing']:GetPlot(src) == plot then return plot end
end

local function bankAccount(src)
    local player = core:GetPlayer(src)
    return player and core:GetAccount('player', player.citizenid, 'bank')
end

local function deskData(src, plot)
    local d = desk(plot)
    local acc = bankAccount(src)
    return { mode = 'desk', stored = d.stored, output = d.output, running = d.running, capacity = Config.Capacity,
        bank = acc and acc.balance or 0, account = acc ~= nil, cash = inv:GetItemCount(src, 'money') }
end

-- LOAD + TICK

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS runv_desks (
        plot VARCHAR(50) NOT NULL PRIMARY KEY,
        cash INT UNSIGNED NOT NULL DEFAULT 0,
        output INT UNSIGNED NOT NULL DEFAULT 0,
        running TINYINT NOT NULL DEFAULT 0
    )]])
    for _, row in ipairs(MySQL.query.await('SELECT * FROM runv_desks') or {}) do
        desks[row.plot] = { stored = row.cash, output = row.output, running = row.running == 1 }
    end

    while true do
        Wait(Config.Tick * 1000)
        for plot, d in pairs(desks) do
            if d.running then
                -- clan districts speed laundering up (rnv-clans, by the desk owner's clan)
                local bonus = 0
                local owner = GetResourceState('rnv-clans') == 'started' and exports['rnv-housing']:GetOwner(plot)
                if owner then bonus = exports['rnv-clans']:GetLaunderBonus(owner) end
                local amount = math.min(math.floor(Config.Step * (1 + bonus / 100)), d.stored)
                d.stored = d.stored - amount
                d.output = d.output + math.floor(amount * Config.Rate)
                if d.stored <= 0 then d.running = false end
                save(plot)
            end
        end
    end
end)

-- ACTIONS (from rnv-inventory's desk panel): { kind, amount, invSlot }

lib.callback.register('rnv-laundering:data', function(src)
    local plot = myDesk(src)
    return plot and deskData(src, plot) or false
end)

lib.callback.register('rnv-laundering:action', function(src, data)
    local plot = myDesk(src)
    if not plot or type(data) ~= 'table' then return false end
    local d = desk(plot)
    local amount = math.floor(tonumber(data.amount) or 0)

    if data.kind == 'deposit' then
        -- the whole money stack the player dragged onto the desk, up to the free space
        local item = inv:GetSlot(src, tonumber(data.invSlot) or 0)
        if not item or item.name ~= 'money' then return false end
        amount = math.min(item.count, Config.Capacity - d.stored)
        if amount <= 0 or not inv:RemoveItem(src, 'money', amount, nil, item.slot) then return false end
        d.stored = d.stored + amount
    elseif data.kind == 'take' then
        if amount <= 0 or amount > d.stored or d.running then return false end
        if not inv:CanCarryItem(src, 'money', amount) then return false end
        d.stored = d.stored - amount
        inv:AddItem(src, 'money', amount)
    elseif data.kind == 'start' then
        if d.stored <= 0 or not bankAccount(src) then return false end
        d.running = true
    elseif data.kind == 'stop' then
        d.running = false
    elseif data.kind == 'transfer' then
        local acc = bankAccount(src)
        if not acc or d.output <= 0 then return false end
        local ok = core:AddMoney(acc.id, d.output, 'laundering:' .. plot)
        if not ok then return false end
        if GetResourceState('rnv-clans') == 'started' then exports['rnv-clans']:AddTax(src, d.output) end
        d.output = 0
    else
        return false
    end
    save(plot)
    return deskData(src, plot)
end)

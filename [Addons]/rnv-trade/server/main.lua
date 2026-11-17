-- Fence (loot container + SELL) and Smuggler's Van (cargo + MAKE DEAL). Proceeds are a physical CASH PILE on the
-- vendor's counter that anyone nearby can take (take it fast, it can be stolen)

local inv = exports['rnv-inventory']

local piles = {}   -- id -> { coords, amount }
local nextPile = 1

local function near(src, point)
    local pos = GetEntityCoords(GetPlayerPed(src))
    return #(pos - vec3(point.x, point.y, point.z)) <= Config.UseDistance + 2.0
end

local function bonus(src, kind)
    if GetResourceState('rnv-progression') ~= 'started' then return 0 end
    local b = exports['rnv-progression']:GetBonus(src)
    return b and b[kind] or 0
end

local function addPile(counter, amount)
    local id = nextPile
    nextPile = nextPile + 1
    piles[id] = { coords = vec3(counter.x, counter.y, counter.z), amount = amount }
    TriggerClientEvent('rnv-trade:client:piles', -1, piles)
end

-- PRICES from the item data (rnv.sell)
CreateThread(function()
    for name, item in pairs(inv:Items()) do
        local r = item.rnv
        if r and r.sell then
            if name ~= 'money' then Config.Loot[name] = r.sell end -- the Fence buys anything with a sell price
            if r.type == 'Cargo Sheet' and name:find('_full$') then Config.Cargo[name] = r.sell end
        end
    end
end)

-- FENCE

CreateThread(function()
    inv:RegisterStash('fence', 'FENCE', Config.FenceSlots, 1000000000, false) -- shared: everyone at the van sees it
end)

local function fenceCost()
    local total = 0
    for _, item in pairs(inv:GetInventoryItems('fence') or {}) do
        total = total + (Config.Loot[item.name] or 0) * item.count
    end
    return total
end

local function growth(cost)
    return math.min(Config.FenceBonus.max, math.floor(cost / Config.FenceBonus.per))
end

local function fenceData(src, sold)
    return { mode = 'fence', values = Config.Loot, bonus = bonus(src, 'fence'), per = Config.FenceBonus.per, max = Config.FenceBonus.max, sold = sold }
end

-- Only loot goes into the Fence container
inv:registerHook('swapItems', function(payload)
    if payload.toInventory == payload.fromInventory or payload.toType ~= 'stash' then return true end
    return Config.Loot[payload.fromSlot.name] ~= nil
end, { inventoryFilter = { '^fence' } })

lib.callback.register('rnv-trade:fenceData', function(src)
    if not near(src, Config.Fence.prompt) then return false end
    return fenceData(src)
end)

local function sellFence(src)
    if not near(src, Config.Fence.prompt) then return false end
    local cost = fenceCost()
    if cost <= 0 then return false end
    local total = math.floor(cost * (1 + (bonus(src, 'fence') + growth(cost)) / 100))
    inv:ClearInventory('fence')
    addPile(Config.Fence.counter, total)
    return fenceData(src, total)
end

-- SMUGGLER

local function cargoInBag(src)
    local list, cost = {}, 0
    for _, item in pairs(inv:GetInventoryItems(src) or {}) do
        local price = Config.Cargo[item.name]
        if price then
            list[#list + 1] = item
            cost = cost + price * item.count
        end
    end
    return list, cost
end

local function smugglerData(src)
    local _, cost = cargoInBag(src)
    local pct = bonus(src, 'cargo')
    local extra = math.floor(cost * pct / 100)
    return { mode = 'smuggler', cost = cost, pct = pct, bonus = extra, total = cost + extra }
end

lib.callback.register('rnv-trade:smugglerData', function(src)
    if not near(src, Config.Smuggler.prompt) then return false end
    return smugglerData(src)
end)

local function sellCargo(src)
    if not near(src, Config.Smuggler.prompt) then return false end
    local list, cost = cargoInBag(src)
    if cost <= 0 then return false end
    local total = cost + math.floor(cost * bonus(src, 'cargo') / 100)
    for _, item in ipairs(list) do
        inv:RemoveItem(src, item.name, item.count, nil, item.slot)
    end
    addPile(Config.Smuggler.counter, total)
    return smugglerData(src)
end

-- Called by rnv-inventory's marketAction (target 'trade'): { kind = 'fence' | 'smuggler' }
lib.callback.register('rnv-trade:action', function(src, data)
    if type(data) ~= 'table' then return false end
    if data.kind == 'fence' then return sellFence(src) end
    if data.kind == 'smuggler' then return sellCargo(src) end
    return false
end)

-- CASH PILES (first player to finish collecting gets it)

lib.callback.register('rnv-trade:piles', function()
    return piles
end)

lib.callback.register('rnv-trade:take', function(src, id)
    local pile = piles[id]
    if not pile or #(GetEntityCoords(GetPlayerPed(src)) - pile.coords) > Config.UseDistance + 2.0 then return false end
    local taken = 0
    while pile.amount > 0 do
        local chunk = math.min(Config.CashBundle, pile.amount)
        if not inv:CanCarryItem(src, 'money', chunk) or not inv:AddItem(src, 'money', chunk) then break end
        pile.amount = pile.amount - chunk
        taken = taken + chunk
        Wait(150) -- one pickup card per bundle
    end
    if pile.amount <= 0 then piles[id] = nil end
    TriggerClientEvent('rnv-trade:client:piles', -1, piles)
    if taken == 0 then return false, 'space' end
    return taken, pile.amount > 0 and 'space' or nil
end)

-- Sale value of an item (Fence loot or Smuggler cargo), used by rnv-police for confiscation pay
exports('GetValue', function(name)
    return Config.Loot[name] or Config.Cargo[name] or 0
end)

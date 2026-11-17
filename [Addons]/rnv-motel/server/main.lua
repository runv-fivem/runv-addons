-- Cash Stash (rnv-inventory stash, money only) and paying the motel owner's debt from the bank

local core = exports['rnv-core']
local inv = exports['rnv-inventory']
local owner = vec3(Config.Owner.coords.x, Config.Owner.coords.y, Config.Owner.coords.z)

local function nearOwner(src)
    return #(GetEntityCoords(GetPlayerPed(src)) - owner) <= Config.UseDistance + 2.0
end

local function bankAccount(src)
    local player = core:GetPlayer(src)
    return player and core:GetAccount('player', player.citizenid, 'bank')
end

-- CASH STASH

CreateThread(function()
    local s = Config.Stash
    inv:RegisterStash(s.id, s.label, s.slots, 1000000000, true)
end)

-- Only money goes in, and never more than the capacity
inv:registerHook('swapItems', function(payload)
    if payload.toInventory == payload.fromInventory or payload.toType ~= 'stash' then return true end
    if payload.fromSlot.name ~= 'money' then return false end
    local stored = inv:GetItemCount(payload.toInventory, 'money') or 0
    return stored + payload.count <= Config.Stash.capacity
end, { inventoryFilter = { '^' .. Config.Stash.id } })

-- DEBT

lib.callback.register('rnv-motel:debtStatus', function(src)
    local acc = bankAccount(src)
    local objective = GetResourceState('rnv-missions') == 'started' and exports['rnv-missions']:GetObjective(src, 'debt')
    return { objective = objective, debt = Config.Debt, balance = acc and acc.balance or 0, account = acc ~= nil }
end)

lib.callback.register('rnv-motel:payDebt', function(src)
    if not nearOwner(src) then return false end
    if exports['rnv-missions']:GetObjective(src, 'debt') ~= 'active' then return false end
    local acc = bankAccount(src)
    if not acc then return false, 'no_account' end
    local player = core:GetPlayer(src)
    local ok, err = core:RemoveMoney(acc.id, Config.Debt, 'motel_debt', 'debt:' .. player.citizenid)
    if not ok then return false, err end
    exports['rnv-missions']:CompleteObjective(src, 'debt')
    return true
end)

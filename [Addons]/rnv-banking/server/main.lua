-- Account opening at the Bank Employee and cash withdrawals. Core owns the account, rnv-inventory owns the cash

local core = exports['rnv-core']
local inv = exports['rnv-inventory']

local function account(src)
    local player = core:GetPlayer(src)
    return player and core:GetAccount('player', player.citizenid, 'bank')
end

local function nearEmployee(src)
    local p = Config.Employee.prompt
    return #(GetEntityCoords(GetPlayerPed(src)) - p) <= Config.Employee.distance + 2.0
end

lib.callback.register('rnv-banking:status', function(src)
    local acc = account(src)
    return { opened = acc ~= nil, balance = acc and acc.balance or 0, fee = Config.OpenFee }
end)

lib.callback.register('rnv-banking:open', function(src)
    if not nearEmployee(src) then return false end
    if core:GetRole(src) ~= 'civilian' then return false, 'role' end
    if account(src) then return false, 'exists' end
    if inv:GetItemCount(src, 'money') < Config.OpenFee then return false, 'cash' end
    if not inv:RemoveItem(src, 'money', Config.OpenFee) then return false, 'cash' end

    local player = core:GetPlayer(src)
    local id = core:OpenAccount('player', player.citizenid, 'bank')
    if not id then
        inv:AddItem(src, 'money', Config.OpenFee) -- refund
        return false, 'exists'
    end
    return true
end)

local function nearAtm(src)
    local pos = GetEntityCoords(GetPlayerPed(src))
    for _, atm in ipairs(Config.Atms) do
        if #(pos - atm) <= Config.AtmDistance + 2.0 then return true end
    end
    return false
end

-- at = 'employee' or 'atm'
lib.callback.register('rnv-banking:withdraw', function(src, amount, at)
    amount = tonumber(amount)
    if not amount or amount < 1 or amount ~= math.floor(amount) then return false, 'amount' end
    if at == 'employee' and not nearEmployee(src) then return false end
    if at ~= 'employee' and not nearAtm(src) then return false end
    local acc = account(src)
    if not acc then return false, 'no_account' end
    if acc.balance < amount then return false, 'funds' end
    if not inv:CanCarryItem(src, 'money', amount) then return false, 'space' end

    local ok, err = core:RemoveMoney(acc.id, amount, 'withdraw:' .. at)
    if not ok then return false, err end
    if not inv:AddItem(src, 'money', amount) then
        core:AddMoney(acc.id, amount, 'withdraw_refund')
        return false, 'space'
    end
    return true
end)

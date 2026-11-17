-- Police: join/leave duty (slot cap, issued gear, patrol car), voluntary surrender, arrest with bag confiscation and
-- officer pay, or a bribe both sides accept (criminal keeps the bag, money moves bank to bank)

local core = exports['rnv-core']
local inv = exports['rnv-inventory']

local cops = {}        -- src -> { car, cid, coins }
local surrender = {}   -- suspect src -> true
local deals = {}       -- suspect src -> { cop, amount, stage = 'criminal' | 'cop' }

local function notify(src, text, kind, extra)
    local data = { text = text, type = kind or 'inform', duration = 6000 }
    for k, v in pairs(extra or {}) do data[k] = v end
    exports['rnv-interface']:Notify(src, data)
end

local function copCount()
    local n = 0
    for _ in pairs(cops) do n = n + 1 end
    return n
end

local function bankAccount(src)
    local player = core:GetPlayer(src)
    return player and core:GetAccount('player', player.citizenid, 'bank')
end

local function dist(a, b)
    return #(GetEntityCoords(GetPlayerPed(a)) - GetEntityCoords(GetPlayerPed(b)))
end

-- DUTY

local function removeGear(src)
    for _, item in pairs(inv:GetInventoryItems(src) or {}) do
        if item.metadata and item.metadata.issued then
            inv:RemoveItem(src, item.name, item.count, nil, item.slot)
        end
    end
end

-- SALARY: coins -> cash (70-80%) + random loot for the rest, into the cop's own stash
CreateThread(function()
    inv:RegisterStash(Config.Salary.id, Config.Salary.label, Config.Salary.slots, 1000000000, true)
end)

local function salaryEmpty(cid)
    return next(inv:GetInventoryItems(Config.Salary.id, cid) or {}) == nil
end

local function payout(src, cop)
    local total = (cop.coins or 0) * Config.CoinValue
    if total <= 0 then return end
    local stash = { id = Config.Salary.id, owner = cop.cid }
    local share = Config.CashShare[1] + math.random() * (Config.CashShare[2] - Config.CashShare[1])
    local cash = math.floor(total * share)
    local rest = total - cash
    local values = {}
    for _, name in ipairs(Config.SalaryLoot) do values[name] = exports['rnv-trade']:GetValue(name) or 0 end
    for _ = 1, 100 do
        local fits = {}
        for name, value in pairs(values) do
            if value > 0 and value <= rest then fits[#fits + 1] = name end
        end
        if #fits == 0 then break end
        local name = fits[math.random(#fits)]
        if not inv:AddItem(stash, name, 1) then break end
        rest = rest - values[name]
    end
    inv:AddItem(stash, 'money', cash + rest) -- what no item could cover is paid as cash too
    notify(src, ('Shift over: [[%d police coins]] = [[$%d]]. Take it from your [[Salary]] at the station'):format(cop.coins, total), 'success', { duration = 9000 })
end

local function endDuty(src)
    local cop = cops[src]
    if not cop then return end
    cops[src] = nil
    payout(src, cop)
    removeGear(src)
    if cop.car and DoesEntityExist(cop.car) then DeleteEntity(cop.car) end
    if core:GetRole(src) == 'cop' then core:SetRole(src, 'civilian', 'off_duty') end
    TriggerClientEvent('rnv-police:client:duty', src, false)
end

local function giveGear(src, g)
    local meta = { issued = true }
    for k, v in pairs(g.meta or {}) do meta[k] = v end
    if not (g.slot and not inv:GetSlot(src, g.slot) and inv:AddItem(src, g.item, g.count, meta, g.slot)) then
        inv:AddItem(src, g.item, g.count, meta)
    end
end

local function startDuty(src)
    local player = core:GetPlayer(src)
    for _, g in ipairs(Config.Gear) do giveGear(src, g) end
    local s = Config.CarSpawn
    local car = CreateVehicleServerSetter(joaat(Config.CarModel), 'automobile', s.x, s.y, s.z, s.w)
    if car and car ~= 0 then
        SetVehicleNumberPlateText(car, ('LSPD%04d'):format(src))
        Entity(car).state:set('rnv:owner', src, true) -- rnv-vehicles keys
        Entity(car).state:set('doorslockstate', 1, true)
    end
    cops[src] = { car = car, cid = player.citizenid, coins = 0 }
    core:SetRole(src, 'cop', 'recruited')
    TriggerClientEvent('rnv-police:client:duty', src, true)
end

-- Why `src` can't join right now (nil = can join)
local function cannotJoin(src)
    local player = core:GetPlayer(src)
    if not player or cops[src] then return 'role' end
    if core:GetRole(src) ~= 'civilian' then return 'role' end
    if #(GetEntityCoords(GetPlayerPed(src)) - Config.Duty) > Config.PartyRange then return 'far' end
    if not salaryEmpty(player.citizenid) then return 'salary' end
end

lib.callback.register('rnv-police:join', function(src)
    if #(GetEntityCoords(GetPlayerPed(src)) - Config.Duty) > Config.UseDistance + 2.0 then return false end
    local members = GetResourceState('rnv-party') == 'started' and exports['rnv-party']:GetPartyMembers(src) or { src }
    for _, member in ipairs(members) do
        local why = cannotJoin(member)
        if why then
            local p = core:GetPlayer(member)
            return false, why, member ~= src and p and p.name or nil
        end
    end
    if copCount() + #members > Config.MaxCops then return false, 'full' end
    if #members == 1 then
        startDuty(src)
        return true
    end
    local player = core:GetPlayer(src)
    exports['rnv-party']:AskParty(src, ('[[%s]] suggests joining the Police'):format(player.name), Config.AskTime, function(ok)
        if not ok then return end
        if copCount() + #members > Config.MaxCops then return notify(src, 'No free [[police slot]] right now', 'error') end
        for _, member in ipairs(members) do
            if cannotJoin(member) then return notify(src, 'Someone in your party can no longer join', 'error') end
        end
        for _, member in ipairs(members) do startDuty(member) end
    end)
    return true, 'asked'
end)

lib.callback.register('rnv-police:leave', function(src)
    if not cops[src] or #(GetEntityCoords(GetPlayerPed(src)) - Config.Duty) > Config.UseDistance + 2.0 then return false end
    endDuty(src)
    return true
end)

lib.callback.register('rnv-police:status', function()
    return { count = copCount(), max = Config.MaxCops }
end)

-- Dying on duty loses the issued gear and ends the shift
AddEventHandler('rnv:server:lifeStateChanged', function(src, value)
    if value == 'dead' and cops[src] then endDuty(src) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if cops[src] then endDuty(src) end
    surrender[src] = nil
    deals[src] = nil
end)

-- SURRENDER

RegisterNetEvent('rnv-police:server:surrender', function()
    local src = source
    if surrender[src] or core:GetRole(src) ~= 'criminal' then return end
    local nearCop = false
    for cop in pairs(cops) do
        if dist(src, cop) <= Config.SurrenderRange then nearCop = true end
    end
    if not nearCop then return notify(src, 'No [[police officer]] nearby', 'error') end
    surrender[src] = true
    Player(src).state:set('rnv:surrender', true, true)
end)

local function release(src)
    surrender[src] = nil
    deals[src] = nil
    Player(src).state:set('rnv:surrender', false, true)
end

local function itemValue(item)
    if item.name == 'money' then return item.count end
    if GetResourceState('rnv-trade') ~= 'started' then return 0 end
    return exports['rnv-trade']:GetValue(item.name) * item.count
end

local function bagValue(src)
    local value = 0
    for _, item in pairs(inv:GetInventoryItems(src) or {}) do
        if item.slot <= 54 then value = value + itemValue(item) end
    end
    return value
end

-- Bag (slots 1-54) confiscated; equipment stays. Returns the value of what was taken
local function confiscate(src)
    local value = 0
    for _, item in pairs(inv:GetInventoryItems(src) or {}) do
        if item.slot <= 54 then
            value = value + itemValue(item)
            inv:RemoveItem(src, item.name, item.count, nil, item.slot)
        end
    end
    return value
end

local function addCoins(cop, amount, why)
    if not cops[cop] then return end
    cops[cop].coins = cops[cop].coins + amount
    notify(cop, ('%s: [[+%d police coins]] (%d this shift)'):format(why, amount, cops[cop].coins), 'success')
end

-- A cop killed a Criminal (rnv-combat)
AddEventHandler('rnv-combat:killed', function(victim, killer, victimRole)
    if victimRole == 'criminal' then addCoins(killer, Config.Coins.kill, 'Criminal down') end
end)

local function arrest(suspect, cop)
    confiscate(suspect)
    release(suspect)
    addCoins(cop, Config.Coins.arrest, 'Suspect arrested')
    notify(suspect, 'You were [[arrested]]. Your bag was confiscated', 'error')
    TriggerClientEvent('rnv-police:client:arrested', suspect)
end

-- ARREST (cop) -> bribe offer (criminal, Y/N) -> bribe answer (cop, Y/N) -> arrest or release

RegisterNetEvent('rnv-police:server:arrest', function(suspect)
    local cop = source
    suspect = tonumber(suspect)
    if not cops[cop] or not suspect or not surrender[suspect] or deals[suspect] then return end
    if dist(cop, suspect) > Config.ArrestRange + 1.0 then return end

    local amount = math.floor(bagValue(suspect) * Config.BribeShare)
    local acc = bankAccount(suspect)
    if amount <= 0 or not acc or acc.balance < amount then return arrest(suspect, cop) end

    deals[suspect] = { cop = cop, amount = amount, stage = 'criminal' }
    TriggerClientEvent('rnv-police:client:question', suspect, ('Offer a bribe of [[$%d]] to keep your bag?'):format(amount))
    notify(cop, 'The suspect is deciding...', 'inform')
    SetTimeout(Config.AnswerTime * 1000, function()
        local d = deals[suspect]
        if d and d.stage == 'criminal' and d.cop == cop then arrest(suspect, cop) end
    end)
end)

RegisterNetEvent('rnv-police:server:answer', function(yes)
    local src = source
    -- the criminal answers the bribe question
    local d = deals[src]
    if d and d.stage == 'criminal' then
        if not yes then return arrest(src, d.cop) end
        d.stage = 'cop'
        TriggerClientEvent('rnv-police:client:question', d.cop, ('The suspect offers a bribe of [[$%d]]. Accept?'):format(d.amount))
        local suspect, cop = src, d.cop
        SetTimeout(Config.AnswerTime * 1000, function()
            local again = deals[suspect]
            if again and again.stage == 'cop' and again.cop == cop then arrest(suspect, cop) end
        end)
        return
    end
    -- the cop answers the bribe offer
    for suspect, deal in pairs(deals) do
        if deal.cop == src and deal.stage == 'cop' then
            if not yes then return arrest(suspect, src) end
            local from, to = bankAccount(suspect), bankAccount(src)
            local ok = from and to and core:Transfer(from.id, to.id, deal.amount, 'police_bribe')
            if not ok then return arrest(suspect, src) end
            release(suspect)
            notify(src, 'Bribe accepted: [[$' .. deal.amount .. ']]', 'success')
            notify(suspect, 'The officer took the bribe. You keep your bag', 'success')
            return
        end
    end
end)

exports('IsCop', function(src) return cops[tonumber(src)] ~= nil end)

-- RESTOCK at the trunk of the own patrol car: issued consumables back to full, issued vest full
lib.callback.register('rnv-police:restock', function(src)
    local cop = cops[src]
    if not cop or not cop.car or not DoesEntityExist(cop.car) then return false end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(cop.car)) > 5.0 then return false end
    for _, g in ipairs(Config.Gear) do
        if g.restock then
            local have = 0
            for _, item in pairs(inv:GetInventoryItems(src) or {}) do
                if item.name == g.item and item.metadata and item.metadata.issued then have = have + item.count end
            end
            if have < g.count then giveGear(src, { item = g.item, count = g.count - have, slot = g.slot }) end
        end
    end
    local vest = inv:GetSlot(src, 57)
    if vest and vest.metadata and vest.metadata.issued then
        local meta = vest.metadata
        meta.armour = 50
        inv:SetMetadata(src, 57, meta)
    end
    return true
end)

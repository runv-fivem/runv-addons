-- Black Market purchases, research unlocks and Suspicious Door deals. Pattern from rnv-inventory shops (buyItem):
-- check offer and price -> check cash and space -> add the item -> take the cash
-- Research = 'research' player metadata ({ [offerId] = true }) until Progression Shipments exists

local core = exports['rnv-core']
local inv = exports['rnv-inventory']

-- Catalog from the item data (rnv.buy / rnv.unlock / rnv.rarity): one section per category, cheapest first
local TIER = { [1] = 'green', [2] = 'green', [4] = 'purple', [5] = 'gold', [6] = 'gold' }
local bySection = {}
for name, item in pairs(inv:Items()) do
    local r = item.rnv
    local tab = r and r.buy and Config.CategoryTab[r.category]
    if tab then
        local section = bySection[r.category]
        if not section then
            section = { title = Config.CategoryTitle[r.category] or r.category, tier = 'green', tab = tab, offers = {} }
            bySection[r.category] = section
            Config.Sections[#Config.Sections + 1] = section
        end
        section.offers[#section.offers + 1] = {
            id = name, item = name, price = r.buy, tier = TIER[r.rarity] or 'green',
            unlock = r.unlock and r.unlock > 0 and r.unlock or nil,
            max = item.stack and Config.StackMax or nil,
        }
    end
end
for _, section in pairs(bySection) do
    table.sort(section.offers, function(a, b) return a.price < b.price end)
end
local ORDER = { WEAPONS = 1, AMMO = 2, GRENADES = 3, ['ARMOR & BAGS'] = 4, MEDICINE = 5, ['KEYS & TOOLS'] = 6, PRODUCTION = 7, ['CAR UPGRADES'] = 8 }
table.sort(Config.Sections, function(a, b) return (ORDER[a.title] or 99) < (ORDER[b.title] or 99) end)

local offers = {}
for _, section in ipairs(Config.Sections) do
    for _, offer in ipairs(section.offers) do offers[offer.id] = offer end
end

local deals = {}
for _, deal in ipairs(Config.Deals) do deals[deal.id] = deal end

local function near(src, point)
    return #(GetEntityCoords(GetPlayerPed(src)) - point) <= Config.UseDistance + 2.0
end

-- the motel owner, or the laptop inside the player's base (rnv-housing)
local function atMarket(src)
    if near(src, Config.Owner) then return true end
    return GetResourceState('rnv-housing') == 'started' and exports['rnv-housing']:IsInside(src) ~= nil
end

local function research(src)
    return core:GetMetadata(src, 'research') or {}
end

-- Data for the Black Market panel (state of every offer for this player)
local function marketData(src)
    local done = research(src)
    local sections = {}
    for i, section in ipairs(Config.Sections) do
        local list = {}
        for j, offer in ipairs(section.offers) do
            local state = 'buy'
            if offer.requires and not done[offer.requires] then
                state = 'locked'
            elseif offer.unlock and not done[offer.id] then
                state = 'unlock'
            end
            list[j] = { id = offer.id, item = offer.item, price = offer.price, unlock = offer.unlock, max = offer.max, tier = offer.tier, state = state }
        end
        sections[i] = { title = section.title, tier = section.tier, tab = section.tab or 'GEAR', offers = list }
    end
    return { mode = 'market', tabs = Config.Tabs, sections = sections, cash = inv:GetItemCount(src, 'money') }
end

-- Data for the Suspicious Door panel (how much of each input the player has)
local function doorData(src)
    local list = {}
    for i, deal in ipairs(Config.Deals) do
        local inputs = {}
        for j, input in ipairs(deal.inputs) do
            inputs[j] = { item = input.item, count = input.count, have = inv:GetItemCount(src, input.item) }
        end
        list[i] = { id = deal.id, title = deal.title, output = deal.output, price = deal.price, inputs = inputs }
    end
    return { mode = 'door', deals = list }
end

-- count only for offers with max (ammo); everything else is bought one at a time
local function buy(src, offer, count)
    local done = research(src)
    if offer.requires and not done[offer.requires] then return false end
    if offer.unlock and not done[offer.id] then return false end
    count = offer.max and math.floor(tonumber(count) or 1) or 1
    if count < 1 or count > (offer.max or 1) then return false end
    local price = offer.price * count
    if inv:GetItemCount(src, 'money') < price then return false, 'cash' end
    if not inv:CanCarryItem(src, offer.item, count) then return false, 'space' end
    if not inv:AddItem(src, offer.item, count) then return false, 'space' end
    inv:RemoveItem(src, 'money', price)
    if GetResourceState('rnv-clans') == 'started' then exports['rnv-clans']:AddTax(src, price) end
    return true
end

local function unlock(src, offer)
    local done = research(src)
    if not offer.unlock or done[offer.id] then return false end
    if offer.requires and not done[offer.requires] then return false end
    if inv:GetItemCount(src, 'money') < offer.unlock then return false, 'cash' end
    if not inv:RemoveItem(src, 'money', offer.unlock) then return false, 'cash' end
    done[offer.id] = true
    if GetResourceState('rnv-clans') == 'started' then exports['rnv-clans']:AddTax(src, offer.unlock) end
    core:SetMetadata(src, 'research', done)
    core:Save(src)
    return true
end

local function makeDeal(src, deal)
    for _, input in ipairs(deal.inputs) do
        if inv:GetItemCount(src, input.item) < input.count then return false, 'items' end
    end
    if not inv:CanCarryItem(src, deal.output, 1) then return false, 'space' end
    for _, input in ipairs(deal.inputs) do
        inv:RemoveItem(src, input.item, input.count)
    end
    inv:AddItem(src, deal.output, 1)
    return true
end

-- Called by rnv-inventory's NUI (marketAction): { kind = 'buy'|'unlock'|'deal', id, count }
lib.callback.register('rnv-blackmarket:action', function(src, data)
    if type(data) ~= 'table' then return false end
    local ok, why = false, nil
    if data.kind == 'deal' then
        if not near(src, Config.Door) or not deals[data.id] then return false end
        ok, why = makeDeal(src, deals[data.id])
        return { ok = ok, why = why, data = doorData(src) }
    end
    local offer = offers[data.id]
    if not atMarket(src) or not offer then return false end
    if data.kind == 'buy' then ok, why = buy(src, offer, data.count) end
    if data.kind == 'unlock' then ok, why = unlock(src, offer) end
    return { ok = ok, why = why, data = marketData(src) }
end)

lib.callback.register('rnv-blackmarket:open', function(src, mode)
    if mode == 'door' and near(src, Config.Door) then return doorData(src) end
    if mode == 'market' and atMarket(src) then return marketData(src) end
    return false
end)

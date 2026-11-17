-- Criminal transition, death and respawn. Life state and role live in rnv-core

local core = exports['rnv-core']

local function inCity(src)
    return GetResourceState('rnv-progression') == 'started' and exports['rnv-progression']:GetNotoriety(src) ~= nil
end

local function canMask(src)
    return core:GetRole(src) == 'civilian' and core:GetLifeState(src) == 'alive' and inCity(src)
end

local function becomeCriminal(src)
    core:SetRole(src, 'criminal', 'mask')
    TriggerClientEvent('rnv-combat:client:mask', src)
end

-- In a party everyone is asked first (Y / N); all accept -> the whole party becomes Criminal
RegisterNetEvent('rnv-combat:server:mask', function()
    local src = source
    if not canMask(src) then return end
    if GetResourceState('rnv-party') ~= 'started' then return becomeCriminal(src) end
    local player = core:GetPlayer(src)
    local text = ('[[%s]] suggests becoming Criminals'):format(player and player.name or '?')
    exports['rnv-party']:AskParty(src, text, Config.AskTime, function(ok, members)
        if not ok then return end
        for _, member in ipairs(members) do
            if canMask(member) then becomeCriminal(member) end
        end
    end)
end)

local function loseBag(src)
    local items = exports['rnv-inventory']:GetInventoryItems(src) or {}
    for _, item in pairs(items) do
        if item.slot >= Config.LossSlots.from and item.slot <= Config.LossSlots.to then
            exports['rnv-inventory']:RemoveItem(src, item.name, item.count, nil, item.slot)
        end
    end
end

-- killer = server id of the player who killed (or nil). Other resources hear 'rnv-combat:killed' (rnv-police coins)
RegisterNetEvent('rnv-combat:server:died', function(killer)
    local src = source
    if core:GetLifeState(src) ~= 'alive' then return end
    killer = tonumber(killer)
    if killer and killer ~= src and GetPlayerName(killer) then
        TriggerEvent('rnv-combat:killed', src, killer, core:GetRole(src))
    end
    core:SetLifeState(src, 'dead', 'killed')
    if core:GetRole(src) == 'criminal' and inCity(src) then
        loseBag(src)
    end
end)

RegisterNetEvent('rnv-combat:server:respawned', function()
    local src = source
    if core:GetLifeState(src) ~= 'dead' then return end
    core:SetLifeState(src, 'alive', 'respawn')
end)

-- DAMAGE RULES (who can hurt whom)
-- Criminals can hurt everyone, cops only criminals, party members never each other
-- Civilians can't attack at all (client weapon block). NPCs are not touched

local function playerOf(entity)
    if entity == 0 or GetEntityType(entity) ~= 1 then return nil end
    local owner = NetworkGetEntityOwner(entity)
    if owner and owner > 0 and GetPlayerPed(owner) == entity then return owner end
end

local function sameParty(a, b)
    if GetResourceState('rnv-party') ~= 'started' then return false end
    for _, id in ipairs(exports['rnv-party']:GetPartyMembers(a)) do
        if id == b then return true end
    end
    return false
end

local function canHurt(attacker, victim)
    if attacker == victim then return true end
    if sameParty(attacker, victim) then return false end
    if core:GetRole(attacker) == 'cop' then return core:GetRole(victim) == 'criminal' end
    return true
end

AddEventHandler('weaponDamageEvent', function(sender, data)
    for _, netId in ipairs(data.hitGlobalIds or { data.hitGlobalId }) do
        local victim = playerOf(NetworkGetEntityFromNetworkId(netId))
        if victim and not canHurt(sender, victim) then
            CancelEvent()
            return
        end
    end
end)

-- The hurt player's client reports what it really lost; the shooter gets the number to show
RegisterNetEvent('rnv-combat:server:damaged', function(attacker, amount)
    local src = source
    attacker, amount = tonumber(attacker), math.floor(tonumber(amount) or 0)
    if not attacker or amount <= 0 or amount > 500 or attacker == src or not GetPlayerName(attacker) then return end
    TriggerClientEvent('rnv-combat:client:hitNumber', attacker, src, amount)
end)

-- Rentals live in memory (one per player). Keys = the renter and the renter's party

local rentals = {} -- src -> vehicle entity

local function terminalById(id)
    for _, t in ipairs(Config.Terminals) do
        if t.id == id then return t end
    end
end

local function near(src, coords, distance)
    return #(GetEntityCoords(GetPlayerPed(src)) - vec3(coords.x, coords.y, coords.z)) <= distance
end

local function activeRental(src)
    local veh = rentals[src]
    if veh and DoesEntityExist(veh) then return veh end
    rentals[src] = nil
    Player(src).state:set('rnv:rental', false, true)
end

local function hasKey(src, veh)
    local owner = Entity(veh).state['rnv:owner']
    if not owner or owner == src then return true end
    if GetResourceState('rnv-party') ~= 'started' then return false end
    for _, member in ipairs(exports['rnv-party']:GetPartyMembers(owner)) do
        if member == src then return true end
    end
    return false
end

local function removeRental(src)
    local veh = rentals[src]
    if veh and DoesEntityExist(veh) then DeleteEntity(veh) end
    rentals[src] = nil
end

lib.callback.register('rnv-vehicles:rent', function(src, terminalId)
    local t = terminalById(terminalId)
    if not t or not near(src, t.prop, Config.UseDistance + 1.0) then return false end
    if activeRental(src) then return false, 'active' end

    local s = t.spawn
    local veh = CreateVehicleServerSetter(joaat(Config.RentalModel), 'automobile', s.x, s.y, s.z, s.w)
    if not veh or veh == 0 then return false end
    SetVehicleNumberPlateText(veh, ('RENT%04d'):format(src))
    Entity(veh).state:set('rnv:owner', src, true)
    Entity(veh).state:set('doorslockstate', 1, true)
    rentals[src] = veh
    Player(src).state:set('rnv:rental', NetworkGetNetworkIdFromEntity(veh), true)
    return true
end)

lib.callback.register('rnv-vehicles:park', function(src, terminalId)
    local t = terminalById(terminalId)
    local veh = activeRental(src)
    if not t or not veh or not near(src, t.prop, Config.UseDistance + 1.0) then return false end
    if #(GetEntityCoords(veh) - vec3(t.spawn.x, t.spawn.y, t.spawn.z)) > Config.ParkDistance then return false, 'far' end

    -- Rental trunks are not kept: refuse while something is still inside
    local trunk = exports['rnv-inventory']:GetInventoryItems('trunk' .. GetVehicleNumberPlateText(veh))
    if trunk and next(trunk) then return false, 'trunk' end

    removeRental(src)
    Player(src).state:set('rnv:rental', false, true)
    return true
end)

lib.callback.register('rnv-vehicles:hasKey', function(src, netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    return veh ~= 0 and DoesEntityExist(veh) and hasKey(src, veh)
end)

RegisterNetEvent('rnv-vehicles:server:toggleLock', function(netId)
    local src = source
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) or not Entity(veh).state['rnv:owner'] then return end
    if not hasKey(src, veh) or #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) > Config.LockDistance + 2.0 then return end
    local locked = Entity(veh).state.doorslockstate == 2
    Entity(veh).state:set('doorslockstate', locked and 1 or 2, true)
    SetVehicleDoorsLocked(veh, locked and 1 or 2) -- rnv-inventory reads this to allow the trunk
    TriggerClientEvent('rnv-vehicles:client:lockChanged', src, not locked)
end)

AddEventHandler('playerDropped', function()
    removeRental(source)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src in pairs(rentals) do
        removeRental(src)
        Player(src).state:set('rnv:rental', false, true)
    end
end)

exports('GetRental', activeRental)
exports('HasKey', hasKey)

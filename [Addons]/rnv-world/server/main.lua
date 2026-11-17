-- Arriving in a city starts the visit as a Civilian (Criminal comes from the mask later)
RegisterNetEvent('rnv-world:server:arrived', function(destination)
    local src = source
    if destination == 'los_santos' then
        exports['rnv-core']:SetRole(src, 'civilian', 'arrive:los_santos')
        if GetResourceState('rnv-progression') == 'started' then
            exports['rnv-progression']:StartVisit(src)
        end
        if GetResourceState('rnv-missions') == 'started' then
            exports['rnv-missions']:Fact(src, 'city_arrived')
        end
    elseif destination == 'settlement' then
        exports['rnv-core']:SetRole(src, 'civilian', 'arrive:settlement')
    end
end)

-- Back at the Motel: the city visit is over
RegisterNetEvent('rnv-world:server:atMotel', function()
    exports['rnv-core']:SetRole(source, 'civilian', 'motel')
    if GetResourceState('rnv-progression') == 'started' then
        exports['rnv-progression']:EndVisit(source)
    end
end)

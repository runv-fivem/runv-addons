-- Vendor vans + NPCs + counters, FENCE / SMUGGLER'S VAN prompts, and CASH PILE pickups

local entities = {}
local pileProps = {}
local counters = {} -- vendor table entities (the cash bundles lie on their top)

local function load(model)
    local hash = joaat(model)
    lib.requestModel(hash)
    return hash
end

local function spawnVendor(v)
    local c = v.van.coords
    local van = CreateVehicle(load(v.van.model), c.x, c.y, c.z, c.w, false, false)
    SetVehicleOnGroundProperly(van)
    SetEntityInvincible(van, true)
    FreezeEntityPosition(van, true)
    SetVehicleDoorsLocked(van, 2)
    entities[#entities + 1] = van

    local p = v.ped.coords
    local ok, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z + 2.0, false)
    local ped = CreatePed(4, load(v.ped.model), p.x, p.y, ok and gz or p.z, p.w, false, false)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    entities[#entities + 1] = ped

    local t = v.counter
    local counter = CreateObject(load('prop_table_03'), t.x, t.y, t.z - 1.0, false, false, false)
    SetEntityHeading(counter, t.w)
    PlaceObjectOnGroundProperly(counter)
    FreezeEntityPosition(counter, true)
    entities[#entities + 1] = counter
    counters[#counters + 1] = counter
end

local function openFence()
    local data = lib.callback.await('rnv-trade:fenceData', false)
    if data then exports['rnv-inventory']:openMarket(data, 'stash', 'fence') end
end

local function openSmuggler()
    local data = lib.callback.await('rnv-trade:smugglerData', false)
    if data then exports['rnv-inventory']:openMarket(data) end
end

-- Vendors spawn once the player is near (the ground must be loaded to place them)
CreateThread(function()
    local pending = { Config.Fence, Config.Smuggler }
    while #pending > 0 do
        local pos = GetEntityCoords(PlayerPedId())
        for i = #pending, 1, -1 do
            local v = pending[i]
            if #(pos - v.van.coords.xyz) < 100.0 and HasCollisionLoadedAroundEntity(PlayerPedId()) then
                spawnVendor(v)
                table.remove(pending, i)
            end
        end
        Wait(1000)
    end
end)

CreateThread(function()
    exports['rnv-interface']:AddPrompt({ id = 'trade_fence', coords = Config.Fence.prompt, title = 'FENCE', label = 'Sell', distance = Config.UseDistance, onSelect = openFence })
    exports['rnv-interface']:AddPrompt({ id = 'trade_smuggler', coords = Config.Smuggler.prompt, title = "SMUGGLER'S VAN", label = 'Sell Cargo', distance = Config.UseDistance, onSelect = openSmuggler })
end)

-- CASH PILES

local function takePile(id)
    local ok = exports['rnv-interface']:Progress({ label = 'COLLECTING...', duration = Config.CollectTime, canCancel = true })
    if not ok then return end
    local amount, why = lib.callback.await('rnv-trade:take', false, id)
    if why == 'space' then
        exports['rnv-interface']:Notify({ text = 'No room for more [[cash]] in your bag', type = 'error', duration = 4000 })
    end
end

local function showPiles(piles)
    for id, props in pairs(pileProps) do
        for _, obj in ipairs(props) do DeleteEntity(obj) end
        exports['rnv-interface']:RemovePrompt('cash_pile_' .. id)
    end
    pileProps = {}
    for id, pile in pairs(piles or {}) do
        id = tonumber(id)
        local c = pile.coords
        -- the vendor table under the pile: bundles lie on its top surface, laid out along the table
        local tableEnt
        for _, t in ipairs(counters) do
            if DoesEntityExist(t) and #(GetEntityCoords(t).xy - c.xy) < 1.5 then tableEnt = t end
        end
        local _, maxDim = GetModelDimensions(GetEntityModel(tableEnt or 0))
        -- one bundle per Config.CashBundle $, in rows of 4 on the table top
        local props = {}
        local n = math.max(1, math.min(Config.CashMaxProps, math.ceil(pile.amount / Config.CashBundle)))
        for i = 0, n - 1 do
            local ox, oy = (i % 4 - 1.5) * 0.22, (math.floor(i / 4) - 0.5) * 0.18
            local at = tableEnt and GetOffsetFromEntityInWorldCoords(tableEnt, ox, oy, maxDim.z) or vec3(c.x + ox, c.y + oy, c.z + 0.78)
            local obj = CreateObject(load(Config.CashProp), at.x, at.y, at.z, false, false, false)
            SetEntityHeading(obj, math.random(0, 359) + 0.0)
            FreezeEntityPosition(obj, true)
            props[#props + 1] = obj
        end
        pileProps[id] = props
        exports['rnv-interface']:AddPrompt({
            id = 'cash_pile_' .. id, coords = vec3(c.x, c.y, c.z + 0.3), title = 'CASH PILE', label = 'Take Cash',
            distance = Config.UseDistance, onSelect = function() takePile(id) end,
        })
    end
end

RegisterNetEvent('rnv-trade:client:piles', showPiles)

CreateThread(function()
    showPiles(lib.callback.await('rnv-trade:piles', false))
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, e in ipairs(entities) do DeleteEntity(e) end
    showPiles({})
    exports['rnv-interface']:RemovePrompt('trade_fence')
    exports['rnv-interface']:RemovePrompt('trade_smuggler')
end)

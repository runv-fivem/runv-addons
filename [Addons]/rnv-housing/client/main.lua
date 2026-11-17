-- Plot props and prompts (rent sign, Plot Plan, door), the PLOT OWNER screen, and the interior (exit, cabinet, laptop)

local plots = {}     -- from the server: id -> { owner, main, extra }
local spawned = {}   -- id -> { props = {...} }
local insidePlot = nil
local rentPlot = nil

local function myCid()
    local data = exports['rnv-core']:GetPlayerData()
    return data and data.citizenid
end

local function plotConfig(id)
    for _, p in ipairs(Config.Plots) do
        if p.id == id then return p end
    end
end

-- World position of a layout offset on a plot (same math as the server), on the ground
local function plotPoint(p, offset)
    local c = p.center
    local r = math.rad(c.w)
    local x = c.x + offset.x * math.cos(r) - offset.y * math.sin(r)
    local y = c.y + offset.x * math.sin(r) + offset.y * math.cos(r)
    local ok, z = GetGroundZFor_3dCoord(x, y, c.z + 50.0, false)
    return vec3(x, y, ok and z or c.z)
end

local function myPlot()
    local cid = myCid()
    for id, d in pairs(plots) do
        if d.owner == cid then return id end
    end
end

-- PROPS

local function spawnProp(model, pos, heading)
    local hash = joaat(model)
    lib.requestModel(hash)
    local obj = CreateObject(hash, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(obj, heading)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

local function despawn(id)
    for _, obj in ipairs(spawned[id] or {}) do DeleteEntity(obj) end
    spawned[id] = nil
    exports['rnv-interface']:RemovePrompt('plot_sign_' .. id)
    exports['rnv-interface']:RemovePrompt('plot_plan_' .. id)
    exports['rnv-interface']:RemovePrompt('plot_door_' .. id)
end

local openRent, openPlan, enterPlot

local function spawnPlot(p)
    local d = plots[p.id]
    local h = p.center.w
    local props = {}
    local L = Config.Layout

    props[#props + 1] = spawnProp(Config.SignProp, plotPoint(p, L.sign), h)
    if d then
        props[#props + 1] = spawnProp(Config.PlanProp, plotPoint(p, L.plan), h)
        if d.main then
            props[#props + 1] = spawnProp(Config.Structures[d.main].prop, plotPoint(p, L.main), h)
        end
        for _, name in pairs(d.extra or {}) do
            local s = Config.Structures[name]
            local at = L[s.at]
            if type(at[1]) == 'vector3' then
                for _, offset in ipairs(at) do props[#props + 1] = spawnProp(s.prop, plotPoint(p, offset), h + 90.0) end
            else
                props[#props + 1] = spawnProp(s.prop, plotPoint(p, at), h)
            end
        end
    end
    spawned[p.id] = props

    local sign = plotPoint(p, L.sign)
    if not d then
        exports['rnv-interface']:AddPrompt({
            id = 'plot_sign_' .. p.id, coords = sign + vec3(0.0, 0.0, 1.2), title = 'PLOT ' .. p.name, label = 'Rent',
            distance = Config.UseDistance, onSelect = function() openRent(p.id) end,
        })
    end
    if d and d.owner == myCid() then
        exports['rnv-interface']:AddPrompt({
            id = 'plot_plan_' .. p.id, coords = plotPoint(p, L.plan) + vec3(0.0, 0.0, 1.1), title = 'PLOT PLAN', label = 'Modification',
            distance = Config.UseDistance, onSelect = function() openPlan(p.id) end,
        })
        if d.main then
            exports['rnv-interface']:AddPrompt({
                id = 'plot_door_' .. p.id, coords = plotPoint(p, L.door) + vec3(0.0, 0.0, 1.0), title = Config.Structures[d.main].label, label = 'Enter',
                distance = Config.UseDistance, onSelect = function() enterPlot(p.id) end,
            })
        end
    end
end

-- Spawn plots near the player, rebuild after every server update
CreateThread(function()
    while true do
        Wait(1000)
        local pos = GetEntityCoords(PlayerPedId())
        for _, p in ipairs(Config.Plots) do
            local dist = #(pos - p.center.xyz)
            if dist < 150.0 and not spawned[p.id] then
                spawnPlot(p)
            elseif dist > 200.0 and spawned[p.id] then
                despawn(p.id)
            end
        end
    end
end)

RegisterNetEvent('rnv-housing:client:plots', function(data)
    plots = data or {}
    for id in pairs(spawned) do despawn(id) end
end)

CreateThread(function()
    plots = lib.callback.await('rnv-housing:plots', false) or {}
end)

-- PLOT OWNER (rent) SCREEN

local function closeRent()
    if not rentPlot then return end
    rentPlot = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerScreenblurFadeOut(300)
    DisplayRadar(true)
    LocalPlayer.state:set('rnv:screen', false, false)
end

openRent = function(id)
    local info = lib.callback.await('rnv-housing:rentInfo', false, id)
    if not info or not info.free then return end
    if info.owns then
        return exports['rnv-interface']:Notify({ text = 'You already rent a [[plot]]', type = 'error', duration = 4000 })
    end
    rentPlot = id
    LocalPlayer.state:set('rnv:screen', true, false)
    TriggerScreenblurFadeIn(300)
    DisplayRadar(false)
    SendNUIMessage({ action = 'rent', name = info.name, has = info.has, image = 'nui://rnv-inventory/web/images/' .. Config.TitleItem .. '.png' })
    SetNuiFocus(true, true)
end

RegisterNUICallback('cancel', function(_, cb)
    cb(1)
    closeRent()
end)

RegisterNUICallback('rent', function(_, cb)
    cb(1)
    local id = rentPlot
    closeRent()
    local ok = lib.callback.await('rnv-housing:rent', false, id)
    if not ok then
        exports['rnv-interface']:Notify({ text = 'You need a [[Land Plot Title]]', type = 'error', duration = 4000 })
    end
end)

-- PLOT PLAN (LAND PLOT panel in the rnv-inventory UI)

openPlan = function(id)
    local data = lib.callback.await('rnv-housing:planData', false, id)
    if data then exports['rnv-inventory']:openMarket(data) end
end

-- INTERIOR

-- Teleport frozen until collision (and the interior) are loaded, then stand on the ground
local function teleport(pos, heading)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    local interior = GetInteriorAtCoords(pos.x, pos.y, pos.z)
    if interior ~= 0 then PinInteriorInMemory(interior) end
    local timeout = GetGameTimer() + 10000
    while GetGameTimer() < timeout and (not HasCollisionLoadedAroundEntity(ped) or (interior ~= 0 and not IsInteriorReady(interior))) do
        RequestCollisionAtCoord(pos.x, pos.y, pos.z)
        Wait(100)
    end
    local ok, z = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 2.0, false)
    SetEntityCoords(ped, pos.x, pos.y, ok and z or pos.z, false, false, false, false)
    SetEntityHeading(ped, heading)
    SetGameplayCamRelativeHeading(0.0) -- camera looks where the ped faces
    FreezeEntityPosition(ped, false)
end

local function leave()
    local id = insidePlot
    if not id then return end
    DoScreenFadeOut(300)
    Wait(300)
    TriggerServerEvent('rnv-housing:server:exit')
    local p = plotConfig(id)
    teleport(plotPoint(p, Config.Layout.door) + vec3(0.0, 0.0, 1.0), p.center.w + 180.0)
    DoScreenFadeIn(300)
end

local function setInsidePrompts(plotId, interior)
    local exit = interior.exit
    exports['rnv-interface']:AddPrompt({ id = 'plot_exit', coords = vec3(exit.x, exit.y, exit.z + 1.0), title = 'EXIT', label = 'Leave', distance = Config.UseDistance, onSelect = leave })
    exports['rnv-interface']:AddPrompt({
        id = 'plot_stash', coords = interior.stash + vec3(0.0, 0.0, 1.0), title = Config.Stash.label, label = 'Open', distance = Config.UseDistance,
        onSelect = function() exports['rnv-inventory']:openInventory('stash', 'plot_' .. plotId) end,
    })
    exports['rnv-interface']:AddPrompt({
        id = 'plot_laptop', coords = interior.laptop + vec3(0.0, 0.0, 1.0), title = 'LAPTOP', distance = Config.UseDistance,
        options = { { label = 'Black Market', icon = 'cash', onSelect = function() exports['rnv-blackmarket']:Open('market') end } },
    })
    exports['rnv-interface']:AddPrompt({
        id = 'plot_desk', coords = interior.desk + vec3(0.0, 0.0, 1.0), title = 'LAUNDERING DESK', label = 'Open', distance = Config.UseDistance,
        onSelect = function() exports['rnv-laundering']:Open() end,
    })
end

local function clearInsidePrompts()
    exports['rnv-interface']:RemovePrompt('plot_exit')
    exports['rnv-interface']:RemovePrompt('plot_stash')
    exports['rnv-interface']:RemovePrompt('plot_laptop')
    exports['rnv-interface']:RemovePrompt('plot_desk')
end

enterPlot = function(id)
    DoScreenFadeOut(300)
    Wait(300)
    local result = lib.callback.await('rnv-housing:enter', false, id)
    if result then
        local exit = result.interior.exit
        teleport(vec3(exit.x, exit.y, exit.z + 1.0), exit.w)
        insidePlot = id
        setInsidePrompts(id, result.interior)
    end
    Wait(500)
    DoScreenFadeIn(300)
end

-- Players in other plots (or outside) are hidden from each other
RegisterNetEvent('rnv-housing:client:conceal', function(entered)
    local mine = entered[tostring(GetPlayerServerId(PlayerId()))] or entered[GetPlayerServerId(PlayerId())]
    if not mine and insidePlot then
        insidePlot = nil
        clearInsidePrompts()
    end
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local sid = GetPlayerServerId(player)
            local theirs = entered[tostring(sid)] or entered[sid]
            NetworkConcealPlayer(player, theirs ~= mine, false)
        end
    end
end)

-- RESPAWN: own plot with a main building (rnv-combat asks)
exports('Enter', function(id) enterPlot(id) end)

exports('GetRespawn', function()
    local id = myPlot()
    local p = id and plotConfig(id)
    if not p or not plots[id].main then return nil end
    local door = plotPoint(p, Config.Layout.door)
    return vec4(door.x, door.y, door.z, p.center.w + 180.0)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeRent()
    clearInsidePrompts()
    for id in pairs(spawned) do despawn(id) end
end)

-- dev: show the PLOT OWNER screen without renting
exports('TestRentScreen', function()
    rentPlot = -1 -- no real plot: ESC closes, RENT is refused by the server
    LocalPlayer.state:set('rnv:screen', true, false)
    TriggerScreenblurFadeIn(300)
    DisplayRadar(false)
    SendNUIMessage({ action = 'rent', name = 'FRUITCAKE', has = 1, image = 'nui://rnv-inventory/web/images/' .. Config.TitleItem .. '.png' })
    SetNuiFocus(true, true)
end)

-- World map: leaving the Motel area opens the real world straight from above (aerial camera, north on the
-- left) with every place drawn as a cluster of hex cells. Picking a destination travels there; Back returns to the Motel

local mapOpen = false
local wasInMotel = false
local frozen = nil

local function fadeOut()
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end
end

local function inMotel()
    return #(GetEntityCoords(PlayerPedId()) - Config.Motel.center) <= Config.Motel.radius
end

local function leaveVehicle(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        TaskLeaveVehicle(ped, veh, 16) -- 16 = teleport out
        Wait(100)
    end
end

local function placePed(ped, coords)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, coords.w)
    local timeout = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        Wait(0)
    end
end

local function placesForNui()
    local list = {}
    for _, d in ipairs(Config.Destinations) do
        list[#list + 1] = {
            id = d.id, label = d.label, text = d.text, image = d.image, iconImage = d.iconImage,
            card = d.card, badge = d.badge, travel = d.travel ~= nil,
        }
    end
    return list
end

-- AERIAL CAMERA: pose = focus point + distance; the camera looks at it at Config.Map.pitch / yaw
local cam, pose, target, selected, hovered = nil, nil, nil, nil, nil

local function dirs(pitch, yaw)
    local p, y = math.rad(pitch), math.rad(yaw)
    local cp, sp, cy, sy = math.cos(p), math.sin(p), math.cos(y), math.sin(y)
    return vector3(-sy * cp, cy * cp, sp), vector3(cy, sy, 0.0), vector3(sy * sp, -cy * sp, cp)   -- forward, right, up
end

local function camPos()
    local f = dirs(pose.pitch, pose.yaw)
    return vector3(pose.x, pose.y, pose.z) - f * pose.dist
end

local function destination(id)
    for _, d in ipairs(Config.Destinations) do
        if d.id == id then return d end
    end
end

local function inZone(d, x, y)
    local inside, j = false, #d.zone
    for i = 1, #d.zone do
        local a, b = d.zone[i], d.zone[j]
        if (a.y > y) ~= (b.y > y) and x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x then inside = not inside end
        j = i
    end
    return inside
end

-- HEX CELLS (pointy-top grid, the old NUI map's maths): every cell whose center is inside the zone polygon
-- Outer edges = cell edges with no neighbour of the same place; only those get a border
local SQ3 = math.sqrt(3)
local DIRS = { { 1, 0 }, { 0, 1 }, { -1, 1 }, { -1, 0 }, { 0, -1 }, { 1, -1 } }   -- neighbour across edge i (corners i, i+1)

local function corner(s, cx, cy, i)
    local a = math.rad(60 * i - 30)
    return cx + s * math.cos(a), cy + s * math.sin(a)
end

local function buildCells(d)
    local s = d.hex
    local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
    for _, v in ipairs(d.zone) do
        minX, maxX, minY, maxY = math.min(minX, v.x), math.max(maxX, v.x), math.min(minY, v.y), math.max(maxY, v.y)
    end
    local set, cells = {}, {}
    for r = math.floor(minY / (1.5 * s)) - 1, math.ceil(maxY / (1.5 * s)) + 1 do
        for q = math.floor(minX / (s * SQ3) - r / 2) - 1, math.ceil(maxX / (s * SQ3) - r / 2) + 1 do
            local cx, cy = s * SQ3 * (q + r / 2), s * 1.5 * r
            if inZone(d, cx, cy) then
                set[q .. ',' .. r] = true
                local c = { x = cx, y = cy, dark = (q * 31 + r * 17 + q * r) % 5 < 2 }
                for i = 0, 5 do c[i + 1] = vector2(corner(s, cx, cy, i)) end
                c.q, c.r = q, r
                cells[#cells + 1] = c
            end
        end
    end
    local edges = {}
    for _, c in ipairs(cells) do
        for i = 0, 5 do
            if not set[(c.q + DIRS[i + 1][1]) .. ',' .. (c.r + DIRS[i + 1][2])] then
                edges[#edges + 1] = { c[i + 1], c[(i + 1) % 6 + 1] }
            end
        end
    end
    d.cells, d.edges = cells, edges
    local x, y = 0.0, 0.0
    for _, c in ipairs(cells) do x, y = x + c.x, y + c.y end
    d.center = vector3(x / math.max(1, #cells), y / math.max(1, #cells), d.roof)
end

for _, d in ipairs(Config.Destinations) do buildCells(d) end

local function tri(a, b, c, r, g, bl, al)
    DrawPoly(a, b, c, r, g, bl, al)
    DrawPoly(c, b, a, r, g, bl, al)   -- both sides: DrawPoly draws one face only
end

-- roof = the cells, two tones; border = a flat ribbon on the outer edges, width kept steady on screen
local function drawPlace(d, sel, hov)
    local z = d.roof
    local alpha = sel and 120 or hov and 105 or 70
    for _, c in ipairs(d.cells) do
        local r, g, b = 236, 208, 142
        if c.dark then r, g, b = 150, 120, 76 end
        local m = vector3(c.x, c.y, z)
        for i = 1, 6 do
            local p1, p2 = c[i], c[i % 6 + 1]
            tri(m, vector3(p1.x, p1.y, z), vector3(p2.x, p2.y, z), r, g, b, alpha)
        end
    end
    local w = pose.dist * (sel and 0.0026 or 0.0016)
    local r, g, b = 240, 226, 172
    if sel then r, g, b = 255, 255, 255 end
    for _, e in ipairs(d.edges) do
        local a, bb = e[1], e[2]
        local dx, dy = bb.x - a.x, bb.y - a.y
        local len = math.sqrt(dx * dx + dy * dy)
        local nx, ny = -dy / len * w / 2, dx / len * w / 2
        local p1, p2 = vector3(a.x + nx, a.y + ny, z + 1.0), vector3(a.x - nx, a.y - ny, z + 1.0)
        local p3, p4 = vector3(bb.x - nx, bb.y - ny, z + 1.0), vector3(bb.x + nx, bb.y + ny, z + 1.0)
        tri(p1, p2, p3, r, g, b, 255)
        tri(p1, p3, p4, r, g, b, 255)
    end
end

local function overview()
    local c = Config.Map.center
    target.x, target.y, target.z, target.dist = c.x, c.y, c.z, Config.Map.dist
end

local function selectPlace(id)
    local d = id and destination(id)
    selected = d and id or nil
    if d then
        target.x, target.y, target.z, target.dist = d.center.x, d.center.y, d.roof, d.view
    else
        overview()
    end
    SendNUIMessage({ action = 'select', id = selected })
end

-- where each place is on screen: diamond above the cluster center, popup left of the cluster's left-most point
local function screenData()
    local out = {}
    for _, d in ipairs(Config.Destinations) do
        local on, x, y = GetScreenCoordFromWorldCoord(d.center.x, d.center.y, d.roof)
        local left = 1.0
        for _, e in ipairs(d.edges) do
            local ok, sx = GetScreenCoordFromWorldCoord(e[1].x, e[1].y, d.roof)
            if ok and sx < left then left = sx end
        end
        out[d.id] = { on = on, x = x, y = y, left = left }
    end
    return out
end

local function concealEntities()
    for _, pool in ipairs({ 'CPed', 'CVehicle', 'CObject' }) do
        for _, e in ipairs(GetGamePool(pool)) do SetEntityLocallyInvisible(e) end
    end
end

local function startCamera()
    local c = Config.Map.center
    pose = { x = c.x, y = c.y, z = c.z, dist = Config.Map.dist, pitch = Config.Map.pitch, yaw = Config.Map.yaw }
    target = {}
    for k, v in pairs(pose) do target[k] = v end
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', false)
    SetCamFov(cam, Config.Map.fov)
    SetCamFarClip(cam, 50000.0)
    SetCamCoord(cam, camPos())
    SetCamRot(cam, pose.pitch, 0.0, pose.yaw, 2)
    concealEntities()
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, false)
    NetworkOverrideClockTime(9, 0, 0)   -- morning sun reads best from above
    CreateThread(function()
        local nextFrame = 0
        while cam do
            local blend = 1 - math.exp(-math.min(GetFrameTime(), 0.05) * 4.0)
            for _, k in ipairs({ 'x', 'y', 'z', 'dist' }) do pose[k] = pose[k] + (target[k] - pose[k]) * blend end
            SetCamCoord(cam, camPos())
            SetCamRot(cam, pose.pitch, 0.0, pose.yaw, 2)
            SetFocusPosAndVel(pose.x, pose.y, pose.z, 0.0, 0.0, 0.0)
            OverrideLodscaleThisFrame(Config.Map.lod)
            HideHudAndRadarThisFrame()
            concealEntities()
            for _, d in ipairs(Config.Destinations) do drawPlace(d, d.id == selected, d.id == hovered) end
            if GetGameTimer() >= nextFrame then
                nextFrame = GetGameTimer() + 33
                SendNUIMessage({ action = 'frame', screen = screenData() })
            end
            Wait(0)
        end
    end)
end

local function stopCamera()
    if not cam then return end
    local old = cam
    cam = nil
    RenderScriptCams(false, false, 0, true, false)
    DestroyCam(old, false)
    ClearFocus()
    NetworkClearClockTimeOverride()
end

local function closeMap()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    stopCamera()
    selected, hovered = nil, nil
    if frozen and DoesEntityExist(frozen) then FreezeEntityPosition(frozen, false) end
    frozen = nil
    DisplayRadar(true)
    mapOpen = false
    LocalPlayer.state:set('rnv:map', false, false)
end

-- screen point (0..1) -> ground point under it, against the focus height
local function pick(u, v)
    local f, r, up = dirs(pose.pitch, pose.yaw)
    local o = camPos()
    local w, h = GetActiveScreenResolution()
    local scale = math.tan(math.rad(Config.Map.fov / 2))
    local d = f + r * ((2 * u - 1) * scale * w / h) + up * ((1 - 2 * v) * scale)
    if d.z >= -0.01 then return nil end
    local t = (pose.z - o.z) / d.z
    return o.x + d.x * t, o.y + d.y * t
end

RegisterNUICallback('pick', function(data, cb)
    cb(1)
    if not cam then return end
    local x, y = pick(data.u, data.v)
    if not x then return end
    for _, d in ipairs(Config.Destinations) do
        if inZone(d, x, y) then return selectPlace(d.id) end
    end
    selectPlace(nil)
end)

RegisterNUICallback('hover', function(data, cb)
    cb(1)
    if not cam then return end
    local x, y = pick(data.u, data.v)
    hovered = nil
    if not x then return end
    for _, d in ipairs(Config.Destinations) do
        if inZone(d, x, y) then hovered = d.id end
    end
end)

RegisterNUICallback('select', function(data, cb)
    cb(1)
    if cam then selectPlace(data.id) end
end)

-- drag pans the focus point; the screen's up-down maps onto the ground ahead (divided by the 45 degree slope)
RegisterNUICallback('pan', function(data, cb)
    cb(1)
    if not cam then return end
    local _, r = dirs(pose.pitch, pose.yaw)
    local fy = vector3(-math.sin(math.rad(pose.yaw)), math.cos(math.rad(pose.yaw)), 0.0)
    local s = 2 * pose.dist * math.tan(math.rad(Config.Map.fov / 2)) / data.h
    local k = 1 / math.max(0.3, -math.sin(math.rad(pose.pitch)))
    target.x = math.max(-4000.0, math.min(4500.0, target.x - r.x * data.dx * s + fy.x * data.dy * s * k))
    target.y = math.max(-4000.0, math.min(8000.0, target.y - r.y * data.dx * s + fy.y * data.dy * s * k))
end)

RegisterNUICallback('zoom', function(data, cb)
    cb(1)
    if not cam then return end
    target.dist = math.max(Config.Map.minDist, math.min(Config.Map.maxDist, target.dist * (data.dir > 0 and 1.15 or 1 / 1.15)))
end)

-- The map opens where the player is: the ped (or its car) is frozen and the NUI map covers the screen
local function openMap()
    if mapOpen then return end
    mapOpen = true
    LocalPlayer.state:set('rnv:map', true, false)
    fadeOut()

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    frozen = veh ~= 0 and veh or ped
    FreezeEntityPosition(frozen, true)
    DisplayRadar(false)

    startCamera()
    SendNUIMessage({ action = 'open', places = placesForNui() })
    SetNuiFocus(true, true)
    Wait(800)   -- let the first frames stream in under the fade
    DoScreenFadeIn(500)
end

local function goToMotel()
    local ped = PlayerPedId()
    leaveVehicle(ped)
    placePed(ped, Config.Motel.arrival)
    wasInMotel = true
    TriggerServerEvent('rnv-world:server:atMotel')
end

local function backToMotel()
    fadeOut()
    if mapOpen then closeMap() end
    goToMotel()
    DoScreenFadeIn(500)
end

local function travel(id)
    local d
    for _, dest in ipairs(Config.Destinations) do
        if dest.id == id then d = dest end
    end
    if not d or not d.travel then return end
    if d.travel == 'motel' then return backToMotel() end

    fadeOut()
    if mapOpen then closeMap() end

    local ped = PlayerPedId()
    leaveVehicle(ped)

    -- Settlement: your own base door if you have one (on foot), else a road with a car
    local door = d.travel == 'home' and GetResourceState('rnv-housing') == 'started' and exports['rnv-housing']:GetRespawn()
    if door then
        placePed(ped, door)
    else
        local a = d.arrivals[math.random(#d.arrivals)]
        placePed(ped, a)
        local hash = joaat(d.vehicle)
        lib.requestModel(hash)
        local car = CreateVehicle(hash, a.x, a.y, a.z, a.w, true, false)
        SetModelAsNoLongerNeeded(hash)
        SetVehicleOnGroundProperly(car)
        SetVehicleHasBeenOwnedByPlayer(car, true)
        SetPedIntoVehicle(ped, car, -1)
    end

    TriggerServerEvent('rnv-world:server:arrived', id)
    wasInMotel = false
    DoScreenFadeIn(500)
end

RegisterNUICallback('travel', function(data, cb)
    cb(1)
    travel(data.id)
end)

RegisterNUICallback('back', function(_, cb)
    cb(1)
    backToMotel()
end)

-- Leaving the Motel area opens the map
CreateThread(function()
    while true do
        Wait(500)
        if LocalPlayer.state['rnv:spawned'] and not mapOpen then
            local inside = inMotel()
            if wasInMotel and not inside then
                CreateThread(openMap)
            end
            wasInMotel = inside
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and mapOpen then closeMap() end
end)

-- Used by rnv-prison (escape) and rnv-login (where players start)
exports('GoToMotel', goToMotel)
exports('GetMotelArrival', function() return Config.Motel.arrival end)
exports('OpenMap', function() CreateThread(openMap) end)
exports('Travel', function(id) CreateThread(function() travel(id) end) end)

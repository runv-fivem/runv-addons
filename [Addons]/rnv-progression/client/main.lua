-- Authority screen + tattoos on the ped + Tattoo Artist in prison

local screenOpen = false
local cam = nil
local artistPed = nil

local function playerData()
    return exports['rnv-core']:GetPlayerData() or {}
end

local function authority()
    local md = playerData().metadata or {}
    return md.authority or 0
end

local function ownedTattoos()
    local md = playerData().metadata or {}
    return md.tattoos or {}
end

local function isFemale(ped)
    return GetEntityModel(ped) == joaat('mp_f_freemode_01')
end

local function addTattoo(ped, t)
    local hash = isFemale(ped) and t.female or t.male
    AddPedDecorationFromHashes(ped, joaat(t.collection), joaat(hash))
end

-- Owned tattoos (+ an optional preview) on the player ped
local function applyTattoos(previewId)
    local ped = PlayerPedId()
    ClearPedDecorations(ped)
    for _, id in ipairs(ownedTattoos()) do
        if Config.Tattoos[id] then addTattoo(ped, Config.Tattoos[id]) end
    end
    if previewId and Config.Tattoos[previewId] then addTattoo(ped, Config.Tattoos[previewId]) end
end

-- Reapply when the ped changes (model swaps make a new ped)
CreateThread(function()
    local lastPed = 0
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        if ped ~= lastPed and LocalPlayer.state['rnv:spawned'] then
            lastPed = ped
            applyTattoos()
        end
    end
end)

AddEventHandler('rnv:client:onPlayerDataChanged', function()
    if not screenOpen then applyTattoos() end
end)

-- AUTHORITY SCREEN

local function screenData(atArtist)
    local owned = {}
    for _, id in ipairs(ownedTattoos()) do owned[id] = true end
    local list = {}
    for i, t in ipairs(Config.Tattoos) do
        list[i] = { id = t.id, name = t.name, threshold = t.threshold, desc = t.desc, owned = owned[t.id] == true }
    end
    return {
        track = Config.TrackName,
        authority = authority(),
        tattoos = list,
        atArtist = atArtist,
        female = isFemale(PlayerPedId()),
    }
end

local function startCamera()
    local ped = PlayerPedId()
    local from = GetOffsetFromEntityInWorldCoords(ped, 0.0, -2.9, 0.1)
    local to = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.0, -0.05)
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', from.x, from.y, from.z, 0.0, 0.0, 0.0, 48.0, true, 2)
    PointCamAtCoord(cam, to.x, to.y, to.z)
    RenderScriptCams(true, true, 500, true, true)
end

local function closeScreen()
    if not screenOpen then return end
    screenOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    RenderScriptCams(false, true, 500, true, true)
    if cam then DestroyCam(cam, false) end
    cam = nil
    FreezeEntityPosition(PlayerPedId(), false)
    DisplayRadar(true)
    LocalPlayer.state:set('rnv:screen', false, false)
    applyTattoos()
end

local function openScreen(atArtist)
    if screenOpen then return end
    screenOpen = true
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    -- Face the artist: the camera behind the player is then free
    if atArtist and artistPed then
        local a = GetEntityCoords(artistPed)
        local p = GetEntityCoords(ped)
        SetEntityHeading(ped, GetHeadingFromVector_2d(a.x - p.x, a.y - p.y))
    end
    FreezeEntityPosition(ped, true)
    DisplayRadar(false)
    LocalPlayer.state:set('rnv:screen', true, false)
    startCamera()
    SendNUIMessage({ action = 'open', data = screenData(atArtist) })
    SetNuiFocus(true, true)
end

RegisterNUICallback('preview', function(data, cb)
    applyTattoos(tonumber(data.id))
    cb(1)
end)

RegisterNUICallback('claim', function(data, cb)
    local ok, err = lib.callback.await('rnv-progression:claim', false, tonumber(data.id))
    if not ok then
        local msg = { artist = 'Available only from the Tattoo Artist in Prison', locked = 'Not enough Authority', owned = 'Already tattooed' }
        exports['rnv-interface']:Notify({ text = msg[err] or 'Could not tattoo', type = 'error' })
    end
    cb({ ok = ok })
end)

-- Metadata arrives a moment after the claim; refresh the screen with it
AddEventHandler('rnv:client:onPlayerDataChanged', function()
    if screenOpen then
        SendNUIMessage({ action = 'update', data = screenData(true) })
    end
end)

RegisterNUICallback('close', function(_, cb)
    cb(1)
    closeScreen()
end)

-- TATTOO ARTIST

CreateThread(function()
    local a = Config.Artist
    local hash = joaat(a.model)
    lib.requestModel(hash)
    artistPed = CreatePed(4, hash, a.coords.x, a.coords.y, a.coords.z - 1.0, a.coords.w, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityInvincible(artistPed, true)
    SetBlockingOfNonTemporaryEvents(artistPed, true)
    FreezeEntityPosition(artistPed, true)
    TaskStartScenarioInPlace(artistPed, 'WORLD_HUMAN_SMOKING', 0, true)

    exports['rnv-interface']:AddPrompt({
        id = 'tattoo_artist',
        coords = vec3(a.coords.x, a.coords.y, a.coords.z + 0.3),
        title = 'TATTOO ARTIST',
        label = 'Authority',
        distance = 2.0,
        onSelect = function()
            -- Tutorial first talk (rnv-missions), afterwards the Authority screen
            if GetResourceState('rnv-missions') == 'started' and exports['rnv-missions']:HasDialogue('artist') then
                exports['rnv-missions']:StartDialogue('artist', artistPed)
            else
                openScreen(true)
            end
        end,
    })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeScreen()
    if artistPed then DeleteEntity(artistPed) end
    exports['rnv-interface']:RemovePrompt('tattoo_artist')
end)

-- Other resources (pause menu) open the screen for preview only
exports('OpenAuthority', function() openScreen(false) end)

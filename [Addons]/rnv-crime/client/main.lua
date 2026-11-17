-- Crime prompts (only while Criminal), progress bars, Pacific Standard vault door. Shops are in rnv-marketrob

local crimeState = { targets = {} }

local labels = { vault = 'DRILLING...' }
local whyText = {
    tool = 'You need the right [[tool]]',
    locked = 'Open the [[locked room]] first',
    robbed = 'Already [[robbed]]',
}

local function isCriminal()
    return LocalPlayer.state['rnv:role'] == 'criminal'
end

local function rob(t)
    local time, why = lib.callback.await('rnv-crime:start', false, t.id)
    if not time then
        if whyText[why] then exports['rnv-interface']:Notify({ text = whyText[why], type = 'error', duration = 4000 }) end
        return
    end
    local ok = exports['rnv-interface']:Progress({ label = labels[t.kind] or 'OPENING...', duration = time, canCancel = true })
    if not ok then return TriggerServerEvent('rnv-crime:server:cancel', t.id) end
    local result = lib.callback.await('rnv-crime:finish', false, t.id)
    if result and result.stash then
        exports['rnv-inventory']:openInventory('stash', result.stash)
    end
end

-- PROMPTS

local function refreshPrompts()
    local criminal = isCriminal()
    for _, t in ipairs(Config.Targets) do
        local s = crimeState.targets[t.id] or {}
        local id = 'crime_' .. t.id
        if not criminal or (s.robbed and not (s.open and Config.Containers[t.kind])) or t.kind == 'room' and s.open then
            exports['rnv-interface']:RemovePrompt(id)
        elseif s.open and Config.Containers[t.kind] then
            exports['rnv-interface']:AddPrompt({ id = id, coords = t.coords + vec3(0.0, 0.0, 0.6), title = t.title, label = 'Open', distance = Config.UseDistance,
                onSelect = function() exports['rnv-inventory']:openInventory('stash', 'crime_' .. t.id) end })
        else
            exports['rnv-interface']:AddPrompt({ id = id, coords = t.coords + vec3(0.0, 0.0, 0.6), title = t.title, label = t.label, distance = Config.UseDistance,
                onSelect = function() rob(t) end })
        end
    end
end

-- VAULT DOOR

local function setVault(open)
    local d = Config.VaultDoor
    local door = GetClosestObjectOfType(d.coords.x, d.coords.y, d.coords.z, 2.0, joaat(d.model), false, false, false)
    if door == 0 then return end
    if not d.closed then d.closed = GetEntityHeading(door) end
    FreezeEntityPosition(door, true)
    SetEntityHeading(door, open and (d.closed + d.open) or d.closed)
end

CreateThread(function()
    local g = Config.VaultGate
    AddDoorToSystem(joaat('rnv_vault_gate'), joaat(g.model), g.coords.x, g.coords.y, g.coords.z, false, false, false)
    DoorSystemSetDoorState(joaat('rnv_vault_gate'), 0, false, false)
    while true do
        Wait(2000)
        local s = crimeState.targets.bank_vault
        setVault(s and s.open)
    end
end)

-- STATE

local function applyState(s)
    crimeState = s or { targets = {} }
    refreshPrompts()
end

RegisterNetEvent('rnv-crime:client:state', applyState)

AddStateBagChangeHandler('rnv:role', ('player:%s'):format(GetPlayerServerId(PlayerId())), function()
    Wait(0)
    refreshPrompts()
end)

CreateThread(function()
    applyState(lib.callback.await('rnv-crime:state', false))
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, t in ipairs(Config.Targets) do exports['rnv-interface']:RemovePrompt('crime_' .. t.id) end
    setVault(false)
end)

-- Motel owner's menu: Talk (tutorial), Black Market, Cash Stash, Pay Debt

local ownerPed = nil
local debtOpen = false

-- PAY DEBT SCREEN

local function closeDebt()
    if not debtOpen then return end
    debtOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerScreenblurFadeOut(300)
    DisplayRadar(true)
    LocalPlayer.state:set('rnv:screen', false, false)
end

local function openDebt()
    local status = lib.callback.await('rnv-motel:debtStatus', false)
    if not status.account then
        return exports['rnv-interface']:Notify({ text = 'You need a [[bank account]] first', type = 'error', duration = 4000 })
    end
    debtOpen = true
    LocalPlayer.state:set('rnv:screen', true, false)
    TriggerScreenblurFadeIn(300)
    DisplayRadar(false)
    SendNUIMessage({ action = 'debt', debt = status.debt, balance = status.balance })
    SetNuiFocus(true, true)
end

RegisterNUICallback('cancel', function(_, cb)
    cb(1)
    closeDebt()
end)

local refreshMenu

RegisterNUICallback('confirm', function(_, cb)
    cb(1)
    closeDebt()
    local ok = lib.callback.await('rnv-motel:payDebt', false)
    if not ok then
        exports['rnv-interface']:Notify({ text = 'Not enough [[bank balance]]', type = 'error', duration = 4000 })
    end
    refreshMenu()
end)

-- LENNY MENU

refreshMenu = function()
    local options = {}
    if GetResourceState('rnv-missions') == 'started' and exports['rnv-missions']:HasDialogue('owner') then
        options[#options + 1] = { label = 'Talk', icon = 'speak', onSelect = function() exports['rnv-missions']:StartDialogue('owner', ownerPed) end }
    end
    if GetResourceState('rnv-blackmarket') == 'started' then
        options[#options + 1] = { label = 'Black Market', icon = 'cash', onSelect = function() exports['rnv-blackmarket']:Open('market') end }
    end
    options[#options + 1] = { label = 'Cash Stash', icon = 'cash', onSelect = function() exports['rnv-inventory']:openInventory('stash', Config.Stash.id) end }
    local status = lib.callback.await('rnv-motel:debtStatus', false)
    if status.objective == 'active' then
        options[#options + 1] = { label = 'Pay Debt', icon = 'card', onSelect = openDebt }
    end

    local c = Config.Owner.coords
    exports['rnv-interface']:AddPrompt({
        id = 'owner', coords = vec3(c.x, c.y, c.z + 0.3), title = 'MOTEL OWNER', distance = Config.UseDistance, options = options,
    })
end

-- Tutorial stage or objectives changed (rnv-missions sends its state)
RegisterNetEvent('rnv-missions:client:state', function()
    Wait(0)
    refreshMenu()
end)

CreateThread(function()
    local c = Config.Owner.coords
    local hash = joaat(Config.Owner.model)
    lib.requestModel(hash)
    ownerPed = CreatePed(4, hash, c.x, c.y, c.z - 1.0, c.w, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityInvincible(ownerPed, true)
    SetBlockingOfNonTemporaryEvents(ownerPed, true)
    FreezeEntityPosition(ownerPed, true)
    TaskStartScenarioInPlace(ownerPed, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)

    while not LocalPlayer.state['rnv:spawned'] do Wait(1000) end
    refreshMenu()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeDebt()
    if ownerPed then DeleteEntity(ownerPed) end
    exports['rnv-interface']:RemovePrompt('owner')
end)

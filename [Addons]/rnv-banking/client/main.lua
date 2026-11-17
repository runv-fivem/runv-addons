-- Bank Employee + ATM option prompts and the bank screens (open account / withdraw)

local employeePed = nil
local screen = nil -- 'open' | 'withdraw'
local withdrawAt = nil

local function notify(text, kind)
    exports['rnv-interface']:Notify({ text = text, type = kind or 'error', duration = 4000 })
end

local function money(n)
    local s = tostring(math.floor(n))
    while true do
        local k
        s, k = s:gsub('^(%d+)(%d%d%d)', '%1.%2')
        if k == 0 then break end
    end
    return '$' .. s
end

-- SCREENS

local function openScreen(kind, data)
    screen = kind
    LocalPlayer.state:set('rnv:screen', true, false)
    TriggerScreenblurFadeIn(300)
    DisplayRadar(false)
    data.action = kind
    SendNUIMessage(data)
    SetNuiFocus(true, true)
end

local function closeScreen()
    if not screen then return end
    screen = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerScreenblurFadeOut(300)
    DisplayRadar(true)
    LocalPlayer.state:set('rnv:screen', false, false)
end

local refreshEmployee

local function startOpen()
    local status = lib.callback.await('rnv-banking:status', false)
    if status.opened then return refreshEmployee(status) end
    openScreen('open', { fee = money(status.fee) })
end

local function startWithdraw(at)
    local status = lib.callback.await('rnv-banking:status', false)
    if not status.opened then return notify('You need a [[bank account]] first') end
    withdrawAt = at
    openScreen('withdraw', { balance = status.balance, balanceText = money(status.balance) })
end

RegisterNUICallback('cancel', function(_, cb)
    cb(1)
    closeScreen()
end)

RegisterNUICallback('confirm', function(data, cb)
    cb(1)
    local kind = screen
    closeScreen()
    if kind == 'open' then
        local ok, why = lib.callback.await('rnv-banking:open', false)
        if ok then
            refreshEmployee({ opened = true })
        elseif why == 'cash' then
            notify('Not enough [[cash]]')
        elseif why == 'role' then
            notify('Only a [[Civilian]] can open an account')
        end
    elseif kind == 'withdraw' then
        local ok, why = lib.callback.await('rnv-banking:withdraw', false, tonumber(data.amount), withdrawAt)
        if not ok and why == 'funds' then notify('Not enough [[balance]]') end
        if not ok and why == 'space' then notify('No space in your [[bag]]') end
    end
end)

-- BANK EMPLOYEE

refreshEmployee = function(status)
    local e = Config.Employee
    local option
    if status.opened then
        option = { label = 'Withdraw Cash', icon = 'cash', onSelect = function() startWithdraw('employee') end }
    else
        option = { label = 'Open Account', price = money(status.fee or Config.OpenFee), icon = 'card', onSelect = startOpen }
    end
    exports['rnv-interface']:AddPrompt({
        id = 'bank_employee', coords = e.prompt, title = 'BANK EMPLOYEE', distance = e.distance,
        options = { option },
    })
end

CreateThread(function()
    local e = Config.Employee
    local hash = joaat(e.model)
    lib.requestModel(hash)
    employeePed = CreatePed(4, hash, e.ped.x, e.ped.y, e.ped.z, e.ped.w, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityInvincible(employeePed, true)
    SetBlockingOfNonTemporaryEvents(employeePed, true)
    FreezeEntityPosition(employeePed, true)

    while not LocalPlayer.state['rnv:spawned'] do Wait(1000) end
    refreshEmployee(lib.callback.await('rnv-banking:status', false))
end)

-- ATMs (Config.Atms)

CreateThread(function()
    local current = nil
    while true do
        Wait(500)
        local pos = GetEntityCoords(PlayerPedId())
        local found = nil
        for i, atm in ipairs(Config.Atms) do
            if #(pos - atm) <= Config.AtmDistance + 0.5 then found = i break end
        end
        if found ~= current then
            current = found
            if found then
                local atm = Config.Atms[found]
                exports['rnv-interface']:AddPrompt({
                    id = 'atm', coords = vec3(atm.x, atm.y, atm.z + 1.2), title = 'ATM', distance = Config.AtmDistance + 0.5,
                    options = { { label = 'Withdraw Cash', icon = 'cash', onSelect = function() startWithdraw('atm') end } },
                })
            else
                exports['rnv-interface']:RemovePrompt('atm')
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeScreen()
    if employeePed then DeleteEntity(employeePed) end
    exports['rnv-interface']:RemovePrompt('bank_employee')
    exports['rnv-interface']:RemovePrompt('atm')
end)

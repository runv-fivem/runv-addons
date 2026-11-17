-- Prompts for the machines on the player's plot (option menu) and the GROW TABLE panel

local shown = {}

local function notify(text)
    exports['rnv-interface']:Notify({ text = text, type = 'error', duration = 4000 })
end

local function onGround(point)
    local ok, z = GetGroundZFor_3dCoord(point.x, point.y, point.z + 50.0, false)
    return vec3(point.x, point.y, (ok and z or point.z) + 1.1)
end

local function clock(seconds)
    return ('%d:%02d'):format(math.floor(seconds / 60), seconds % 60)
end

local function openGrow()
    local data = lib.callback.await('rnv-production:growData', false)
    if not data then return end
    exports['rnv-inventory']:openMarket(data)
    CreateThread(function()
        while LocalPlayer.state.invOpen do
            Wait(2000)
            local fresh = lib.callback.await('rnv-production:growData', false)
            if not fresh or not LocalPlayer.state.invOpen then break end
            exports['rnv-inventory']:updateMarket(fresh)
        end
    end)
end

local function workbenchOptions(kind, s)
    local m = Config.Machines[kind]
    if s.state == 'idle' then
        return { { label = m.start, icon = 'card', onSelect = function()
            local ok, why = lib.callback.await('rnv-production:start', false, kind)
            if not ok and why == 'input' then notify('You need [[Valuable Cargo]]') end
        end } }
    elseif s.state == 'busy' then
        return { { label = m.busy .. ' ' .. clock(s.left), icon = 'card', onSelect = function() end } }
    end
    return { { label = m.take, icon = 'card', onSelect = function()
        local ok, why = lib.callback.await('rnv-production:take', false, kind)
        if not ok and why == 'space' then notify('No space in your [[bag]]') end
    end } }
end

-- Rebuild the machine prompts every 2 s (timers count down in the label)
CreateThread(function()
    while true do
        Wait(2000)
        local now = {}
        local status = LocalPlayer.state['rnv:spawned'] and lib.callback.await('rnv-production:status', false)
        if status then
            for kind, s in pairs(status) do
                local id = 'machine_' .. kind
                now[id] = true
                if kind == 'grow' then
                    exports['rnv-interface']:AddPrompt({ id = id, coords = onGround(s.point), title = Config.Grow.title, distance = Config.UseDistance,
                        options = { { label = 'Open', icon = 'card', onSelect = openGrow } } })
                else
                    exports['rnv-interface']:AddPrompt({ id = id, coords = onGround(s.point), title = Config.Machines[kind].title, distance = Config.UseDistance,
                        options = workbenchOptions(kind, s) })
                end
            end
        end
        for id in pairs(shown) do
            if not now[id] then exports['rnv-interface']:RemovePrompt(id) end
        end
        shown = now
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id in pairs(shown) do exports['rnv-interface']:RemovePrompt(id) end
end)

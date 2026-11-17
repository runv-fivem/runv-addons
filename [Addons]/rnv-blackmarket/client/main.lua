-- Suspicious Door prompt + Open export (rnv-motel's owner menu calls Open('market')). Screens are rnv-inventory UI panels

local function open(mode)
    local data = lib.callback.await('rnv-blackmarket:open', false, mode)
    if data then exports['rnv-inventory']:openMarket(data) end
end

CreateThread(function()
    while not LocalPlayer.state['rnv:spawned'] do Wait(1000) end
    exports['rnv-interface']:AddPrompt({
        id = 'suspicious_door', coords = Config.Door, title = 'SUSPICIOUS DOOR', label = 'Open', distance = Config.UseDistance,
        onSelect = function() open('door') end,
    })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    exports['rnv-interface']:RemovePrompt('suspicious_door')
end)

exports('Open', open)

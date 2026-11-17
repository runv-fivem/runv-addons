-- Opens the LAUNDERING DESK panel (rnv-inventory UI) and refreshes it while it is open

local function open()
    local data = lib.callback.await('rnv-laundering:data', false)
    if not data then return end
    exports['rnv-inventory']:openMarket(data)
    CreateThread(function()
        while LocalPlayer.state.invOpen do
            Wait(2000)
            local fresh = lib.callback.await('rnv-laundering:data', false)
            if not fresh or not LocalPlayer.state.invOpen then break end
            exports['rnv-inventory']:updateMarket(fresh)
        end
    end)
end

exports('Open', open)

-- First prison admission. 'prison' metadata = 'done' once the player escaped

local core = exports['rnv-core']

lib.callback.register('rnv-prison:status', function(src)
    return {
        done = core:GetMetadata(src, 'prison') == 'done',
        years = core:GetMetadata(src, 'authority') or 0, -- Authority # = total jail years
    }
end)

RegisterNetEvent('rnv-prison:server:escape', function()
    local src = source
    local pos = GetEntityCoords(GetPlayerPed(src))
    if #(pos - Config.Exit.xyz) > 5.0 then return end
    core:SetMetadata(src, 'prison', 'done')
    if GetResourceState('rnv-missions') == 'started' then
        exports['rnv-missions']:Fact(src, 'prison_escaped')
    end
    core:Save(src)
end)

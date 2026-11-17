-- Tutorial progress = 'tutorial' metadata (index of the next stage; #stages + 1 = done)
-- Named objectives = 'objectives' metadata ({ debt = 'active' | 'done' })

local core = exports['rnv-core']

local function stageOf(src)
    return core:GetMetadata(src, 'tutorial') or 1
end

local function sendState(src)
    local stage = stageOf(src)
    local objectives = core:GetMetadata(src, 'objectives') or {}
    TriggerClientEvent('rnv-missions:client:state', src, {
        stage = stage,
        done = stage > #Config.Tutorial,
        debt = objectives.debt,
    })
end

---A committed fact from a domain resource (prison escape, city arrival, dialogue end)
local function fact(src, name)
    local stage = stageOf(src)
    for i = stage, #Config.Tutorial do
        if Config.Tutorial[i].fact == name then
            core:SetMetadata(src, 'tutorial', i + 1)
            if name == 'artist_talked' then
                local objectives = core:GetMetadata(src, 'objectives') or {}
                objectives.debt = objectives.debt or 'active'
                core:SetMetadata(src, 'objectives', objectives)
            end
            core:Save(src)
            sendState(src)
            return true
        end
    end
    return false
end

RegisterNetEvent('rnv-missions:server:dialogueDone', function(id)
    local src = source
    local dialogue = Config.Dialogues[id]
    local npc = Config.Npcs[id]
    if not dialogue or not npc then return end
    local pos = GetEntityCoords(GetPlayerPed(src))
    if #(pos - vec3(npc.x, npc.y, npc.z)) > 6.0 then return end
    fact(src, dialogue.fact)
end)

RegisterNetEvent('rnv-missions:server:request', function()
    sendState(source)
end)

AddEventHandler('rnv:server:playerLoaded', function(src)
    sendState(src)
end)

---A named objective is finished by its domain resource (rnv-motel pays the debt)
local function completeObjective(src, name)
    local objectives = core:GetMetadata(src, 'objectives') or {}
    if objectives[name] ~= 'active' then return false end
    objectives[name] = 'done'
    core:SetMetadata(src, 'objectives', objectives)
    core:Save(src)
    sendState(src)
    return true
end

exports('Fact', fact)
exports('CompleteObjective', completeObjective)
exports('GetObjective', function(src, name) return (core:GetMetadata(src, 'objectives') or {})[name] end)
exports('GetStage', stageOf)

lib.addCommand('rnv_settutorial', {
    help = 'Set the tutorial stage of a player (1 = start)',
    params = {
        { name = 'target', type = 'playerId', help = 'Player id or "me"' },
        { name = 'stage', type = 'number', help = 'Stage index' },
    },
    restricted = 'group.admin',
}, function(_, args)
    core:SetMetadata(args.target, 'tutorial', math.floor(args.stage))
    core:Save(args.target)
    sendState(args.target)
end)

lib.addCommand('rnv_setobjective', {
    help = 'Set a named objective of a player (e.g. debt active)',
    params = {
        { name = 'target', type = 'playerId', help = 'Player id or "me"' },
        { name = 'name', type = 'string', help = 'Objective name' },
        { name = 'state', type = 'string', help = 'active | done | none' },
    },
    restricted = 'group.admin',
}, function(_, args)
    local objectives = core:GetMetadata(args.target, 'objectives') or {}
    objectives[args.name] = args.state ~= 'none' and args.state or nil
    core:SetMetadata(args.target, 'objectives', objectives)
    core:Save(args.target)
    sendState(args.target)
end)

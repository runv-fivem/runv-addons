-- Notoriety (per city visit, in memory) and Authority + tattoos (permanent, player metadata)

local core = exports['rnv-core']
local notoriety = {} -- src -> { level, points }

-- NOTORIETY

local function syncNotoriety(src)
    local n = notoriety[src]
    Player(src).state:set('rnv:notoriety', n and { level = n.level, bonus = Config.Bonus[n.level] } or false, true)
end

local function partySize(src)
    if GetResourceState('rnv-party') ~= 'started' then return 1 end
    return #exports['rnv-party']:GetPartyMembers(src)
end

local function startVisit(src)
    local size = math.min(math.max(partySize(src), 1), #Config.StartLevel)
    notoriety[src] = { level = Config.StartLevel[size], points = 0 }
    syncNotoriety(src)
end

local function endVisit(src)
    notoriety[src] = nil
    syncNotoriety(src)
end

local function addNotoriety(src, points)
    local n = notoriety[src]
    if not n or type(points) ~= 'number' or points <= 0 then return false end
    n.points = n.points + points
    while n.points >= Config.PointsPerLevel and n.level < Config.MaxLevel do
        n.points = n.points - Config.PointsPerLevel
        n.level = n.level + 1
    end
    syncNotoriety(src)
    return true
end

AddEventHandler('playerDropped', function()
    notoriety[source] = nil
end)

exports('StartVisit', startVisit)
exports('EndVisit', endVisit)
exports('AddNotoriety', addNotoriety)
exports('GetNotoriety', function(src) return notoriety[tonumber(src)] and notoriety[tonumber(src)].level end)
exports('GetBonus', function(src)
    local n = notoriety[tonumber(src)]
    return n and Config.Bonus[n.level]
end)

-- AUTHORITY + TATTOOS

local function getAuthority(src)
    return core:GetMetadata(src, 'authority') or 0
end

local function getTattoos(src)
    return core:GetMetadata(src, 'tattoos') or {}
end

local function addAuthority(src, amount)
    if type(amount) ~= 'number' or amount <= 0 then return false end
    core:SetMetadata(src, 'authority', getAuthority(src) + math.floor(amount))
    core:Save(src)
    return true
end

lib.callback.register('rnv-progression:claim', function(src, id)
    local tattoo = Config.Tattoos[id]
    if not tattoo then return false, 'invalid' end
    local pos = GetEntityCoords(GetPlayerPed(src))
    if #(pos - Config.Artist.coords.xyz) > 4.0 then return false, 'artist' end
    if getAuthority(src) < tattoo.threshold then return false, 'locked' end

    local owned = getTattoos(src)
    for _, t in ipairs(owned) do
        if t == id then return false, 'owned' end
    end
    owned[#owned + 1] = id
    core:SetMetadata(src, 'tattoos', owned)
    core:Save(src)
    return true
end)

exports('GetAuthority', getAuthority)
exports('AddAuthority', addAuthority)
exports('GetTattoos', getTattoos)

lib.addCommand('rnv_setauthority', {
    help = 'Set Authority (jail years) of a player',
    params = {
        { name = 'target', type = 'playerId', help = 'Player id or "me"' },
        { name = 'amount', type = 'number', help = 'Authority #' },
    },
    restricted = 'group.admin',
}, function(src, args)
    core:SetMetadata(args.target, 'authority', math.max(0, math.floor(args.amount)))
    core:Save(args.target)
end)

-- Clans: create (bank fee), join/request/invite, ranks, kick/leave/disband, announcement, treasury (Core 'group' account),
-- districts (claims, conflicts by zone control), district tax and laundering bonus

local core = exports['rnv-core']

local clans = {}      -- id -> clan row
local members = {}    -- citizenid -> { clan, rank, rep, name, last_seen }
local requests = {}   -- clan id -> { citizenid -> name }
local events = {}     -- clan id -> { {kind, title, text, at} } newest first
local districts = {}  -- district -> { clan, pending }
local claims = {}     -- district -> { clan, endsAt }
local conflicts = {}  -- district -> { attacker, defender, startsAt, endsAt, score = { [clanId] = n } }
local invites = {}    -- target src -> { clan, from }

local RANK = { Leader = 1, Officer = 2, Fighter = 3, Recruit = 4 }

-- HELPERS

local function cidOf(src)
    local p = core:GetPlayer(src)
    return p and p.citizenid, p
end

local function srcOf(cid)
    for src, p in pairs(core:GetPlayers()) do
        if p.citizenid == cid then return tonumber(src) end
    end
end

local function notify(src, text, kind, extra)
    local data = { text = text, type = kind or 'inform', duration = 6000 }
    for k, v in pairs(extra or {}) do data[k] = v end
    exports['rnv-interface']:Notify(src, data)
end

local function account(id)
    return core:GetAccount('group', 'clan:' .. id, 'bank')
end

local function bankOf(src)
    local cid = cidOf(src)
    return cid and core:GetAccount('player', cid, 'bank')
end

local function count(id)
    local n = 0
    for _, m in pairs(members) do if m.clan == id then n = n + 1 end end
    return n
end

local function event(id, kind, title, text)
    events[id] = events[id] or {}
    table.insert(events[id], 1, { kind = kind, title = title, text = text, at = os.time() })
    if #events[id] > 30 then table.remove(events[id]) end
    MySQL.insert('INSERT INTO runv_clan_events (clan_id, kind, title, text, at) VALUES (?, ?, ?, ?, ?)', { id, kind, title, text, os.time() })
end

local function saveMember(cid)
    local m = members[cid]
    if not m then
        MySQL.update('DELETE FROM runv_clan_members WHERE citizenid = ?', { cid })
        return
    end
    MySQL.update('INSERT INTO runv_clan_members (citizenid, clan_id, rank_name, rep, name, last_seen) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE clan_id = VALUES(clan_id), rank_name = VALUES(rank_name), rep = VALUES(rep), name = VALUES(name), last_seen = VALUES(last_seen)',
        { cid, m.clan, m.rank, m.rep, m.name, m.last_seen })
end

local function saveClan(id)
    local c = clans[id]
    MySQL.update('UPDATE runv_clans SET emblem = ?, language = ?, entry = ?, description = ?, announcement = ?, announce_by = ?, reputation = ? WHERE id = ?',
        { c.emblem, c.language, c.entry, c.description, c.announcement, c.announce_by, c.reputation, id })
end

local function saveDistrict(name)
    local d = districts[name]
    MySQL.update('INSERT INTO runv_districts (district, clan_id, pending) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE clan_id = VALUES(clan_id), pending = VALUES(pending)', { name, d.clan, d.pending })
end

local function canManage(cid)
    local m = members[cid]
    return m and RANK[m.rank] <= 2
end

local function controlled(id)
    local list = {}
    for name, d in pairs(districts) do
        if d.clan == id then list[#list + 1] = name end
    end
    return list
end

local function launderingBonus(id)
    local bonus = 0
    for _, name in ipairs(controlled(id)) do bonus = bonus + Config.Districts[name].laundering end
    return bonus
end

local function addMember(id, cid, name, rank)
    members[cid] = { clan = id, rank = rank, rep = 0, name = name, last_seen = os.time() }
    saveMember(cid)
    if requests[id] then requests[id][cid] = nil end
    MySQL.update('DELETE FROM runv_clan_requests WHERE citizenid = ?', { cid })
end

-- LOAD

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS runv_clans (
        id INT AUTO_INCREMENT PRIMARY KEY, cycle_id INT NOT NULL, name VARCHAR(32) NOT NULL UNIQUE, tag VARCHAR(8) NOT NULL UNIQUE,
        emblem INT NOT NULL DEFAULT 1, language VARCHAR(32) NOT NULL, entry VARCHAR(16) NOT NULL DEFAULT 'open',
        description TEXT NULL, announcement TEXT NULL, announce_by VARCHAR(32) NULL, reputation INT NOT NULL DEFAULT 0, created INT NOT NULL)]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS runv_clan_members (
        citizenid VARCHAR(50) PRIMARY KEY, clan_id INT NOT NULL, rank_name VARCHAR(16) NOT NULL, rep INT NOT NULL DEFAULT 0,
        name VARCHAR(32) NULL, last_seen INT NOT NULL DEFAULT 0)]])
    MySQL.query.await('CREATE TABLE IF NOT EXISTS runv_clan_requests (clan_id INT NOT NULL, citizenid VARCHAR(50) NOT NULL, name VARCHAR(32) NULL, PRIMARY KEY (clan_id, citizenid))')
    MySQL.query.await('CREATE TABLE IF NOT EXISTS runv_clan_events (id INT AUTO_INCREMENT PRIMARY KEY, clan_id INT NOT NULL, kind VARCHAR(16) NOT NULL, title VARCHAR(64) NOT NULL, text VARCHAR(255) NOT NULL, at INT NOT NULL)')
    MySQL.query.await('CREATE TABLE IF NOT EXISTS runv_districts (district VARCHAR(32) PRIMARY KEY, clan_id INT NULL, pending INT NOT NULL DEFAULT 0)')

    while not GlobalState.rnvCycle do Wait(100) end
    for _, c in ipairs(MySQL.query.await('SELECT * FROM runv_clans WHERE cycle_id = ?', { GlobalState.rnvCycle }) or {}) do
        clans[c.id] = c
    end
    for _, m in ipairs(MySQL.query.await('SELECT * FROM runv_clan_members') or {}) do
        if clans[m.clan_id] then members[m.citizenid] = { clan = m.clan_id, rank = m.rank_name, rep = m.rep, name = m.name, last_seen = m.last_seen } end
    end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM runv_clan_requests') or {}) do
        requests[r.clan_id] = requests[r.clan_id] or {}
        requests[r.clan_id][r.citizenid] = r.name
    end
    for _, e in ipairs(MySQL.query.await('SELECT * FROM runv_clan_events ORDER BY id DESC LIMIT 500') or {}) do
        events[e.clan_id] = events[e.clan_id] or {}
        if #events[e.clan_id] < 30 then events[e.clan_id][#events[e.clan_id] + 1] = { kind = e.kind, title = e.title, text = e.text, at = e.at } end
    end
    for _, d in ipairs(MySQL.query.await('SELECT * FROM runv_districts') or {}) do
        if Config.Districts[d.district] then districts[d.district] = { clan = clans[d.clan_id] and d.clan_id or nil, pending = d.pending } end
    end
    for name in pairs(Config.Districts) do districts[name] = districts[name] or { pending = 0 } end
end)

-- VIEW (everything the clan screens show)

local function memberStatus(cid, m)
    local src = srcOf(cid)
    if not src then
        return { online = false, text = ('Online %d min ago'):format(math.floor((os.time() - (m.last_seen or os.time())) / 60)) }
    end
    local inCity = GetResourceState('rnv-progression') == 'started' and exports['rnv-progression']:GetNotoriety(src)
    return { online = true, text = inCity and 'Los Santos' or 'Motel' }
end

local function view(src)
    local cid, player = cidOf(src)
    local bank = bankOf(src)
    local base = { bank = bank and bank.balance or 0, hasAccount = bank ~= nil, fee = Config.CreateFee, languages = Config.Languages,
        emblems = Config.Emblems, nameLength = Config.NameLength, tagLength = Config.TagLength, descLength = Config.DescLength }
    local me = cid and members[cid]
    if not me then
        base.mode = 'intro'
        return base
    end
    local c = clans[me.clan]
    local acc = account(me.clan)
    local list = {}
    for mcid, m in pairs(members) do
        if m.clan == me.clan then
            list[#list + 1] = { cid = mcid, name = m.name, rank = m.rank, rep = m.rep, you = mcid == cid, status = memberStatus(mcid, m) }
        end
    end
    table.sort(list, function(a, b)
        if RANK[a.rank] ~= RANK[b.rank] then return RANK[a.rank] < RANK[b.rank] end
        return (a.name or '') < (b.name or '')
    end)
    local reqs = {}
    for rcid, name in pairs(requests[me.clan] or {}) do reqs[#reqs + 1] = { cid = rcid, name = name } end

    local owned, claimList, conflictList = {}, {}, {}
    for name, d in pairs(districts) do
        local cfg = Config.Districts[name]
        if d.clan == me.clan then
            owned[#owned + 1] = { id = name, label = cfg.label, laundering = cfg.laundering, tax = cfg.tax }
        end
        local cl = claims[name]
        if cl and cl.clan == me.clan then claimList[#claimList + 1] = { label = cfg.label, left = math.max(0, cl.endsAt - os.time()) } end
        local cf = conflicts[name]
        if cf and (cf.attacker == me.clan or cf.defender == me.clan) then
            local enemy = clans[cf.attacker == me.clan and cf.defender or cf.attacker]
            conflictList[#conflictList + 1] = { label = cfg.label, enemy = enemy and ('[' .. enemy.tag .. '] ' .. enemy.name) or '-',
                startsIn = math.max(0, cf.startsAt - os.time()), left = math.max(0, cf.endsAt - os.time()),
                us = cf.score[me.clan] or 0, them = cf.score[cf.attacker == me.clan and cf.defender or cf.attacker] or 0 }
        end
    end

    base.mode = 'clan'
    base.me = { cid = cid, rank = me.rank, manage = RANK[me.rank] <= 2, leader = me.rank == 'Leader' }
    base.clan = { id = c.id, name = c.name, tag = c.tag, emblem = c.emblem, language = c.language, entry = c.entry, description = c.description or '',
        announcement = c.announcement or '', announceBy = c.announce_by or '', reputation = c.reputation, balance = acc and acc.balance or 0,
        members = #list, max = Config.MaxMembers }
    base.bonuses = { laundering = launderingBonus(c.id), districts = #owned, businesses = 0 }
    base.events = events[c.id] or {}
    base.memberList = list
    base.requests = reqs
    base.owned = owned
    base.claims = claimList
    base.conflicts = conflictList
    base.taxIn = Config.TaxInterval - (os.time() % Config.TaxInterval)
    base.ranks = Config.Ranks
    return base
end

lib.callback.register('rnv-clans:view', function(src)
    return view(src)
end)

-- CREATE

lib.callback.register('rnv-clans:create', function(src, data)
    local cid, player = cidOf(src)
    if not cid or members[cid] or type(data) ~= 'table' then return false end
    local name = tostring(data.name or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local tag = tostring(data.tag or ''):gsub('%s', '')
    local desc = tostring(data.description or ''):sub(1, Config.DescLength)
    local emblem = math.floor(tonumber(data.emblem) or 1)
    if #name < 3 or #name > Config.NameLength or #tag < 2 or #tag > Config.TagLength then return false, 'name' end
    if emblem < 1 or emblem > Config.Emblems then return false end
    local language = 'English'
    for _, l in ipairs(Config.Languages) do if l == data.language then language = l end end
    local entry = data.entry == 'request' and 'request' or 'open'
    for _, c in pairs(clans) do
        if c.name:lower() == name:lower() or c.tag:lower() == tag:lower() then return false, 'taken' end
    end
    local bank = bankOf(src)
    if not bank then return false, 'account' end
    local ok = core:RemoveMoney(bank.id, Config.CreateFee, 'clan_create')
    if not ok then return false, 'funds' end

    local id = MySQL.insert.await('INSERT INTO runv_clans (cycle_id, name, tag, emblem, language, entry, description, created) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { GlobalState.rnvCycle, name, tag, emblem, language, entry, desc, os.time() })
    if not id then
        core:AddMoney(bank.id, Config.CreateFee, 'clan_create_refund')
        return false, 'taken'
    end
    clans[id] = { id = id, name = name, tag = tag, emblem = emblem, language = language, entry = entry, description = desc, reputation = 0 }
    core:OpenAccount('group', 'clan:' .. id, 'bank')
    addMember(id, cid, player.name, 'Leader')
    event(id, 'new', 'NEW CLAN', player.name .. ' created the clan')
    return view(src)
end)

-- SEARCH / JOIN

lib.callback.register('rnv-clans:search', function(_, query, openOnly, language)
    query = tostring(query or ''):lower()
    local list = {}
    for id, c in pairs(clans) do
        local okName = query == '' or c.name:lower():find(query, 1, true) or c.tag:lower():find(query, 1, true)
        local okLang = not language or language == 'Any Language' or c.language == language
        if okName and okLang and (not openOnly or c.entry == 'open') then
            list[#list + 1] = { id = id, name = c.name, tag = c.tag, emblem = c.emblem, reputation = c.reputation, members = count(id), max = Config.MaxMembers,
                language = c.language, entry = c.entry, description = c.description or '', districts = #controlled(id), businesses = 0 }
        end
    end
    table.sort(list, function(a, b) return a.members > b.members end)
    return list
end)

lib.callback.register('rnv-clans:join', function(src, id)
    local cid, player = cidOf(src)
    local c = clans[tonumber(id)]
    if not cid or not c or members[cid] then return false end
    if count(c.id) >= Config.MaxMembers then return false, 'full' end
    if c.entry == 'open' then
        addMember(c.id, cid, player.name, 'Recruit')
        event(c.id, 'member', 'NEW CLAN MEMBER', player.name .. ' joined the clan')
        return view(src)
    end
    requests[c.id] = requests[c.id] or {}
    requests[c.id][cid] = player.name
    MySQL.insert('INSERT IGNORE INTO runv_clan_requests (clan_id, citizenid, name) VALUES (?, ?, ?)', { c.id, cid, player.name })
    for mcid, m in pairs(members) do
        local msrc = m.clan == c.id and RANK[m.rank] <= 2 and srcOf(mcid)
        if msrc then notify(msrc, '[[' .. player.name .. ']] wants to join the clan', 'inform') end
    end
    return false, 'requested'
end)

lib.callback.register('rnv-clans:answerRequest', function(src, target, accept)
    local cid = cidOf(src)
    if not canManage(cid) then return false end
    local id = members[cid].clan
    local name = requests[id] and requests[id][target]
    if not name then return false end
    requests[id][target] = nil
    MySQL.update('DELETE FROM runv_clan_requests WHERE clan_id = ? AND citizenid = ?', { id, target })
    if accept and not members[target] and count(id) < Config.MaxMembers then
        addMember(id, target, name, 'Recruit')
        event(id, 'member', 'NEW CLAN MEMBER', name .. ' joined the clan')
    end
    return view(src)
end)

-- INVITE (by user id, Y/N card like party invites)

lib.callback.register('rnv-clans:invite', function(src, userId)
    local cid, player = cidOf(src)
    if not canManage(cid) then return false end
    local id = members[cid].clan
    if count(id) >= Config.MaxMembers then return false, 'full' end
    for tsrc, p in pairs(core:GetPlayers()) do
        if tostring(p.userId) == tostring(userId) then
            tsrc = tonumber(tsrc)
            if members[p.citizenid] then return false, 'member' end
            invites[tsrc] = { clan = id, from = player.name }
            TriggerClientEvent('rnv-clans:client:invite', tsrc, ('[[%s]] invites you to [[[%s] %s]]'):format(player.name, clans[id].tag, clans[id].name), Config.InviteTime)
            SetTimeout(Config.InviteTime * 1000, function() invites[tsrc] = nil end)
            return true
        end
    end
    return false, 'offline'
end)

RegisterNetEvent('rnv-clans:server:inviteAnswer', function(accept)
    local src = source
    local inv = invites[src]
    invites[src] = nil
    if not inv or not accept then return end
    local cid, player = cidOf(src)
    if not cid or members[cid] or not clans[inv.clan] or count(inv.clan) >= Config.MaxMembers then return end
    addMember(inv.clan, cid, player.name, 'Recruit')
    event(inv.clan, 'member', 'NEW CLAN MEMBER', player.name .. ' joined the clan')
    notify(src, 'You joined [[' .. clans[inv.clan].name .. ']]', 'success')
end)

-- ROSTER

lib.callback.register('rnv-clans:setRank', function(src, target, rank)
    local cid = cidOf(src)
    local me, other = members[cid], members[target]
    if not me or not other or other.clan ~= me.clan or target == cid or not RANK[rank] then return false end
    if RANK[me.rank] >= RANK[other.rank] then return false end          -- only over lower ranks
    if rank == 'Leader' then
        if me.rank ~= 'Leader' then return false end
        me.rank = 'Officer'
        saveMember(cid)
    elseif RANK[rank] <= RANK[me.rank] then
        return false                                                     -- can't raise someone to your own rank
    end
    other.rank = rank
    saveMember(target)
    event(me.clan, 'rank', rank:upper() .. ' NEW RANK', (other.name or '?') .. ' earned a new rank')
    return view(src)
end)

lib.callback.register('rnv-clans:kick', function(src, target)
    local cid = cidOf(src)
    local me, other = members[cid], members[target]
    if not me or not other or other.clan ~= me.clan or target == cid then return false end
    if RANK[me.rank] > 2 or RANK[me.rank] >= RANK[other.rank] then return false end
    members[target] = nil
    saveMember(target)
    event(me.clan, 'kick', 'MEMBER LEFT', (other.name or '?') .. ' was kicked')
    return view(src)
end)

local function disband(id, leaderSrc)
    local acc = account(id)
    local bank = leaderSrc and bankOf(leaderSrc)
    if acc and acc.balance > 0 and bank then core:Transfer(acc.id, bank.id, acc.balance, 'clan_disband') end
    for mcid, m in pairs(members) do
        if m.clan == id then members[mcid] = nil saveMember(mcid) end
    end
    for name, d in pairs(districts) do
        if d.clan == id then d.clan = nil saveDistrict(name) end
    end
    clans[id] = nil
    MySQL.update('DELETE FROM runv_clans WHERE id = ?', { id })
end

lib.callback.register('rnv-clans:leave', function(src)
    local cid = cidOf(src)
    local me = members[cid]
    if not me then return false end
    if me.rank == 'Leader' then
        if count(me.clan) > 1 then return false, 'leader' end
        disband(me.clan, src)
    else
        local id = me.clan
        members[cid] = nil
        saveMember(cid)
        event(id, 'leave', 'MEMBER LEFT', (me.name or '?') .. ' left the clan')
    end
    return view(src)
end)

lib.callback.register('rnv-clans:edit', function(src, data)
    local cid, player = cidOf(src)
    if not canManage(cid) or type(data) ~= 'table' then return false end
    local c = clans[members[cid].clan]
    if data.announcement ~= nil then
        c.announcement = tostring(data.announcement):sub(1, 250)
        c.announce_by = player.name
    end
    if data.description ~= nil then c.description = tostring(data.description):sub(1, Config.DescLength) end
    if data.entry == 'open' or data.entry == 'request' then c.entry = data.entry end
    saveClan(c.id)
    return view(src)
end)

-- TREASURY: Leader moves the whole clan balance to their own bank account (TRANSFER TO ACCOUNT)
lib.callback.register('rnv-clans:transfer', function(src)
    local cid = cidOf(src)
    local me = members[cid]
    if not me or me.rank ~= 'Leader' then return false end
    local acc, bank = account(me.clan), bankOf(src)
    if not acc or not bank or acc.balance <= 0 then return false end
    core:Transfer(acc.id, bank.id, acc.balance, 'clan_transfer')
    return view(src)
end)

-- DISTRICTS

local function winDistrict(name, id, kind)
    local d = districts[name]
    local old = d.clan
    d.clan = id
    saveDistrict(name)
    local label = Config.Districts[name].label
    if id then
        clans[id].reputation = clans[id].reputation + 10
        saveClan(id)
        event(id, 'victory', 'VICTORY', 'Your clan controls district ' .. label .. ' now')
        if kind == 'claim' then event(id, 'victory', 'VICTORY CLAIM WON', 'Claim for district ' .. label .. ' won') end
    end
    if old and old ~= id and clans[old] then event(old, 'defeat', 'DEFEAT CONFLICT LOST!', 'Conflict for district ' .. label .. ' ended in defeat') end
end

lib.callback.register('rnv-clans:claim', function(src, name)
    local cid = cidOf(src)
    local cfg = Config.Districts[name]
    if not cfg or not canManage(cid) then return false, 'rank' end
    if #(GetEntityCoords(GetPlayerPed(src)) - cfg.board) > 6.0 then return false end
    local id = members[cid].clan
    local d = districts[name]
    if d.clan == id then return false, 'owned' end
    if claims[name] or conflicts[name] then return false, 'busy' end
    if d.clan then
        local now = os.time()
        conflicts[name] = { attacker = id, defender = d.clan, startsAt = now + Config.ConflictDelay, endsAt = now + Config.ConflictDelay + Config.ConflictTime, score = {} }
        event(id, 'conflict', 'CONFLICT', 'Conflict for district ' .. cfg.label .. ' scheduled')
        event(d.clan, 'conflict', 'CONFLICT', '[' .. clans[id].tag .. '] attacks district ' .. cfg.label)
        return true, 'conflict'
    end
    claims[name] = { clan = id, endsAt = os.time() + Config.ClaimTime }
    event(id, 'claim', 'CLAIM STARTED', 'Claim for district ' .. cfg.label .. ' started')
    return true, 'claim'
end)

-- Conflict score: each tick, the clan with more living members inside the district zone gets a point
local function zoneCount(id, cfg)
    local n = 0
    for mcid, m in pairs(members) do
        local msrc = m.clan == id and srcOf(mcid)
        if msrc and core:GetLifeState(msrc) == 'alive' and #(GetEntityCoords(GetPlayerPed(msrc)) - cfg.center) <= cfg.radius then n = n + 1 end
    end
    return n
end

CreateThread(function()
    while true do
        Wait(Config.ConflictTick * 1000)
        local now = os.time()
        for name, cl in pairs(claims) do
            if now >= cl.endsAt then
                claims[name] = nil
                if clans[cl.clan] then winDistrict(name, cl.clan, 'claim') end
            end
        end
        for name, cf in pairs(conflicts) do
            local cfg = Config.Districts[name]
            if now >= cf.startsAt and now < cf.endsAt then
                local a, b = zoneCount(cf.attacker, cfg), zoneCount(cf.defender, cfg)
                if a > b then cf.score[cf.attacker] = (cf.score[cf.attacker] or 0) + 1 end
                if b > a then cf.score[cf.defender] = (cf.score[cf.defender] or 0) + 1 end
            elseif now >= cf.endsAt then
                conflicts[name] = nil
                local a, b = cf.score[cf.attacker] or 0, cf.score[cf.defender] or 0
                if a > b and clans[cf.attacker] then winDistrict(name, cf.attacker, 'conflict')
                elseif clans[cf.defender] then event(cf.defender, 'victory', 'VICTORY', 'District ' .. cfg.label .. ' defended') end
                if clans[cf.attacker] and a <= b then event(cf.attacker, 'defeat', 'DEFEAT CONFLICT LOST!', 'Conflict for district ' .. cfg.label .. ' ended in defeat') end
            end
        end
    end
end)

-- TAX: residents of an owned district pay a share of their Black Market spending and laundering into pending;
-- every Config.TaxInterval it moves to the clan balance if the clan leader lives (rents a plot) in that district
local function districtOfPlot(plot)
    for name, cfg in pairs(Config.Districts) do
        for _, p in ipairs(cfg.plots) do if p == plot then return name end end
    end
end

exports('AddTax', function(src, amount)
    if GetResourceState('rnv-housing') ~= 'started' or type(amount) ~= 'number' or amount <= 0 then return end
    local plot = exports['rnv-housing']:GetPlot(src)
    local name = plot and districtOfPlot(plot)
    local d = name and districts[name]
    if not d or not d.clan then return end
    d.pending = d.pending + math.floor(amount * Config.Districts[name].tax / 100)
    saveDistrict(name)
end)

CreateThread(function()
    while true do
        Wait((Config.TaxInterval - (os.time() % Config.TaxInterval)) * 1000 + 1000)
        for name, d in pairs(districts) do
            if d.clan and d.pending > 0 and GetResourceState('rnv-housing') == 'started' then
                local leaderCid
                for mcid, m in pairs(members) do if m.clan == d.clan and m.rank == 'Leader' then leaderCid = mcid end end
                local lsrc = leaderCid and srcOf(leaderCid)
                local lplot = lsrc and exports['rnv-housing']:GetPlot(lsrc)
                if lplot and districtOfPlot(lplot) == name then
                    local acc = account(d.clan)
                    if acc and core:AddMoney(acc.id, d.pending, 'district_tax:' .. name) then
                        event(d.clan, 'tax', 'TAX COLLECTED', ('$%d tax from %s'):format(d.pending, Config.Districts[name].label))
                        d.pending = 0
                        saveDistrict(name)
                    end
                end
            end
        end
    end
end)

-- Laundering speed bonus for a citizen's clan (rnv-laundering asks per desk owner)
exports('GetLaunderBonus', function(cid)
    local m = members[cid]
    return m and launderingBonus(m.clan) or 0
end)

exports('GetClan', function(src)
    local cid = cidOf(src)
    local m = cid and members[cid]
    return m and { id = m.clan, tag = clans[m.clan].tag, name = clans[m.clan].name, rank = m.rank }
end)

-- last seen
AddEventHandler('playerDropped', function()
    local cid = cidOf(source)
    if cid and members[cid] then
        members[cid].last_seen = os.time()
        saveMember(cid)
    end
    invites[source] = nil
end)

AddEventHandler('rnv:server:playerLoaded', function(src, player)
    local m = members[player.citizenid]
    if m then
        m.name = player.name
        m.last_seen = os.time()
        saveMember(player.citizenid)
    end
end)

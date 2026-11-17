Config = {}

-- Clans. Treasury = Core account ('group', 'clan:<id>')
Config.CreateFee = 5000          -- CREATE 5.000, paid from the bank
Config.MaxMembers = 20
Config.NameLength = 16           -- Clan Name * (16)
Config.TagLength = 4             -- Clan Tag * (4)
Config.DescLength = 250
Config.Languages = { 'English', 'Russian', 'Persian', 'Portuguese', 'French', 'German', 'Spanish', 'Turkish' }
Config.Emblems = 12              -- html/img/emblem1..12.png
Config.Ranks = { 'Leader', 'Officer', 'Fighter', 'Recruit' }  -- Leader/Officer manage, Fighter fights, Recruit doesn't
Config.InviteTime = 30

-- Districts (CONTROL OVER BUSINESSES). Claiming: Leader/Officer at the board. Unowned = claim timer;
-- owned by another clan = conflict: zone control (clan with more living members in the zone each tick scores)
Config.Districts = {
    sandy = {
        label = 'SANDY SHORES', board = vec3(1853.4, 3684.5, 34.3), center = vec3(1790.0, 3610.0, 33.0), radius = 120.0,
        laundering = 20, tax = 12,           -- e.g. +20% laundering speed, 12% tax collection
        plots = { 'fruitcake', 'cactus' },  -- rnv-housing plots in this district (their residents pay the tax)
    },
}
Config.ClaimTime = 2 * 60        -- dev values (live timers should be hours)
Config.ConflictDelay = 60
Config.ConflictTime = 5 * 60
Config.ConflictTick = 10
Config.TaxInterval = 5 * 60      -- "Tax collection in": pending tax moves to the clan balance while the leader lives in the district

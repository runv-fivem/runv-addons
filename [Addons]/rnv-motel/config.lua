Config = {}

-- Motel owner at the Dream View Motel. rnv-missions checks dialogue distance to the same point
Config.Owner = { model = 'a_m_m_hillbilly_01', coords = vec4(-112.4, 6322.6, 31.49, 125.0) }
Config.UseDistance = 2.0

-- Cash Stash: money only, per player. Capacity $100,000
Config.Stash = { id = 'motel_cash', label = 'CASH STASH', slots = 6, capacity = 100000 }

-- The motel owner's debt ($1,000,000), paid from the bank account. Missions owns the 'debt' objective
Config.Debt = 1000000

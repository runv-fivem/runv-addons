Config = {}

-- Fence van ($ marker) in Los Santos: drag loot into the FENCE container, SELL, then take the CASH PILE from the counter
-- Parked in the Legion Square lot against the wall, NPC and table on the lot side
Config.Fence = {
    van = { model = 'boxville', coords = vec4(211.7, -780.0, 30.8, 146.0) },
    ped = { model = 'g_m_y_mexgoon_01', coords = vec4(213.9, -781.5, 30.8, 236.0) },
    counter = vec4(215.0, -782.2, 30.8, 236.0), -- table the cash pile lands on
    prompt = vec3(215.6, -782.6, 31.6),
}

-- Smuggler's Van: sells cargo with the Notoriety cargo bonus
Config.Smuggler = {
    van = { model = 'pony', coords = vec4(-1168.0, -1505.0, 4.4, 35.0) },
    ped = { model = 'g_m_m_armboss_01', coords = vec4(-1165.6, -1508.4, 4.4, 35.0) },
    counter = vec4(-1166.8, -1508.9, 4.4, 35.0),
    prompt = vec3(-1166.0, -1507.6, 5.2),
}

Config.UseDistance = 2.0

-- Prices come from the item data (rnv-inventory items `rnv.sell`), filled at start:
-- the Fence buys anything with a sell price, the Smuggler full Cargo Sheets. Notoriety bonuses are added on top
Config.Loot = {}
Config.Cargo = {}

-- Fence: one shared container for everyone at the van (126 slots = 6 x 21, scrolls). Sale bonus grows with the deal:
-- +1% per `per` $ of item cost, up to `max` %, on top of the Notoriety fence bonus
Config.FenceSlots = 126
Config.FenceBonus = { per = 5000, max = 20 }

-- Cash on the table: one bundle prop per `bundle` $ (up to `maxProps`); taking it adds the money one bundle at a time,
-- only while there is room (the rest stays on the table)
Config.CashBundle = 10000
Config.CashMaxProps = 8

Config.CashProp = 'prop_cash_pile_01'
Config.CollectTime = 2000

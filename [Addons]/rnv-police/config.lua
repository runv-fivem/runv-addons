Config = {}

-- Police Station = Mission Row (duty point and car spawn)
Config.Duty = vec3(440.085, -974.924, 30.689)
Config.CarSpawn = vec4(452.0, -996.0, 26.0, 175.0)
Config.CarModel = 'police'
Config.MaxCops = 4               -- 4 officers per city
Config.UseDistance = 2.0

-- Issued gear (tagged metadata.issued, taken back on Go Off Duty and lost on death). slot = where it goes first
-- (55 weapon slot 1 = hotbar 1, 57 vest, 59 pouch, 60/61 pouch cells = hotbar 3/4); a taken slot falls back to the bag
-- restock = given again at the patrol car trunk
Config.Gear = {
    { item = 'versatile_pouch_2', count = 1, slot = 59 },
    { item = 'dp_9_mk1', count = 1, slot = 55 },
    { item = 'medium_body_armor', count = 1, slot = 57, meta = { armour = 50 } },
    { item = 'afak', count = 1, slot = 60, restock = true },
    { item = 'steel_plate_1', count = 1, slot = 61, restock = true },
    { item = 'pistol_ammo', count = 60, restock = true },
}

-- Restock at the back of your own patrol car (trunk opens, RESTOCKING... with an animation)
Config.Restock = { time = 6000, distance = 1.6, anim = { dict = 'anim@heists@prison_heiststation@cop_reactions', clip = 'cop_b_idle' } }

-- Uniform (freemode components) per model: component = { drawable, texture }
Config.Uniform = {
    mp_m_freemode_01 = { [3] = { 0, 0 }, [4] = { 35, 0 }, [6] = { 25, 0 }, [8] = { 58, 0 }, [11] = { 55, 0 } },
    mp_f_freemode_01 = { [3] = { 14, 0 }, [4] = { 34, 0 }, [6] = { 25, 0 }, [8] = { 35, 0 }, [11] = { 48, 0 } },
}

-- Surrender (Q): only near an on-duty cop
Config.SurrenderKey = 'Q'
Config.SurrenderRange = 15.0
Config.ArrestRange = 3.0

-- Police coins: earned on duty, paid out at the end of the shift into the cop's own SALARY stash
Config.Coins = { arrest = 10, kill = 5 } -- per Criminal arrested / killed
Config.CoinValue = 1000                  -- $ per coin
Config.CashShare = { 0.70, 0.80 }        -- random share paid as cash, the rest as random loot items
Config.SalaryLoot = { 'alon_gia_necklace', 'pegiuet_watch', 'alon_gia_ring', 'deity_statue', 'stone_maiden_statue', 'gold_bar' } -- values from rnv-trade
Config.Salary = { id = 'police_salary', label = 'SALARY', slots = 30 }

-- A party joins together: everyone near the station, everyone answers Y / N
Config.PartyRange = 10.0
Config.AskTime = 15

-- Bribe: offered from the criminal's bank account, as a share of the bag value; both sides answer with Y / N
Config.BribeShare = 0.5
Config.AnswerTime = 15

Config = {}

-- NOTORIETY (city-visit reputation). Level at city entry by party size: solo 4, duo 2, trio 1
Config.StartLevel = { 4, 2, 1 }
Config.MaxLevel = 5
Config.PointsPerLevel = 100 -- project value

-- Bonus per level: fence = normal loot sale, smuggler = cargo sale
-- loot = the dice chip, same as fence
Config.Bonus = {
    [1] = { cargo = 0, fence = 0, loot = 0 },
    [2] = { cargo = 5, fence = 10, loot = 10 },
    [3] = { cargo = 10, fence = 20, loot = 20 },
    [4] = { cargo = 15, fence = 35, loot = 35 },
    [5] = { cargo = 25, fence = 50, loot = 50 },
}

-- AUTHORITY (permanent, # = years of jail time). Tattoos unlock at a threshold; Authority is never spent
Config.TrackName = 'OUTLAW'

-- Tattoo Artist in prison (Bolingbroke yard for now)
Config.Artist = {
    coords = vec4(1704.5, 2543.0, 45.56, 90.0),
    model = 's_m_y_prismuscl_01',
}

-- 23 tattoos: CHANCE / FEARLESSNESS / CROWN / FREEDOM / PRAYER, the rest use GTA tattoo labels
-- Thresholds from 1 up to 800
Config.Tattoos = {
    { id = 1, name = 'CHANCE', threshold = 1, collection = 'mpchristmas3_overlays', male = 'MP_Christmas3_Tat_042_M', female = 'MP_Christmas3_Tat_042_F', desc = "One life, one chance. A symbol of a criminal who no longer fears death and has irrevocably accepted their path. Worn by those who've chosen their ultimate path." }, -- Snake (ZONE_TORSO)
    { id = 2, name = 'FEARLESSNESS', threshold = 5, collection = 'multiplayer_overlays', male = 'FM_Tat_M_011', female = 'FM_Tat_F_011', desc = "Represents physical strength, unyielding will, and commitment to see things through to the end. Signifies that the person wearing it stood strong in prison and didn't break. Tattooed on those who do not shy away from a fight." }, -- LS Script (ZONE_TORSO)
    { id = 3, name = 'CLOWN AND GUN', threshold = 15, collection = 'multiplayer_overlays', male = 'FM_Tat_Award_M_017', female = 'FM_Tat_Award_F_017', desc = "" }, -- Clown and Gun (ZONE_TORSO)
    { id = 4, name = 'WAY OF THE GUN', threshold = 40, collection = 'multiplayer_overlays', male = 'FM_Tat_M_036', female = 'FM_Tat_F_036', desc = "" }, -- Way of the Gun (ZONE_TORSO)
    { id = 5, name = 'EAGLE AND SERPENT', threshold = 60, collection = 'multiplayer_overlays', male = 'FM_Tat_M_013', female = 'FM_Tat_F_013', desc = "" }, -- Eagle and Serpent (ZONE_TORSO)
    { id = 6, name = 'DEMON SKULL JESTER', threshold = 80, collection = 'mpchristmas3_overlays', male = 'MP_Christmas3_Tat_021_M', female = 'MP_Christmas3_Tat_021_F', desc = "" }, -- Demon Skull Jester (ZONE_TORSO)
    { id = 7, name = 'BLOOD MONEY', threshold = 100, collection = 'mpvinewood_overlays', male = 'MP_Vinewood_Tat_022_M', female = 'MP_Vinewood_Tat_022_F', desc = "" }, -- Blood Money (ZONE_TORSO)
    { id = 8, name = 'CROWN', threshold = 130, collection = 'mpgunrunning_overlays', male = 'MP_Gunrunning_Tattoo_020_M', female = 'MP_Gunrunning_Tattoo_020_F', desc = "" }, -- Crowned Weapons (ZONE_TORSO)
    { id = 9, name = 'FREEDOM', threshold = 160, collection = 'mpbiker_overlays', male = 'MP_MP_Biker_Tat_006_M', female = 'MP_MP_Biker_Tat_006_F', desc = "" }, -- Chopper Freedom (ZONE_TORSO)
    { id = 10, name = 'PRAYER', threshold = 200, collection = 'multiplayer_overlays', male = 'FM_Tat_Award_M_005', female = 'FM_Tat_Award_F_005', desc = "" }, -- Angel (ZONE_TORSO)
    { id = 11, name = 'ROLL THE DICE', threshold = 240, collection = 'mpvinewood_overlays', male = 'MP_Vinewood_Tat_017_M', female = 'MP_Vinewood_Tat_017_F', desc = "" }, -- Roll the Dice (ZONE_TORSO)
    { id = 12, name = 'SNAKE EYES', threshold = 280, collection = 'mpvinewood_overlays', male = 'MP_Vinewood_Tat_008_M', female = 'MP_Vinewood_Tat_008_F', desc = "" }, -- Snake Eyes (ZONE_TORSO)
    { id = 13, name = 'DOLLAR GUNS CROSSED', threshold = 320, collection = 'mpsecurity_overlays', male = 'MP_Security_Tat_026_M', female = 'MP_Security_Tat_026_F', desc = "" }, -- Dollar Guns Crossed (ZONE_TORSO)
    { id = 14, name = 'SKULL ON THE CROSS', threshold = 360, collection = 'multiplayer_overlays', male = 'FM_Tat_M_009', female = 'FM_Tat_F_009', desc = "" }, -- Skull on the Cross (ZONE_TORSO)
    { id = 15, name = 'ROSE & ACES', threshold = 400, collection = 'mpvinewood_overlays', male = 'MP_Vinewood_Tat_016_M', female = 'MP_Vinewood_Tat_016_F', desc = "" }, -- Rose & Aces (ZONE_TORSO)
    { id = 16, name = 'TIGER & MASK', threshold = 450, collection = 'mpchristmas2017_overlays', male = 'MP_Christmas2017_Tattoo_004_M', female = 'MP_Christmas2017_Tattoo_004_F', desc = "" }, -- Tiger & Mask (ZONE_LEFT_ARM)
    { id = 17, name = 'WITCH & SKULL', threshold = 500, collection = 'mpsum2_overlays', male = 'MP_Sum2_Tat_037_M', female = 'MP_Sum2_Tat_037_F', desc = "" }, -- Witch & Skull (ZONE_TORSO)
    { id = 18, name = 'WINGED SKULL', threshold = 550, collection = 'mpsum2_overlays', male = 'MP_Sum2_Tat_042_M', female = 'MP_Sum2_Tat_042_F', desc = "" }, -- Winged Skull (ZONE_TORSO)
    { id = 19, name = 'SKULLS AND ROSE', threshold = 600, collection = 'multiplayer_overlays', male = 'FM_Tat_M_045', female = 'FM_Tat_F_045', desc = "" }, -- Skulls and Rose (ZONE_TORSO)
    { id = 20, name = 'SPARTAN & LION', threshold = 650, collection = 'mpchristmas2017_overlays', male = 'MP_Christmas2017_Tattoo_021_M', female = 'MP_Christmas2017_Tattoo_021_F', desc = "" }, -- Spartan & Lion (ZONE_TORSO)
    { id = 21, name = 'ROARING TIGER', threshold = 700, collection = 'mpchristmas2_overlays', male = 'MP_Xmas2_M_Tat_011', female = 'MP_Xmas2_F_Tat_011', desc = "" }, -- Roaring Tiger (ZONE_TORSO)
    { id = 22, name = 'WOLF INSIGNIA', threshold = 750, collection = 'mpgunrunning_overlays', male = 'MP_Gunrunning_Tattoo_013_M', female = 'MP_Gunrunning_Tattoo_013_F', desc = "" }, -- Wolf Insignia (ZONE_TORSO)
    { id = 23, name = '8 BALL SKULL', threshold = 800, collection = 'mpchristmas2_overlays', male = 'MP_Xmas2_M_Tat_012', female = 'MP_Xmas2_F_Tat_012', desc = "" }, -- 8 Ball Skull (ZONE_LEFT_ARM)
}

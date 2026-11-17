Config = {}

Config.Reset = 20 * 60          -- seconds after the first robbery event until the store resets
Config.UseDistance = 1.6
Config.SpotTime = 4000          -- ms the clerk needs to see a Criminal before calling
Config.CallTime = 4000          -- ms on the phone (aim at the clerk to stop it)
Config.LocationDelay = 5000     -- ms after the call until the police get the location
Config.SpotDistance = 15.0
Config.BlipTime = 90
Config.SafeTool = 'mini_drill'  -- safes need a Mini Drill (kept)
Config.ClerkModel = 'mp_m_shopkeep_01'
Config.DoorModel = 'v_ilev_ml_door1'   -- the back door added to 24/7 and LTD back rooms (they have an open doorway)
Config.PosterModel = 'ch_prop_vault_painting_01d'
Config.SafeModel = 'h4_prop_h4_safe_01a'
Config.PointStages = 4   -- a shelf / display is searched 3 times: full -> fewer items -> almost empty -> empty

-- ms per action (server checks the same numbers)
Config.Time = { till = 6000, clerktill = 4000, point = 4000, door = 5000, safe = 10000, wallsafe = 12000, poster = 10000 }
Config.Points = { till = 1, point = 1, door = 1, safe = 3, wallsafe = 3, poster = 2 }   -- Notoriety

-- prompt title / label / progress text per loot point kind
Config.PointText = {
    shelf = { 'SHELF', 'Search', 'SEARCHING...' },
    cigs = { 'CIGARETTES', 'Take', 'TAKING...' },
    pharmacy = { 'PHARMACY', 'Search', 'SEARCHING...' },
    fridge = { 'FRIDGE', 'Take', 'TAKING...' },
    sweets = { 'SWEETS', 'Take', 'TAKING...' },
    liquor = { 'LIQUOR SHELF', 'Take', 'TAKING...' },
    shoes = { 'SHOE BOXES', 'Search', 'SEARCHING...' },
    glasses = { 'SUNGLASSES', 'Take', 'TAKING...' },
    luggage = { 'LUGGAGE', 'Search', 'SEARCHING...' },
    jewel = { 'JEWELRY', 'Take', 'TAKING...' },
    cologne = { 'COLOGNE', 'Take', 'TAKING...' },
    bag = { 'HANDBAGS', 'Take', 'TAKING...' },
}

-- weighted loot. { item, weight } ; { item, 0, min, max } = always, amount range
Config.Loot = {
    till = { { 'money', 0, 250, 800 } },
    shelf = { { 'medications', 30 }, { 'vial_with_supplements', 20 }, { 'keke_cigarettes', 15 }, { 'alcohol', 20 }, { 'flers_perfume', 10 }, { 'vial_with_liquid', 2 } },
    fridge = { { 'alcohol', 45 }, { 'fine_wine_bottle', 15 }, { 'black_pirate_bottle', 12 }, { 'severka_bottle', 12 }, { 'omega_bottle', 10 }, { 'eclipse_bottle', 4 }, { 'rosefield_bottle', 2 } },
    pharmacy = { { 'medications', 40 }, { 'vial_with_supplements', 25 }, { 'thermometer', 15 }, { 'vial_with_vaccine', 15 }, { 'vial_with_liquid', 5 } },
    sweets = { { 'alcohol', 30 }, { 'medications', 20 }, { 'keke_cigarettes', 25 }, { 'costume_jewelry', 25 } },
    cigs = { { 'keke_cigarettes', 50 }, { 'lucky_shot_cigarettes', 45 }, { 'old_huba_cigars', 5 } },
    liquor = { { 'fine_wine_bottle', 25 }, { 'black_pirate_bottle', 20 }, { 'severka_bottle', 20 }, { 'omega_bottle', 15 }, { 'diamond_breeze_bottle', 12 }, { 'eclipse_bottle', 5 }, { 'rosefield_bottle', 3 } },
    shoes = { { 'costume_jewelry', 50 }, { 'trio_perfume', 30 }, { 'flers_perfume', 20 } },
    glasses = { { 'costume_jewelry', 60 }, { 'sugi_earrings', 25 }, { 'guddi_earrings', 15 } },
    luggage = { { 'costume_jewelry', 40 }, { 'g_flow_smartphone', 25 }, { 'consteran_watch', 20 }, { 'air_p_laptop', 10 }, { 'nurdan_watch', 5 } },
    jewel = { { 'alon_gia_ring', 30 }, { 'guddi_necklace', 25 }, { 'maffi_earrings', 20 }, { 'guddi_ring', 12 }, { 'refier_necklace', 10 }, { 'penarai_necklace', 3 } },
    cologne = { { 'lacrocas_perfume', 50 }, { 'infinity_perfume', 40 }, { 'duchee_perfume', 10 } },
    bag = { { 'costume_jewelry', 50 }, { 'chipardi_necklace', 30 }, { 'pegiuet_watch', 20 } },
    poster = { { 'painting_picture_fake_1', 50 }, { 'painting_picture_tube_1', 35 }, { 'painting_2', 13 }, { 'painting_3', 2 } },
    safe = { { 'money', 0, 2000, 8000 }, { 'guddi_ring', 40 }, { 'nurdan_watch', 30 }, { 'maffi_necklace', 25 }, { 'old_huba_cigars', 25 }, { 'polex_watch', 2 } },
}

-- where the clerk stands: 0.8 m behind the store's first till, facing the customers
function ClerkSpot(store)
    local t = store.tills[1]
    local r = math.rad(t.w)
    return vec4(t.x + 0.8 * math.sin(r), t.y - 0.8 * math.cos(r), t.z - 1.1, t.w)
end

function SafeSpot(store)
    return store.safe or store.wallsafe
end

function BackDoorSpot(store)
    if store.door then return store.door.xyz end
    return store.doors and store.doors[1] and store.doors[1][2]
end

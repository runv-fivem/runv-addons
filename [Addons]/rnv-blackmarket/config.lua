Config = {}

-- Where the screens open (Dream View Motel). A base laptop comes with Housing
Config.Owner = vec3(-112.4, 6322.6, 31.79) -- rnv-motel owner ped
Config.Door = vec3(-109.6, 6323.4, 31.9) -- Suspicious Door
Config.UseDistance = 2.0

-- Black Market catalog: built at start from the item data (rnv-inventory items `rnv.buy` = price, `rnv.unlock` = one-time
-- research price). Tab per item category; vehicles wait for a vehicle shop
Config.Tabs = { 'GEAR', 'VEHICLES', 'CONSTRUCTION' }
Config.CategoryTab = {
    weapons = 'GEAR', ['ammo-grenades'] = 'GEAR', ['armor-bags'] = 'GEAR', medicine = 'GEAR', ['keys-tools'] = 'GEAR',
    ['car-upgrades'] = 'GEAR', base = 'CONSTRUCTION',
}
Config.CategoryTitle = {
    weapons = 'WEAPONS', ['ammo-grenades'] = 'GRENADES', ['armor-bags'] = 'ARMOR & BAGS', medicine = 'MEDICINE',
    ['keys-tools'] = 'KEYS & TOOLS', ['car-upgrades'] = 'CAR UPGRADES', base = 'BASE BUILDING',
}
Config.StackMax = 10 -- how many of a stackable item one BUY window sells at most

-- Ammo has no buy price in the data: $ per round, max = rounds per buy (SMG: 360 for $1.800)
Config.Sections = {
    {
        title = 'AMMO', tier = 'green',
        offers = {
            { id = 'pistol_ammo', item = 'pistol_ammo', price = 5, max = 60 },
            { id = 'smg_ammo', item = 'smg_ammo', price = 5, max = 360 },
            { id = 'assault_rifle_ammo', item = 'assault_rifle_ammo', price = 8, max = 360 },
            { id = 'shotgun_ammo', item = 'shotgun_ammo', price = 10, max = 60 },
        },
    },
    -- Grow Table input: no buy price in the data (project value)
    { title = 'PRODUCTION', tier = 'green', offers = { { id = 'loose_leaves', item = 'loose_leaves', price = 500, max = 10 } } },
}

-- Suspicious Door (goods for goods)
-- price = tooltip "PRICE ~ $X" (shown only, never charged). Cash inputs use item 'money'
Config.Deals = {
    { id = 'id_card_4', title = 'ID Card', output = 'id_card_4', price = 7200,
        inputs = { { item = 'evidence', count = 20 } } },
    { id = 'id_card_5', title = 'ID Card', output = 'id_card_5',
        inputs = { { item = 'deposit_box_keys_1_full', count = 1 } } },
    { id = 'drill', title = 'Drill', output = 'drill',
        inputs = { { item = 'action_camera_1_full', count = 1 }, { item = 'usb_hacking_tool_1_full', count = 2 }, { item = 'money', count = 50000 } } },
}

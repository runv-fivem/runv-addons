Config = {}

-- Plots in the (server-owned) Sandy Shores settlement. center = plot middle, w = heading the base faces
-- Everything on a plot is placed by an offset from its center, turned by w
Config.Plots = {
    { id = 'fruitcake', name = 'FRUITCAKE', center = vec4(1806.6, 3616.6, 33.0, 30.0) },
    { id = 'cactus', name = 'CACTUS', center = vec4(1767.6, 3594.1, 33.0, 30.0) }, -- open sand between the dirt road and the highway
}

-- Offsets from the plot center (x right, y forward)
Config.Layout = {
    sign = vec3(-4.0, -14.0, 0.0),   -- rent sign next to the plot
    plan = vec3(4.0, -9.0, 0.0),     -- Plot Plan table (PLOT PLAN / Modification)
    main = vec3(0.0, 4.0, 0.0),      -- main building
    door = vec3(0.0, 0.0, 0.0),      -- enter point in front of the main building
    garage = vec3(11.0, -2.0, 0.0),
    cargo_bench = vec3(9.0, 6.0, 0.0),
    contraband_bench = vec3(9.0, 10.0, 0.0),
    grow_table = vec3(-6.0, 12.0, 0.0),
    fence = { vec3(-12.0, -15.0, 0.0), vec3(-12.0, -7.0, 0.0), vec3(-12.0, 1.0, 0.0), vec3(-12.0, 9.0, 0.0), vec3(-12.0, 17.0, 0.0) },
}

Config.SignProp = 'prop_forsale_lrg_01'
Config.PlanProp = 'prop_tool_bench02'
Config.TitleItem = 'land_plot_title_1'
Config.UseDistance = 2.0

-- Structure items. slot 'main' = Basic Structures (one building), 'extra' = Additional Structures (Config.ExtraSlots)
Config.ExtraSlots = 4
-- interior = the GTA interior the building leads to
Config.Structures = {
    trailer = { slot = 'main', label = 'TRAILER', prop = 'prop_trailer_01_new', interior = 'GTAOHouseLow1' },
    small_house = { slot = 'main', label = 'SMALL HOUSE', prop = 'prop_portacabin01', interior = 'GTAOHouseMid1' },
    mesh_fence = { slot = 'extra', label = 'MESH FENCE', prop = 'prop_fncconstruc_02a', at = 'fence' },
    car_garage = { slot = 'extra', label = 'GARAGE', prop = 'prop_container_01a', at = 'garage' },
    cargo_workbench = { slot = 'extra', label = 'CARGO WORKBENCH', prop = 'gr_prop_gr_bench_04a', at = 'cargo_bench' },
    contraband_workbench = { slot = 'extra', label = 'CONTRABAND WORKBENCH', prop = 'gr_prop_gr_bench_02a', at = 'contraband_bench' },
    grow_table = { slot = 'extra', label = 'GROW TABLE', prop = 'bkr_prop_weed_table_01a', at = 'grow_table' },
}

-- Interiors (desk = the clothing spot). Cabinet, laptop and Laundering Desk inside each
Config.Interiors = {
    GTAOHouseLow1 = { exit = vec4(266.2, -1007.03, -100.92, 6.02), stash = vec3(265.96, -999.37, -99.01), laptop = vec3(262.91, -1002.92, -99.01), desk = vec3(260.4, -1003.27, -99.01) },
    GTAOHouseMid1 = { exit = vec4(346.76, -1011.52, -99.2, 358.57), stash = vec3(351.98, -998.8, -99.2), laptop = vec3(349.24, -995.09, -99.2), desk = vec3(350.84, -993.9, -99.2) },
}

Config.Stash = { slots = 30, label = 'CABINET' }

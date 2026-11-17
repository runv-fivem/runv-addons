Config = {}

Config.Reset = 20 * 60          -- seconds after the break-in until the house resets (doors, loot, NPCs, alarm)
Config.BoxTime = 8000           -- ms to switch off the electric box
Config.DoorTime = 5000          -- ms to break the front door open (hold E, no tool)
Config.AlarmTime = 10           -- seconds from the break-in until the alarm reaches the police
Config.SpotTime = 4000          -- ms an NPC needs to see a Criminal before it calls
Config.CallTime = 4000          -- ms the NPC is on the phone (aim at it to stop the call)
Config.LocationDelay = 5000     -- ms after the call/alarm until the police get the house location
Config.SpotDistance = 15.0      -- m an NPC sees a Criminal from
Config.BlipTime = 90            -- seconds the house blip stays on the cops' map
Config.UseDistance = 1.6
Config.SafeTool = 'mini_drill'  -- safes need a Mini Drill (kept, not used up)
Config.Points = { box = 1, door = 1, grab = 1, painting = 2, safe = 3 }   -- Notoriety

-- Loot tables. One roll per point: weighted pick
Config.Loot = {
    jewel = { { 'costume_jewelry', 40 }, { 'guddi_earrings', 15 }, { 'amina_ring', 15 }, { 'alon_gia_necklace', 15 }, { 'guddi_ring', 8 }, { 'maffi_necklace', 6 }, { 'amina_earrings', 1 } },
    watch = { { 'consteran_watch', 35 }, { 'pegiuet_watch', 30 }, { 'pardin_watch', 25 }, { 'penarai_watch', 7 }, { 'nurdan_watch', 2 }, { 'polex_watch', 1 } },
    tech = { { 'air_p_laptop', 35 }, { 'utab_laptop', 30 }, { 'g_flow_smartphone', 20 }, { 'hubrid_laptop', 10 }, { 'sus_vilo_laptop', 5 } },
    painting = { { 'painting_picture_fake_1', 45 }, { 'painting_picture_tube_1', 35 }, { 'painting_2', 17 }, { 'painting_3', 3 } },
    safe = { { 'money', 0, 4000, 12000 }, { 'guddi_ring', 50 }, { 'nurdan_watch', 30 }, { 'maffi_necklace', 30 }, { 'deity_statue', 15 }, { 'polex_watch', 3 } },
}

-- Layouts in house-local coords (x right, y back, z up from the ground floor; heading local, 0 = +y)
-- room = MLO room the item sits in (default 'ground'); objects must be put in their room or they don't draw
-- Kinds: prop (decoration), grab (stealable item on furniture), painting, safe, cam (CCTV), npc
Config.Layouts = {
    h1 = {
        door = vec3(1.4, -8.0, 0.0),        -- front door (mp_h1_door_02), prompt on the door
        box = vec4(7.5, 1.0, 1.1, 270.0),   -- right side wall, outside
        alarm = vec3(3.0, -6.5, 2.4),       -- siren inside by the front door
        rooms = { ground = 145430881, bed = -1396677706, study = -1643985349, hall = 1350773561 },   -- MLO room keys (same in every mp_h1)
        inside = { min = vec3(-6.3, -10.1, -0.5), max = vec3(7.4, 6.7, 8.0) },
        items = {
            -- ground floor: living room
            { kind = 'prop', model = 'apa_mp_h_acc_rugwooll_04', pos = vec4(-3.2, 2.0, 0.0, 0.0) },
            { kind = 'prop', model = 'apa_mp_h_stn_sofacorn_01', pos = vec4(-5.3, 4.9, 0.0, 180.0) },
            { kind = 'prop', model = 'apa_mp_h_yacht_coffee_table_01', pos = vec4(-3.2, 2.0, 0.0, 0.0) },
            { kind = 'prop', model = 'apa_mp_h_str_sideboardl_06', pos = vec4(0.4, 2.0, 0.0, 90.0) },
            { kind = 'prop', model = 'prop_tv_flat_01', pos = vec4(0.45, 2.0, 0.9, 90.0) },
            { kind = 'prop', model = 'apa_mp_h_acc_plant_tall_01', pos = vec4(-5.7, -2.5, 0.0, 0.0) },
            { kind = 'grab', id = 'coffee', model = 'p_watch_01', loot = 'watch', pos = vec4(-3.0, 2.1, 0.45, 0.0) },
            { kind = 'painting', id = 'living_art', model = 'ch_prop_vault_painting_01a', loot = 'painting', pos = vec4(-3.0, -3.53, 1.06, 180.0) },
            { kind = 'cam', model = 'prop_cctv_cam_01a', pos = vec4(-6.0, 6.3, 2.9, 225.0) },
            -- ground floor: dining
            { kind = 'prop', model = 'apa_mp_h_din_table_04', pos = vec4(4.7, 3.0, 0.0, 0.0) },
            { kind = 'prop', model = 'apa_mp_h_din_chair_04', pos = vec4(4.0, 2.2, 0.0, 0.0) },
            { kind = 'prop', model = 'apa_mp_h_din_chair_04', pos = vec4(5.4, 2.2, 0.0, 0.0) },
            { kind = 'prop', model = 'apa_mp_h_din_chair_04', pos = vec4(4.0, 3.8, 0.0, 180.0) },
            { kind = 'prop', model = 'apa_mp_h_din_chair_04', pos = vec4(5.4, 3.8, 0.0, 180.0) },
            { kind = 'grab', id = 'laptop', model = 'prop_laptop_01a', loot = 'tech', pos = vec4(4.7, 3.0, 0.78, 180.0) },
            { kind = 'painting', id = 'dining_art', model = 'ch_prop_vault_painting_01b', loot = 'painting', pos = vec4(7.18, 4.0, 1.06, 270.0) },
            { kind = 'cam', model = 'prop_cctv_cam_01a', pos = vec4(6.9, -8.5, 2.9, 45.0) },
            -- upstairs: bedroom + study
            { kind = 'prop', model = 'apa_mp_h_bed_double_08', pos = vec4(-4.0, 5.3, 3.5, 180.0), room = 'bed' },
            { kind = 'prop', model = 'apa_mp_h_bed_table_wide_12', pos = vec4(-2.7, 6.0, 3.5, 180.0), room = 'bed' },
            { kind = 'prop', model = 'apa_mp_h_acc_rugwools_01', pos = vec4(-4.2, 3.0, 3.5, 0.0), room = 'bed' },
            { kind = 'grab', id = 'bedside', model = 'prop_jewel_02a', loot = 'jewel', pos = vec4(-2.7, 6.0, 4.05, 0.0), room = 'bed' },
            { kind = 'painting', id = 'bed_art', model = 'ch_prop_vault_painting_01c', loot = 'painting', pos = vec4(-6.06, 5.0, 4.56, 90.0), room = 'bed' },
            { kind = 'safe', id = 'safe', model = 'h4_prop_h4_safe_01a', loot = 'safe', pos = vec4(-5.6, -2.6, 3.5, 90.0), room = 'study' },
        },
        npcs = {
            { model = 'a_m_m_bevhills_02', pos = vec4(5.8, 5.4, 0.0, 180.0) },
            { model = 'a_f_y_bevhills_02', pos = vec4(4.5, 4.5, 3.5, 180.0), room = 'hall' },
        },
    },
    bng = {
        door = vec3(-3.3, -1.4, 0.0),       -- front door (wh_bng_door_02, diagonal wall)
        box = vec4(7.57, 1.0, 1.1, 270.0),
        alarm = vec3(-2.0, -1.0, 2.4),
        rooms = { ground = 553932866, bed = -330116139 },
        inside = { min = vec3(-8.7, -7.9, -0.5), max = vec3(7.5, 4.6, 5.0) },
        items = {
            -- living room (left wing)
            { kind = 'prop', model = 'apa_mp_h_acc_rugwooll_04', pos = vec4(-4.2, 2.2, 0.0, 0.0) },
            { kind = 'prop', model = 'apa_mp_h_stn_sofa2seat_02', pos = vec4(-4.2, 3.9, 0.0, 180.0) },
            { kind = 'prop', model = 'apa_mp_h_yacht_coffee_table_01', pos = vec4(-4.2, 2.2, 0.0, 0.0) },
            { kind = 'prop', model = 'apa_mp_h_str_sideboards_02', pos = vec4(-4.4, 0.55, 0.0, 0.0) },
            { kind = 'prop', model = 'prop_tv_flat_01', pos = vec4(-4.4, 0.55, 0.85, 0.0) },
            { kind = 'grab', id = 'coffee', model = 'p_watch_01', loot = 'watch', pos = vec4(-4.0, 2.3, 0.45, 0.0) },
            { kind = 'painting', id = 'living_art', model = 'ch_prop_vault_painting_01a', loot = 'painting', pos = vec4(-2.2, 4.29, 1.06, 0.0) },
            { kind = 'cam', model = 'prop_cctv_cam_01a', pos = vec4(-7.2, 4.2, 2.6, 225.0) },
            -- dining / kitchen
            { kind = 'prop', model = 'apa_mp_h_din_table_04', pos = vec4(1.5, -4.5, 0.0, 90.0) },
            { kind = 'prop', model = 'apa_mp_h_din_chair_04', pos = vec4(0.7, -3.8, 0.0, 270.0) },
            { kind = 'prop', model = 'apa_mp_h_din_chair_04', pos = vec4(0.7, -5.2, 0.0, 270.0) },
            { kind = 'prop', model = 'apa_mp_h_din_chair_04', pos = vec4(2.3, -3.8, 0.0, 90.0) },
            { kind = 'prop', model = 'apa_mp_h_din_chair_04', pos = vec4(2.3, -5.2, 0.0, 90.0) },
            { kind = 'grab', id = 'laptop', model = 'prop_laptop_01a', loot = 'tech', pos = vec4(1.5, -4.5, 0.78, 270.0) },
            { kind = 'painting', id = 'dining_art', model = 'ch_prop_vault_painting_01b', loot = 'painting', pos = vec4(-0.58, 2.2, 1.06, 270.0) },
            { kind = 'cam', model = 'prop_cctv_cam_01a', pos = vec4(4.0, -7.5, 2.6, 315.0) },
            -- bedroom (right)
            { kind = 'prop', model = 'apa_mp_h_bed_double_08', pos = vec4(6.3, 2.4, 0.0, 270.0), room = 'bed' },
            { kind = 'prop', model = 'apa_mp_h_bed_table_wide_12', pos = vec4(6.9, 0.2, 0.0, 270.0), room = 'bed' },
            { kind = 'grab', id = 'bedside', model = 'prop_jewel_02a', loot = 'jewel', pos = vec4(6.9, 0.2, 0.55, 0.0), room = 'bed' },
            { kind = 'safe', id = 'safe', model = 'h4_prop_h4_safe_01a', loot = 'safe', pos = vec4(5.4, 4.0, 0.0, 180.0), room = 'bed' },
        },
        npcs = {
            { model = 'a_m_m_bevhills_02', pos = vec4(-5.8, 1.2, 0.0, 270.0) },
            { model = 'a_f_y_bevhills_02', pos = vec4(3.4, -2.2, 0.0, 90.0) },
        },
    },
}

-- The robbery homes (rnv_homeint map). origin / heading = the MLO instance; doors = map door ids for the door system
Config.Houses = {
    {
        key = 'mp_h1_p02', label = 'Mirror Park House', layout = 'h1', origin = vec3(1375.1558, -547.8932, 73.2905), heading = 338.570,
        doors = {
            { 'whippy_mp_mp_h1_p02_mp_h1_door_01', 'mp_h1_door_01', vec3(1381.0672757, -543.1942146, 74.8054500) },
            { 'whippy_mp_mp_h1_p02_mp_h1_door_02', 'mp_h1_door_02', vec3(1373.8677821, -555.4253974, 74.8054500) },
            { 'whippy_mp_mp_h1_p02_mp_h1_door_03', 'mp_h1_door_03', vec3(1372.9990349, -550.9248562, 74.7904500) },
            { 'whippy_mp_mp_h1_p02_mp_h1_door_04', 'mp_h1_door_04', vec3(1375.1713319, -544.5691325, 78.2904500) },
            { 'whippy_mp_mp_h1_p02_mp_h1_door_05', 'mp_h1_door_05', vec3(1373.7829687, -548.1064262, 78.2904500) },
            { 'whippy_mp_mp_h1_p02_mp_h1_door_06', 'mp_h1_door_06', vec3(1378.1584913, -547.0306928, 78.2904500) },
            { 'whippy_mp_mp_h1_p02_mp_h1_door_07', 'mp_h1_door_07', vec3(1377.0624151, -549.8232932, 78.2904500) },
        },
    },
    {
        key = 'mp_h1_p03', label = 'Mirror Park House', layout = 'h1', origin = vec3(1330.2678, -528.0859, 71.0456), heading = 340.246,
        doors = {
            { 'whippy_mp_mp_h1_p03_mp_h1_door_01', 'mp_h1_door_01', vec3(1336.0394138, -523.2160278, 72.5606100) },
            { 'whippy_mp_mp_h1_p03_mp_h1_door_02', 'mp_h1_door_02', vec3(1329.2006241, -535.6524860, 72.5606100) },
            { 'whippy_mp_mp_h1_p03_mp_h1_door_03', 'mp_h1_door_03', vec3(1328.2006577, -531.1792702, 72.5456100) },
            { 'whippy_mp_mp_h1_p03_mp_h1_door_04', 'mp_h1_door_04', vec3(1330.1861918, -524.7627484, 76.0456100) },
            { 'whippy_mp_mp_h1_p03_mp_h1_door_05', 'mp_h1_door_05', vec3(1328.9018487, -528.3391239, 76.0456100) },
            { 'whippy_mp_mp_h1_p03_mp_h1_door_06', 'mp_h1_door_06', vec3(1333.2440473, -527.1359152, 76.0456100) },
            { 'whippy_mp_mp_h1_p03_mp_h1_door_07', 'mp_h1_door_07', vec3(1332.2300921, -529.9593696, 76.0456100) },
        },
    },
    {
        key = 'mp_h1_p04', label = 'Mirror Park House', layout = 'h1', origin = vec3(1337.5210, -604.4516, 73.3055), heading = 144.005,
        doors = {
            { 'whippy_mp_mp_h1_p04_mp_h1_door_01', 'mp_h1_door_01', vec3(1330.6177509, -607.5129882, 74.8205300) },
            { 'whippy_mp_mp_h1_p04_mp_h1_door_02', 'mp_h1_door_02', vec3(1340.6617737, -597.4854198, 74.8205300) },
            { 'whippy_mp_mp_h1_p04_mp_h1_door_03', 'mp_h1_door_03', vec3(1340.3708029, -602.0597970, 74.8055300) },
            { 'whippy_mp_mp_h1_p04_mp_h1_door_04', 'mp_h1_door_04', vec3(1336.6699778, -607.6649720, 78.3055300) },
            { 'whippy_mp_mp_h1_p04_mp_h1_door_05', 'mp_h1_door_05', vec3(1338.9032826, -604.5905050, 78.3055300) },
            { 'whippy_mp_mp_h1_p04_mp_h1_door_06', 'mp_h1_door_06', vec3(1334.3978532, -604.5313082, 78.3055300) },
            { 'whippy_mp_mp_h1_p04_mp_h1_door_07', 'mp_h1_door_07', vec3(1336.1609887, -602.1040973, 78.3055300) },
        },
    },
    {
        key = 'wh_bng_p02', label = 'Mirror Park Bungalow', layout = 'bng', origin = vec3(1255.8485, -481.1010, 68.7786), heading = 170.0,
        doors = {
            { 'whippy_mp_wh_bng_p02_wh_bng_door_01', 'wh_bng_door_01', vec3(1249.7839027, -473.1957424, 70.2780645) },
            { 'whippy_mp_wh_bng_p02_wh_bng_door_02', 'wh_bng_door_02', vec3(1258.8496426, -479.9050675, 70.3345645) },
            { 'whippy_mp_wh_bng_p02_wh_bng_door_03', 'wh_bng_door_03', vec3(1254.6602938, -480.3532607, 70.2835645) },
            { 'whippy_mp_wh_bng_p02_wh_bng_door_04', 'wh_bng_door_04', vec3(1251.1269018, -477.9329214, 70.2835645) },
        },
    },
}

-- house-local -> world (same maths on client and server)
function HouseWorld(house, lx, ly, lz)
    local r = math.rad(house.heading)
    local o = house.origin
    return vec3(o.x + lx * math.cos(r) - ly * math.sin(r), o.y + lx * math.sin(r) + ly * math.cos(r), o.z + lz)
end

function HousePoint(house, p)
    local w = HouseWorld(house, p.x, p.y, p.z)
    if p.w then return vec4(w.x, w.y, w.z, (p.w + house.heading) % 360.0) end
    return w
end

function HouseItem(house, id)
    for _, it in ipairs(Config.Layouts[house.layout].items) do
        if it.id == id then return it end
    end
end

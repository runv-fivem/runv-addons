Config = {}

-- Motel = Dream View Motel, Paleto Bay (cs1_04_motel)
Config.Motel = {
    arrival = vec4(-121.0, 6318.0, 31.5, 315.8),
    center = vec3(-110.0, 6330.0, 31.5),
    radius = 55.0, -- leaving this area opens the map
}

-- World map = the real world straight from above (aerial camera at 90 degrees). yaw 270 = east at the top of
-- the screen, so north is on the left and Los Santos on the right
-- center/dist = the opening view (whole map); drag pans, the wheel zooms between minDist and maxDist
Config.Map = { pitch = -89.9, yaw = 270.0, fov = 50.0, center = vec3(300.0, 2100.0, 50.0), dist = 7600.0,
    minDist = 500.0, maxDist = 9000.0, lod = 2.0 }

-- Every place is a cluster of pointy-top hex cells: every cell of a `hex`-sized grid whose
-- center is inside `zone`. The cells are a see-through roof at height `roof`; only the outer border is drawn
-- view = the camera distance when the place is selected

-- Places on the map. travel = 'city' (arrivals + car), 'motel' (GoToMotel), 'home' (own plot door, else arrivals),
-- nil = info only. card/badge = bottom card (HOME / HUB / LOS SANTOS)
Config.Destinations = {
    {
        id = 'prison',
        label = 'PRISON',
        text = 'Bolingbroke Penitentiary. Every new face starts here, and the only way back in is in handcuffs.',
        image = 'img/prison.jpg',
        iconImage = 'img/prison_icon.jpg',
        center = vec2(1690.0, 2580.0), radius = 380.0,
        zone = { vec2(1530.0, 2470.0), vec2(1850.0, 2410.0), vec2(1880.0, 2700.0), vec2(1720.0, 2790.0), vec2(1540.0, 2700.0) },
        hex = 90.0, roof = 260.0, view = 2400.0,
    },
    {
        id = 'settlement',
        label = 'SETTLEMENT',
        card = 'HOME', badge = 'home',
        travel = 'home',
        text = 'Desert plots outside Sandy Shores. Rent land, build your base and run your business. The desert is never safe.',
        image = 'img/settlement.jpg',
        iconImage = 'img/settlement_icon.jpg',
        center = vec2(1790.0, 3610.0), radius = 420.0,
        zone = { vec2(1430.0, 3480.0), vec2(1990.0, 3420.0), vec2(2080.0, 3720.0), vec2(1770.0, 3900.0), vec2(1420.0, 3760.0) },
        hex = 90.0, roof = 220.0, view = 2600.0,
        arrivals = {
            vec4(1803.25, 3655.0, 33.3, 209.0),
            vec4(1782.5, 3558.5, 34.8, 299.8),
        },
        vehicle = 'blista',
    },
    {
        id = 'motel',
        label = 'MOTEL',
        card = 'HUB', badge = 'person',
        travel = 'motel',
        text = 'Your hideout. Stash your cash, visit the Black Market and plan the next run.',
        image = 'img/motel.jpg',
        iconImage = 'img/motel_icon.jpg',
        center = vec2(-110.0, 6330.0), radius = 300.0,
        zone = { vec2(-260.0, 6200.0), vec2(30.0, 6150.0), vec2(120.0, 6420.0), vec2(-60.0, 6560.0), vec2(-300.0, 6430.0) },
        hex = 80.0, roof = 220.0, view = 2200.0,
    },
    {
        id = 'los_santos',
        label = 'LOS SANTOS',
        card = 'LOS SANTOS', badge = 'chart',
        travel = 'city',
        text = 'The big city. Work a clean job, rob the stores and banks, or wear the badge and hunt the ones who do. Pick your side.',
        image = 'img/los_santos.jpg',
        iconImage = 'img/los_santos_icon.jpg',
        center = vec2(-300.0, -1000.0), radius = 1500.0,
        zone = {
            vec2(-1850.0, -700.0), vec2(-1700.0, -100.0), vec2(-1100.0, 300.0), vec2(-400.0, 350.0), vec2(300.0, 300.0),
            vec2(900.0, 250.0), vec2(1250.0, -300.0), vec2(1350.0, -1100.0), vec2(1300.0, -1900.0), vec2(900.0, -2400.0),
            vec2(200.0, -2100.0), vec2(-400.0, -2000.0), vec2(-1350.0, -1850.0),
        },
        hex = 230.0, roof = 380.0, view = 5200.0,
        -- arrival: a parked civilian car, player in the driver seat
        arrivals = {
            vec4(229.5, -797.5, 30.6, 160.0),
            vec4(-341.5, -767.0, 33.7, 270.0),
            vec4(-1185.0, -1490.0, 4.0, 125.0),
        },
        vehicle = 'blista',
    },
}

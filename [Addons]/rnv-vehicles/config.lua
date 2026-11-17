Config = {}

-- Free rental at a Parking Terminal, only while you have no active vehicle
Config.RentalModel = 'blista'
Config.TerminalProp = 'prop_parkingpay'
Config.UseDistance = 2.0
Config.ParkDistance = 15.0 -- the rental must be this close to the terminal's spawn point to park it

Config.Terminals = {
    { id = 'legion', prop = vec4(226.0, -792.5, 30.7, 160.0), spawn = vec4(226.2, -796.3, 30.6, 160.0) },
    { id = 'vespucci', prop = vec4(-1180.5, -1487.0, 4.4, 125.0), spawn = vec4(-1187.0, -1487.1, 4.0, 125.0) },
}

-- Lock key and max distance
Config.LockKey = 'L'
Config.LockDistance = 5.0

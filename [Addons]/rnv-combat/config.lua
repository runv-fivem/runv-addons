Config = {}

-- Hold F (control 23) in the city as a Civilian to put the mask on and become Criminal
Config.MaskKey = 23
Config.MaskHold = 300 -- ms of holding before the progress bar starts
Config.MaskTime = 2000
Config.MaskLabel = 'MASK ON...'
-- After the switch: kneel, mask out of the bag at maskAt ms, stand up (amb@medic kneel loop, 3.9 s clip)
Config.MaskAnim = { dict = 'amb@medic@standing@kneel@base', clip = 'base', duration = 2600, maskAt = 1500 }
Config.AskTime = 15 -- seconds the party has to answer "suggests becoming Criminals"

-- Default mask (ped component 1) per freemode model
Config.Mask = {
    mp_m_freemode_01 = { drawable = 52, texture = 0 },
    mp_f_freemode_01 = { drawable = 52, texture = 0 },
}

-- Roles allowed to draw, aim, shoot and punch
Config.Armed = { criminal = true, cop = true }

-- Seconds dead before the respawn at the Motel
Config.RespawnTime = 10

-- Criminal death in the city loses every item in these rnv-inventory slots (1-54 = BAG grid)
Config.LossSlots = { from = 1, to = 54 }

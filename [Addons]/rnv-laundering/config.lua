Config = {}

-- Every house (rnv-housing main building) has a Laundering Desk. Project numbers:
-- picked 1:1, $1000 per 10 s, storage limit $400,000
Config.Rate = 1.0          -- bank money per $1 of cash
Config.Step = 1000         -- cash laundered per tick
Config.Tick = 10           -- seconds per tick (server time, also while offline)
Config.Capacity = 400000

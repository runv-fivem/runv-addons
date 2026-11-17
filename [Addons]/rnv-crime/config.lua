Config = {}

-- Every crime needs the Criminal role (mask on in a city visit, rnv-combat)
Config.UseDistance = 1.6
Config.Cooldown = 20 * 60        -- seconds before a robbed target refills
Config.LockpickBreak = 0.3       -- chance the lockpick breaks on use

-- Targets. kind: vault | goldvault | armory (shops moved to rnv-marketrob)
--   room = the locked room that must be open first, tool = item needed,
--   consume = tool is used up, time = ms, points = Notoriety, loot = rolled into the reward
Config.Targets = {
    -- Bank Vault (Pacific Standard): Drill on the vault door (city alert), Gold Vault needs the bank ID Card
    { id = 'bank_vault', kind = 'vault', title = 'BANK VAULT', label = 'Install Drill', coords = vec3(253.2, 222.2, 101.68), tool = 'drill', consume = true, time = 120000, points = 50,
        loot = { { item = 'gold_bar', min = 1, max = 2 }, { item = 'money', min = 20000, max = 40000 } } },
    { id = 'gold_vault', kind = 'goldvault', room = 'bank_vault', title = 'GOLD VAULT', label = 'ID Card', coords = vec3(264.3, 213.5, 101.68), tool = 'id_card_5', consume = true, time = 5000, points = 50,
        loot = { { item = 'gold_bar', min = 2, max = 3 }, { item = 'stone_maiden_statue', min = 1, max = 1 } } },

    -- Police armory (Mission Row): the armory ID Card from the Suspicious Door
    { id = 'police_armory', kind = 'armory', title = 'ARMORY', label = 'ID Card', coords = vec3(452.3, -980.0, 30.69), tool = 'id_card_4', consume = true, time = 5000, points = 40,
        loot = { { item = 'rc_5_56_mk1', min = 1, max = 1 }, { item = 'dp_9_mk1', min = 2, max = 2 }, { item = 'assault_rifle_ammo', min = 60, max = 60 }, { item = 'pistol_ammo', min = 48, max = 48 } } },
}

-- Kinds whose reward goes into a container (SAFE panel) instead of straight into the bag
Config.Containers = { safe = true, vault = true, goldvault = true, armory = true }

-- The vault door (v_ilev_bk_vaultdoor) swings open when the vault is cracked
Config.VaultDoor = { model = 'v_ilev_bk_vaultdoor', coords = vec3(255.228, 223.976, 102.393), open = -90.0 }
Config.VaultGate = { model = 'hei_v_ilev_bk_safegate_pris', coords = vec3(251.858, 221.066, 101.832) }

Config = {}

-- Machines are Additional Structures on the player's plot (rnv-housing). Live time 30 min; 5 min while developing
Config.UseDistance = 2.0

Config.Machines = {
    cargo = {
        structure = 'cargo_workbench', at = 'cargo_bench', title = 'CARGO WORKBENCH',
        input = 'cargo_sheet_1_full', time = 5 * 60,
        start = 'Process Cargo', busy = 'Processing', take = 'Take Loot',
        -- what one Valuable Cargo turns into (project values)
        output = { { item = 'pegiuet_watch', min = 1, max = 3 }, { item = 'alon_gia_ring', min = 1, max = 3 }, { item = 'alon_gia_necklace', min = 1, max = 2 } },
    },
    contraband = {
        structure = 'contraband_workbench', at = 'contraband_bench', title = 'CONTRABAND WORKBENCH',
        input = 'cargo_sheet_1_full', time = 5 * 60,
        start = 'Repack Cargo', busy = 'Repacking', take = 'Take Premium Cargo',   -- Repack Cargo
        output = { { item = 'cargo_sheet_2_full', min = 1, max = 1 } },
    },
}

-- GROW TABLE: 6 pots, a Growing Bush becomes a Mature Bush after the time
Config.Grow = {
    structure = 'grow_table', at = 'grow_table', title = 'GROW TABLE',
    pots = 6, input = 'loose_leaves', output = 'harvest_package_1', time = 5 * 60,
}

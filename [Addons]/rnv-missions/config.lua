Config = {}

-- Onboarding chain (project-authored, approved by the user). A stage completes on its fact
-- A fact of a later stage also completes the earlier ones (the tutorial never blocks the sandbox)
Config.Tutorial = {
    { fact = 'artist_talked', objective = 'Talk to the [[Tattoo Artist]] in the prison yard' },
    { fact = 'prison_escaped', objective = 'Escape the prison through the [[toilet]] in the yard' },
    { fact = 'owner_talked', objective = 'Talk to the [[Motel Owner]]' },
    { fact = 'city_arrived', objective = 'Leave the motel and travel to [[Los Santos]]' },
}

-- Named objective started by the Tattoo Artist talk. Payable later (Banking)
Config.DebtObjective = 'Pay your debt to the [[Motel Owner]]'

-- Dialogues: each step = an NPC line + the player's reply (E). The fact is sent when it ends
Config.Dialogues = {
    artist = {
        speaker = 'Tattoo Artist',
        fact = 'artist_talked',
        steps = {
            { line = "I can get you over that wall. Nothing's free though: once you're out, you owe us, and we always collect.", reply = 'Fine. Who do I pay?' },
            { line = 'The motel owner up in Paleto. Use the toilet in the yard, it leads out.', reply = 'See you around.' },
        },
    },
    owner = {
        speaker = 'Motel Owner',
        fact = 'owner_talked',
        steps = {
            { line = "So you're the new one. The boys told me you'd come.", reply = 'They said I owe you.' },
            { line = 'You do. Bank it when you can. Until then, go make some money. Los Santos is down south - leave the motel and pick it on the map.', reply = 'On my way.' },
        },
    },
}

-- NPCs the dialogues belong to (server checks the player is near them)
Config.Npcs = {
    artist = vec3(1704.5, 2543.0, 45.56), -- rnv-progression spawns this ped
    owner = vec4(-112.4, 6322.6, 31.49, 125.0),
}

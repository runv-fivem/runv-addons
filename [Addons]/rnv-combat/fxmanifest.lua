fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rnv-combat'
description 'RUN V - Criminal mask (hold F), civilian weapon block, death + respawn, loss on death'
version '0.1.0'

shared_scripts {
    '@rnv-core/lib/init.lua',
    'config.lua',
}
client_script 'client/main.lua'
server_script 'server/main.lua'

dependencies { 'rnv-core', 'rnv-interface' }

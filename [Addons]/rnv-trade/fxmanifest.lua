fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rnv-trade'
description 'RUN V - Fence (loot) and Smuggler\'s Van (cargo) with cash piles on the counter'
version '0.1.0'

shared_scripts {
    '@rnv-core/lib/init.lua',
    'config.lua',
}
client_script 'client/main.lua'
server_script 'server/main.lua'

dependencies { 'rnv-core', 'rnv-interface', 'rnv-inventory' }

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rnv-production'
description 'RUN V - Cargo Workbench, Contraband Workbench (Repack Cargo) and Grow Table on the player plot'
version '0.1.0'

shared_scripts {
    '@rnv-core/lib/init.lua',
    'config.lua',
}
client_script 'client/main.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies { 'oxmysql', 'rnv-core', 'rnv-interface', 'rnv-inventory', 'rnv-housing' }

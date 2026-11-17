fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rnv-vehicles'
description 'RUN V - Parking Terminal rental, lock + keys (renter and party), trunk via rnv-inventory'
version '0.1.0'

shared_scripts {
    '@rnv-core/lib/init.lua',
    'config.lua',
}
client_script 'client/main.lua'
server_script 'server/main.lua'

dependencies { 'rnv-core', 'rnv-interface' }

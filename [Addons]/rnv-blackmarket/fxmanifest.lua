fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rnv-blackmarket'
description 'RUN V - Black Market catalog (motel owner) and Suspicious Door barter; screens live in the rnv-inventory UI'
version '0.1.0'

shared_scripts {
    '@rnv-core/lib/init.lua',
    'config.lua',
}
client_script 'client/main.lua'
server_script 'server/main.lua'

dependencies { 'rnv-core', 'rnv-interface', 'rnv-inventory' }

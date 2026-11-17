fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rnv-police'
description 'RUN V - police duty (slots, gear, car), surrender (Q), arrest with bag confiscation and pay, bribes'
version '0.1.0'

shared_scripts {
    '@rnv-core/lib/init.lua',
    'config.lua',
}
client_script 'client/main.lua'
server_script 'server/main.lua'

dependencies { 'rnv-core', 'rnv-interface', 'rnv-inventory' }

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rnv-prison'
description 'RUN V - prison intro: arrive, JAIL TIME, escape'
version '0.1.0'

shared_scripts {
    '@rnv-core/lib/init.lua',
    'config.lua',
}
client_script 'client/main.lua'
server_script 'server/main.lua'

dependencies { 'rnv-core', 'rnv-interface' }

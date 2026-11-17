fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rnv-crime'
description 'RUN V - shop robberies, locked rooms, safes (Mini Drill), Bank Vault (Drill), police armory, alarms'
version '0.1.0'

shared_scripts {
    '@rnv-core/lib/init.lua',
    'config.lua',
}
client_script 'client/main.lua'
server_script 'server/main.lua'

dependencies { 'rnv-core', 'rnv-interface', 'rnv-inventory' }

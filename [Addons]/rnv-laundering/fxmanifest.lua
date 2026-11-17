fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rnv-laundering'
description 'RUN V - Laundering Desk in every house: cash storage, laundering, Transfer to My Account'
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

dependencies { 'oxmysql', 'rnv-core', 'rnv-inventory', 'rnv-housing' }

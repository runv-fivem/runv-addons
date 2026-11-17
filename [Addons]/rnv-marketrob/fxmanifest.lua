fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rnv-marketrob'
description 'RUN V - store robbery: 24/7, LTD, Rob\'s Liquor and clothing stores in Los Santos (tills, shelves, back door, safe, poster, clerk)'

shared_scripts {
    '@rnv-core/lib/init.lua',
    'config.lua',
    'stores.lua',
    'stagemodels.lua',
    'fridgedoors.lua',
}
client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/icons/*.svg',
}

dependencies {
    'rnv-core',
    'rnv-interface',
    'rnv-inventory',
    'rnv-robbase',
}

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rnv-housing'
description 'RUN V - land plots (rent, Plot Plan structures), main building interior, cabinet stash, residence'
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

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/vue.global.prod.js',
    'html/fonts/*.otf',
    'html/img/*.png',
    'html/icons/*.svg',
    'html/fonts/*.woff',
}

dependencies { 'oxmysql', 'rnv-core', 'rnv-interface', 'rnv-inventory' }

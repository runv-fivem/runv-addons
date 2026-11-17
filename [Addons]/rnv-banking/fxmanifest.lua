fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rnv-banking'
description 'RUN V - Bank Employee (open account) and cash withdrawals (employee + ATMs)'
version '0.1.0'

shared_scripts {
    '@rnv-core/lib/init.lua',
    'config.lua',
}
client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/vue.global.prod.js',
    'html/fonts/*.otf',
    'html/fonts/*.woff',
    'html/img/*.png',
}

dependencies { 'rnv-core', 'rnv-interface', 'rnv-inventory' }

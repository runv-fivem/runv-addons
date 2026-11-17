fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rnv-world'
description 'RUN V - motel area + world map travel'
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
    'html/img/*.jpg',
}

dependencies { 'rnv-core' }

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rnv-houserob'
description 'RUN V - house robbery in the Mirror Park homes (electric box, alarm, NPC witnesses, paintings, valuables, safe)'

shared_scripts {
    '@rnv-core/lib/init.lua',
    'config.lua',
}
client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/fonts/*.otf',
    'html/icons/*.svg',
}

dependencies {
    'rnv-core',
    'rnv-interface',
    'rnv-inventory',
    'rnv-robbase',
}

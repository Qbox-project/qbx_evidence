fx_version 'cerulean'
game 'gta5'

name 'qbx_evidence'
description 'Evidence system for Qbox'
repository 'https://github.com/Qbox-project/qbx_evidence'
version '1.0.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua'
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

files {
    'config/client.lua',
    'config/shared.lua',
    'locales/*.json',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
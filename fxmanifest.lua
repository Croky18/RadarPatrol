lua54 'yes'

fx_version 'cerulean'
game 'gta5'

author 'Croky19'
description 'QBCore/ESX Police Speed Radar Script'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client/main.lua'
server_script 'server/main.lua'

dependency 'ox_lib'
fx_version 'cerulean'
game 'gta5'

author "Mrlion (@lostedmrlion)"
version "1.0"
description 'Specialized weapon animations for LEO jobs'

files {
    'data/clip_sets.xml'
}

data_file 'CLIP_SETS_FILE' 'data/clip_sets.xml'

client_scripts {
    'config.lua',
    'client.lua'
}

server_scripts {
    'server.lua'
}

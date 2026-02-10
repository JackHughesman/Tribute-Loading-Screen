fx_version 'cerulean'
game 'gta5'

author 'MysticDev'
description 'Mystic MTA-style chat (NUI)'

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/index.css',
  'html/app.js',
  'html/sounds/*.ogg',
  'config.lua'
}


shared_script 'config.lua'
client_script 'cl_chat.lua'
server_script 'sv_chat.lua'

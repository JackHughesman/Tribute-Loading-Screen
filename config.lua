Config = {}

--MYSTIC DEVELOPMENT CUSTOM CHAT 
--For any questions make sure to read the README file.

Config.Colors = {
  WHITE = {255,255,255},
  ERROR = {255,80,80}
}
Config.UI = {
  maxMessagesVisible = 16,      
  maxMessagesStored  = 250,     

  -- Idle fade
  idleFadeEnabled = true,
  idleFadeDelay   = 15000,
  idleFadeOpacity = 0.20,

  -- PageUp/PageDown behavior
  pageScrollLines = 2,          -- smooth feel (small steps)
  allowScrollWhenNotTyping = true,

  -- Smooth scroll animation
  smoothScroll = true,
  smoothScrollMs = 140
}

Config.MainChat = {
  proximityEnabled = false,
  radius = 25.0,
  roleplayMode = false
}

Config.Commands = {
  me = "me",
  doCmd = "do",
  looc = "looc",
  loocAlias = "l",
  ooc = "ooc",
  pm = "pm",
  rpm = "rpm",
  announce = "announce" 
}

--/me command
Config.Me = {
  enabled = true,
  proximityEnabled = true,
  radius = 25.0,
  color = {255,105,180}
}

--/do command
Config.Do = {
  enabled = true,
  proximityEnabled = true,
  radius = 25.0,
  color = {255,105,180}
}

--/looc command OR B binding   for local out of character chat
Config.LocalOOC = {
  enabled = true,
  radius = 25.0,
  mode = "keybind",
  keybind = {
    commandName = "looc_key",
    defaultKey = "B"
  }
}

--/ooc command that is serverwide
Config.GlobalOOC = {
  enabled = true,
  whitelistEnabled = false,
  steamWhitelist = { "steam:110000112345678" },
  color = {190,220,255}
}

--/announce command 
Config.Announce = {
  enabled = true,
  whitelistEnabled = false,
  steamWhitelist = { "steam:110000112345678" },         
  prefixColor = {255, 60, 60}, 
  messageColor = {255,255,255}  
}

--/pm command 
Config.PM = {
  enabled = true,
  color = {255,255,0}
}

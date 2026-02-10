-- mystic-chat/sv_chat.lua

local lastPMFrom = {}
local lastPMTo   = {}

-- ----------------------------
-- Helpers
-- ----------------------------
local function getSteamIdentifier(src)
  for _, id in ipairs(GetPlayerIdentifiers(src)) do
    if id:sub(1, 6) == "steam:" then
      return id
    end
  end
  return nil
end

local function isSteamWhitelisted(src, list)
  local steam = getSteamIdentifier(src)
  if not steam then return false end
  for _, allowed in ipairs(list or {}) do
    if tostring(allowed):lower() == tostring(steam):lower() then
      return true
    end
  end
  return false
end

local function dist(a, b)
  local dx = a.x - b.x
  local dy = a.y - b.y
  local dz = a.z - b.z
  return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function getCoords(src)
  local ped = GetPlayerPed(src)
  if ped and ped ~= 0 then
    return GetEntityCoords(ped)
  end
  return nil
end

local function sendToPlayer(src, color, text)
  TriggerClientEvent('chat:addMessage', src, {
    color = color or (Config.Colors and Config.Colors.WHITE) or {255,255,255},
    multiline = true,
    args = { text }
  })
end

local function sendToAll(color, text)
  TriggerClientEvent('chat:addMessage', -1, {
    color = color or (Config.Colors and Config.Colors.WHITE) or {255,255,255},
    multiline = true,
    args = { text }
  })
end

local function sendProximity(src, radius, color, text)
  local srcCoords = getCoords(src)
  if not srcCoords then
    sendToAll(color, text)
    return
  end

  for _, pid in ipairs(GetPlayers()) do
    local p = tonumber(pid)
    if p then
      local pCoords = getCoords(p)
      if pCoords and dist(srcCoords, pCoords) <= radius then
        sendToPlayer(p, color, text)
      end
    end
  end
end

local function broadcastMainChat(src, color, text)
  local main = Config.MainChat or {}
  if main.proximityEnabled then
    sendProximity(src, main.radius or 25.0, color, text)
  else
    sendToAll(color, text)
  end
end

local function rgbToHex(rgb, fallback)
  if type(rgb) == "table" and #rgb >= 3 then
    return string.format("%02X%02X%02X", rgb[1], rgb[2], rgb[3])
  end
  return fallback or "FFFFFF"
end

-- Find player by numeric id OR partial name (case-insensitive)
local function findPlayerByQuery(query)
  if not query or query == "" then
    return nil, "Usage: /pm <id|name> <message>"
  end

  -- numeric id?
  local id = tonumber(query)
  if id and GetPlayerName(id) then
    return id, nil
  end

  local q = tostring(query):lower()
  local matches = {}

  for _, pid in ipairs(GetPlayers()) do
    local p = tonumber(pid)
    if p then
      local name = GetPlayerName(p)
      if name and name:lower():find(q, 1, true) then
        table.insert(matches, { id = p, name = name })
      end
    end
  end

  if #matches == 0 then
    return nil, "No player matched that name."
  end

  if #matches == 1 then
    return matches[1].id, nil
  end

  table.sort(matches, function(a,b) return a.id < b.id end)
  local preview = {}
  for i = 1, math.min(5, #matches) do
    preview[#preview+1] = string.format("%d:%s", matches[i].id, matches[i].name)
  end

  return nil, "Multiple matches: " .. table.concat(preview, ", ") .. " (be more specific or use ID)"
end

-- ----------------------------
-- Suggestions init
-- ----------------------------
RegisterNetEvent('chat:init', function()
  local src = source
  local cmds = Config.Commands or {}

  TriggerClientEvent('chat:addSuggestion', src, "/" .. (cmds.me or "me"), "Roleplay action (local if enabled)", {
    { name = "message", help = "What your character does" }
  })

  TriggerClientEvent('chat:addSuggestion', src, "/" .. (cmds.doCmd or "do"), "Roleplay scene description (local if enabled)", {
    { name = "message", help = "Describe the scene/event" }
  })

  TriggerClientEvent('chat:addSuggestion', src, "/" .. (cmds.looc or "looc"), "Local OOC chat", {
    { name = "message", help = "Message" }
  })

  TriggerClientEvent('chat:addSuggestion', src, "/" .. (cmds.ooc or "ooc"), "Global OOC chat", {
    { name = "message", help = "Message" }
  })

  TriggerClientEvent('chat:addSuggestion', src, "/" .. ((cmds.announce) or "announce"), "Server announcement (whitelist optional)", {
    { name = "message", help = "Message" }
  })

  TriggerClientEvent('chat:addSuggestion', src, "/" .. (cmds.pm or "pm"), "Private message", {
    { name = "id|name", help = "Player ID or partial name" },
    { name = "message", help = "Message" }
  })

  TriggerClientEvent('chat:addSuggestion', src, "/" .. (cmds.rpm or "rpm"), "Reply to last PM", {
    { name = "message", help = "Message" }
  })
end)

-- ----------------------------
-- Default (non-command) chat
-- ----------------------------
RegisterNetEvent('_chat:messageEntered', function(author, color, message)
  local src = source
  if not message or message == "" then return end

  local name = GetPlayerName(src) or author or ("ID " .. tostring(src))
  local line = string.format("%s: %s", name, message)

  broadcastMainChat(src, (Config.Colors and Config.Colors.WHITE) or {255,255,255}, line)
end)

-- ----------------------------
-- /me  "* Name message"
-- ----------------------------
RegisterCommand((Config.Commands and Config.Commands.me) or "me", function(src, args)
  if not (Config.Me and Config.Me.enabled) then
    sendToPlayer(src, Config.Colors.ERROR, "This command is disabled.")
    return
  end

  local msg = (table.concat(args, " ") or ""):gsub("%s+$", "")
  if msg == "" then
    sendToPlayer(src, Config.Colors.ERROR, "Usage: /me <message>")
    return
  end

  local name = GetPlayerName(src) or ("ID " .. tostring(src))
  local line = string.format("* %s %s", name, msg)

  if Config.Me.proximityEnabled then
    sendProximity(src, Config.Me.radius or 25.0, Config.Me.color or {255,105,180}, line)
  else
    sendToAll(Config.Me.color or {255,105,180}, line)
  end
end, false)

-- ----------------------------
-- /do "* msg ((Name))"
-- ----------------------------
RegisterCommand((Config.Commands and Config.Commands.doCmd) or "do", function(src, args)
  if not (Config.Do and Config.Do.enabled) then
    sendToPlayer(src, Config.Colors.ERROR, "This command is disabled.")
    return
  end

  local msg = (table.concat(args, " ") or ""):gsub("%s+$", "")
  if msg == "" then
    sendToPlayer(src, Config.Colors.ERROR, "Usage: /do <message>")
    return
  end

  local name = GetPlayerName(src) or ("ID " .. tostring(src))
  local line = string.format("* %s ((%s))", msg, name)

  if Config.Do.proximityEnabled then
    sendProximity(src, Config.Do.radius or 25.0, Config.Do.color or {255,105,180}, line)
  else
    sendToAll(Config.Do.color or {255,105,180}, line)
  end
end, false)

-- ----------------------------
-- /looc  "Name: (( message ))"
-- ----------------------------
RegisterCommand((Config.Commands and Config.Commands.looc) or "looc", function(src, args)
  if not (Config.LocalOOC and Config.LocalOOC.enabled) then
    sendToPlayer(src, Config.Colors.ERROR, "Local OOC is disabled.")
    return
  end

  local msg = (table.concat(args, " ") or ""):gsub("%s+$", "")
  if msg == "" then
    sendToPlayer(src, Config.Colors.ERROR, "Usage: /looc <message>")
    return
  end

  local name = GetPlayerName(src) or ("ID " .. tostring(src))
  local line = string.format("%s: (( %s ))", name, msg)

  local color = (Config.GlobalOOC and Config.GlobalOOC.color) or {190,220,255}
  sendProximity(src, Config.LocalOOC.radius or 25.0, color, line)
end, false)

-- /l alias for looc
RegisterCommand((Config.Commands and Config.Commands.loocAlias) or "l", function(src, args)
  ExecuteCommand(((Config.Commands and Config.Commands.looc) or "looc") .. " " .. table.concat(args, " "))
end, false)

-- ----------------------------
-- /ooc (global)
-- ----------------------------
RegisterCommand((Config.Commands and Config.Commands.ooc) or "ooc", function(src, args)
  if not (Config.GlobalOOC and Config.GlobalOOC.enabled) then
    sendToPlayer(src, Config.Colors.ERROR, "Global OOC is disabled.")
    return
  end

  if Config.GlobalOOC.whitelistEnabled then
    if not isSteamWhitelisted(src, Config.GlobalOOC.steamWhitelist) then
      sendToPlayer(src, Config.Colors.ERROR, "You are not whitelisted to use /ooc.")
      return
    end
  end

  local msg = (table.concat(args, " ") or ""):gsub("%s+$", "")
  if msg == "" then
    sendToPlayer(src, Config.Colors.ERROR, "Usage: /ooc <message>")
    return
  end

  local name = GetPlayerName(src) or ("ID " .. tostring(src))
  local line = string.format("OOC: %s ((%s))", msg, name)

  sendToAll(Config.GlobalOOC.color or {190,220,255}, line)
end, false)

-- ----------------------------
-- /announce (global) + sound to all
-- ----------------------------
RegisterCommand((Config.Commands and Config.Commands.announce) or "announce", function(src, args)
  if not (Config.Announce and Config.Announce.enabled) then
    sendToPlayer(src, Config.Colors.ERROR, "Announcements are disabled.")
    return
  end

  if Config.Announce.whitelistEnabled then
    if not isSteamWhitelisted(src, Config.Announce.steamWhitelist) then
      sendToPlayer(src, Config.Colors.ERROR, "You are not whitelisted to use /announce.")
      return
    end
  end

  local msg = (table.concat(args, " ") or ""):gsub("%s+$", "")
  if msg == "" then
    sendToPlayer(src, Config.Colors.ERROR, "Usage: /announce <message>")
    return
  end

  local prefixHex = rgbToHex(Config.Announce.prefixColor, "FF3C3C")
  local msgHex    = rgbToHex(Config.Announce.messageColor, "FFFFFF")
  local line      = string.format("^#%sANNOUNCEMENT:^#%s %s", prefixHex, msgHex, msg)

  sendToAll((Config.Colors and Config.Colors.WHITE) or {255,255,255}, line)
  TriggerClientEvent('mystic-chat:playSound', -1, 'announce')
end, false)

-- ----------------------------
-- /pm <id|partialName> <message>  + sound to receiver only
-- ----------------------------
RegisterCommand((Config.Commands and Config.Commands.pm) or "pm", function(src, args)
  if not (Config.PM and Config.PM.enabled) then
    sendToPlayer(src, Config.Colors.ERROR, "PMs are disabled.")
    return
  end

  local targetQuery = args[1]
  if not targetQuery then
    sendToPlayer(src, Config.Colors.ERROR, "Usage: /pm <id|name> <message>")
    return
  end

  table.remove(args, 1)
  local msg = (table.concat(args, " ") or ""):gsub("%s+$", "")
  if msg == "" then
    sendToPlayer(src, Config.Colors.ERROR, "Usage: /pm <id|name> <message>")
    return
  end

  local targetId, err = findPlayerByQuery(targetQuery)
  if not targetId then
    sendToPlayer(src, Config.Colors.ERROR, err or "Invalid target.")
    return
  end

  local srcName = GetPlayerName(src) or ("ID " .. tostring(src))
  local tgtName = GetPlayerName(targetId) or ("ID " .. tostring(targetId))

  lastPMTo[src] = targetId
  lastPMFrom[targetId] = src

  local color = Config.PM.color or {255,255,0}
  sendToPlayer(src, color, string.format("PM to %s: %s", tgtName, msg))
  sendToPlayer(targetId, color, string.format("PM from %s: %s", srcName, msg))

  TriggerClientEvent('mystic-chat:playSound', targetId, 'pm')
end, false)

-- ----------------------------
-- /rpm <message>
-- ----------------------------
RegisterCommand((Config.Commands and Config.Commands.rpm) or "rpm", function(src, args)
  if not (Config.PM and Config.PM.enabled) then
    sendToPlayer(src, Config.Colors.ERROR, "PMs are disabled.")
    return
  end

  local targetId = lastPMFrom[src] or lastPMTo[src]
  if not targetId or not GetPlayerName(targetId) then
    sendToPlayer(src, Config.Colors.ERROR, "No one to reply to.")
    return
  end

  local msg = (table.concat(args, " ") or ""):gsub("%s+$", "")
  if msg == "" then
    sendToPlayer(src, Config.Colors.ERROR, "Usage: /rpm <message>")
    return
  end

  local srcName = GetPlayerName(src) or ("ID " .. tostring(src))
  local tgtName = GetPlayerName(targetId) or ("ID " .. tostring(targetId))

  lastPMTo[src] = targetId
  lastPMFrom[targetId] = src

  local color = Config.PM.color or {255,255,0}
  sendToPlayer(src, color, string.format("PM to %s: %s", tgtName, msg))
  sendToPlayer(targetId, color, string.format("PM from %s: %s", srcName, msg))

  TriggerClientEvent('mystic-chat:playSound', targetId, 'pm')
end, false)

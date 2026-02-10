local chatInputActive = false
local chatInputActivating = false
local chatHidden = false
local chatLoaded = false
local chatManuallyHidden = false

-- scroll state
local scrollVel = 0.0
local scrollDir = 0 -- -1 down, +1 up
local scrollAcc = 0.0

-- tuning (feels MTA-ish)
local SCROLL_ACCEL = 14.0
local SCROLL_DECAY = 10.0
local SCROLL_MAX_VEL = 18.0
local SCROLL_EVENT_RATE = 18.0 -- events per second at max-ish

RegisterNetEvent('chat:addMessage')
RegisterNetEvent('chat:clear')
RegisterNetEvent('__cfx_internal:serverPrint')
RegisterNetEvent('_chat:messageEntered')
RegisterNetEvent('mystic-chat:playSound')

AddEventHandler('chat:addMessage', function(message)
  if chatManuallyHidden then return end
  SendNUIMessage({ type = 'ON_MESSAGE', message = message })
end)

AddEventHandler('chat:clear', function()
  SendNUIMessage({ type = 'ON_CLEAR' })
end)

AddEventHandler('__cfx_internal:serverPrint', function(msg)
  if chatManuallyHidden then return end
  SendNUIMessage({
    type = 'ON_MESSAGE',
    message = { color = {255,255,255}, args = { msg } }
  })
end)

RegisterNUICallback('loaded', function(_, cb)
  chatLoaded = true

  local ui = (Config and Config.UI) or {}
  SendNUIMessage({
    type = "ON_CONFIG",
    config = {
      maxMessagesVisible = ui.maxMessagesVisible or 16,
      maxMessagesStored  = ui.maxMessagesStored  or 250,
      pageScrollLines    = ui.pageScrollLines    or 2,
      smoothScroll       = (ui.smoothScroll ~= false),
      smoothScrollMs     = ui.smoothScrollMs or 160
    }
  })

  cb('ok')
end)

RegisterNUICallback('chatResult', function(data, cb)
  chatInputActive = false
  SetNuiFocus(false, false)

  if data and not data.canceled then
    local msg = data.message or ""
    if msg ~= "" then
      if msg:sub(1, 1) == "/" then
        ExecuteCommand(msg:sub(2))
      else
        TriggerServerEvent('_chat:messageEntered', GetPlayerName(PlayerId()), {255,255,255}, msg)
      end
    end
  end

  cb('ok')
end)

RegisterCommand("hidechat", function()
  chatManuallyHidden = true
  SendNUIMessage({ type = "ON_HIDE_CHAT" })
end, false)

RegisterCommand("showchat", function()
  chatManuallyHidden = false
  SendNUIMessage({ type = "ON_SHOW_CHAT" })
end, false)

AddEventHandler('mystic-chat:playSound', function(sound)
  SendNUIMessage({ type = "ON_SOUND", sound = sound })
end)

local function openChatWithPrefix(prefix)
  if chatInputActive or chatManuallyHidden then return end
  chatInputActive = true
  chatInputActivating = true
  SendNUIMessage({ type = 'ON_OPEN', prefix = prefix or "" })
end

-- Main loop
CreateThread(function()
  SetTextChatEnabled(false)
  SetNuiFocus(false, false)

  local last = GetGameTimer()

  while true do
    Wait(0)
    local now = GetGameTimer()
    local dt = (now - last) / 1000.0
    last = now

    -- page up/down hold + glide
    if chatLoaded and not chatManuallyHidden then
      local holdingUp = IsControlPressed(0, 10)   -- PageUp
      local holdingDn = IsControlPressed(0, 11)   -- PageDown

      if holdingUp and not holdingDn then
        scrollDir = 1
        scrollVel = math.min(SCROLL_MAX_VEL, scrollVel + SCROLL_ACCEL * dt)
      elseif holdingDn and not holdingUp then
        scrollDir = -1
        scrollVel = math.min(SCROLL_MAX_VEL, scrollVel + SCROLL_ACCEL * dt)
      else
        -- glide/decay
        scrollVel = math.max(0.0, scrollVel - SCROLL_DECAY * dt)
        if scrollVel == 0.0 then scrollDir = 0 end
      end

      if scrollVel > 0.0 and scrollDir ~= 0 then
        -- convert velocity into repeated scroll events
        scrollAcc = scrollAcc + (scrollVel / SCROLL_MAX_VEL) * (SCROLL_EVENT_RATE * dt)
        while scrollAcc >= 1.0 do
          scrollAcc = scrollAcc - 1.0
          SendNUIMessage({ type = "ON_SCROLL", dir = (scrollDir == 1 and "up" or "down") })
        end
      end
    end

    -- B keybind -> open chat with /looc prefix (only if enabled + keybind mode)
    if not chatInputActive and not chatManuallyHidden then
      if Config and Config.LocalOOC and Config.LocalOOC.enabled and Config.LocalOOC.mode == "keybind" then
        local bPressed = IsControlJustPressed(0, 29) -- B
        if bPressed then
          local loocCmd = (Config.Commands and Config.Commands.looc) or "looc"
          openChatWithPrefix("/" .. loocCmd .. " ")
        end
      end
    end

    -- open chat with T
    if not chatInputActive and not chatManuallyHidden and IsControlPressed(0, 245) then
      openChatWithPrefix("")
    end

    if chatInputActivating and not IsControlPressed(0, 245) then
      if chatLoaded then
        SetNuiFocus(true, true)
      else
        chatInputActive = false
      end
      chatInputActivating = false
    end

    local shouldHide = IsScreenFadedOut() or IsPauseMenuActive()
    if shouldHide ~= chatHidden then
      chatHidden = shouldHide
      SendNUIMessage({ type = 'ON_SCREEN_STATE_CHANGE', shouldHide = shouldHide })
    end
  end
end)

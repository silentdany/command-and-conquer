-- Setup, key bindings, slash commands.
--
-- Secure frames, attributes and override bindings can only be changed out
-- of combat, so everything here is deferred to PLAYER_REGEN_ENABLED when
-- the player is fighting.

local ADDON_NAME, ns = ...
local W = ns.Wheel

local PREFIX = "|cff4fa3ffCommand & Conquer|r: "

BINDING_HEADER_CNC = "Command & Conquer"
BINDING_NAME_CNC_WHEEL = "Call wheel (hold, flick, release)"
BINDING_NAME_CNC_INC = "INC wheel (direct)"
BINDING_NAME_CNC_EFC = "EFC wheel (direct)"
BINDING_NAME_CNC_FLAG = "FLAG wheel (direct)"
BINDING_NAME_CNC_DEF = "DEF wheel (direct)"
BINDING_NAME_CNC_ATTACK = "ATTACK wheel (direct)"

local function out(fmt, ...)
  local text = select("#", ...) > 0 and fmt:format(...) or fmt
  DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. text)
end

local pendingSetup = false

local function playerFullName()
  local name, realm
  if UnitFullName then name, realm = UnitFullName("player") end
  name = name or UnitName("player")
  if (not realm or realm == "") and GetNormalizedRealmName then realm = GetNormalizedRealmName() end
  if realm and realm ~= "" then return name .. "-" .. realm end
  return name
end

-- Test mode whispers yourself instead of writing in /bg.
local function currentPrefix()
  if CnCDB.test then return "/w " .. playerFullName() end
  return "/bg"
end

---------------------------------------------------------------------------
-- Bindings: Bindings.xml declares the keys (so they show in the game's key
-- binding screen); here they become clicks on the secure wheel button.
---------------------------------------------------------------------------

local BINDINGS = { { name = "CNC_WHEEL", button = "LeftButton" } }
for name, a in pairs(ns.DIRECT) do
  BINDINGS[#BINDINGS + 1] = { name = name, button = ns.ACTIONS[a].key }
end

local lastSignature

local function applyBindings()
  local parts, list = {}, {}
  for _, b in ipairs(BINDINGS) do
    local keys = { GetBindingKey(b.name) }
    for _, key in ipairs(keys) do
      list[#list + 1] = { key = key, button = b.button }
      parts[#parts + 1] = key .. "=" .. b.button
    end
  end
  table.sort(parts)
  local signature = table.concat(parts, ",")
  if signature == lastSignature then return #list end
  lastSignature = signature

  ClearOverrideBindings(W.send)
  for _, item in ipairs(list) do
    SetOverrideBindingClick(W.send, true, item.key, W.BUTTON_NAME, item.button)
  end
  return #list
end

local function setup()
  if InCombatLockdown() then
    pendingSetup = true
    return
  end
  pendingSetup = false
  W:Build()
  W:SetPrefix(currentPrefix())
  W:SetScale(CnCDB.scale or 1)
  local count = applyBindings()
  if count == 0 then
    out("bind a key in Esc > Key Bindings > AddOns > Command & Conquer.")
  end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function help()
  out("hold your wheel key, flick toward an action, then a choice, release to send.")
  out("Back to the center before release = nothing sent.")
  out("/cnc test : toggle test mode (whisper yourself instead of /bg)")
  out("/cnc scale <0.6-2> : wheel size (default 1)")
  out("/cnc status : show mode and bound keys")
end

local function status()
  out("mode: %s, size %.2f", CnCDB.test and "TEST (whisper to yourself)" or "/bg", CnCDB.scale or 1)
  for _, b in ipairs(BINDINGS) do
    local keys = { GetBindingKey(b.name) }
    if #keys > 0 then out("  %s: %s", _G["BINDING_NAME_" .. b.name], table.concat(keys, ", ")) end
  end
end

SLASH_COMMANDANDCONQUER1 = "/cnc"
SlashCmdList.COMMANDANDCONQUER = function(input)
  local cmd, arg = (input or ""):lower():match("^%s*(%S*)%s*(%S*)")
  if cmd == "test" then
    if InCombatLockdown() then
      out("can't change mode in combat.")
      return
    end
    CnCDB.test = not CnCDB.test
    W:SetPrefix(currentPrefix())
    out("test mode %s.", CnCDB.test and "ON: calls are whispered to you" or "OFF: calls go to /bg")
  elseif cmd == "scale" then
    local value = tonumber(arg)
    if not value or value < 0.6 or value > 2 then
      out("usage: /cnc scale <0.6-2> (now %.2f)", CnCDB.scale or 1)
      return
    end
    if not W:SetScale(value) then
      out("can't change size in combat.")
      return
    end
    CnCDB.scale = value
    out("wheel size %.2f.", value)
  elseif cmd == "status" then
    status()
  else
    help()
  end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UPDATE_BINDINGS")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == ADDON_NAME then
      CnCDB = CnCDB or {}
    end
  elseif event == "PLAYER_LOGIN" then
    setup()
  elseif event == "UPDATE_BINDINGS" then
    if not W.built then return end
    if InCombatLockdown() then pendingSetup = true else applyBindings() end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if pendingSetup then setup() end
  end
end)

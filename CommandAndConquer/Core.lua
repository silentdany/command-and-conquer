-- Setup, key bindings, slash commands.
--
-- Secure frames, attributes and override bindings can only be changed out
-- of combat, so everything here is deferred to PLAYER_REGEN_ENABLED when
-- the player is fighting.

local ADDON_NAME, ns = ...
local W = ns.Wheel

local PREFIX = "|cff4fa3ffCommand & Conquer|r: "

BINDING_HEADER_CNC = "Command & Conquer"
BINDING_NAME_CNC_WHEEL = "C&C: wheel"
BINDING_NAME_CNC_DEF = "C&C: DEF only"
BINDING_NAME_CNC_FLAG = "C&C: FLAG only"
BINDING_NAME_CNC_EFC = "C&C: EFC only"
BINDING_NAME_CNC_ATTACK = "C&C: ATTACK only"
BINDING_NAME_CNC_SCOUT = "C&C: SCOUT only"
BINDING_NAME_CNC_INC = "C&C: INC only"

local function out(fmt, ...)
  local text = select("#", ...) > 0 and fmt:format(...) or fmt
  DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. text)
end

local pendingSetup = false

-- /cnc debug prints what the wheel sees, to diagnose in game.
function ns.Debug(fmt, ...)
  if not ns.debug then return end
  local text = select("#", ...) > 0 and fmt:format(...) or fmt
  DEFAULT_CHAT_FRAME:AddMessage("|cff999999[C&C debug]|r " .. text)
end

local function playerFullName()
  local name, realm
  if UnitFullName then name, realm = UnitFullName("player") end
  name = name or UnitName("player")
  if (not realm or realm == "") and GetNormalizedRealmName then realm = GetNormalizedRealmName() end
  if realm and realm ~= "" then return name .. "-" .. realm end
  return name
end

-- Automatic: /bg in a battleground, a whisper to yourself anywhere else
-- (practice). A saved test toggle stayed on in a BG once (17/11/2026), so
-- there is no toggle any more.
local function inBattleground()
  local _, instanceType = IsInInstance()
  return instanceType == "pvp"
end

local function currentPrefix()
  if inBattleground() then return "/bg" end
  return "/w " .. playerFullName()
end

local lastPrefix

local function updatePrefix()
  local prefix = currentPrefix()
  if prefix == lastPrefix then return end
  if not W:SetPrefix(prefix) then
    return false
  end
  lastPrefix = prefix
  if prefix == "/bg" then
    out("battleground: calls go to /bg.")
  else
    out("outside battlegrounds: calls are whispered to you (practice).")
  end
  return true
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
  updatePrefix()
  W:SetScale(CnCDB.scale or 1)
  local count = applyBindings()
  if count == 0 then
    out("bind a key to \"C&C: wheel\" in Esc > Key Bindings > AddOns.")
  end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function help()
  out("hold your wheel key, flick toward an action, then a choice, release to send.")
  out("Back to the center before release = nothing sent. Right click = one step back, right click twice = close.")
  out("In a battleground calls go to /bg; anywhere else they are whispered to you (practice).")
  out("/cnc scale <0.6-2> : wheel size (default 1)")
  out("/cnc status : show mode and bound keys")
end

local function status()
  out("calls go to: %s, size %.2f", inBattleground() and "/bg" or "a whisper to you (practice)", CnCDB.scale or 1)
  for _, b in ipairs(BINDINGS) do
    local keys = { GetBindingKey(b.name) }
    if #keys > 0 then out("  %s: %s", _G["BINDING_NAME_" .. b.name], table.concat(keys, ", ")) end
  end
end

SLASH_COMMANDANDCONQUER1 = "/cnc"
SlashCmdList.COMMANDANDCONQUER = function(input)
  local cmd, arg = (input or ""):lower():match("^%s*(%S*)%s*(%S*)")
  if cmd == "scale" then
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
  elseif cmd == "debug" then
    ns.debug = not ns.debug
    out("debug %s.", ns.debug and "ON (prints to chat while the wheel is used)" or "OFF")
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
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == ADDON_NAME then
      CnCDB = CnCDB or {}
      CnCDB.test = nil -- old saved toggle (v0.1 to v0.3)
    end
  elseif event == "PLAYER_LOGIN" then
    setup()
  elseif event == "UPDATE_BINDINGS" then
    if not W.built then return end
    if InCombatLockdown() then pendingSetup = true else applyBindings() end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    if not W.built then return end
    if InCombatLockdown() then pendingSetup = true else updatePrefix() end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if pendingSetup then setup() end
  end
end)

-- Setup, key bindings, slash commands, experimental switches.
--
-- Secure frames, attributes and override bindings can only be changed out
-- of combat, so everything here is deferred to PLAYER_REGEN_ENABLED when
-- the player is fighting.

local ADDON_NAME, ns = ...
local W = ns.Wheel
local R = ns.Report

local PREFIX = "|cff4fa3ffCommand & Conquer|r: "

BINDING_HEADER_CNC = "Command & Conquer"
BINDING_NAME_CNC_WHEEL = "C&C: wheel"
BINDING_NAME_CNC_EFC = "C&C: EFC only (their carrier)"
BINDING_NAME_CNC_ATTACK = "C&C: ATTACK only"
BINDING_NAME_CNC_FC = "C&C: FC only (our carrier)"
BINDING_NAME_CNC_DEF = "C&C: DEF only"
BINDING_NAME_CNC_INC = "C&C: INC only"

local function out(fmt, ...)
  local text = select("#", ...) > 0 and fmt:format(...) or fmt
  DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. text)
end
ns.Print = out

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
  local wasBG = lastPrefix == "/bg"
  lastPrefix = prefix
  if prefix == "/bg" then
    out("battleground: calls go to /bg.")
    R:Add("zone", "entered a battleground")
  else
    out("outside battlegrounds: calls are whispered to you (practice).")
    if wasBG then R:Add("zone", "left the battleground, stats: %s", R:Summary()) end
  end
  return true
end

---------------------------------------------------------------------------
-- Options and experimental switches
--
-- Uncertain features sit behind "experimental", with an automatic fallback
-- to the v0.7 behaviour (decision 18/11/2026). Timed features need the
-- secure timer self-test to pass.
---------------------------------------------------------------------------

local EXP_FEATURES = {
  hover = "hover delay: a sector is picked after 0.1 s on its icon",
  undo = "tap the key within 3 s after a call: \"Ignore my last call\"",
  carrier = "pings and skull on the carriers' units, \"I have their flag\" when you carry",
}

ns.timersOK = nil -- nil = not tested yet

local function defaults()
  CnCDB.exp = CnCDB.exp or {}
  local exp = CnCDB.exp
  if exp.on == nil then exp.on = false end
  for name in pairs(EXP_FEATURES) do
    if exp[name] == nil then exp[name] = true end
  end
  CnCDB.carriers = CnCDB.carriers or {}
end

local function expOn(name)
  return CnCDB.exp.on and CnCDB.exp[name]
end

local function carrierUnits()
  if not expOn("carrier") then return {} end
  return { enemyUnit = CnCDB.carriers.enemy, friendUnit = CnCDB.carriers.friend }
end

local function applyOptions()
  if InCombatLockdown() then
    pendingSetup = true
    return false
  end
  local timers = ns.timersOK == true
  local units = carrierUnits()
  W:SetOptions({
    dwell = (timers and expOn("hover")) and 0.1 or nil,
    undo = timers and expOn("undo"),
    me = expOn("carrier") and units.friendUnit ~= nil,
    fcUnit = units.friendUnit,
  })
  W:ApplyPings(units)
  return true
end
ns.ApplyOptions = applyOptions

---------------------------------------------------------------------------
-- Bindings: Bindings.xml declares the keys (so they show in the game's key
-- binding screen); here they become clicks on the secure wheel button.
---------------------------------------------------------------------------

local BINDINGS = { { name = "CNC_WHEEL", button = "LeftButton" } }
for name, a in pairs(ns.DIRECT) do
  BINDINGS[#BINDINGS + 1] = { name = name, button = ns.ACTIONS[a].key }
end
table.sort(BINDINGS, function(x, y) return x.name < y.name end)

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

local function runSelfTest(asked)
  W:SelfTest(function(ok, detail, env)
    ns.timersOK = ok
    ns.secureEnv = env
    R:Add("selftest", "secure timers %s (%s)%s; secure code sees UnitIsUnit=%s, UnitExists=%s",
      ok and "OK" or "FAILED", detail, asked and ", /cnc timers" or "", tostring(env.UnitIsUnit), tostring(env.UnitExists))
    if asked then
      out("secure timers %s (%s): hover and undo %s.", ok and "OK" or "FAILED", detail, ok and "possible" or "off")
    elseif not ok then
      ns.Debug("secure timers unavailable: hover and undo stay off.")
    end
    applyOptions()
  end)
end

local function setup()
  if InCombatLockdown() then
    pendingSetup = true
    return
  end
  pendingSetup = false
  local first = not W.built
  W:Build()
  updatePrefix()
  W:SetScale(CnCDB.scale or 1)
  W:SetPings(CnCDB.ping ~= false)
  applyOptions()
  local count = applyBindings()
  if first then
    if count == 0 then
      out("bind a key to \"C&C: wheel\" in Esc > Key Bindings > AddOns.")
    end
    runSelfTest()
  end
end

-- What every release did, for the report.
W.OnClosed = function(result, msg, path)
  if result == "none" then return end
  R:Count(result)
  local extra = ""
  if CnCDB.exp.on then
    local units = carrierUnits()
    local seen = {}
    if units.enemyUnit then seen[#seen + 1] = "enemy " .. units.enemyUnit .. "=" .. tostring(UnitExists(units.enemyUnit)) end
    if units.friendUnit then seen[#seen + 1] = "friend " .. units.friendUnit .. "=" .. tostring(UnitExists(units.friendUnit)) end
    if #seen > 0 then extra = " [units " .. table.concat(seen, ", ") .. "]" end
  end
  -- Rings shifted to stay on screen (or rects not readable), see Wheel.lua.
  local fit = W.send and W.send:GetAttribute("fit")
  if fit and fit ~= "" then extra = extra .. " [fit " .. fit:gsub("^ ", "") .. "]" end
  R:Add("call", "%s %s: %s%s%s", inBattleground() and "BG" or "practice", result, tostring(msg),
    path and path ~= "" and (" (" .. path .. ")") or "", extra)
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function help()
  out("hold your wheel key, flick toward an action, then a place, release to send.")
  out("EFC and FC: release right after the action = ping the carrier. Optional steps: side (one big sector) and count.")
  out("In a battleground calls go to /bg; anywhere else they are whispered to you (practice).")
  out("/cnc scale <0.6-2> : wheel size (default 1)")
  out("/cnc ping : turn the pings sent with calls on or off")
  out("/cnc exp [on|off|hover|undo|carrier] : experimental features")
  out("/cnc carrier enemy|friend <unit> : carrier units for the experimental pings (clear to reset)")
  out("/cnc report : test report summary (full report saved at logout or /reload)")
  out("/cnc status : show mode and bound keys")
  out("/cnc timers : test the secure timers again (experimental hover and undo need them)")
end

local function status()
  out("v%s, calls go to: %s, size %.2f, pings %s", ns.VERSION, inBattleground() and "/bg" or "a whisper to you (practice)",
    CnCDB.scale or 1, CnCDB.ping == false and "OFF" or "ON")
  out("secure timers: %s", ns.timersOK == nil and "not tested" or (ns.timersOK and "OK" or "FAILED"))
  local list = {}
  for name in pairs(EXP_FEATURES) do list[#list + 1] = name .. (CnCDB.exp[name] and "+" or "-") end
  table.sort(list)
  out("experimental %s: %s; carriers: enemy %s, friend %s", CnCDB.exp.on and "ON" or "OFF", table.concat(list, " "),
    tostring(CnCDB.carriers.enemy), tostring(CnCDB.carriers.friend))
  for _, b in ipairs(BINDINGS) do
    local keys = { GetBindingKey(b.name) }
    if #keys > 0 then out("  %s: %s", _G["BINDING_NAME_" .. b.name], table.concat(keys, ", ")) end
  end
end

local function expCommand(arg)
  if InCombatLockdown() then
    out("can't change experimental features in combat.")
    return
  end
  local exp = CnCDB.exp
  if arg == "on" or arg == "off" then
    exp.on = (arg == "on")
  elseif EXP_FEATURES[arg] then
    exp[arg] = not exp[arg]
  elseif arg == "" then
    exp.on = not exp.on
  else
    out("usage: /cnc exp [on|off|hover|undo|carrier]")
    return
  end
  applyOptions()
  R:Add("exp", "experimental %s, hover %s, undo %s, carrier %s", tostring(exp.on), tostring(exp.hover),
    tostring(exp.undo), tostring(exp.carrier))
  out("experimental %s.", exp.on and "ON" or "OFF")
  for name, text in pairs(EXP_FEATURES) do
    out("  %s %s: %s", exp[name] and "[x]" or "[ ]", name, text)
  end
  if exp.on and ns.timersOK == false then
    out("  secure timers failed the self-test: hover and undo stay off.")
  end
end

local function carrierCommand(who, unit)
  if InCombatLockdown() then
    out("can't change carriers in combat.")
    return
  end
  if who == "clear" then
    CnCDB.carriers = {}
  elseif (who == "enemy" or who == "friend") and unit and unit:match("^[%a%d]+$") then
    CnCDB.carriers[who] = unit
  else
    out("usage: /cnc carrier enemy|friend <unit> (for example arena1), or /cnc carrier clear")
    return
  end
  applyOptions()
  R:Add("exp", "carrier units: enemy %s, friend %s", tostring(CnCDB.carriers.enemy), tostring(CnCDB.carriers.friend))
  out("carrier units: enemy %s, friend %s.", tostring(CnCDB.carriers.enemy), tostring(CnCDB.carriers.friend))
end

SLASH_COMMANDANDCONQUER1 = "/cnc"
SlashCmdList.COMMANDANDCONQUER = function(input)
  local cmd, arg, arg2 = (input or ""):lower():match("^%s*(%S*)%s*(%S*)%s*(%S*)")
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
  elseif cmd == "ping" then
    if not W:SetPings(CnCDB.ping == false) then
      out("can't change pings in combat.")
      return
    end
    CnCDB.ping = (CnCDB.ping == false)
    out("pings with calls %s.", CnCDB.ping and "ON" or "OFF")
  elseif cmd == "exp" then
    expCommand(arg)
  elseif cmd == "carrier" then
    carrierCommand(arg, arg2)
  elseif cmd == "report" then
    if arg == "clear" then
      R:Clear()
      out("report cleared.")
      return
    end
    local lines = CnCDB.report and CnCDB.report.lines or {}
    out("report: %d lines, this session: %s.", #lines, R:Summary())
    out("saved at logout or /reload; tools/update-cnc.bat copies it to the clipboard. /cnc report clear to empty it.")
  elseif cmd == "status" then
    status()
  elseif cmd == "timers" then
    if InCombatLockdown() then
      out("out of combat only.")
      return
    end
    out("testing the secure timers (up to 20 s)...")
    runSelfTest(true)
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
      defaults()
      R:Start()
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

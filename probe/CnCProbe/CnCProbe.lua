-- CnCProbe: answers one question before any wheel code is written.
-- Can an add-on post in /bg on this client, and from which kind of context?
--
--   slash     sent straight from a slash command (Enter key = hardware event)
--   binding   sent from a key binding, on key release (hardware event)
--   timer     sent from C_Timer (no hardware event)
--   onupdate  sent from a frame OnUpdate (no hardware event) = how a
--             "flick to send" wheel would send
--   addon     addon-to-addon message (only seen by players with the add-on)
--
-- Every test message carries a nonce. The probe listens to the chat events
-- and marks a test "ECHO" when the server sends our own line back.

local ADDON_NAME = ...
local PREFIX = "|cff4fa3ff[CnC Probe]|r "
local ADDON_MSG_PREFIX = "CnCProbe"
local ECHO_TIMEOUT = 4
local STEP = 1.2
local MAX_RUNS = 30

local db
local seq = 0
local pending = {}
local results = {}
local reportTimerToken = 0
local lastRecord
local unknownEvents = {}

local function out(fmt, ...)
  local text = select("#", ...) > 0 and fmt:format(...) or fmt
  DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. text)
end

-- Whispers need "Name-Realm" on clients with connected realms.
local function playerName()
  local name, realm
  if UnitFullName then name, realm = UnitFullName("player") end
  name = name or UnitName("player")
  if (not realm or realm == "") and GetNormalizedRealmName then realm = GetNormalizedRealmName() end
  if realm and realm ~= "" then return name .. "-" .. realm end
  return name
end

---------------------------------------------------------------------------
-- API resolution (Classic Era vs modern clients)
---------------------------------------------------------------------------

local function sendChat(msg, chatType, target)
  if C_ChatInfo and C_ChatInfo.SendChatMessage then
    return C_ChatInfo.SendChatMessage(msg, chatType, nil, target)
  end
  return SendChatMessage(msg, chatType, nil, target)
end

local function sendAddon(msg, chatType, target)
  local fn = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
  return fn(ADDON_MSG_PREFIX, msg, chatType, target)
end

local function registerPrefix()
  local fn = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
  if fn then pcall(fn, ADDON_MSG_PREFIX) end
end

local function openChat(text)
  if ChatFrame_OpenChat then
    ChatFrame_OpenChat(text)
  elseif ChatFrameUtil and ChatFrameUtil.OpenChat then
    ChatFrameUtil.OpenChat(text)
  else
    out("Aucune fonction pour pré-remplir le chat sur ce client.")
  end
end

local function buildInfo()
  local version, build, date, toc = GetBuildInfo()
  return {
    version = version, build = build, date = date, toc = toc,
    project = WOW_PROJECT_ID,
  }
end

local function context()
  local _, instanceType = IsInInstance()
  local instGroup, homeGroup = false, false
  if IsInGroup then
    instGroup = IsInGroup(LE_PARTY_CATEGORY_INSTANCE or 2) and true or false
    homeGroup = IsInGroup(LE_PARTY_CATEGORY_HOME or 1) and true or false
  end
  return {
    instanceType = instanceType or "none",
    instanceGroup = instGroup,
    homeGroup = homeGroup,
    inCombat = InCombatLockdown() and true or false,
  }
end

local function chatTypesFor(mode)
  if mode == "auto" then
    local ctx = context()
    if ctx.instanceGroup then return { "INSTANCE_CHAT", "BATTLEGROUND" } end
    if ctx.homeGroup then return { "PARTY" } end
    return { "WHISPER" }
  end
  local map = {
    bg = { "INSTANCE_CHAT", "BATTLEGROUND" },
    instance = { "INSTANCE_CHAT" },
    battleground = { "BATTLEGROUND" },
    party = { "PARTY" },
    raid = { "RAID" },
    say = { "SAY" },
    whisper = { "WHISPER" },
  }
  return map[mode]
end

---------------------------------------------------------------------------
-- Report
---------------------------------------------------------------------------

local function counts(list)
  local ok = {}
  for _, r in ipairs(list) do
    if r.status:find("^ECHO") or r.status:find("^SENT") then ok[r.trigger] = true end
  end
  return ok
end

local function verdict(list)
  local ok = counts(list)
  if ok.onupdate or ok.timer then
    return "OK : la roue peut envoyer dès le glissé, sans clic ni relâchement."
  elseif ok.slash or ok.binding then
    return "Envoi seulement depuis une action clavier : la roue enverra au relâchement de la touche."
  elseif ok.secure then
    return "Macro sécurisée OK : la roue enverra au relâchement de la touche, par un bouton sécurisé."
  elseif ok.editbox then
    return "Pré-remplissage OK : la roue écrit la ligne, le joueur tape Entrée."
  elseif ok.addon then
    return "/bg bloqué pour les add-ons, mais les messages add-on passent : affichage partagé entre joueurs équipés possible."
  end
  return "Tout est bloqué : repli sur l'aide à la saisie (/cnct editbox)."
end

local function report()
  if #results == 0 then
    out("Aucun test lancé. Tape /cnct run")
    return
  end
  local ctx = results[1].ctx
  out("Rapport (%s, groupe instance : %s)", ctx.instanceType, tostring(ctx.instanceGroup))
  for _, r in ipairs(results) do
    local extra = ""
    if r.error then extra = " | erreur : " .. r.error end
    if r.blocked then extra = extra .. " | bloqué : " .. r.blocked end
    if r.callReturn and r.callReturn ~= "nil" then extra = extra .. " | retour : " .. r.callReturn end
    out("  %-9s %-14s %s%s", r.trigger, r.chatType, r.status, extra)
  end
  if next(unknownEvents) then
    local names = {}
    for name in pairs(unknownEvents) do names[#names + 1] = name end
    table.sort(names)
    out("  Événements inconnus sur ce client : %s", table.concat(names, ", "))
  end
  local v = verdict(results)
  out("|cffffd200Verdict :|r %s", v)
  if ctx.instanceType ~= "pvp" then
    out("|cffff7f7fAttention :|r test hors BG. Le vrai verdict se fait dans le Goulet.")
  end
end

local function saveRun()
  if not db then return end
  local run = {
    when = date("%Y-%m-%d %H:%M:%S"),
    build = buildInfo(),
    results = {},
    unknownEvents = {},
    verdict = verdict(results),
  }
  for _, r in ipairs(results) do
    run.results[#run.results + 1] = {
      trigger = r.trigger, chatType = r.chatType, kind = r.kind,
      status = r.status, error = r.error, blocked = r.blocked,
      callReturn = r.callReturn, ctx = r.ctx,
    }
  end
  for name in pairs(unknownEvents) do run.unknownEvents[#run.unknownEvents + 1] = name end
  table.insert(db.runs, run)
  while #db.runs > MAX_RUNS do table.remove(db.runs, 1) end
end

local function scheduleReport(delay)
  reportTimerToken = reportTimerToken + 1
  local token = reportTimerToken
  C_Timer.After(delay, function()
    if token ~= reportTimerToken then return end
    report()
    saveRun()
  end)
end

---------------------------------------------------------------------------
-- Attempts
---------------------------------------------------------------------------

local function attempt(trigger, chatType, kind)
  seq = seq + 1
  local nonce = ("%d%02d"):format(math.random(100, 999), seq % 100)
  local rec = {
    trigger = trigger, chatType = chatType, kind = kind, nonce = nonce,
    status = "WAITING", ctx = context(),
  }
  local target = (chatType == "WHISPER") and playerName() or nil
  local text = ("CnC add-on test #%s, please ignore"):format(nonce)
  local fn = (kind == "addon") and sendAddon or sendChat

  lastRecord = rec
  local ok, ret = pcall(fn, text, chatType, target)
  if ok then
    rec.callReturn = tostring(ret)
    pending[nonce] = rec
  else
    rec.status = "LUA ERROR"
    rec.error = tostring(ret)
  end
  results[#results + 1] = rec

  C_Timer.After(ECHO_TIMEOUT, function()
    if rec.status == "WAITING" then
      rec.status = "NO ECHO"
      pending[nonce] = nil
    end
  end)
end

-- Manual tests: the player sends the line, the probe only waits for the echo.
local function track(trigger, chatType, timeout)
  seq = seq + 1
  local nonce = ("%d%02d"):format(math.random(100, 999), seq % 100)
  local rec = {
    trigger = trigger, chatType = chatType, kind = "chat", nonce = nonce,
    status = "WAITING", ctx = context(),
  }
  wipe(results)
  wipe(pending)
  results[1] = rec
  pending[nonce] = rec
  lastRecord = rec
  C_Timer.After(timeout, function()
    if rec.status == "WAITING" then
      rec.status = "NO ECHO"
      pending[nonce] = nil
    end
  end)
  scheduleReport(timeout + 0.5)
  return rec
end

-- Secure macro button: the click is a hardware event and the macro runs
-- through Blizzard's own code, like a macro the player wrote.
local secureButton
local function nextSecureText()
  local rec = track("secure", "macro /bg", ECHO_TIMEOUT)
  return ("/bg CnC secure test #%s, please ignore"):format(rec.nonce)
end

local function showSecureButton()
  if InCombatLockdown() then
    out("Hors combat seulement (le bouton se prépare avant le combat).")
    return
  end
  if not secureButton then
    local b = CreateFrame("Button", "CnCProbeSecureButton", UIParent,
      "SecureActionButtonTemplate, UIPanelButtonTemplate")
    b:SetSize(240, 34)
    b:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    b:SetText("CnC : test macro /bg")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "/bg CnC secure test, please ignore")
    -- Fresh nonce for each click, set just before the secure click runs.
    -- A click sends a down and an up event; the macro runs on one of them.
    -- Only the first edge sets a new nonce so both edges share the same text.
    local lastAt = 0
    b:SetScript("PreClick", function(self)
      if InCombatLockdown() or GetTime() - lastAt < 1 then return end
      lastAt = GetTime()
      self:SetAttribute("macrotext", nextSecureText())
    end)
    secureButton = b
  end
  secureButton:Show()
  out("Clique le bouton en haut de l'écran (hors combat). Rapport ~5 s après. /cnct hide pour le cacher.")
end

local onUpdateFrame = CreateFrame("Frame")
local function nextOnUpdate(fn)
  onUpdateFrame:SetScript("OnUpdate", function(self)
    self:SetScript("OnUpdate", nil)
    fn()
  end)
end

local function runAll(mode)
  local types = chatTypesFor(mode)
  if not types then
    out("Mode inconnu : %s", tostring(mode))
    return
  end
  wipe(results)
  wipe(pending)
  out("Test lancé sur %s. Rapport dans ~%d s.", table.concat(types, " + "), math.ceil(3 * STEP + ECHO_TIMEOUT + 1))

  -- 1) Straight from the slash command (hardware event: the Enter key).
  for _, ct in ipairs(types) do attempt("slash", ct, "chat") end

  -- 2) From a timer (no hardware event).
  C_Timer.After(STEP, function()
    for _, ct in ipairs(types) do attempt("timer", ct, "chat") end
  end)

  -- 3) From OnUpdate, exactly like a wheel that sends on flick.
  C_Timer.After(2 * STEP, function()
    nextOnUpdate(function()
      for _, ct in ipairs(types) do attempt("onupdate", ct, "chat") end
    end)
  end)

  -- 4) Addon-to-addon message, on the first chat type only.
  C_Timer.After(3 * STEP, function()
    local ct = types[1]
    attempt("addon", ct, "addon")
  end)

  scheduleReport(3 * STEP + ECHO_TIMEOUT + 0.5)
end

-- Called from Bindings.xml. keystate is "down" or "up".
function CnCProbe_OnBinding(keystate)
  if keystate ~= "up" then return end
  local types = chatTypesFor("auto")
  wipe(results)
  wipe(pending)
  for _, ct in ipairs(types) do attempt("binding", ct, "chat") end
  out("Test raccourci (relâchement) envoyé sur %s.", table.concat(types, " + "))
  scheduleReport(ECHO_TIMEOUT + 0.5)
end

BINDING_HEADER_CNCPROBE = "Command & Conquer Probe"
BINDING_NAME_CNCPROBE_SEND = "Test d'envoi /bg (au relâchement)"

---------------------------------------------------------------------------
-- Echo detection
---------------------------------------------------------------------------

local CHAT_EVENTS = {
  "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
  "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER",
  "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
  "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
  "CHAT_MSG_SAY", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
  "CHAT_MSG_ADDON", "CHAT_MSG_SYSTEM",
}

-- "No player named '%s' is currently playing." as a Lua pattern, so a
-- whisper the server bounced still counts as sent.
local function notFoundPattern()
  local fmt = ERR_CHAT_PLAYER_NOT_FOUND_S
  if type(fmt) ~= "string" then return nil end
  local escaped = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
  return "^" .. escaped:gsub("%%%%s", ".+") .. "$"
end

local function markUnreadable(kind)
  for nonce, rec in pairs(pending) do
    if rec.kind == kind then
      rec.status = "ECHO UNREADABLE (secret)"
      pending[nonce] = nil
    end
  end
end

local function onSystem(msg)
  local pattern = notFoundPattern()
  if not pattern then return end
  local ok, hit = pcall(function() return msg:find(pattern) ~= nil end)
  if not ok or not hit then return end
  for _, rec in ipairs(results) do
    if rec.status == "WAITING" and rec.chatType == "WHISPER" then
      rec.status = "SENT (cible introuvable)"
      pending[rec.nonce] = nil
      return
    end
  end
end

local function onChat(event, ...)
  if not next(pending) then return end
  if event == "CHAT_MSG_SYSTEM" then return onSystem((...)) end
  local kind = (event == "CHAT_MSG_ADDON") and "addon" or "chat"
  local a1, a2 = ...
  local ok, nonce = pcall(function()
    local text = a1
    if kind == "addon" then
      if a1 ~= ADDON_MSG_PREFIX then return nil end
      text = a2
    end
    return text:match("#(%d+)")
  end)
  if not ok then
    -- Modern clients may hand add-ons "secret" chat values in instances.
    markUnreadable(kind)
    return
  end
  local rec = nonce and pending[nonce]
  if rec then
    rec.status = "ECHO OK"
    rec.echoEvent = event
    pending[nonce] = nil
  end
end

---------------------------------------------------------------------------
-- Info
---------------------------------------------------------------------------

local function has(v) return v and "oui" or "non" end

local function info()
  local b = buildInfo()
  local ctx = context()
  out("Client %s (build %s, %s), interface %s, projet %s",
    tostring(b.version), tostring(b.build), tostring(b.date), tostring(b.toc), tostring(b.project))
  out("Instance : %s | groupe instance : %s | groupe : %s | combat : %s",
    ctx.instanceType, tostring(ctx.instanceGroup), tostring(ctx.homeGroup), tostring(ctx.inCombat))
  out("API : SendChatMessage %s | C_ChatInfo.SendChatMessage %s | SendAddonMessage %s | issecretvalue %s | ChatFrame_OpenChat %s",
    has(SendChatMessage), has(C_ChatInfo and C_ChatInfo.SendChatMessage),
    has((C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage),
    has(issecretvalue), has(ChatFrame_OpenChat))
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function help()
  out("/cnct info : version du client et API disponibles")
  out("/cnct run [auto|bg|instance|battleground|party|raid|say|whisper] : lance les tests (auto par défaut)")
  out("/cnct secure : bouton de test « macro /bg » à cliquer (hors combat)")
  out("/cnct editbox : pré-remplit une ligne /bg, à envoyer avec Entrée")
  out("/cnct report : réaffiche le dernier rapport")
  out("/cnct clear : vide l'historique sauvegardé")
  out("Raccourci : Échap > Raccourcis > AddOns > Command & Conquer Probe")
end

SLASH_CNCPROBE1 = "/cnct"
SLASH_CNCPROBE2 = "/cncprobe"
SlashCmdList.CNCPROBE = function(input)
  local cmd, arg = (input or ""):lower():match("^%s*(%S*)%s*(%S*)")
  if cmd == "run" then
    runAll(arg ~= "" and arg or "auto")
  elseif cmd == "info" then
    info()
  elseif cmd == "editbox" then
    local rec = track("editbox", "editbox /bg", 30)
    openChat(("/bg CnC editbox test #%s, please ignore"):format(rec.nonce))
    out("Ligne pré-remplie : tape Entrée dans les 30 s.")
  elseif cmd == "secure" then
    showSecureButton()
  elseif cmd == "hide" then
    if secureButton and not InCombatLockdown() then secureButton:Hide() end
  elseif cmd == "report" then
    report()
  elseif cmd == "clear" then
    if db then wipe(db.runs) end
    out("Historique vidé.")
  else
    help()
  end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")

local function safeRegister(event)
  local ok = pcall(frame.RegisterEvent, frame, event)
  if not ok then unknownEvents[event] = true end
end

safeRegister("ADDON_LOADED")
safeRegister("ADDON_ACTION_BLOCKED")
safeRegister("ADDON_ACTION_FORBIDDEN")
for _, e in ipairs(CHAT_EVENTS) do safeRegister(e) end

frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... == ADDON_NAME then
      CnCProbeDB = CnCProbeDB or {}
      CnCProbeDB.runs = CnCProbeDB.runs or {}
      db = CnCProbeDB
      registerPrefix()
      out("chargé. Tape /cnct pour l'aide.")
    end
  elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
    local addon, func = ...
    if addon == ADDON_NAME then
      local tag = ("%s (%s)"):format(tostring(func), event)
      if lastRecord then lastRecord.blocked = tag end
      out("|cffff4040Action bloquée :|r %s", tag)
    end
  else
    onChat(event, ...)
  end
end)

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
  local first = list[1] and list[1].trigger or ""
  if first:find("^alerte") then
    local rec = list[1]
    if rec.status:find("UNREADABLE") then
      return "Alerte envoyée, mais son contenu est illisible pour les add-ons : pas d'alerte à l'écran possible."
    elseif ok[first] then
      return first == "alerte directe"
        and "Alertes OK : l'add-on peut les envoyer lui-même. Vérifie qu'un allié équipé les reçoit."
        or "Alertes OK par la macro du relâchement. Vérifie qu'un allié équipé les reçoit."
    end
    return "Alerte non reçue en retour : bloquée ou pas transmise sur ce canal."
  end
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
-- Blizzard ping system (ping wheel): is it on this client, and can a
-- secure macro "/ping" run from an add-on button in a battleground?
local pingButton
local function pingInfo()
  local api = {}
  if type(C_Ping) == "table" then
    for k in pairs(C_Ping) do api[#api + 1] = tostring(k) end
    table.sort(api)
  end
  out("C_Ping : %s", type(C_Ping) ~= "table" and "absent" or (#api > 0 and table.concat(api, ", ") or "présent, vide"))
  local slash = {}
  for i = 1, 4 do
    local v = _G["SLASH_PING" .. i]
    if v then slash[#slash + 1] = v end
  end
  out("Commande /ping : %s", #slash > 0 and table.concat(slash, " ") or "introuvable")
  local key = GetBindingKey and GetBindingKey("TOGGLEPINGLISTENER")
  out("Touche de ping Blizzard : %s", key or "non liée ou absente")
end

local alertButton
local function alertChannel()
  local ctx = context()
  if ctx.instanceGroup then return "INSTANCE_CHAT" end
  if ctx.homeGroup then return "PARTY" end
  return "WHISPER", playerName()
end

local function sendAlertDirect()
  local channel, target = alertChannel()
  local rec = track("alerte directe", channel, ECHO_TIMEOUT)
  rec.kind = "addon"
  lastRecord = rec
  local ok, ret = pcall(sendAddon, ("ALERT|#%s|Enemy carrier at the tunnel (test)"):format(rec.nonce), channel, target)
  rec.callReturn = tostring(ret)
  if not ok then
    rec.status = "LUA ERROR"
    rec.error = tostring(ret)
    pending[rec.nonce] = nil
  end
  out("Alerte envoyée par l'add-on sur %s (retour : %s). Rapport dans ~5 s.", channel, tostring(ret))
end

local function showAlertButton()
  if InCombatLockdown() then
    out("Hors combat seulement (le bouton se prépare avant le combat).")
    return
  end
  if not alertButton then
    local b = CreateFrame("Button", "CnCProbeAlertButton", UIParent,
      "SecureActionButtonTemplate, UIPanelButtonTemplate")
    b:SetSize(260, 34)
    b:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    b:SetText("CnC : test alerte (macro /run)")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "macro")
    local lastAt = 0
    b:SetScript("PreClick", function(self)
      if InCombatLockdown() or GetTime() - lastAt < 1 then return end
      lastAt = GetTime()
      local channel, target = alertChannel()
      local rec = track("alerte macro", channel, ECHO_TIMEOUT)
      rec.kind = "addon"
      local targetArg = target and (", '" .. target .. "'") or ""
      self:SetAttribute("macrotext", ("/run C_ChatInfo.SendAddonMessage('%s', 'ALERT|#%s|Incoming at our ramp (test)', '%s'%s)")
        :format(ADDON_MSG_PREFIX, rec.nonce, channel, targetArg))
    end)
    alertButton = b
  end
  alertButton:Show()
end

local function showPingButton()
  if InCombatLockdown() then
    out("Hors combat seulement.")
    return
  end
  if not pingButton then
    local b = CreateFrame("Button", "CnCProbePingButton", UIParent,
      "SecureActionButtonTemplate, UIPanelButtonTemplate")
    b:SetSize(240, 34)
    b:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    b:SetText("CnC : test /ping sur la cible")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "/ping [@target] attack")
    pingButton = b
  end
  pingButton:Show()
  out("Cible quelqu'un (un ennemi ou un allié), puis clique le bouton. Un ping « attaque » doit apparaître sur la cible.")
  out("Dis-moi si tu le vois, et s'il y a un message d'erreur. /cnct hide pour cacher les boutons.")
end

-- Map locations: can the add-on read the player's map position, ping the
-- minimap, and build a shareable map pin link, in a battleground?
local function mapInfo()
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local name = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  out("Carte : %s (%s)", tostring(mapID), name and tostring(name.name) or "?")

  local x, y
  if mapID and C_Map.GetPlayerMapPosition then
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if ok and pos then
      local okXY, px, py = pcall(function() return pos:GetXY() end)
      if okXY then x, y = px, py end
    end
  end
  local okSecret = x and pcall(function() return x + 0 end)
  out("Position sur la carte : %s", x and (okSecret and ("%.3f, %.3f"):format(x, y) or "secret (illisible)") or "indisponible")

  local okUP, ux, uy = pcall(UnitPosition, "player")
  out("UnitPosition : %s", (okUP and ux) and "lisible" or "indisponible")

  if Minimap and Minimap.PingLocation then
    lastRecord = nil
    local ok, err = pcall(Minimap.PingLocation, Minimap, 0, 0)
    out("Ping minicarte sur toi : %s. Regarde ta minicarte (et demande à un allié).",
      ok and "appel accepté" or ("erreur : " .. tostring(err)))
  else
    out("Ping minicarte : fonction absente")
  end

  if mapID and C_Map.CanSetUserWaypointOnMap and UiMapPoint and x and okSecret then
    local can = C_Map.CanSetUserWaypointOnMap(mapID)
    out("Repère de carte autorisé ici : %s", tostring(can))
    if can then
      local ok = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(mapID, x, y))
      local link = ok and C_Map.GetUserWaypointHyperlink and C_Map.GetUserWaypointHyperlink()
      out("Lien de repère : %s", link or "aucun")
      if C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint() end
    end
  else
    out("Repère de carte : API absente ou position illisible")
  end
end

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

-- Add-on to add-on alerts (/cnct alert). Payload "ALERT|#nonce|text".
-- Received alerts (ours and other players' with CnCProbe) show in big on
-- screen, the way Command & Conquer would show calls.
local alertFrame
local function showAlert(text, sender)
  if not alertFrame then
    alertFrame = CreateFrame("Frame", nil, UIParent)
    alertFrame:SetSize(1, 1)
    alertFrame:SetPoint("TOP", UIParent, "TOP", 0, -170)
    alertFrame:SetFrameStrata("HIGH")
    alertFrame.text = alertFrame:CreateFontString(nil, "OVERLAY")
    alertFrame.text:SetFont(STANDARD_TEXT_FONT, 26, "OUTLINE")
    alertFrame.text:SetPoint("TOP")
    alertFrame.text:SetTextColor(1, 0.82, 0.2)
    alertFrame:SetScript("OnUpdate", function(f, elapsed)
      f.left = f.left - elapsed
      if f.left <= 0 then f:Hide() else f:SetAlpha(math.min(1, f.left)) end
    end)
  end
  alertFrame.text:SetText(text .. "\n|cffbbbbbb" .. tostring(sender) .. "|r")
  alertFrame.left = 4
  alertFrame:SetAlpha(1)
  alertFrame:Show()
  if SOUNDKIT and SOUNDKIT.RAID_WARNING then pcall(PlaySound, SOUNDKIT.RAID_WARNING) end
end

-- Returns true when the add-on message was an alert (handled here).
local function onAlert(prefix, text, channel, sender)
  local ok, isAlert, body = pcall(function()
    if prefix ~= ADDON_MSG_PREFIX then return false end
    local b = text:match("^ALERT|#%d+|(.*)$")
    return b ~= nil, b
  end)
  if not ok then
    out("Message add-on reçu mais |cffff7f7fillisible|r (valeur secrète) sur %s.", tostring(channel))
    return false
  end
  if not isAlert then return false end
  local okS, who = pcall(function() return sender .. "" end)
  who = okS and who or "?"
  out("Alerte reçue de %s sur %s : %s", who, tostring(channel), body)
  showAlert(body, who)
  return false -- let onChat match the nonce for our own echo
end

local function onChat(event, ...)
  if event == "CHAT_MSG_ADDON" then onAlert(...) end
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
-- Carriers: which frames and units are the two flag carrier portraits
-- Forever shows top right in Warsong Gulch? (v0.6, 20/11/2026)
---------------------------------------------------------------------------

local CARRIER_NAME_PATTERN = { "Arena", "Flag", "Carrier", "WorldState", "Objective", "UIWidget", "Battlefield" }

local function readable(v)
  if issecretvalue and issecretvalue(v) then return "<secret>" end
  return tostring(v)
end

local function carriersInfo()
  local lines = {}
  local function note(fmt, ...)
    local text = select("#", ...) > 0 and fmt:format(...) or fmt
    lines[#lines + 1] = text
    out(text)
  end
  local ctx = context()
  note("Porteurs : instance %s, combat %s", tostring(ctx.instanceType), tostring(ctx.inCombat))

  -- 1. Units that could be the carriers.
  local units = { "arena1", "arena2", "arena3", "arena4", "arena5", "focus", "target" }
  for _, u in ipairs(units) do
    if UnitExists(u) then
      note("  unité %s : nom %s, ami %s, c'est moi %s", u, readable(UnitName(u)),
        readable(UnitIsFriend("player", u)), readable(UnitIsUnit(u, "player")))
    end
  end

  -- 2. Visible frames in the top right of the screen, or with a telling name.
  local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
  local f = EnumerateFrames()
  local found = 0
  while f and found < 40 do
    pcall(function() -- forbidden or odd frames must not stop the scan
    local name = f:GetName()
    if f:IsVisible() then
      local unit = (f.GetAttribute and f:GetAttribute("unit")) or f.unit
      local x, y = f:GetCenter()
      local topRight = x and y and x > sw * 0.6 and y > sh * 0.45
      local telling = false
      if name then
        for _, pat in ipairs(CARRIER_NAME_PATTERN) do
          if name:find(pat) then telling = true end
        end
      end
      if (topRight and (unit or (name and f:IsMouseEnabled()))) or (telling and unit) then
        found = found + 1
        note("  cadre %s : unité %s, protégé %s, souris %s, position %d,%d", tostring(name), readable(unit),
          tostring(f:IsProtected()), tostring(f:IsMouseEnabled()), x or -1, y or -1)
      end
    end
    end)
    f = EnumerateFrames(f)
  end
  if found == 0 then note("  aucun cadre trouvé en haut à droite (faire le test quand les portraits sont affichés)") end

  -- 3. What the secure code of the wheel can use.
  if not InCombatLockdown() and SecureHandlerExecute then
    local header = CnCProbeSecureHeader or CreateFrame("Frame", "CnCProbeSecureHeader", UIParent, "SecureHandlerBaseTemplate")
    local ok, err = pcall(SecureHandlerExecute, header, [[
      self:SetAttribute("has-UnitIsUnit", UnitIsUnit and true or false)
      self:SetAttribute("has-UnitExists", UnitExists and true or false)
      self:SetAttribute("has-UnitName", UnitName and true or false)
    ]])
    note("  code sécurisé : UnitIsUnit %s, UnitExists %s, UnitName %s%s",
      tostring(header:GetAttribute("has-UnitIsUnit")), tostring(header:GetAttribute("has-UnitExists")),
      tostring(header:GetAttribute("has-UnitName")), ok and "" or (" (erreur " .. tostring(err) .. ")"))
  end
  if db then
    db.carriers = { when = date("%Y-%m-%d %H:%M:%S"), lines = lines }
  end
  out("Résultat gardé dans les SavedVariables (CnCProbeDB.carriers). À faire en BG, portraits affichés, hors combat.")
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
  out("/cnct ping : système de ping présent ? + bouton de test « /ping » (hors combat)")
  out("/cnct map : position sur la carte, ping minicarte, repère de carte partageable")
  out("/cnct alert : alerte add-on à add-on (envoi direct + bouton macro), affichage en gros à l'écran")
  out("/cnct carriers : cadres et unités des portraits des porteurs (en BG, portraits affichés)")
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
  elseif cmd == "alert" then
    sendAlertDirect()
    showAlertButton()
    out("Ensuite, clique le bouton « test alerte » (hors combat) pour l'envoi par macro.")
    out("Un allié avec CnCProbe voit tes alertes en gros à l'écran, et toi les siennes.")
  elseif cmd == "map" then
    mapInfo()
  elseif cmd == "carriers" then
    carriersInfo()
  elseif cmd == "ping" then
    pingInfo()
    showPingButton()
  elseif cmd == "secure" then
    showSecureButton()
  elseif cmd == "hide" then
    if not InCombatLockdown() then
      if secureButton then secureButton:Hide() end
      if pingButton then pingButton:Hide() end
      if alertButton then alertButton:Hide() end
    end
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

-- WoW API emulation to run the real add-on outside the game.
--
-- Used by the offline tests (tools/wheelsim.lua, Lua 5.1 = WoW's Lua) and
-- by the training web page (same file, Lua 5.4 in the browser through
-- wasmoon). Nothing in here knows about the wheel: it emulates frames,
-- anchors, textures, the mouse, key bindings, secure snippets (restricted
-- environment, frame handles, WrapScript, RegisterAutoHide), secure macro
-- buttons and macro commands. The add-on files run unchanged on top.
--
-- What this cannot prove: how the real client and Forever's own
-- restrictions behave. Always confirm in game.

local Emu = {}

local unpack = unpack or table.unpack
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end -- WoW has it
math.mod = math.mod or math.fmod

Emu.W, Emu.H = 1365, 768       -- UIParent size (WoW: 768 units high)
Emu.now = 0
Emu.combat = false
Emu.inBG = true
Emu.cursorX, Emu.cursorY = 400, 300
Emu.addonName = "CommandAndConquer"
-- Functions the restricted environment exposes on top of Blizzard's list.
-- UnitIsUnit is NOT in Blizzard's list (RestrictedEnvironment.lua): the
-- web page can switch this "hypothesis" on to show what would happen.
Emu.secureExtras = {}
Emu.bindings = { CNC_WHEEL = { "TAB" } }
Emu.output = {}  -- events for the caller (chat, ping, mark, print, call, blocked)
Emu.macros = {}  -- every macro the secure button ran

-- Units. Aliases share the same table (UnitIsUnit compares tables).
Emu.units = { player = { name = "Elemente", realm = "Venera", friendly = true } }

local function emit(kind, ...)
  local parts = { kind }
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  Emu.output[#Emu.output + 1] = parts
end
Emu.emit = emit

---------------------------------------------------------------------------
-- Loading code (Lua 5.1 and 5.2+)
---------------------------------------------------------------------------

local function loadIn(src, name, env)
  if setfenv and loadstring then
    local fn, err = loadstring(src, name)
    if not fn then error(err, 2) end
    if env then setfenv(fn, env) end
    return fn
  end
  local fn, err = load(src, name, "t", env or _G)
  if not fn then error(err, 2) end
  return fn
end
Emu.loadIn = loadIn

---------------------------------------------------------------------------
-- Objects
---------------------------------------------------------------------------

local POINTS = {
  CENTER = { 0.5, 0.5 }, BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
  LEFT = { 0, 0.5 }, RIGHT = { 1, 0.5 }, TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 },
}
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6,
  FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local LAYERS = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }

local frames = {}  -- creation order
local counter = 0
local secureDepth = 0
local autohide = {}  -- frame -> { duration, elapsed }
local overrides = {} -- key -> { owner, button, mouse }
local eventFrames = {}
local focus

local Frame, Region = {}, {}
local function stubIndex(methods)
  return function(_, k)
    local m = methods[k]
    if m ~= nil then return m end
    if type(k) == "string" and k:match("^%u") then return function() end end
    return nil
  end
end
local FrameMeta = { __index = stubIndex(Frame) }
local RegionMeta = { __index = stubIndex(Region) }

local UIParent

-- An insecure call on a protected frame in combat is blocked, as in game.
local function blocked(self, what)
  if Emu.combat and secureDepth == 0 and self.protected then
    emit("blocked", what)
    if Emu.fire then Emu.fire("ADDON_ACTION_BLOCKED", Emu.addonName, what) end
    return true
  end
  return false
end

local function effScale(obj)
  local s = 1
  while obj do
    s = s * (obj.scale or 1)
    obj = obj.parent
  end
  return s
end

local function effAlpha(obj)
  local a = 1
  while obj do
    a = a * (obj.alpha or 1)
    obj = obj.parent
  end
  return a
end

-- Rectangle in screen units: left, bottom, width, height.
local function rect(obj)
  if obj == UIParent then return 0, 0, Emu.W, Emu.H end
  if obj.allpoints then return rect(obj.allpoints) end
  local a = obj.anchor
  if not a then return nil end
  local es = effScale(obj.isRegion and obj.parent or obj)
  local w, h = (obj.width or 0) * es, (obj.height or 0) * es
  local rl, rb, rw, rh = rect(a.rel)
  if not rl then return nil end
  local rp, p = POINTS[a.relPoint], POINTS[a.point]
  local ax, ay = rl + rw * rp[1] + a.x * es, rb + rh * rp[2] + a.y * es
  return ax - w * p[1], ay - h * p[2], w, h, ax, ay
end
Emu.rect = rect

local function setPoint(self, point, rel, relPoint, x, y)
  if type(rel) == "number" or rel == nil then
    rel, relPoint, x, y = nil, nil, rel, relPoint
  elseif type(relPoint) == "number" then
    relPoint, x, y = nil, relPoint, x
  end
  if type(rel) == "string" then rel = _G[rel] end
  if rel and rel.frame then rel = rel.frame end -- frame handle
  rel = rel or self.parent or UIParent
  self.anchor = { point = point, rel = rel, relPoint = relPoint or point, x = x or 0, y = y or 0 }
  self.allpoints = nil
end

local function isVisible(f)
  while f do
    if not f.shown then return false end
    f = f.parent
  end
  return true
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------

function Frame:Show()
  if self.shown then return end
  if blocked(self, "Show") then return end
  self.shown = true
  Emu.runScript(self, "OnShow")
end

function Frame:Hide()
  if not self.shown then return end
  if blocked(self, "Hide") then return end
  self.shown = false
  autohide[self] = nil
  Emu.runScript(self, "OnHide")
end

function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return isVisible(self) end
function Frame:SetAttribute(k, v)
  if blocked(self, "SetAttribute") then return end
  self.attrs[k] = v
  if self.scripts.OnAttributeChanged then self.scripts.OnAttributeChanged(self, k, v) end
  for _, h in ipairs(self.hooks.OnAttributeChanged or {}) do h(self, k, v) end
end
function Frame:GetAttribute(k) return self.attrs[k] end
function Frame:SetFrameRef(k, f) self.attrs["frameref-" .. k] = f end
function Frame:GetFrameRef(k) return self.attrs["frameref-" .. k] end
function Frame:SetScript(n, fn) self.scripts[n] = fn end
function Frame:GetScript(n) return self.scripts[n] end
function Frame:HookScript(n, fn) self.hooks[n] = self.hooks[n] or {}; table.insert(self.hooks[n], fn) end
function Frame:RegisterEvent(e) eventFrames[e] = eventFrames[e] or {}; eventFrames[e][self] = true end
function Frame:UnregisterEvent(e) if eventFrames[e] then eventFrames[e][self] = nil end end
function Frame:SetPoint(...) if not blocked(self, "SetPoint") then setPoint(self, ...) end end
function Frame:ClearAllPoints() if not blocked(self, "ClearAllPoints") then self.anchor, self.allpoints = nil, nil end end
function Frame:SetAllPoints(rel)
  if blocked(self, "SetAllPoints") then return end
  if rel and rel.frame then rel = rel.frame end
  self.allpoints = rel or self.parent
  self.anchor = nil
end
function Frame:SetSize(w, h) if not blocked(self, "SetSize") then self.width, self.height = w, h end end
function Frame:SetWidth(w) if not blocked(self, "SetWidth") then self.width = w end end
function Frame:SetHeight(h) if not blocked(self, "SetHeight") then self.height = h end end
function Frame:GetWidth()
  if self == UIParent then return Emu.W end
  if self.allpoints then local _, _, w = rect(self); return w / effScale(self) end
  return self.width or 0
end
function Frame:GetHeight()
  if self == UIParent then return Emu.H end
  if self.allpoints then local _, _, _, h = rect(self); return h / effScale(self) end
  return self.height or 0
end
function Frame:SetScale(s) if not blocked(self, "SetScale") then self.scale = s end end
function Frame:GetScale() return self.scale or 1 end
function Frame:GetEffectiveScale() return effScale(self) end
function Frame:SetAlpha(a) self.alpha = a end
function Frame:GetAlpha() return self.alpha or 1 end
function Frame:GetCenter()
  local l, b, w, h = rect(self)
  if not l then return nil end
  local es = effScale(self)
  return (l + w / 2) / es, (b + h / 2) / es
end
function Frame:GetRect()
  local l, b, w, h = rect(self)
  if not l then return nil end
  local es = effScale(self)
  return l / es, b / es, w / es, h / es
end
function Frame:SetFrameStrata(s) self.strata = s end
function Frame:GetFrameStrata()
  local f = self
  while f do
    if f.strata then return f.strata end
    f = f.parent
  end
  return "MEDIUM"
end
function Frame:SetFrameLevel(l) self.level = l end
function Frame:GetFrameLevel()
  if self.level then return self.level end
  if self.parent then return self.parent:GetFrameLevel() + 1 end
  return 0
end
function Frame:EnableMouse(on) self.mouseMotion = on and true or false end
function Frame:SetMouseMotionEnabled(on) self.mouseMotion = on and true or false end
function Frame:SetMouseClickEnabled(on) self.mouseClick = on and true or false end
function Frame:IsMouseEnabled() return self.mouseMotion end
function Frame:IsMouseOver()
  local l, b, w, h = rect(self)
  if not l then return false end
  return Emu.cursorX >= l and Emu.cursorX <= l + w and Emu.cursorY >= b and Emu.cursorY <= b + h
end
function Frame:GetName() return self.name end
function Frame:GetParent() return self.parent end
function Frame:GetObjectType() return self.kind end
function Frame:IsProtected() return self.protected end
function Frame:RegisterForClicks(...) self.clicks = { ... } end
function Frame:GetMousePosition()
  local l, b, w, h = rect(self)
  if not l or w == 0 or h == 0 then return nil end
  local x, y = (Emu.cursorX - l) / w, (Emu.cursorY - b) / h
  if x < 0 or x > 1 or y < 0 or y > 1 then return nil end
  return x, y
end

function Frame:CreateTexture(name, layer, _, sublevel)
  return Emu.newRegion(self, "Texture", layer or "ARTWORK", sublevel or 0)
end
function Frame:CreateFontString(name, layer)
  return Emu.newRegion(self, "FontString", layer or "ARTWORK", 0)
end
function Frame:CreateMaskTexture() return Emu.newRegion(self, "MaskTexture", "ARTWORK", 0) end

-- Secure handler methods (SecureHandlerBaseTemplate).
function Frame:WrapScript(target, script, pre, post)
  if target.frame then target = target.frame end
  target.wraps[script] = { header = self, pre = pre, post = post }
end
function Frame:Execute(body) return Emu.runSnippet(self, body, "self", self) end

-- Override bindings owned by a frame (from a secure handle).
function Frame:SetBindingClick(_, key, buttonName, mouse)
  overrides[key] = { owner = self, button = buttonName, mouse = mouse }
end
function Frame:ClearBindings()
  for k, o in pairs(overrides) do if o.owner == self then overrides[k] = nil end end
end

function CreateFrame(kind, name, parent, template)
  counter = counter + 1
  if type(parent) == "string" then parent = _G[parent] end
  local f = setmetatable({
    kind = kind, name = name, parent = parent, attrs = {}, scripts = {}, hooks = {}, wraps = {},
    regions = {}, shown = true, index = counter, template = template,
    protected = template ~= nil and template:find("Secure") ~= nil,
  }, FrameMeta)
  if name then _G[name] = f end
  if parent == nil and UIParent then f.parent = UIParent end
  frames[#frames + 1] = f
  return f
end

---------------------------------------------------------------------------
-- Regions (textures, font strings)
---------------------------------------------------------------------------

function Emu.newRegion(parent, kind, layer, sublevel)
  counter = counter + 1
  local r = setmetatable({ kind = kind, parent = parent, isRegion = true, layer = layer,
    sublevel = sublevel, shown = true, color = { 1, 1, 1, 1 }, index = counter, rotation = 0 }, RegionMeta)
  parent.regions[#parent.regions + 1] = r
  return r
end
function Region:SetTexture(path) self.texture = path end
function Region:GetTexture() return self.texture end
function Region:SetVertexColor(r, g, b, a) self.color = { r, g, b, a or 1 } end
function Region:SetTextColor(r, g, b, a) self.color = { r, g, b, a or 1 } end
function Region:SetRotation(a) self.rotation = a end
function Region:SetSize(w, h) self.width, self.height = w, h end
function Region:SetWidth(w) self.width = w end
function Region:SetHeight(h) self.height = h end
function Region:SetPoint(...) setPoint(self, ...) end
function Region:SetAllPoints(rel) self.allpoints = rel or self.parent; self.anchor = nil end
function Region:ClearAllPoints() self.anchor, self.allpoints = nil, nil end
function Region:Show() self.shown = true end
function Region:Hide() self.shown = false end
function Region:SetShown(v) self.shown = v and true or false end
function Region:IsShown() return self.shown end
function Region:SetAlpha(a) self.alpha = a end
function Region:SetText(t) self.text = t end
function Region:GetText() return self.text end
function Region:SetFont(font, size, flags) self.font, self.fontSize = font, size end
function Region:SetShadowOffset(x, y) self.shadow = { x, y } end
function Region:GetParent() return self.parent end

---------------------------------------------------------------------------
-- Restricted environment and frame handles
---------------------------------------------------------------------------

local HANDLE_METHODS = { "GetName", "GetID", "IsShown", "IsVisible", "GetWidth", "GetHeight", "GetScale",
  "GetEffectiveScale", "GetRect", "GetFrameLevel", "GetFrameStrata", "IsMouseEnabled", "GetObjectType",
  "IsProtected", "GetAttribute", "GetMousePosition", "Show", "Hide", "SetWidth", "SetHeight", "SetScale",
  "SetAlpha", "ClearAllPoints", "SetPoint", "SetAllPoints", "SetAttribute", "ClearBindings", "SetBindingClick" }

local handleOf

local function unwrap(v)
  if type(v) == "table" and v.frame then return v.frame end
  return v
end

local function wrapValue(v)
  if type(v) == "table" and getmetatable(v) == FrameMeta then return handleOf(v) end
  return v
end

local function wrapAll(...)
  local n = select("#", ...)
  local t = { ... }
  for i = 1, n do t[i] = wrapValue(t[i]) end
  return unpack(t, 1, n)
end

handleOf = function(f)
  if f == nil then return nil end
  if f.handle then return f.handle end
  local h = { frame = f }
  for _, name in ipairs(HANDLE_METHODS) do
    if Frame[name] then h[name] = function(_, ...)
      local args = { ... }
      for i = 1, select("#", ...) do args[i] = unwrap(args[i]) end
      return wrapAll(Frame[name](f, unpack(args, 1, select("#", ...))))
    end end
  end
  h.GetFrameRef = function(_, k) return handleOf(f.attrs["frameref-" .. k]) end
  h.GetParent = function() return handleOf(f.parent) end
  h.IsUnderMouse = function() return f:IsMouseOver() end
  h.RegisterAutoHide = function(_, d) RegisterAutoHide(f, tonumber(d)) end
  h.UnregisterAutoHide = function() autohide[f] = nil end
  h.Run = function(_, body, ...) return Emu.runSnippet(f, body, "self,...", h, ...) end
  h.RunFor = function(_, other, body, ...) return Emu.runSnippet(f, body, "self,...", other, ...) end
  h.RunAttribute = function(_, attr, ...)
    local body = f.attrs[attr]
    if type(body) ~= "string" then error("Invalid snippet body", 2) end
    return Emu.runSnippet(f, body, "self,...", h, ...)
  end
  f.handle = h
  return h
end
Emu.handleOf = handleOf

-- Blizzard's list (Blizzard_RestrictedAddOnEnvironment/RestrictedEnvironment.lua),
-- reduced to what makes sense here.
local function restrictedBase()
  return {
    math = math, string = string, tostring = tostring, tonumber = tonumber, type = type, select = select,
    format = string.format, floor = math.floor, ceil = math.ceil, abs = math.abs, max = math.max, min = math.min,
    strsub = string.sub, strlen = string.len, strfind = string.find, strmatch = string.match,
    print = function() end,
    SecureCmdOptionParse = function(...) return SecureCmdOptionParse(...) end,
    UnitExists = function(u) return UnitExists(u) end,
    UnitIsDead = function(u) return UnitIsDead(u) end,
    PlayerInCombat = function() return Emu.combat end,
  }
end

local function envOf(header)
  if header.env then return header.env end
  local base, working = restrictedBase(), {}
  base.owner = handleOf(header)
  base.control = base.owner
  header.env = setmetatable({}, {
    __index = function(_, k)
      local v = base[k]
      if v == nil then v = Emu.secureExtras[k] end
      if v == nil then v = working[k] end
      return v
    end,
    __newindex = function(_, k, v) working[k] = v end,
  })
  return header.env
end

local compiled = {}

-- Runs a snippet in the environment of `header`, in a secure context.
function Emu.runSnippet(header, body, signature, ...)
  local env = envOf(header)
  local key = signature .. "\0" .. body
  compiled[env] = compiled[env] or {}
  local fn = compiled[env][key]
  if not fn then
    fn = loadIn("return function(" .. signature .. ")\n" .. body .. "\nend", "=snippet", env)()
    compiled[env][key] = fn
  end
  secureDepth = secureDepth + 1
  local results = { pcall(fn, ...) }
  secureDepth = secureDepth - 1
  if not results[1] then error("secure snippet: " .. tostring(results[2]), 0) end
  return unpack(results, 2, table.maxn and table.maxn(results) or #results)
end

-- Script with its WrapScript pre/post bodies.
function Emu.runScript(f, script, ...)
  local wrap = f.wraps[script]
  local allow, message
  if wrap then
    local sig = (script == "OnClick") and "self,button,down" or "self"
    allow, message = Emu.runSnippet(wrap.header, wrap.pre, sig, handleOf(f), ...)
    if allow == false then return false end
  end
  if f.scripts[script] then f.scripts[script](f, ...) end
  for _, h in ipairs(f.hooks[script] or {}) do h(f, ...) end
  if wrap and wrap.post and message ~= nil then
    Emu.runSnippet(wrap.header, wrap.post, "self,message", handleOf(f), message)
  end
  return true
end

function SecureHandlerExecute(frame, body)
  return Emu.runSnippet(frame, body, "self", handleOf(frame))
end

function RegisterAutoHide(frame, duration)
  if frame.frame then frame = frame.frame end
  autohide[frame] = { duration = duration or 0, elapsed = 0 }
end
function UnregisterAutoHide(frame) autohide[frame] = nil end

---------------------------------------------------------------------------
-- Units, macro conditions, macros
---------------------------------------------------------------------------

function UnitExists(u) return Emu.units[u] ~= nil end
function UnitIsDead(u) local x = Emu.units[u]; return x and x.dead or false end
function UnitName(u) local x = Emu.units[u]; if x then return x.name, x.realm end end
function UnitFullName(u) return UnitName(u) end
function UnitIsUnit(a, b) return Emu.units[a] ~= nil and Emu.units[a] == Emu.units[b] end
function UnitCanAttack(_, u) local x = Emu.units[u]; return x and not x.friendly or false end
function UnitIsFriend(_, u) local x = Emu.units[u]; return x and x.friendly or false end

local function condition(cond, unit)
  local x = Emu.units[unit]
  if cond == "exists" then return x ~= nil end
  if cond == "noexists" then return x == nil end
  if cond == "harm" then return x ~= nil and not x.friendly end
  if cond == "help" then return x ~= nil and x.friendly end
  if cond == "dead" then return x ~= nil and x.dead end
  if cond == "nodead" then return x ~= nil and not x.dead end
  if cond == "combat" then return Emu.combat end
  if cond == "nocombat" then return not Emu.combat end
  return false
end

-- "[@unit,cond,...] action; [..] action" -> action, unit
function SecureCmdOptionParse(msg)
  for clause in (msg .. ";"):gmatch("([^;]*);") do
    clause = clause:match("^%s*(.-)%s*$")
    local conds, action = clause:match("^%[(.-)%]%s*(.*)$")
    if not conds then conds, action = "", clause end
    local unit, ok = nil, true
    for c in conds:gmatch("[^,%s]+") do
      local u = c:match("^@(.+)$") or c:match("^target=(.+)$")
      if u then unit = u elseif not condition(c, unit or "target") then ok = false end
    end
    if ok then return action, unit end
  end
  return nil
end

function Emu.runMacro(text)
  Emu.macros[#Emu.macros + 1] = text
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    local cmd, rest = line:match("^(/%S+)%s*(.*)$")
    if cmd == "/bg" or cmd == "/instance" then
      emit("chat", "INSTANCE_CHAT", rest)
    elseif cmd == "/w" or cmd == "/whisper" then
      local who, msg = rest:match("^(%S+)%s+(.*)$")
      emit("chat", "WHISPER", msg or "", who or "")
    elseif cmd == "/ping" then
      local kind, unit = SecureCmdOptionParse(rest)
      if kind then
        unit = unit or "target"
        emit("ping", kind, unit, (UnitName(unit)) or "")
      end
    elseif cmd == "/tm" or cmd == "/targetmarker" then
      local mark, unit = SecureCmdOptionParse(rest)
      if mark then
        unit = unit or "target"
        emit("mark", mark, unit, (UnitName(unit)) or "")
      end
    elseif cmd then
      emit("macro-unknown", line)
    end
  end
end

-- Click on a button (from a key binding).
function Emu.click(f, mouse, down)
  if not Emu.runScript(f, "OnClick", mouse, down) then return false end
  if f.template and f.template:find("SecureActionButtonTemplate") and f.attrs.type == "macro" then
    local onDown = f.attrs.useOnKeyDown ~= false
    if down == onDown and f.attrs.macrotext then
      secureDepth = secureDepth + 1
      Emu.runMacro(f.attrs.macrotext)
      secureDepth = secureDepth - 1
      return true
    end
  end
  return false
end

---------------------------------------------------------------------------
-- Rest of the global API used by the add-on
---------------------------------------------------------------------------

STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 856 }
function PlaySound(id) emit("sound", id) end
function InCombatLockdown() return Emu.combat end
function IsInInstance() if Emu.inBG then return true, "pvp" end return false, "none" end
function GetTime() return Emu.now end
function GetCursorPosition() return Emu.cursorX, Emu.cursorY end
function GetBuildInfo() return "1.60.1", "70938", "sim", 16001 end
function GetNormalizedRealmName() return Emu.units.player.realm end
function GetBindingKey(name) return unpack(Emu.bindings[name] or {}) end
function ClearOverrideBindings(owner) for k, o in pairs(overrides) do if o.owner == owner then overrides[k] = nil end end end
function SetOverrideBindingClick(owner, _, key, buttonName, mouse)
  overrides[key] = { owner = owner, button = buttonName, mouse = mouse or "LeftButton" }
end
Emu.looking = false
function IsMouselooking() return Emu.looking end
function MouselookStop() Emu.looking = false end
function MouselookStart() Emu.looking = true end
function IsMouseButtonDown(b) return (b == "RightButton" and Emu.rightDown) or false end
function hooksecurefunc() end
date = os and os.date or function() return "?" end
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m)
  emit("print", (tostring(m):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
end }

UIParent = CreateFrame("Frame", "UIParent")
UIParent.parent = nil
UIParent.strata = "MEDIUM"
WorldFrame = UIParent

---------------------------------------------------------------------------
-- Driving the emulation
---------------------------------------------------------------------------

function Emu.fire(event, ...)
  local list = {}
  for f in pairs(eventFrames[event] or {}) do list[#list + 1] = f end
  table.sort(list, function(a, b) return a.index < b.index end)
  for _, f in ipairs(list) do
    if f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
  end
end

local function sortKey(f)
  return (STRATA[f:GetFrameStrata()] or 3) * 1e9 + f:GetFrameLevel() * 1e5 + f.index
end

local function visibleFrames()
  local list = {}
  for _, f in ipairs(frames) do
    if f ~= UIParent and isVisible(f) then list[#list + 1] = f end
  end
  table.sort(list, function(a, b) return sortKey(a) < sortKey(b) end)
  return list
end

-- Mouse focus: the topmost visible mouse-enabled frame under the cursor.
function Emu.updateFocus()
  local new
  for _, f in ipairs(visibleFrames()) do
    if f.mouseMotion and f:IsMouseOver() then new = f end
  end
  if new == focus then return end
  local old = focus
  focus = new
  if old then Emu.runScript(old, "OnLeave", true) end
  if new then Emu.runScript(new, "OnEnter", true) end
end

function Emu.mouse(x, y)
  Emu.cursorX, Emu.cursorY = x, y
  Emu.updateFocus()
end

function Emu.key(key, down)
  local o = overrides[key]
  if not o then return false end
  local button = _G[o.button]
  if not button then return false end
  local ran = Emu.click(button, o.mouse, down)
  Emu.updateFocus()
  return ran
end

function Emu.tick(dt)
  Emu.now = Emu.now + dt
  local timers = {}
  for f, entry in pairs(autohide) do timers[#timers + 1] = { f, entry } end
  table.sort(timers, function(a, b) return a[1].index < b[1].index end)
  for _, item in ipairs(timers) do
    local f, entry = item[1], item[2]
    if autohide[f] ~= entry then
      -- re-registered or removed meanwhile
    elseif not f.shown then
      autohide[f] = nil
    elseif f:IsMouseOver() then
      entry.elapsed = 0
    else
      entry.elapsed = entry.elapsed + dt
      if entry.elapsed >= entry.duration then
        autohide[f] = nil
        secureDepth = secureDepth + 1
        local ok, err = pcall(Frame.Hide, f)
        secureDepth = secureDepth - 1
        if not ok then error(err, 0) end
      end
    end
  end
  for _, f in ipairs(visibleFrames()) do
    if f.scripts.OnUpdate then f.scripts.OnUpdate(f, dt) end
  end
  Emu.updateFocus()
end

-- Advances time in small steps (timers, fades).
function Emu.wait(seconds)
  local step = 1 / 60
  local t = 0
  while t < seconds - 1e-9 do
    Emu.tick(step)
    t = t + step
  end
end

function Emu.setCombat(on)
  if on == Emu.combat then return end
  Emu.combat = on
  Emu.fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end

function Emu.setBG(on)
  Emu.inBG = on
  Emu.fire("ZONE_CHANGED_NEW_AREA")
end

function Emu.centerOf(f)
  local l, b, w, h = rect(f)
  return l + w / 2, b + h / 2
end

-- Loads add-on files in TOC order. read(path) returns the source.
function Emu.loadAddon(name, dir, read)
  Emu.addonName = name
  local toc = read(dir .. "/" .. name .. ".toc")
  local ns = {}
  for line in (toc .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    if line ~= "" and not line:match("^%s*#") then
      local file = line:match("^%s*(.-)%s*$")
      if file:match("%.lua$") then
        local chunk = loadIn(read(dir .. "/" .. file), "@" .. name .. "/" .. file)
        chunk(name, ns)
      end
    end
  end
  Emu.fire("ADDON_LOADED", name)
  Emu.fire("PLAYER_LOGIN")
  Emu.fire("PLAYER_ENTERING_WORLD")
  return ns
end

-- Every call that left the wheel, for the caller (results and paths).
function Emu.watchCalls(ns)
  local W = ns.Wheel
  local previous = W.OnClosed
  W.OnClosed = function(result, msg, path)
    if previous then previous(result, msg, path) end
    emit("call", result, msg or "", path or "")
  end
end

-- Returns and clears the output, one event per line, fields tab separated.
function Emu.takeOutput()
  local lines = {}
  for _, e in ipairs(Emu.output) do
    for i = 1, #e do e[i] = e[i]:gsub("[\t\n]", " ") end
    lines[#lines + 1] = table.concat(e, "\t")
  end
  Emu.output = {}
  return table.concat(lines, "\n")
end

-- What is on screen, back to front, one region per line:
--   T  texture  centerX centerY width height rotation r g b a
--   F  text     anchorX anchorY point size r g b a
-- Screen units, origin bottom left (as in WoW).
local function fmt(n) return string.format("%.2f", n) end

function Emu.draw()
  local out = {}
  for _, f in ipairs(visibleFrames()) do
    local regions = {}
    for _, r in ipairs(f.regions) do
      if r.shown then regions[#regions + 1] = r end
    end
    table.sort(regions, function(a, b)
      local la, lb = LAYERS[a.layer] or 3, LAYERS[b.layer] or 3
      if la ~= lb then return la < lb end
      if a.sublevel ~= b.sublevel then return a.sublevel < b.sublevel end
      return a.index < b.index
    end)
    local alpha = effAlpha(f)
    for _, r in ipairs(regions) do
      local c = r.color
      local a = (c[4] or 1) * alpha * (r.alpha or 1)
      if a > 0.005 then
        local l, b, w, h, ax, ay = rect(r)
        if l then
          if r.kind == "Texture" and r.texture and w > 0 and h > 0 then
            out[#out + 1] = table.concat({ "T", r.texture, fmt(l + w / 2), fmt(b + h / 2), fmt(w), fmt(h),
              fmt(r.rotation or 0), fmt(c[1]), fmt(c[2]), fmt(c[3]), fmt(a) }, "\t")
          elseif r.kind == "FontString" and r.text and r.text ~= "" then
            out[#out + 1] = table.concat({ "F", (tostring(r.text):gsub("[\t\n]", " ")), fmt(ax), fmt(ay),
              r.anchor and r.anchor.point or "CENTER", fmt((r.fontSize or 12) * effScale(f)), fmt(c[1]), fmt(c[2]), fmt(c[3]), fmt(a) }, "\t")
          end
        end
      end
    end
  end
  return table.concat(out, "\n")
end

return Emu

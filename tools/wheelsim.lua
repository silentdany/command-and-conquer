-- Offline test of the wheel: emulates the WoW API and the secure snippets.
-- Run from the repo root: lua5.1 tools/wheelsim.lua CommandAndConquer
-- Minimal WoW API emulation to run Data/Wheel/Core and the secure snippets.
local ADDON_DIR = arg[1]
date = os.date
STANDARD_TEXT_FONT = "font"
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1 }
function PlaySound() end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) print((m:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))) end }
local combat = false
function InCombatLockdown() return combat end
function UnitFactionGroup() return "Alliance" end
function UnitFullName() return "Elemente", "Venera" end
function UnitName() return "Elemente" end
local looking = false
function IsMouselooking() return looking end
function MouselookStop() looking = false; print("  [mouselook stopped]") end
function MouselookStart() looking = true; print("  [mouselook restored]") end
function IsMouseButtonDown() return true end
local bindings = { CNC_WHEEL = { "BUTTON4" }, CNC_INC = { "SHIFT-BUTTON4" } }
function GetBindingKey(name) return unpack(bindings[name] or {}) end
local overrides = {}
function ClearOverrideBindings() overrides = {} end
function SetOverrideBindingClick(_, _, key, btn, mb) overrides[key] = { btn = btn, mb = mb } end
SlashCmdList = {}

local function region()
  local r = {}
  setmetatable(r, { __index = function(t, k) if k:match("^%l") then return nil end return function() end end })
  r.SetText = function(self, t) self.t = t end
  return r
end
local allFrames = {}
local Frame = {}
Frame.__index = function(t, k)
  if Frame[k] then return Frame[k] end
  if k:match("^%l") then return nil end
  return function() end
end
function CreateFrame(kind, name, parent, template)
  local f = setmetatable({ attrs = {}, refs = {}, scripts = {}, hooks = {}, shown = true, name = name, parent = parent, wraps = {}, x = 0, y = 0 }, Frame)
  if name then _G[name] = f end
  allFrames[#allFrames + 1] = f
  return f
end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() local f = self while f do if not f.shown then return false end f = f.parent end return true end
function Frame:SetAttribute(k, v)
  self.attrs[k] = v
  for _, h in ipairs(self.hooks.OnAttributeChanged or {}) do h(self, k, v) end
end
function Frame:GetAttribute(k) return self.attrs[k] end
function Frame:SetFrameRef(k, f) self.refs[k] = f end
function Frame:GetFrameRef(k) return self.refs[k] end
function Frame:SetScript(n, fn) self.scripts[n] = fn end
function Frame:HookScript(n, fn) self.hooks[n] = self.hooks[n] or {}; table.insert(self.hooks[n], fn) end
function Frame:CreateTexture() return region() end
function Frame:CreateFontString() return region() end
function Frame:CreateMaskTexture() return region() end
function Frame:RegisterEvent() end
-- positions: track anchor point offsets in absolute coords
function Frame:SetPoint(p, rel, rp, x, y)
  if type(rel) == "number" or rel == nil then x, y, rel = rel, rp, self.parent end
  if type(rp) ~= "string" then x, y = rp, x end
  self.anchor = { rel = rel, rp = rp, x = x or 0, y = y or 0 }
end
function Frame:GetCenter()
  local a = self.anchor
  if not a or not a.rel or a.rel == UIParent then
    if a and a.rp == "BOTTOMLEFT" then return a.x, a.y end
    return 960 + (a and a.x or 0), 540 + (a and a.y or 0)
  end
  if a.rp == "BOTTOMLEFT" then return a.x, a.y end
  local rx, ry = a.rel:GetCenter()
  return rx + a.x, ry + a.y
end
function Frame:GetWidth() return 1920 end
function Frame:GetHeight() return 1080 end
local mouseX, mouseY = 500, 400
function Frame:GetMousePosition() return mouseX / 1920, mouseY / 1080 end
function Frame:WrapScript(frame, script, pre)
  frame.wraps[script] = { header = self, pre = pre }
end
UIParent = CreateFrame("Frame", "UIParent")

local function runSnippet(frame, script, ...)
  local w = frame.wraps[script]
  if not w then return true end
  local args = { ... }
  local env = setmetatable({ self = frame, owner = w.header, tonumber = tonumber, tostring = tostring, string = string, math = math }, { __index = function(_, k) error("restricted env: unknown global " .. tostring(k), 2) end })
  if script == "OnClick" then env.button, env.down = args[1], args[2] end
  local fn = assert(loadstring(w.pre, "=" .. script))
  setfenv(fn, env)
  local ret = fn()
  return ret ~= false
end

local ns = {}
for _, file in ipairs({ "Data.lua", "Wheel.lua", "Core.lua" }) do
  local chunk = assert(loadfile(ADDON_DIR .. "/" .. file))
  chunk("CommandAndConquer", ns)
end
local events = allFrames[#allFrames]
for _, f in ipairs(allFrames) do if f.scripts.OnEvent then events = f end end
events.scripts.OnEvent(events, "ADDON_LOADED", "CommandAndConquer")
events.scripts.OnEvent(events, "PLAYER_LOGIN")
local W = ns.Wheel
local send = W.send
local sent = {}

local function press(key, down)
  local o = overrides[key]
  assert(o, "no override for " .. key)
  local ok = runSnippet(send, "OnClick", o.mb, down)
  if ok then
    assert(not down, "macro must not run on key down")
    sent[#sent + 1] = send.attrs.macrotext
    print("  MACRO RUN: " .. send.attrs.macrotext)
  end
end
local function enter(node)
  if not node:IsVisible() then return end
  runSnippet(node, "OnEnter")
end
-- Move the mouse onto a node: emulate OnEnter for visible node under cursor.
local function moveTo(node) enter(node) end
local r1, r2, r3 = W.rings[1], W.rings[2], W.rings[3]

print("== 1. DEF > Roof, release")
looking = true
press("BUTTON4", true)
assert(W.root:IsShown() and r1:IsShown() and not r2:IsShown())
moveTo(r1.nodes[1])           -- DEF (N)
assert(r2:IsShown() and not r1:IsShown())
moveTo(r2.nodes[2])           -- Roof (NE)
print("  preview:", W.preview.text.t)
press("BUTTON4", false)
assert(sent[#sent] == "/bg Defend our roof")
assert(not W.root:IsShown())

print("== 2. INC > Tunnel > 3, release")
press("BUTTON4", true)
moveTo(r1.nodes[5])           -- INC (NW)
moveTo(r2.nodes[5])           -- Tunnel (S)
assert(r3:IsShown() and not r2:IsShown())
moveTo(r3.nodes[3])           -- 3
press("BUTTON4", false)
assert(sent[#sent] == "/bg 3 incoming at our tunnel", sent[#sent])

print("== 3. INC > Ramp, release without count")
press("BUTTON4", true)
moveTo(r1.nodes[5]); moveTo(r2.nodes[3])
press("BUTTON4", false)
assert(sent[#sent] == "/bg Incoming at our ramp")

print("== 4. Back to center = cancel")
local n = #sent
press("BUTTON4", true)
moveTo(r1.nodes[2]); moveTo(r2.nodes[4]); moveTo(r2.center)
press("BUTTON4", false)
assert(#sent == n, "cancel sent something")

print("== 5. Release at step 1 = nothing")
press("BUTTON4", true); press("BUTTON4", false)
assert(#sent == n)

print("== 6. Direct INC binding (SHIFT-BUTTON4) > GY side > 5+")
press("SHIFT-BUTTON4", true)
assert(r2:IsShown() and not r1:IsShown())
moveTo(r2.nodes[7]); moveTo(r3.nodes[5])
press("SHIFT-BUTTON4", false)
assert(sent[#sent] == "/bg 5+ incoming at our GY side", sent[#sent])

print("== 7. Change mind inside step 2: Ramp then Tunnel (EFC)")
press("BUTTON4", true)
moveTo(r1.nodes[3]); moveTo(r2.nodes[3]); moveTo(r2.nodes[5])
press("BUTTON4", false)
assert(sent[#sent] == "/bg Enemy carrier at our tunnel (EFC)")

print("== 8. Test mode")
SlashCmdList.COMMANDANDCONQUER("test")
press("BUTTON4", true); moveTo(r1.nodes[2]); moveTo(r2.nodes[1]); press("BUTTON4", false)
assert(sent[#sent] == "/w Elemente-Venera I have their flag, escort me", sent[#sent])

print("== 9. Every message fits a macro (255)")
for k, v in pairs(send.attrs) do
  if type(k) == "string" and k:match("^m%d") then assert(#v + 30 < 255) end
end
print("ALL OK, sent " .. #sent .. " messages")

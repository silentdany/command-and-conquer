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
inBG = true
function IsInInstance() if inBG then return true, "pvp" end return false, "none" end
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
function Frame:GetEffectiveScale() return 1 end
cursorX, cursorY = 500, 400
function GetCursorPosition() return cursorX, cursorY end
function Frame:GetHeight() return 1080 end
local mouseX, mouseY = 500, 400
function Frame:GetMousePosition() return mouseX / 1920, mouseY / 1080 end
function Frame:SetBindingClick(_, key, btn, mb) overrides[key] = { btn = btn, mb = mb, owner = self } end
function Frame:ClearBindings() for k, o in pairs(overrides) do if o.owner == self then overrides[k] = nil end end end
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
local function rightClick()
  if ns.Wheel.catcher:IsVisible() then runSnippet(ns.Wheel.catcher, "OnClick", "RightButton", true) end
end
local function enter(node)
  if not node:IsVisible() then return end
  runSnippet(node, "OnEnter")
end
-- Move the mouse onto a node: emulate OnEnter for visible node under cursor.
local function moveTo(node) enter(node) end
local r1, r2, r3, r4, r5 = W.rings[1], W.rings[2], W.rings[3], W.rings[4], W.rings[5]
-- Indices: actions 1 DEF, 2 FLAG, 3 EFC, 4 ATTACK, 5 SCOUT, 6 INC.
-- Places: 1 FR, 2 ROOF, 3 RAMP, 4 TUN, 5 GY, 6 MID (or action specific).
local function last() return sent[#sent] end

print("== 1. DEF > Roof, release")
looking = true
press("BUTTON4", true)
assert(W.root:IsShown() and r1:IsShown() and not r2:IsShown())
assert(W.catcher:IsVisible(), "right-click catcher not shown while open")
moveTo(r1.nodes[1]); assert(r2:IsShown() and not r1:IsShown())
moveTo(r2.nodes[2])
print("  preview:", W.preview.text.t)
press("BUTTON4", false)
assert(last() == "/bg Defend our roof", last())
assert(not W.root:IsShown() and not W.catcher:IsVisible())

print("== 2. INC > Tunnel > 3")
press("BUTTON4", true); moveTo(r1.nodes[6]); moveTo(r2.nodes[4])
assert(r3:IsShown() and not r2:IsShown())
moveTo(r3.nodes[3]); press("BUTTON4", false)
assert(last() == "/bg 3 incoming at our tunnel", last())

print("== 3. INC > Ramp, release without count")
press("BUTTON4", true); moveTo(r1.nodes[6]); moveTo(r2.nodes[3]); press("BUTTON4", false)
assert(last() == "/bg Incoming at our ramp", last())

print("== 4. Back to center = cancel")
local n = #sent
press("BUTTON4", true); moveTo(r1.nodes[2]); moveTo(r2.nodes[4]); moveTo(r2.center); press("BUTTON4", false)
assert(#sent == n)

print("== 5. Release at step 1 = nothing")
press("BUTTON4", true); press("BUTTON4", false); assert(#sent == n)

print("== 6. Direct INC key > GY > 5+")
press("SHIFT-BUTTON4", true); assert(r2:IsShown() and not r1:IsShown())
moveTo(r2.nodes[5]); moveTo(r3.nodes[5]); press("SHIFT-BUTTON4", false)
assert(last() == "/bg 5+ incoming at our graveyard side", last())

print("== 7. SCOUT > EFR > 3, CLEAR, 1, no number")
press("BUTTON4", true); moveTo(r1.nodes[5]); moveTo(r2.nodes[1])
assert(r4:IsShown() and not r3:IsShown())
moveTo(r4.nodes[4]); press("BUTTON4", false)
assert(last() == "/bg 3 enemies in their flag room", last())
press("BUTTON4", true); moveTo(r1.nodes[5]); moveTo(r2.nodes[1]); moveTo(r4.nodes[1]); press("BUTTON4", false)
assert(last() == "/bg Their flag room is clear", last())
press("BUTTON4", true); moveTo(r1.nodes[5]); moveTo(r2.nodes[6]); moveTo(r4.nodes[2]); press("BUTTON4", false)
assert(last() == "/bg 1 enemy at mid", last())
press("BUTTON4", true); moveTo(r1.nodes[5]); moveTo(r2.nodes[2]); moveTo(r4.center); press("BUTTON4", false)
assert(last() == "/bg Enemies on their roof", last())

print("== 8. Right click: back from count to places, pick another place")
press("BUTTON4", true); moveTo(r1.nodes[6]); moveTo(r2.nodes[4])
assert(r3:IsShown())
rightClick()
assert(r2:IsShown() and not r3:IsShown() and W.root:IsShown())
moveTo(r2.center)                 -- cursor lands in the dead center
moveTo(r2.nodes[3]); press("BUTTON4", false)
assert(last() == "/bg Incoming at our ramp", last())

print("== 9. Right click: back from places to actions, then another action")
press("BUTTON4", true); moveTo(r1.nodes[1]); moveTo(r2.nodes[1])
rightClick()
assert(r1:IsShown() and not r2:IsShown())
moveTo(r1.nodes[3]); moveTo(r2.nodes[6]); press("BUTTON4", false)
assert(last() == "/bg Enemy carrier at mid", last())

print("== 9b. EFC: side step, escorts, all optional")
press("BUTTON4", true); moveTo(r1.nodes[3]); moveTo(r2.nodes[4])
assert(r5:IsShown() and not r4:IsShown(), "side ring expected")
moveTo(r5.nodes[1])                       -- THEIRS (top)
assert(r4:IsShown() and r4.nodes[1].big.t == "ALONE", tostring(r4.nodes[1].big.t))
moveTo(r4.nodes[4]); press("BUTTON4", false)
assert(last() == "/bg Enemy carrier entering their tunnel with 3 escorts", last())

press("BUTTON4", true); moveTo(r1.nodes[3]); moveTo(r2.nodes[4]); press("BUTTON4", false)
assert(last() == "/bg Enemy carrier at the tunnel", last())          -- released at the side step

press("BUTTON4", true); moveTo(r1.nodes[3]); moveTo(r2.nodes[3]); moveTo(r5.nodes[2]); press("BUTTON4", false)
assert(last() == "/bg Enemy carrier at our ramp", last())            -- released at the escort step

press("BUTTON4", true); moveTo(r1.nodes[3]); moveTo(r2.nodes[5]); moveTo(r5.nodes[2]); moveTo(r4.nodes[2]); press("BUTTON4", false)
assert(last() == "/bg Enemy carrier at our graveyard side with 1 escort", last())

press("BUTTON4", true); moveTo(r1.nodes[3]); moveTo(r2.nodes[2])
assert(r4:IsShown() and not r5:IsShown(), "roof has no side step")
moveTo(r4.nodes[1]); press("BUTTON4", false)
assert(last() == "/bg Enemy carrier on their roof, alone", last())

print("== 9c. Right click from escorts back to the side step, change side")
press("BUTTON4", true); moveTo(r1.nodes[3]); moveTo(r2.nodes[4]); moveTo(r5.nodes[2]); moveTo(r4.nodes[3])
rightClick()
assert(r5:IsShown() and not r4:IsShown())
assert(send.attrs.msg == "Enemy carrier at the tunnel", send.attrs.msg)
moveTo(r5.center); moveTo(r5.nodes[1]); press("BUTTON4", false)
assert(last() == "/bg Enemy carrier entering their tunnel", last())

print("== 9d. SCOUT count labels")
press("BUTTON4", true); moveTo(r1.nodes[5]); moveTo(r2.nodes[1])
assert(r4.nodes[1].big.t == "CLEAR", tostring(r4.nodes[1].big.t))
rightClick(); rightClick(); press("BUTTON4", false)

print("== 10. Double right click closes, release sends nothing")
n = #sent
press("BUTTON4", true); moveTo(r1.nodes[4]); moveTo(r2.nodes[2])
rightClick() -- no pick in between
rightClick()
assert(not W.root:IsShown() and not W.catcher:IsVisible())
press("BUTTON4", false); assert(#sent == n)

print("== 11. Double right click from the count ring closes too")
press("BUTTON4", true); moveTo(r1.nodes[6]); moveTo(r2.nodes[1]); moveTo(r3.nodes[2])
rightClick(); moveTo(r2.center); rightClick()
assert(not W.root:IsShown())
press("BUTTON4", false); assert(#sent == n)

print("== 12. Right click at step 1 closes")
press("BUTTON4", true); rightClick(); assert(not W.root:IsShown()); press("BUTTON4", false)

print("== 13. Outside a BG: practice whisper (automatic)")
inBG = false
events.scripts.OnEvent(events, "ZONE_CHANGED_NEW_AREA")
press("BUTTON4", true); moveTo(r1.nodes[2]); moveTo(r2.nodes[1]); press("BUTTON4", false)
assert(last() == "/w Elemente-Venera I have their flag, escort me", last())
inBG = true
events.scripts.OnEvent(events, "PLAYER_ENTERING_WORLD")

print("== 14. Every message fits a macro (255) and every slot has a message")
for a = 1, 6 do for c = 1, 6 do assert(send.attrs["m" .. a .. "-" .. c], a .. "-" .. c) end end
for k, v in pairs(send.attrs) do
  if type(k) == "string" and k:match("^m%d") then assert(#v + 30 < 255) end
end

print("== 15. /cnc scale")
SlashCmdList.COMMANDANDCONQUER("scale 1.4"); assert(CnCDB.scale == 1.4)
SlashCmdList.COMMANDANDCONQUER("scale 9"); assert(CnCDB.scale == 1.4)

print("== 16. Aim highlight follows the cursor angle")
press("BUTTON4", true)
cursorX, cursorY = 500 + 80, 400 + 46   -- 60 degrees: top right sector (FLAG)
W:UpdateAim(); assert(W.aim == 2, "aim " .. tostring(W.aim))
cursorX, cursorY = 500, 400 + 20        -- hollow center
W:UpdateAim(); assert(W.aim == 0)
press("BUTTON4", false)
print("ALL OK, sent " .. #sent .. " messages")

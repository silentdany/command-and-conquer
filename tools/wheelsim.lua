-- Offline test of the wheel: the real add-on files on the WoW emulation
-- (tools/sim/wowemu.lua). The mouse really moves, key bindings really
-- click the secure button, secure snippets run in a restricted
-- environment, timers really wait.
--
-- From the repo root:   lua5.1 tools/wheelsim.lua
-- The same file also runs under Lua 5.4 in node (tools/websim-check.mjs),
-- the runtime of the training web page.

local ROOT = CNC_ROOT or "."
local read = CNC_READ or function(path)
  local f = assert(io.open(path, "rb"), "can't open " .. path)
  local s = f:read("*a")
  f:close()
  return s
end
local loadIn = (setfenv and loadstring) and function(src, name) return assert(loadstring(src, name)) end
  or function(src, name) return assert(load(src, name)) end

local Emu = loadIn(read(ROOT .. "/tools/sim/wowemu.lua"), "@wowemu.lua")()
Emu.bindings = { CNC_WHEEL = { "TAB" }, CNC_INC = { "SHIFT-TAB" }, CNC_EFC = { "CTRL-TAB" } }
Emu.units.target = { name = "Gruk", friendly = false }

local ns = Emu.loadAddon("CommandAndConquer", ROOT .. "/CommandAndConquer", read)
Emu.watchCalls(ns)
local W = ns.Wheel
local send = W.send
local R1, R2, R3, R4, R5 = W.rings[1], W.rings[2], W.rings[3], W.rings[4], W.rings[5]

local passed = 0
local function check(cond, what)
  if not cond then error("FAILED: " .. tostring(what), 2) end
  passed = passed + 1
end

-- Output since the last call: chats, pings, marks, calls, blocked, prints.
local log = { chat = {}, ping = {}, mark = {}, call = {}, blocked = {}, print = {} }
local function drain()
  for _, e in ipairs(Emu.output) do
    if log[e[1]] then table.insert(log[e[1]], e) end
  end
  Emu.output = {}
end
local function reset()
  drain()
  for k in pairs(log) do log[k] = {} end
end

local function lastChat() drain(); local e = log.chat[#log.chat]; return e and e[3] end
local function lastPing() drain(); local e = log.ping[#log.ping]; return e and (e[2] .. "@" .. e[3]) end
local function lastMacro() return Emu.macros[#Emu.macros] end

local function frameStep() Emu.tick(1 / 60) end
local function moveTo(node)
  check(node:IsVisible(), "node not visible")
  Emu.mouse(Emu.centerOf(node))
  frameStep()
end
local function key(k, down) Emu.key(k, down); frameStep() end
local function open(k) key(k or "TAB", true) end
local function release(k) key(k or "TAB", false) end

-- Opens the wheel, follows sectors given as {ring, index} (index 0 =
-- center), releases. Returns the chat message sent (or nil).
local function call(...)
  local before = #Emu.macros
  open()
  for _, step in ipairs({ ... }) do
    local ring = W.rings[step[1]]
    moveTo(step[2] == 0 and ring.center or ring.nodes[step[2]])
  end
  release()
  if #Emu.macros == before then return nil end
  return lastChat()
end
local function wait(s) Emu.wait(s) end

-- Self-test at login: the emulated timers hide after 0.3 s.
wait(0.5)
drain()
check(ns.timersOK == true, "self-test should pass in the emulation")

print("== 1. DEF > ROOF, release")
Emu.looking, Emu.rightDown = true, true
check(call({ 1, 4 }, { 2, 2 }) == "DEF: defend OUR ROOF", lastChat())
check(not W.root:IsShown(), "wheel closed")
check(Emu.looking, "camera given back")
wait(1.1)

print("== 2. Step 1 has 5 sectors, pentagon, labels")
check(#R1.nodes == 5, "5 actions")
open()
local labels = {}
for i = 1, 5 do labels[i] = R1.nodes[i].label.text end
check(table.concat(labels, ",") == "EFC,ATTACK,FC,DEF,INC", table.concat(labels, ","))
local x1, y1 = Emu.centerOf(R1.nodes[1])
local cx, cy = Emu.centerOf(R1)
check(math.abs(x1 - cx) < 0.01 and y1 > cy, "EFC on top")
release()
check(lastChat() == "DEF: defend OUR ROOF", "release at step 1 sends nothing")

print("== 3. Place layout (pyramid), the same for every action")
open(); moveTo(R1.nodes[4])
local want = { "FR", "ROOF", "RAMP", "MID", "GY", "TUN" }
for i = 1, 6 do check(R2.nodes[i].label.text == want[i], "slot " .. i .. " " .. tostring(R2.nodes[i].label.text)) end
check(R2.nodes[1].icon.color[3] > 0.9 and R2.nodes[1].icon.color[1] < 0.5, "DEF places are blue")
check(R2.nodes[4].icon.color[1] == 1, "mid is white")
release()

print("== 4. DEF and ATTACK counts")
wait(1.1)
check(call({ 1, 4 }, { 2, 1 }, { 4, 4 }) == "DEF: 3 defend OUR FLAG ROOM", lastChat())
wait(1.1)
check(call({ 1, 4 }, { 2, 6 }, { 4, 1 }) == "DEF: everyone defend OUR TUNNEL", lastChat())
wait(1.1)
check(call({ 1, 2 }, { 2, 2 }, { 4, 1 }) == "ATTACK: everyone attack THEIR ROOF", lastChat())
check(lastPing() == "attack@target", tostring(lastPing()))
wait(1.1)
check(call({ 1, 2 }, { 2, 3 }, { 4, 2 }) == "ATTACK: 1 attack THEIR RAMP", lastChat())
wait(1.1)
check(call({ 1, 2 }, { 2, 4 }) == "ATTACK: attack MID", lastChat())
wait(1.1)
check(call({ 1, 2 }, { 2, 6 }, { 4, 0 }) == "ATTACK: attack THEIR TUNNEL", "count center = without count")
check(R4.nodes[1].big.text == "ALL" and R4.nodes[6].big.text == "5", "count labels")

print("== 5. EFC: release after step 1 = their carrier")
wait(1.1)
reset()
check(call({ 1, 1 }) == "EFC: attack their flag carrier", lastChat())
check(lastPing() == "attack@target", tostring(lastPing()))
wait(1.1)
check(call({ 1, 1 }, { 2, 3 }) == "EFC: their flag carrier is at OUR RAMP", lastChat())
wait(1.1)
check(call({ 1, 1 }, { 2, 3 }, { 3, 1 }) == "EFC: their flag carrier is at THEIR RAMP", lastChat())
check(R3.nodes[1].icon.color[1] > 0.8 and R3.nodes[1].icon.color[3] < 0.3, "flip sector is red")
wait(1.1)
check(call({ 1, 1 }, { 2, 3 }, { 3, 3 }) == nil, "CANCEL on the side ring")
check(call({ 1, 1 }, { 2, 4 }) == "EFC: their flag carrier is at MID", lastChat())
check(not R3:IsShown(), "mid has no side")
wait(1.1)
-- Top sector of the EFC places ring is empty: nothing happens there.
open(); moveTo(R1.nodes[1]); moveTo(R2.nodes[1])
check(R2:IsShown() and send:GetAttribute("path") == "1", "empty sector ignored")
release()
check(lastChat() == "EFC: attack their flag carrier", lastChat())

print("== 6. FC: our carrier, CAP on top")
wait(1.1)
Emu.units.target = { name = "Bob", friendly = true }
check(call({ 1, 3 }) == "FC: escort our carrier", lastChat())
check(lastPing() == "assist@target", tostring(lastPing()))
wait(1.1)
local n = #log.ping
check(call({ 1, 3 }, { 2, 1 }) == "CAP: our flag is home, cap now", lastChat())
drain()
check(#log.ping == n, "no ping with CAP")
wait(1.1)
check(call({ 1, 3 }, { 2, 6 }) == "FC: escort our carrier, THEIR TUNNEL", lastChat())
wait(1.1)
check(call({ 1, 3 }, { 2, 6 }, { 3, 1 }) == "FC: escort our carrier, OUR TUNNEL", lastChat())
Emu.units.target = { name = "Gruk", friendly = false }

print("== 7. INC: home, their side, counts")
wait(1.1)
check(call({ 1, 5 }, { 2, 6 }) == "INC: enemies coming at OUR TUNNEL", lastChat())
wait(1.1)
check(call({ 1, 5 }, { 2, 6 }, { 4, 4 }) == "INC: 3 enemies coming at OUR TUNNEL", lastChat())
wait(1.1)
check(call({ 1, 5 }, { 2, 6 }, { 4, 2 }) == "INC: 1 enemy coming at OUR TUNNEL", lastChat())
check(lastPing() == "warning@target", tostring(lastPing()))
wait(1.1)
check(call({ 1, 5 }, { 2, 3 }, { 4, 1 }) == "INC: enemies at THEIR RAMP", lastChat())
wait(1.1)
check(call({ 1, 5 }, { 2, 3 }, { 4, 1 }, { 5, 3 }) == "INC: 2 enemies at THEIR RAMP", lastChat())
wait(1.1)
check(call({ 1, 5 }, { 2, 3 }, { 4, 1 }, { 5, 1 }) == "INC: all enemies at THEIR RAMP", lastChat())
wait(1.1)
check(call({ 1, 5 }, { 2, 4 }, { 4, 1 }) == "INC: all enemies coming at MID", lastChat())
wait(1.1)
check(call({ 1, 5 }, { 2, 2 }, { 4, 5 }) == nil, "INC CANCEL")
check(call({ 1, 5 }, { 2, 2 }, { 4, 5 }, { 4, 6 }) == "INC: 5 enemies coming at OUR ROOF", "CANCEL then a count")
wait(1.1)
check(call({ 1, 5 }, { 2, 2 }, { 4, 5 }, { 4, 0 }) == "INC: enemies coming at OUR ROOF", "CANCEL then center")

print("== 8. Cancels")
local count = #Emu.macros
check(call({ 1, 4 }, { 2, 0 }) == nil, "places center = cancel")
check(call() == nil, "release at step 1")
check(#Emu.macros == count, "nothing sent")

print("== 9. Direct keys")
wait(1.1)
open("SHIFT-TAB"); check(R2:IsShown() and not R1:IsShown(), "INC key opens the places")
moveTo(R2.nodes[5]); moveTo(R4.nodes[6]); release("SHIFT-TAB")
check(lastChat() == "INC: 5 enemies coming at OUR GRAVEYARD", lastChat())
wait(1.1)
open("CTRL-TAB"); release("CTRL-TAB")
check(lastChat() == "EFC: attack their flag carrier", "EFC key, release = their carrier")

print("== 10. Anti-spam: 1 s between calls")
wait(1.1)
check(call({ 1, 4 }, { 2, 5 }) == "DEF: defend OUR GRAVEYARD", lastChat())
reset()
check(call({ 1, 2 }, { 2, 5 }) == nil, "second call within 1 s is blocked")
drain()
check(log.call[#log.call][2] == "blocked", "result blocked")
wait(1.0)
check(call({ 1, 2 }, { 2, 5 }) == "ATTACK: attack THEIR GRAVEYARD", "after 1 s it goes")

print("== 11. Outside a BG: practice whisper (automatic)")
wait(1.1)
Emu.setBG(false)
check(call({ 1, 3 }, { 2, 1 }) == "CAP: our flag is home, cap now", lastChat())
check(lastMacro():match("^/w Elemente%-Venera CAP"), lastMacro())
Emu.setBG(true)

print("== 12. Every message fits a macro, every path has a view")
local tree = ns.BuildTree()
local total = 0
for path, msg in pairs(tree.msgs) do
  total = total + 1
  local ping = ns.PingLine(tree.pings[path], { enemyUnit = "arena1", friendUnit = "arena2" }) or ""
  check(#("/bg " .. msg .. "\n" .. ping) < 255, path)
  check(msg:match("^%u+: "), "abbreviation first: " .. msg)
end
for path, r in pairs(tree.nexts) do check(tree.views[path] and tree.views[path].ring == r, "view " .. path) end
print("  " .. total .. " messages")

print("== 13. Experimental: hover delay")
wait(1.1)
SlashCmdList.COMMANDANDCONQUER("exp on")
check(send:GetAttribute("dwell") == 0.1, "dwell on")
-- Flick across DEF to ATTACK in less than 0.1 s: only ATTACK counts.
open()
Emu.mouse(Emu.centerOf(R1.nodes[4])); Emu.tick(0.03)
check(not R2:IsShown(), "not picked yet")
Emu.mouse(Emu.centerOf(R1.nodes[2])); Emu.wait(0.15)
check(R2:IsShown() and send:GetAttribute("a") == 2, "ATTACK picked after the delay")
Emu.mouse(Emu.centerOf(R2.nodes[1])); Emu.wait(0.15)
release()
check(lastChat() == "ATTACK: attack THEIR FLAG ROOM", lastChat())
-- Released before the delay: the pending sector is not taken.
wait(1.1)
open(); Emu.mouse(Emu.centerOf(R1.nodes[4])); Emu.wait(0.15)
Emu.mouse(Emu.centerOf(R2.nodes[3])); Emu.tick(0.03)
release()
check(lastChat() == "ATTACK: attack THEIR FLAG ROOM", "pending pick dropped on release")

print("== 14. Experimental: Ignore my last call")
wait(1.1)
local function slowCall(...)
  local before = #Emu.macros
  open()
  for _, step in ipairs({ ... }) do
    local ring = W.rings[step[1]]
    Emu.mouse(Emu.centerOf(step[2] == 0 and ring.center or ring.nodes[step[2]]))
    Emu.wait(0.15)
  end
  release()
  if #Emu.macros > before then return lastChat() end
end
check(slowCall({ 1, 4 }, { 2, 6 }) == "DEF: defend OUR TUNNEL", lastChat())
wait(0.5)
check(slowCall() == "Ignore my last call", "tap within 3 s")
wait(0.5)
check(slowCall() == nil, "only once")
wait(1.1)
check(slowCall({ 1, 4 }, { 2, 6 }) == "DEF: defend OUR TUNNEL", lastChat())
wait(3.1)
check(slowCall() == nil, "after 3 s a tap sends nothing")
wait(1.1)
check(slowCall({ 1, 4 }, { 2, 6 }, { 4, 5 }) == nil, "CANCEL is not a tap")
SlashCmdList.COMMANDANDCONQUER("exp hover")
SlashCmdList.COMMANDANDCONQUER("exp undo")
check(send:GetAttribute("dwell") == nil and not send:GetAttribute("exp-undo"), "features off")

print("== 15. Experimental: carriers")
wait(1.1)
SlashCmdList.COMMANDANDCONQUER("carrier enemy arena1")
SlashCmdList.COMMANDANDCONQUER("carrier friend arena2")
reset()
check(call({ 1, 1 }, { 2, 6 }) == "EFC: their flag carrier is at OUR TUNNEL", lastChat())
check(lastPing() == "attack@target", "no carrier unit: falls back to the target")
Emu.units.arena1 = { name = "Zug", friendly = false }
Emu.units.arena2 = { name = "Ally", friendly = true }
wait(1.1)
check(call({ 1, 1 }) == "EFC: attack their flag carrier", lastChat())
check(lastPing() == "attack@arena1", tostring(lastPing()))
drain()
check(log.mark[#log.mark] and log.mark[#log.mark][2] == "8" and log.mark[#log.mark][4] == "Zug", "skull on their carrier")
wait(1.1)
check(call({ 1, 3 }) == "FC: escort our carrier", lastChat())
check(lastPing() == "assist@arena2", tostring(lastPing()))
-- You carry: UnitIsUnit is not in the restricted environment, so nothing
-- changes, unless Forever has it (hypothesis switch of the web page).
Emu.units.arena2 = Emu.units.player
wait(1.1)
check(call({ 1, 3 }) == "FC: escort our carrier", "no UnitIsUnit in secure code")
Emu.secureExtras.UnitIsUnit = UnitIsUnit
wait(1.1)
check(call({ 1, 3 }, { 2, 3 }) == "FC: I have their flag, escort me, THEIR RAMP", lastChat())
check(lastPing() == "assist@player", tostring(lastPing()))
Emu.secureExtras.UnitIsUnit = nil
SlashCmdList.COMMANDANDCONQUER("exp off")
SlashCmdList.COMMANDANDCONQUER("carrier clear")
Emu.units.arena1, Emu.units.arena2 = nil, nil

print("== 16. In combat: nothing blocked, everything works")
wait(1.1)
reset()
Emu.setCombat(true)
check(call({ 1, 5 }, { 2, 1 }, { 4, 3 }) == "INC: 2 enemies coming at OUR FLAG ROOM", lastChat())
wait(1.1)
check(call({ 1, 1 }, { 2, 2 }, { 3, 1 }) == "EFC: their flag carrier is at THEIR ROOF", lastChat())
SlashCmdList.COMMANDANDCONQUER("scale 1.5")
drain()
check(#log.blocked == 0, "blocked action in combat: " .. tostring(log.blocked[1] and log.blocked[1][2]))
Emu.setCombat(false)

print("== 17. /cnc scale keeps the wheel under the cursor")
SlashCmdList.COMMANDANDCONQUER("scale 1.4"); check(CnCDB.scale == 1.4, "scale")
SlashCmdList.COMMANDANDCONQUER("scale 9"); check(CnCDB.scale == 1.4, "bad scale refused")
wait(1.1)
check(call({ 1, 4 }, { 2, 2 }) == "DEF: defend OUR ROOF", "scaled wheel works")
SlashCmdList.COMMANDANDCONQUER("scale 1")

print("== 18. Aim highlight follows the cursor angle, empty sectors ignored")
open()
local ox, oy = Emu.centerOf(R1)
Emu.mouse(ox + 50, oy + 40); frameStep() -- ~51 degrees, before the icon: ATTACK (top right)
check(W.aim == 2, "aim " .. tostring(W.aim))
Emu.mouse(ox, oy + 20); frameStep()
check(W.aim == 0, "hollow center")
release()

print("== 19. Situations of the training page all resolve")
local situations = read(ROOT .. "/web/situations.txt")
local nsit = 0
for line in (situations .. "\n"):gmatch("([^\r\n]*)\r?\n") do
  if line:match("%S") and not line:match("^%s*#") then
    local fields = {}
    for field in (line .. "|"):gmatch("([^|]*)|") do fields[#fields + 1] = field:match("^%s*(.-)%s*$") end
    local path, err = ns.PathFromKeys(tree, fields[4] or "")
    check(path, "situation " .. tostring(fields[1]) .. ": " .. tostring(err))
    nsit = nsit + 1
  end
end
check(nsit >= 10, "situations")
print("  " .. nsit .. " situations")

print("== 20. Report")
local lines = CnCDB.report.lines
local joined = table.concat(lines, "\n")
check(joined:find("%[selftest%] secure timers OK"), "self-test noted")
check(joined:find("UnitIsUnit=false"), "secure env noted")
check(joined:find("%[call%] BG sent"), "calls noted")
check(CnCDB.report.stats.blocked == 1, "blocked count")

print("== 21. Debug mode does not break anything")
SlashCmdList.COMMANDANDCONQUER("debug")
wait(1.1)
check(call({ 1, 3 }, { 2, 1 }) == "CAP: our flag is home, cap now", lastChat())
SlashCmdList.COMMANDANDCONQUER("debug")

print("== 22. The next ring stays on screen")
wait(1.1)
reset()
-- Open near the top: DEF, then the flag room (top sector) would open the
-- count ring partly above the screen; it is shifted down to stay whole.
Emu.mouse(Emu.W / 2, Emu.H - 150)
open()
moveTo(R1.nodes[4])
moveTo(R2.nodes[1])
check(send:GetAttribute("step") == 4, "count ring open")
local es = R4:GetEffectiveScale()
local cx, cy = Emu.centerOf(R4)
local reach = (W.RINGS[4].outer + 12) * es
check(cy + reach <= Emu.H + 0.01, "count ring inside the top edge: " .. (cy + reach) .. " <= " .. Emu.H)
local nx, ny = Emu.centerOf(R2.nodes[1])
check(math.abs(cy - ny) > 1, "count ring shifted from the picked sector")
check(send:GetAttribute("path") == "4-1", "nothing picked by the shift: " .. tostring(send:GetAttribute("path")))
moveTo(R4.center)
release()
check(lastChat() == "DEF: defend OUR FLAG ROOM", lastChat())
-- Very close to the top: the shifted count ring opens with its top sector
-- under the cursor. It is not picked until the cursor leaves it.
wait(1.1)
reset()
Emu.mouse(Emu.W / 2, Emu.H - 110)
open()
moveTo(R1.nodes[4])
moveTo(R2.nodes[1])
frameStep()
check(send:GetAttribute("step") == 4, "count ring open")
local tx, ty = Emu.centerOf(R4.nodes[1])
local hx, hy = Emu.cursorX, Emu.cursorY
local half = W.RINGS[4].hit / 2 * R4:GetEffectiveScale()
check(math.abs(hx - tx) <= half and math.abs(hy - ty) <= half, "cursor on the top sector of the shifted ring")
check(send:GetAttribute("path") == "4-1", "guarded sector not picked: " .. tostring(send:GetAttribute("path")))
moveTo(R4.center)
moveTo(R4.nodes[1])
check(send:GetAttribute("path") == "4-1-1", "picked after a real move: " .. tostring(send:GetAttribute("path")))
release()
check(lastChat() == "DEF: everyone defend OUR FLAG ROOM", lastChat())
-- Away from the edges, the next ring opens right on the picked sector.
wait(1.1)
Emu.mouse(Emu.W / 2, Emu.H / 2)
open()
moveTo(R1.nodes[4])
local ax, ay = Emu.centerOf(R1.nodes[4])
local bx, by = Emu.centerOf(R2)
check(math.abs(ax - bx) < 0.01 and math.abs(ay - by) < 0.01, "ring 2 on the picked sector")
release()
reset()

print("ALL OK, " .. passed .. " checks, " .. #Emu.macros .. " macros sent (" .. _VERSION .. ")")

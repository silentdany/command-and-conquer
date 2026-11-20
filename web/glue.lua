-- Glue between the training page (app.js) and the emulated game.
-- Loads the WoW emulation and the add-on's real files (TOC order), then
-- exposes a few CNC_* functions to JavaScript. Nothing about the wheel is
-- written here: what the page shows and sends is the add-on's own code.

local read = CNC_READ

local function run(path)
  return assert(load(read(path), "@" .. path))()
end

Emu = run("lua/tools/sim/wowemu.lua")
Emu.bindings = {
  CNC_WHEEL = { "TAB", "SPACE" },
  CNC_EFC = { "1" }, CNC_ATTACK = { "2" }, CNC_FC = { "3" }, CNC_DEF = { "4" }, CNC_INC = { "5" },
}
Emu.units.target = nil

local ns = Emu.loadAddon("CommandAndConquer", "lua/CommandAndConquer", read)
Emu.watchCalls(ns)
local tree = ns.BuildTree()
CNC_NS = ns

-- Simulated carriers for the experimental carrier pings.
local CARRIERS = { enemy = "arena1", friend = "arena2" }
local state = { carry = false, carriers = false }

local function updateCarriers()
  if state.carriers then
    Emu.units.arena1 = { name = "Zugzug", friendly = false }
    Emu.units.arena2 = state.carry and Emu.units.player or { name = "Aldren", friendly = true }
  else
    Emu.units.arena1, Emu.units.arena2 = nil, nil
  end
end

function CNC_RESIZE(w, h) Emu.W, Emu.H = w, h end
function CNC_MOUSE(x, y) Emu.mouse(x, y) end
function CNC_KEY(key, down) return Emu.key(key, down) and true or false end
function CNC_TICK(dt) Emu.tick(dt) end
function CNC_DRAW() return Emu.draw() end
function CNC_OUTPUT() return Emu.takeOutput() end
function CNC_VERSION() return ns.VERSION end

-- Typed slash command ("/cnc status").
function CNC_SLASH(text)
  local cmd, rest = text:match("^%s*/(%S+)%s*(.-)%s*$")
  if cmd == "cnc" then
    SlashCmdList.COMMANDANDCONQUER(rest)
    return true
  end
  return false
end

-- Sandbox switches. Experimental switches go through the add-on's own
-- saved settings and option code (ns.ApplyOptions), as /cnc does.
function CNC_SET(name, value)
  if name == "target" then
    if value == "enemy" then
      Emu.units.target = { name = "Gruk", friendly = false }
    elseif value == "friend" then
      Emu.units.target = { name = "Bjorn", friendly = true }
    else
      Emu.units.target = nil
    end
  elseif name == "combat" then
    Emu.setCombat(value == "on")
  elseif name == "bg" then
    Emu.setBG(value == "on")
  elseif name == "exp" or name == "hover" or name == "undo" then
    local key = (name == "exp") and "on" or name
    CnCDB.exp[key] = (value == "on")
    if not ns.ApplyOptions() then return false end
  elseif name == "carriers" then
    state.carriers = (value == "on")
    CnCDB.exp.carrier = state.carriers
    CnCDB.carriers = state.carriers and { enemy = CARRIERS.enemy, friend = CARRIERS.friend } or {}
    updateCarriers()
    if not ns.ApplyOptions() then return false end
  elseif name == "carry" then
    state.carry = (value == "on")
    updateCarriers()
  elseif name == "unitisunit" then
    Emu.secureExtras.UnitIsUnit = (value == "on") and UnitIsUnit or nil
  end
  return true
end

-- Path of a call given as wheel keys, or "!" and the reason.
function CNC_PATH(keys)
  local path, err = ns.PathFromKeys(tree, keys)
  return path or ("!" .. tostring(err))
end

function CNC_MESSAGE(path) return tree.msgs[path] or "" end

-- "5-6-4" -> "INC > TUN > 3" (the keys shown on the wheel).
function CNC_KEYS(path)
  local keys, base = {}, ""
  for idx in path:gmatch("%d+") do
    local view = tree.views[base]
    local node = view and view.nodes[tonumber(idx)]
    keys[#keys + 1] = node and node.key or "?"
    base = (base == "") and idx or (base .. "-" .. idx)
  end
  return table.concat(keys, " > ")
end

-- Advances the clock until the login self-test is done.
Emu.wait(0.5)

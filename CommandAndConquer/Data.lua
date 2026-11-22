-- Wheel content, v0.8 (redesign validated by Dany on 19/11/2026).
--
-- Everything turns around the two flag carriers, plus very simple orders:
-- the target is pick-up groups, organised teams use Discord.
--
-- Sectors are numbered clockwise from the top.
--
-- Step 1, 5 sectors (pentagon, point up, no empty sector):
--   1 top EFC (their carrier, the most urgent), 2 top right ATTACK,
--   3 bottom right FC (our carrier), 4 bottom left DEF, 5 top left INC.
--   Attack on the right, defence on the left, urgency on top.
--
-- Step 2, places in a "pyramid" (Dany's view of the map), the same on
-- both sides: the colour says the side, never a word.
--   1 top flag room, 2 top right roof, 3 bottom right ramp,
--   4 bottom mid, 5 bottom left GY, 6 top left tunnel.
--   Blue = our side, red = their side. Mid has no side.
--
-- Optional steps (release = send what is picked so far):
--   side ring: one big sector on top = the same place on the other side,
--              CANCEL bottom left.
--   count ring: ALL top, 1 top right, 2 bottom right, 3 bottom, CANCEL
--               bottom left, 5 top left. For INC the top sector changes
--               side instead (see below).
--
-- Messages: short pro abbreviation in capitals first, then a plain English
-- sentence for newcomers, with side and place in capitals (19/11/2026):
--   "EFC: their flag carrier is at OUR RAMP", "DEF: 3 defend OUR FLAG ROOM".
--
-- This file is plain data plus pure functions: the add-on reads it, the
-- offline simulation and the training web page run the very same file.

local _, ns = ...

ns.VERSION = "0.8.7"
ns.CANCEL = "CANCEL"

-- Ring indices (see RINGS in Wheel.lua).
ns.RING_ACTIONS = 1
ns.RING_PLACES = 2
ns.RING_SIDE = 3
ns.RING_COUNT = 4
ns.RING_COUNT2 = 5 -- count ring opened after a side change (INC)

-- Sector used by CANCEL on each optional ring (always bottom left).
ns.CANCEL_SLOT = { [3] = 3, [4] = 5, [5] = 5 }

ns.OURS, ns.THEIRS, ns.NEUTRAL = "ours", "theirs", "neutral"

ns.PLACES = {
  { key = "FR", label = "FR", icon = "fr", name = "FLAG ROOM" },
  { key = "ROOF", label = "ROOF", icon = "roof", name = "ROOF" },
  { key = "RAMP", label = "RAMP", icon = "ramp", name = "RAMP" },
  { key = "MID", label = "MID", icon = "mid", name = "MID", neutral = true },
  { key = "GY", label = "GY", icon = "gy", name = "GRAVEYARD" },
  { key = "TUN", label = "TUN", icon = "tunnel", name = "TUNNEL" },
}

-- Count ring, by sector. key is also the label.
ns.COUNTS = {
  [1] = { key = "ALL", n = "all" },
  [2] = { key = "1", n = 1 },
  [3] = { key = "2", n = 2 },
  [4] = { key = "3", n = 3 },
  [6] = { key = "5", n = 5 },
}

-- Ping kinds, turned into "/ping" lines by ns.PingLine. Sent in the same
-- secure macro as the message ("/ping [@unit]" tested OK in a BG, 17/11).
--   enemy:  their carrier (experimental unit) or the target if hostile
--   friend: our carrier (experimental unit) or the target if friendly
--   me:     yourself (only when you are the carrier)
--   warn:   "warning" on the target if hostile
ns.PING_EFC = { kind = "attack", who = "enemy", carrier = true, mark = true }
ns.PING_ATTACK = { kind = "attack", who = "enemy" }
ns.PING_FC = { kind = "assist", who = "friend", carrier = true }
ns.PING_ME = { kind = "assist", who = "me" }
ns.PING_INC = { kind = "warning", who = "enemy" }

local function where(place, side)
  if place.neutral then return place.name end
  return (side == ns.OURS and "OUR " or "THEIR ") .. place.name
end

local function other(side)
  if side == ns.OURS then return ns.THEIRS end
  return ns.OURS
end

local function sideOf(place, side)
  if place.neutral then return ns.NEUTRAL end
  return side
end

-- Players asked for (DEF, ATTACK): "DEF: 3 defend OUR FLAG ROOM".
local function playersMessage(abbr, verb, count, at)
  if count.n == "all" then
    return abbr .. ": everyone " .. verb .. " " .. at
  end
  return abbr .. ": " .. count.n .. " " .. verb .. " " .. at
end

-- Enemies seen (INC): "INC: 3 enemies coming at OUR TUNNEL".
local function enemiesMessage(count, side, at)
  local verb = (side == ns.THEIRS) and " at " or " coming at "
  if not count then return "INC: enemies" .. verb .. at end
  if count.n == "all" then return "INC: all enemies" .. verb .. at end
  if count.n == 1 then return "INC: 1 enemy" .. verb .. at end
  return "INC: " .. count.n .. " enemies" .. verb .. at
end

ns.ACTIONS = {
  {
    key = "EFC", label = "EFC", icon = "efc", ping = ns.PING_EFC,
    side = ns.OURS,          -- blue first: that's where we can catch him
    optional = true,         -- release after step 1 = ping their carrier
    msg = "EFC: attack their flag carrier",
    places = { false, true, true, true, true, true }, -- no flag room
    placeMsg = function(at) return "EFC: their flag carrier is at " .. at end,
    flip = true,
  },
  {
    key = "ATTACK", label = "ATTACK", icon = "attack", ping = ns.PING_ATTACK,
    side = ns.THEIRS,
    placeMsg = function(at) return "ATTACK: attack " .. at end,
    countMsg = function(count, at) return playersMessage("ATTACK", "attack", count, at) end,
  },
  {
    key = "FC", label = "FC", icon = "flag", ping = ns.PING_FC,
    side = ns.THEIRS,        -- red first: he needs help to get out
    optional = true,         -- release after step 1 = ping our carrier
    msg = "FC: escort our carrier",
    meMsg = "FC: I have their flag, escort me",
    places = { false, true, true, true, true, true },
    -- CAP takes the flag room sector (top).
    special = { [1] = { key = "CAP", label = "CAP", icon = "cap", msg = "CAP: our flag is home, cap now" } },
    placeMsg = function(at) return "FC: escort our carrier, " .. at end,
    mePlaceMsg = function(at) return "FC: I have their flag, escort me, " .. at end,
    flip = true,
  },
  {
    key = "DEF", label = "DEF", icon = "def",
    side = ns.OURS,
    placeMsg = function(at) return "DEF: defend " .. at end,
    countMsg = function(count, at) return playersMessage("DEF", "defend", count, at) end,
  },
  {
    key = "INC", label = "INC", icon = "inc", ping = ns.PING_INC,
    side = ns.OURS,          -- quick alert at home; red = scouting their side
    placeMsg = function(at, side) return enemiesMessage(nil, side, at) end,
    countMsg = function(count, at, side) return enemiesMessage(count, side, at) end,
    flipInCounts = true,     -- the count ring's top sector changes side
  },
}

-- Binding name -> action index for the direct bindings (skip step 1).
ns.DIRECT = { CNC_EFC = 1, CNC_ATTACK = 2, CNC_FC = 3, CNC_DEF = 4, CNC_INC = 5 }

ns.UNDO_MSG = "Ignore my last call"

---------------------------------------------------------------------------
-- Tree
---------------------------------------------------------------------------

-- Builds every path of the wheel. A path is "a-b-c..." (sector indices).
--   msgs[path]   message sent when released there (nil: nothing sent)
--   nexts[path]  ring opened after picking path
--   pings[path]  ping spec (see ns.PingLine)
--   meMsgs[path] message when you carry their flag (experimental)
--   views[base]  what a ring shows when it opens after base:
--                { ring = r, center = node, nodes = { [i] = node } }
--                node = { key, label, icon, side, big, cancel }
--   paths[path]  { action = a, place = p, side = s, count = c, flipped }
function ns.BuildTree()
  local msgs, nexts, pings, meMsgs, views, paths = {}, {}, {}, {}, {}, {}

  local actionsView = { ring = ns.RING_ACTIONS, nodes = {} }
  views[""] = actionsView

  local function cancelNode()
    return { key = ns.CANCEL, label = ns.CANCEL, icon = "cancel", cancel = true }
  end

  local function placeNode(place, side, big)
    return { key = place.key, label = place.label, icon = place.icon, side = sideOf(place, side), big = big }
  end

  -- Count ring after path p (place picked on side), messages for each count.
  local function addCounts(p, ring, action, place, side, withFlip)
    local view = { ring = ring, nodes = {}, center = placeNode(place, side) }
    views[p] = view
    nexts[p] = ring
    view.nodes[ns.CANCEL_SLOT[ring]] = cancelNode()
    local at = where(place, side)
    for slot, count in pairs(ns.COUNTS) do
      if not (withFlip and slot == 1) then
        local path = p .. "-" .. slot
        view.nodes[slot] = { key = count.key, label = count.key, count = true }
        msgs[path] = action.countMsg(count, at, side)
        paths[path] = { action = paths[p].action, place = place.key, side = sideOf(place, side), count = count.key, flipped = paths[p].flipped }
      end
    end
  end

  for a, action in ipairs(ns.ACTIONS) do
    local ap = "" .. a
    actionsView.nodes[a] = { key = action.key, label = action.label, icon = action.icon }
    nexts[ap] = ns.RING_PLACES
    paths[ap] = { action = action.key }
    if action.optional then
      msgs[ap] = action.msg
      meMsgs[ap] = action.meMsg
    end

    local placesView = { ring = ns.RING_PLACES, nodes = {}, center = { key = action.key, icon = action.icon } }
    views[ap] = placesView

    for slot, place in ipairs(ns.PLACES) do
      local p = ap .. "-" .. slot
      local special = action.special and action.special[slot]
      if special then
        placesView.nodes[slot] = { key = special.key, label = special.label, icon = special.icon }
        msgs[p] = special.msg
        paths[p] = { action = action.key, place = special.key }
      elseif not action.places or action.places[slot] then
        local side = action.side
        local at = where(place, side)
        placesView.nodes[slot] = placeNode(place, side)
        msgs[p] = action.placeMsg(at, side)
        if action.mePlaceMsg then meMsgs[p] = action.mePlaceMsg(at) end
        paths[p] = { action = action.key, place = place.key, side = sideOf(place, side) }

        if action.flip and not place.neutral then
          -- Side ring: one big sector, the same place on the other side.
          local flipSide = other(side)
          local fp = p .. "-1"
          nexts[p] = ns.RING_SIDE
          views[p] = { ring = ns.RING_SIDE, center = placeNode(place, side),
            nodes = { [1] = placeNode(place, flipSide, true), [ns.CANCEL_SLOT[ns.RING_SIDE]] = cancelNode() } }
          views[p].nodes[1].key = "FLIP"
          msgs[fp] = action.placeMsg(where(place, flipSide), flipSide)
          if action.mePlaceMsg then meMsgs[fp] = action.mePlaceMsg(where(place, flipSide)) end
          paths[fp] = { action = action.key, place = place.key, side = flipSide, flipped = true }
        elseif action.countMsg then
          local withFlip = action.flipInCounts and not place.neutral
          addCounts(p, ns.RING_COUNT, action, place, side, withFlip)
          if withFlip then
            local flipSide = other(side)
            local fp = p .. "-1"
            local node = placeNode(place, flipSide)
            node.key = "FLIP"
            views[p].nodes[1] = node
            msgs[fp] = action.placeMsg(where(place, flipSide), flipSide)
            paths[fp] = { action = action.key, place = place.key, side = flipSide, flipped = true }
            addCounts(fp, ns.RING_COUNT2, action, place, flipSide, false)
          end
        end
      end
    end
  end

  -- Pings: the action's, except CAP (said by anyone, nobody to ping).
  for path in pairs(msgs) do
    local a = tonumber(path:match("^(%d+)"))
    local info = paths[path]
    if info.place ~= "CAP" then pings[path] = ns.ACTIONS[a].ping end
  end
  return { msgs = msgs, nexts = nexts, pings = pings, meMsgs = meMsgs, views = views, paths = paths }
end

-- "/ping" (and skull mark) lines for a ping spec. opts:
--   enemyUnit, friendUnit  carrier units (experimental, nil = unknown)
-- Macro conditions skip the line when no unit fits, and fall back from the
-- carrier unit to the target ("[@a] x; [@b] x").
function ns.PingLine(spec, opts)
  if not spec then return nil end
  opts = opts or {}
  if spec.who == "me" then
    return "/ping [@player] " .. spec.kind
  end
  local cond = (spec.who == "friend") and "help" or "harm"
  local target = "[@target," .. cond .. ",nodead] " .. spec.kind
  local unit = spec.carrier and ((spec.who == "friend") and opts.friendUnit or opts.enemyUnit)
  if not unit then
    return "/ping " .. target
  end
  local line = "/ping [@" .. unit .. ",exists,nodead] " .. spec.kind .. "; " .. target
  if spec.mark then
    line = line .. "\n/tm [@" .. unit .. ",exists,nodead] 8"
  end
  return line
end

-- Path from wheel keys, for situations and tests:
-- ns.PathFromKeys(tree, "INC > RAMP > FLIP > 3") -> "5-3-1-4"
function ns.PathFromKeys(tree, text)
  local base, path = "", nil
  for token in text:gmatch("[^>%s]+") do
    local view = tree.views[base]
    if not view then return nil, "nothing to pick after " .. tostring(path) end
    local found
    for i, node in pairs(view.nodes) do
      if node.key == token:upper() and not node.cancel then found = i end
    end
    if not found then return nil, "no \"" .. token .. "\" on that ring" end
    path = (base == "") and ("" .. found) or (base .. "-" .. found)
    base = path
  end
  if not path or not tree.msgs[path] then return nil, "this path sends nothing" end
  return path
end

ns.MEDIA = "Interface\\AddOns\\CommandAndConquer\\Media\\"

function ns.IconPath(name)
  return ns.MEDIA .. "icons\\" .. name
end

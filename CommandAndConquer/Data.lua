-- Wheel content. Based on docs/mapping-roue-v3.md (validated 17/11/2026),
-- cut to 6 options per wheel (Dany, 17/11/2026: bigger sectors, less mess).
-- All text is English for now (decision 17/11/2026). Messages are plain
-- English with no WSG jargon (EFC, EFR, GY, zerg, peel...): Dany, 17/11/2026.
-- Short jargon stays only in the wheel labels.
--
-- Every wheel has 6 sectors, clockwise from the top:
--   1 = top, 2 = top right, 3 = bottom right, 4 = bottom, 5 = bottom left, 6 = top left
--
-- Step 1: actions. INC stays top left (most used), SCOUT bottom left.
-- Step 2: a place keeps the same direction in every action, so the hand
-- learns the gesture:
--   top = flag room, top right = roof, bottom right = ramp,
--   bottom = tunnel, bottom left = GY side, top left = mid
-- Non-place options take the slot of the least useful place for that action.
-- Steps after 2 are optional (Dany, 17/11/2026): releasing in the middle
-- sends what is picked so far.
--   EFC ramp / tunnel / GY: side (THEIRS top, OURS bottom), then escorts.
--   INC, SCOUT, EFC: number of enemies, clockwise from the top.
--
-- icon = file in Media/icons (game-icons.net, see CREDITS.md).
-- enemy = true draws the icon red: a place on their side.
-- counts = labels of the optional count ring for this action. Every
-- optional ring has a CANCEL sector bottom left (sector 5 of 6, 3 of 3):
-- the right click could not be made to work, Dany needs a way out.

local _, ns = ...

ns.CANCEL = "CANCEL"
ns.COUNT_RING = 3
ns.SIDE_RING = 4
local CANCEL = ns.CANCEL

-- Optional ping sent with the call, through the same secure macro
-- ("/ping" with a unit, tested OK in a battleground on 17/11/2026). Macro
-- conditions skip the ping when there is no fitting target.
local PING_ENEMY_ATTACK = "/ping [@target,harm,nodead] attack"
local PING_ENEMY_WARNING = "/ping [@target,harm,nodead] warning"
local PING_FRIEND_ASSIST = "/ping [@target,help,nodead] assist"
-- Only for "I have their flag": the caller is the carrier. Other FLAG
-- calls can come from anyone, and macro conditions cannot tell who holds
-- the flag, so they never ping yourself (bug seen in game, 17/11/2026).
local PING_ME_ASSIST = "/ping [@player] assist"

ns.ACTIONS = {
  {
    key = "DEF", label = "DEF", icon = "def",
    choices = {
      { label = "FR", icon = "flag", msg = "Defend our flag room" },
      { label = "ROOF", icon = "roof", msg = "Defend our roof" },
      { label = "RAMP", icon = "ramp", msg = "Defend our ramp" },
      { label = "TUN", icon = "tunnel", msg = "Defend our tunnel" },
      { label = "GY", icon = "gy", msg = "Guard our graveyard entrance" },
      { label = "ESCORT", icon = "escort", msg = "Protect our flag carrier", ping = PING_FRIEND_ASSIST },
    },
  },
  {
    key = "FLAG", label = "FLAG", icon = "flag",
    choices = {
      { label = "GOT IT", icon = "flag", msg = "I have their flag, escort me", ping = PING_ME_ASSIST },
      { label = "HELP", icon = "help", msg = "Our flag carrier needs help", ping = PING_FRIEND_ASSIST },
      { label = "RAMP", icon = "ramp", msg = "Our flag carrier going ramp" },
      { label = "TUN", icon = "tunnel", msg = "Our flag carrier going tunnel" },
      -- TAKE replaced the carrier's graveyard route (least used), 18/11/2026.
      { label = "TAKE", icon = "take", msg = "Take their flag" },
      { label = "CAP!", icon = "cap", msg = "Our flag is home, cap now" },
    },
  },
  {
    key = "EFC", label = "EFC", icon = "efc", ping = PING_ENEMY_ATTACK,
    counts = { "ALONE", "1", "2", "3", CANCEL, "4+" }, -- escorts (17/11/2026)
    choices = {
      { label = "EFR", icon = "flag", enemy = true, msg = "Enemy carrier in their flag room" },
      { label = "E-ROOF", icon = "roof", enemy = true, msg = "Enemy carrier on their roof" },
      -- The carrier leaves our base and enters theirs: these three ask the side.
      { label = "RAMP", icon = "ramp", msg = "Enemy carrier at the ramp",
        ours = "Enemy carrier at our ramp", theirs = "Enemy carrier on their ramp" },
      { label = "TUN", icon = "tunnel", msg = "Enemy carrier at the tunnel",
        ours = "Enemy carrier at our tunnel", theirs = "Enemy carrier entering their tunnel" },
      { label = "GY", icon = "gy", msg = "Enemy carrier at the graveyard side",
        ours = "Enemy carrier at our graveyard side", theirs = "Enemy carrier at their graveyard side" },
      { label = "MID", icon = "mid", msg = "Enemy carrier at mid" },
    },
  },
  {
    key = "ATTACK", label = "ATTACK", icon = "attack", ping = PING_ENEMY_ATTACK,
    choices = {
      { label = "EFR", icon = "flag", enemy = true, msg = "Attack their flag room" },
      { label = "ROOF", icon = "roof", enemy = true, msg = "Attack their roof" },
      { label = "RAMP", icon = "ramp", enemy = true, msg = "Attack through their ramp" },
      { label = "TUN", icon = "tunnel", enemy = true, msg = "Attack through their tunnel" },
      { label = "ZERG", icon = "zerg", msg = "Everyone attack their base" },
      { label = "MID", icon = "mid", msg = "Take control of mid" },
    },
  },
  {
    key = "SCOUT", label = "SCOUT", icon = "scout", ping = PING_ENEMY_WARNING,
    counts = { "CLEAR", "1", "2", "3", CANCEL, "4+" },
    -- Their side as seen by a scout (added 17/11/2026).
    choices = {
      { label = "EFR", icon = "flag", enemy = true, where = "in their flag room", place = "Their flag room" },
      { label = "E-ROOF", icon = "roof", enemy = true, where = "on their roof", place = "Their roof" },
      { label = "E-RAMP", icon = "ramp", enemy = true, where = "at their ramp", place = "Their ramp" },
      { label = "E-TUN", icon = "tunnel", enemy = true, where = "in their tunnel", place = "Their tunnel" },
      { label = "E-GY", icon = "gy", enemy = true, where = "at their graveyard side", place = "Their graveyard side" },
      { label = "MID", icon = "mid", where = "at mid", place = "Mid" },
    },
  },
  {
    key = "INC", label = "INC", icon = "inc", ping = PING_ENEMY_WARNING,
    counts = { "1", "2", "3", "4", CANCEL, "5+" },
    choices = {
      { label = "FR", icon = "flag", msg = "Incoming in our flag room" },
      { label = "ROOF", icon = "roof", msg = "Incoming on our roof" },
      { label = "RAMP", icon = "ramp", msg = "Incoming at our ramp" },
      { label = "TUN", icon = "tunnel", msg = "Incoming at our tunnel" },
      { label = "GY", icon = "gy", msg = "Incoming at our graveyard side" },
      { label = "MID", icon = "mid", msg = "Incoming at mid" },
    },
  },
}

-- Scout choices: message without a number.
for _, choice in ipairs(ns.ACTIONS[5].choices) do
  choice.msg = "Enemies " .. choice.where
end

-- Binding name -> action index for the direct bindings (skip step 1).
ns.DIRECT = { CNC_DEF = 1, CNC_FLAG = 2, CNC_EFC = 3, CNC_ATTACK = 4, CNC_SCOUT = 5, CNC_INC = 6 }

-- Side ring, clockwise from the top: their base is "up", ours "down".
ns.SIDES = { "THEIRS", "OURS", CANCEL }

-- Messages for each count of a choice, in count ring order. base is the
-- message picked so far (with the side for EFC).
--   INC:   "Incoming at our tunnel" + "3" -> "3 incoming at our tunnel"
--   SCOUT: "3 enemies in their flag room", "1 enemy ...", "Their flag room is clear"
--   EFC:   "Enemy carrier at our ramp with 3 escorts", "..., alone"
function ns.CountMessages(action, choice, base)
  local list = {}
  for k, count in ipairs(action.counts) do
    if count == CANCEL then
      -- no message: the cancel sector
    elseif action.key == "EFC" then
      if count == "ALONE" then
        list[k] = base .. ", alone"
      elseif count == "1" then
        list[k] = base .. " with 1 escort"
      else
        list[k] = base .. " with " .. count .. " escorts"
      end
    elseif action.key == "SCOUT" then
      if count == "CLEAR" then
        list[k] = choice.place .. " is clear"
      elseif count == "1" then
        list[k] = "1 enemy " .. choice.where
      else
        list[k] = count .. " enemies " .. choice.where
      end
    else
      list[k] = count .. " " .. base:gsub("^Incoming", "incoming")
    end
  end
  return list
end

-- Every message by path ("action-choice[-side][-count]", 1-based indices),
-- the optional ring to open after a path, and the ping line for a path
-- (choice ping, else action ping). Read by Wheel.lua.
function ns.BuildTree()
  local msgs, nexts, pings = {}, {}, {}
  for a, action in ipairs(ns.ACTIONS) do
    for c, choice in ipairs(action.choices) do
      local path = a .. "-" .. c
      msgs[path] = choice.msg
      local countable = { [path] = choice.msg }
      if choice.ours then
        nexts[path] = ns.SIDE_RING
        countable = {}
        for side, name in ipairs(ns.SIDES) do
          if name ~= CANCEL then
            local sidePath = path .. "-" .. side
            local msg = (name == "OURS") and choice.ours or choice.theirs
            msgs[sidePath] = msg
            countable[sidePath] = msg
          end
        end
      end
      if action.counts then
        for p, base in pairs(countable) do
          nexts[p] = ns.COUNT_RING
          for k, msg in pairs(ns.CountMessages(action, choice, base)) do
            msgs[p .. "-" .. k] = msg
          end
        end
      end
    end
  end
  for path in pairs(msgs) do
    local a, c = path:match("^(%d+)-(%d+)")
    local action = ns.ACTIONS[tonumber(a)]
    pings[path] = action.choices[tonumber(c)].ping or action.ping
  end
  return msgs, nexts, pings
end

ns.MEDIA = "Interface\\AddOns\\CommandAndConquer\\Media\\"

function ns.IconPath(name)
  return ns.MEDIA .. "icons\\" .. name
end

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
-- countRing = which secure ring shows the counts (3: 5 sectors, 4: 6 sectors);
-- counts = the labels on that ring for this action.

local _, ns = ...

ns.ACTIONS = {
  {
    key = "DEF", label = "DEF", icon = "def",
    choices = {
      { label = "FR", icon = "flag", msg = "Defend our flag room" },
      { label = "ROOF", icon = "roof", msg = "Defend our roof" },
      { label = "RAMP", icon = "ramp", msg = "Defend our ramp" },
      { label = "TUN", icon = "tunnel", msg = "Defend our tunnel" },
      { label = "GY", icon = "gy", msg = "Guard our graveyard entrance" },
      { label = "ESCORT", icon = "escort", msg = "Protect our flag carrier" },
    },
  },
  {
    key = "FLAG", label = "FLAG", icon = "flag",
    choices = {
      { label = "GOT IT", icon = "flag", msg = "I have their flag, escort me" },
      { label = "HELP", icon = "help", msg = "Our flag carrier needs help" },
      { label = "RAMP", icon = "ramp", msg = "Our flag carrier going ramp" },
      { label = "TUN", icon = "tunnel", msg = "Our flag carrier going tunnel" },
      { label = "GY", icon = "gy", msg = "Our flag carrier going graveyard side" },
      { label = "CAP!", icon = "cap", msg = "Our flag is home, cap now" },
    },
  },
  {
    key = "EFC", label = "EFC", icon = "efc",
    countRing = 4, counts = { "ALONE", "1", "2", "3", "4", "5+" }, -- escorts (17/11/2026)
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
    key = "ATTACK", label = "ATTACK", icon = "attack",
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
    key = "SCOUT", label = "SCOUT", icon = "scout",
    countRing = 4, counts = { "CLEAR", "1", "2", "3", "4", "5+" },
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
    key = "INC", label = "INC", icon = "inc",
    countRing = 3, counts = { "1", "2", "3", "4", "5+" },
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
ns.SIDES = { "THEIRS", "OURS" }

-- Messages for each count of a choice, in count ring order. base is the
-- message picked so far (with the side for EFC).
--   INC:   "Incoming at our tunnel" + "3" -> "3 incoming at our tunnel"
--   SCOUT: "3 enemies in their flag room", "1 enemy ...", "Their flag room is clear"
--   EFC:   "Enemy carrier at our ramp with 3 escorts", "..., alone"
function ns.CountMessages(action, choice, base)
  local list = {}
  for k, count in ipairs(action.counts) do
    if action.key == "EFC" then
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

-- Every message by path ("action-choice[-side][-count]", 1-based indices)
-- and the optional ring to open after a path. Read by Wheel.lua.
function ns.BuildTree()
  local msgs, nexts = {}, {}
  for a, action in ipairs(ns.ACTIONS) do
    for c, choice in ipairs(action.choices) do
      local path = a .. "-" .. c
      msgs[path] = choice.msg
      local countable = { [path] = choice.msg }
      if choice.ours then
        nexts[path] = 5
        countable = {}
        for side, name in ipairs(ns.SIDES) do
          local sidePath = path .. "-" .. side
          local msg = (name == "OURS") and choice.ours or choice.theirs
          msgs[sidePath] = msg
          countable[sidePath] = msg
        end
      end
      if action.countRing then
        for p, base in pairs(countable) do
          nexts[p] = action.countRing
          for k, msg in ipairs(ns.CountMessages(action, choice, base)) do
            msgs[p .. "-" .. k] = msg
          end
        end
      end
    end
  end
  return msgs, nexts
end

ns.MEDIA = "Interface\\AddOns\\CommandAndConquer\\Media\\"

function ns.IconPath(name)
  return ns.MEDIA .. "icons\\" .. name
end

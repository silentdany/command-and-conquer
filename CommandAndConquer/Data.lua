-- Wheel content, from docs/mapping-roue-v3.md (validated 17/11/2026).
-- All text is English for now (decision 17/11/2026).
--
-- Step 1: 5 actions, clockwise from the top.
-- Step 2: 8 choices on a compass, clockwise from the top:
--   1 = N, 2 = NE, 3 = E, 4 = SE, 5 = S, 6 = SW, 7 = W, 8 = NW
-- A place keeps the same direction in every action, so the hand learns
-- the gesture: flag room N, roof NE, ramp E, tunnel S, GY side W,
-- balcony NW, mid east SE, mid west SW.
-- Step 3 (INC only): number of enemies, clockwise from the top.
--
-- icon = file in Media/icons (game-icons.net, see CREDITS.md).
-- enemy = true draws the icon red: a place on their side.

local _, ns = ...

ns.ACTIONS = {
  {
    key = "DEF", label = "DEF", icon = "def",
    choices = {
      { label = "FR", icon = "flag", msg = "Defend our flag room" },
      { label = "ROOF", icon = "roof", msg = "Defend our roof" },
      { label = "RAMP", icon = "ramp", msg = "Defend our ramp" },
      { label = "ESCORT", icon = "escort", msg = "Protect our flag carrier" },
      { label = "TUN", icon = "tunnel", msg = "Defend our tunnel" },
      { label = "TURTLE", icon = "turtle", msg = "Everyone defend our base (turtle)" },
      { label = "LOBBY", icon = "lobby", msg = "Guard our GY side entrance" },
      { label = "BALC", icon = "balcony", msg = "Defend our balcony" },
    },
  },
  {
    key = "FLAG", label = "FLAG", icon = "flag",
    choices = {
      { label = "GOT IT", icon = "flag", msg = "I have their flag, escort me" },
      { label = "HELP", icon = "help", msg = "Our flag carrier needs help (peel)" },
      { label = "RAMP", icon = "ramp", msg = "Our flag carrier going ramp" },
      { label = "CAP!", icon = "cap", msg = "Our flag is home, cap now" },
      { label = "TUN", icon = "tunnel", msg = "Our flag carrier going tunnel" },
      { label = "STUCK", icon = "stuck", msg = "Can't cap, get our flag back" },
      { label = "GY", icon = "gy", msg = "Our flag carrier going GY side" },
      { label = "PICK UP", icon = "pickup", msg = "Their flag dropped, pick it up" },
    },
  },
  {
    key = "EFC", label = "EFC", icon = "efc",
    choices = {
      { label = "EFR", icon = "flag", enemy = true, msg = "Enemy carrier in their flag room" },
      { label = "E-ROOF", icon = "roof", enemy = true, msg = "Enemy carrier on their roof" },
      { label = "RAMP", icon = "ramp", msg = "Enemy carrier at our ramp" },
      { label = "MID E", icon = "mid", msg = "Enemy carrier mid east" },
      { label = "TUN", icon = "tunnel", msg = "Enemy carrier at our tunnel (EFC)" },
      { label = "MID W", icon = "mid", msg = "Enemy carrier mid west" },
      { label = "GY", icon = "gy", msg = "Enemy carrier at our GY side" },
      { label = "DROPPED", icon = "dropped", msg = "Our flag dropped, click to return" },
    },
  },
  {
    key = "ATTACK", label = "ATTACK", icon = "attack",
    choices = {
      { label = "EFR", icon = "flag", enemy = true, msg = "Attack their flag room (EFR)" },
      { label = "ROOF", icon = "roof", enemy = true, msg = "Attack their roof" },
      { label = "RAMP", icon = "ramp", enemy = true, msg = "Attack through their ramp" },
      { label = "MID", icon = "mid", msg = "Take control of mid" },
      { label = "TUN", icon = "tunnel", enemy = true, msg = "Attack through their tunnel" },
      { label = "ZERG", icon = "zerg", msg = "Everyone attack their base (zerg)" },
      { label = "BANANA", icon = "banana", enemy = true, msg = "Group up at their banana" },
      { label = "BALC", icon = "balcony", enemy = true, msg = "Attack their balcony" },
    },
  },
  {
    key = "INC", label = "INC", icon = "inc",
    count = true,
    choices = {
      { label = "BANANA", icon = "banana", msg = "Incoming up our banana" },
      { label = "ROOF", icon = "roof", msg = "Incoming on our roof" },
      { label = "RAMP", icon = "ramp", msg = "Incoming at our ramp" },
      { label = "MID E", icon = "mid", msg = "Incoming mid east" },
      { label = "TUN", icon = "tunnel", msg = "Incoming at our tunnel" },
      { label = "MID W", icon = "mid", msg = "Incoming mid west" },
      { label = "GY", icon = "gy", msg = "Incoming at our GY side" },
      { label = "BALC", icon = "balcony", msg = "Incoming from our balcony" },
    },
  },
}

ns.COUNTS = { "1", "2", "3", "4", "5+" }

-- Binding name -> action index for the direct bindings (skip step 1).
ns.DIRECT = { CNC_DEF = 1, CNC_FLAG = 2, CNC_EFC = 3, CNC_ATTACK = 4, CNC_INC = 5 }

-- "Incoming at our tunnel" + "3" -> "3 incoming at our tunnel"
function ns.CountMessage(msg, count)
  return count .. " " .. msg:gsub("^Incoming", "incoming")
end

ns.MEDIA = "Interface\\AddOns\\CommandAndConquer\\Media\\"

function ns.IconPath(name)
  return ns.MEDIA .. "icons\\" .. name
end

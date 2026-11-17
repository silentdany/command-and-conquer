-- Wheel content, from docs/mapping-roue-v3.md (validated 17/11/2026).
--
-- Step 1: 5 actions, clockwise from the top.
-- Step 2: 8 choices on a compass, clockwise from the top:
--   1 = N, 2 = NE, 3 = E, 4 = SE, 5 = S, 6 = SW, 7 = W, 8 = NW
-- A place keeps the same direction in every action, so the hand learns
-- the gesture: flag room N, roof NE, ramp E, tunnel S, GY side W,
-- balcony NW, mid east SE, mid west SW.
-- All text is English for now (decision 17/11/2026).
-- Step 3 (INC only): number of enemies, clockwise from the top.

local _, ns = ...

ns.ACTIONS = {
  {
    key = "DEF", label = "DEF", icon = "Interface\\Icons\\INV_Shield_06",
    choices = {
      { label = "FR", msg = "Defend our flag room" },
      { label = "Roof", msg = "Defend our roof" },
      { label = "Ramp", msg = "Defend our ramp" },
      { label = "Escort", msg = "Protect our flag carrier" },
      { label = "Tunnel", msg = "Defend our tunnel" },
      { label = "Turtle", msg = "Everyone defend our base (turtle)" },
      { label = "Lobby", msg = "Guard our GY side entrance" },
      { label = "Balcony", msg = "Defend our balcony" },
    },
  },
  {
    key = "FLAG", label = "FLAG", icon = "THEIR_FLAG",
    choices = {
      { label = "Got it", msg = "I have their flag, escort me" },
      { label = "Help", msg = "Our flag carrier needs help (peel)" },
      { label = "Ramp", msg = "Our flag carrier going ramp" },
      { label = "Cap!", msg = "Our flag is home, cap now" },
      { label = "Tunnel", msg = "Our flag carrier going tunnel" },
      { label = "Stuck", msg = "Can't cap, get our flag back" },
      { label = "GY side", msg = "Our flag carrier going GY side" },
      { label = "Pick up", msg = "Their flag dropped, pick it up" },
    },
  },
  {
    key = "EFC", label = "EFC", icon = "OUR_FLAG",
    choices = {
      { label = "EFR", msg = "Enemy carrier in their flag room" },
      { label = "Their roof", msg = "Enemy carrier on their roof" },
      { label = "Ramp", msg = "Enemy carrier at our ramp" },
      { label = "Mid E", msg = "Enemy carrier mid east" },
      { label = "Tunnel", msg = "Enemy carrier at our tunnel (EFC)" },
      { label = "Mid W", msg = "Enemy carrier mid west" },
      { label = "GY side", msg = "Enemy carrier at our GY side" },
      { label = "Dropped", msg = "Our flag dropped, click to return" },
    },
  },
  {
    key = "ATTACK", label = "ATTACK", icon = "Interface\\Icons\\INV_Sword_04",
    choices = {
      { label = "EFR", msg = "Attack their flag room (EFR)" },
      { label = "Roof", msg = "Attack their roof" },
      { label = "Ramp", msg = "Attack through their ramp" },
      { label = "Mid", msg = "Take control of mid" },
      { label = "Tunnel", msg = "Attack through their tunnel" },
      { label = "Zerg", msg = "Everyone attack their base (zerg)" },
      { label = "Banana", msg = "Group up at their banana" },
      { label = "Balcony", msg = "Attack their balcony" },
    },
  },
  {
    key = "INC", label = "INC", icon = "Interface\\Icons\\Ability_Warrior_Charge",
    count = true,
    choices = {
      { label = "Banana", msg = "Incoming up our banana" },
      { label = "Roof", msg = "Incoming on our roof" },
      { label = "Ramp", msg = "Incoming at our ramp" },
      { label = "Mid E", msg = "Incoming mid east" },
      { label = "Tunnel", msg = "Incoming at our tunnel" },
      { label = "Mid W", msg = "Incoming mid west" },
      { label = "GY side", msg = "Incoming at our GY side" },
      { label = "Balcony", msg = "Incoming from our balcony" },
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

-- Flag icons depend on the player's faction.
local ALLIANCE_FLAG = "Interface\\Icons\\INV_BannerPVP_02"
local HORDE_FLAG = "Interface\\Icons\\INV_BannerPVP_01"

function ns.ResolveIcon(icon)
  local faction = UnitFactionGroup("player")
  if icon == "OUR_FLAG" then
    return faction == "Horde" and HORDE_FLAG or ALLIANCE_FLAG
  elseif icon == "THEIR_FLAG" then
    return faction == "Horde" and ALLIANCE_FLAG or HORDE_FLAG
  end
  return icon
end

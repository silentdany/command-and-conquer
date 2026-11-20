-- Test report, written to the SavedVariables (CnCDB.report) at logout or
-- /reload. tools/update-cnc.bat copies it to the clipboard so Dany can
-- paste it to Claude. No in-game window: Forever's chat is too small to
-- copy from (decision 18/11/2026).
--
-- It notes what worked or was blocked: self-test of the secure timers,
-- functions seen by secure code, experimental features used, calls sent,
-- blocked actions.

local ADDON_NAME, ns = ...

local R = {}
ns.Report = R

local MAX_LINES = 400

local function stamp()
  return date and date("%H:%M:%S") or "--:--:--"
end

function R:Start()
  CnCDB.report = CnCDB.report or {}
  local rep = CnCDB.report
  rep.lines = rep.lines or {}
  rep.stats = {}
  local version, build, _, interface = "?", "?", nil, "?"
  if GetBuildInfo then version, build, _, interface = GetBuildInfo() end
  self:Add("session", "Command & Conquer %s, client %s build %s, interface %s, %s",
    ns.VERSION, tostring(version), tostring(build), tostring(interface), date and date("%Y-%m-%d") or "?")
end

function R:Add(tag, fmt, ...)
  if not CnCDB or not CnCDB.report then return end
  local text = select("#", ...) > 0 and fmt:format(...) or fmt
  local lines = CnCDB.report.lines
  lines[#lines + 1] = stamp() .. " [" .. tag .. "] " .. text
  while #lines > MAX_LINES do table.remove(lines, 1) end
  ns.Debug("report: [%s] %s", tag, text)
end

function R:Count(key)
  if not CnCDB or not CnCDB.report then return end
  local stats = CnCDB.report.stats
  stats[key] = (stats[key] or 0) + 1
end

-- One line per state of the session, for a quick read.
function R:Summary()
  local stats = (CnCDB.report and CnCDB.report.stats) or {}
  local parts = {}
  for k, v in pairs(stats) do parts[#parts + 1] = k .. "=" .. v end
  table.sort(parts)
  return table.concat(parts, ", ")
end

function R:Clear()
  CnCDB.report = { lines = {}, stats = {} }
end

-- Blocked actions are the most useful thing to know on Forever.
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(_, event, addon, what)
  if event == "PLAYER_LOGOUT" then
    R:Add("session", "end, stats: %s", R:Summary())
    return
  end
  if addon == ADDON_NAME then
    R:Add("blocked", "%s: %s", event, tostring(what))
    R:Count("blocked-action")
  end
end)

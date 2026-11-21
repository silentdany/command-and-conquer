-- The wheel.
--
-- Forever blocks SendChatMessage from add-on code in battlegrounds, but a
-- secure action button running a "/bg ..." macro on a player key press
-- works. So the whole gesture runs in Blizzard's restricted (secure)
-- environment, and the message leaves on key release:
--
--   key down   -> secure snippet opens the wheel under the cursor
--   mouse move -> reaching the icon of a sector (secure OnEnter on a small
--                 hit frame) picks action, place, side, count
--   key up     -> secure snippet writes the macro text, the button runs it
--
-- Add-on (insecure) code only draws: it mirrors the secure state through
-- the button's "state" attribute and never decides what is sent.
--
-- Timed features (anti-spam 1 s, experimental hover delay and "Ignore my
-- last call") use RegisterAutoHide on tiny secure frames: a frame the mouse
-- is not over hides itself after the given time, from Blizzard's code,
-- which is allowed in combat. A self-test at login checks it works on
-- Forever; if not, those features stay off (fallback = v0.7 behaviour).

local _, ns = ...

local W = {}
ns.Wheel = W

local BUTTON_NAME = "CnCWheelButton"

-- outer = wheel radius. Icons sit in the middle of the sector band. The
-- secure hit frame is only the icon area: the cursor must reach the icon
-- to pick a sector. Centers are dead zones: on the places ring it cancels
-- (or sends the action alone for EFC and FC), on optional rings it means
-- "send without this step".
local RINGS = {
  { n = 5, outer = 160, icon = 46, hit = 58 },                          -- 1 actions (pentagon)
  { n = 6, outer = 165, icon = 44, hit = 56, center = true },           -- 2 places
  { n = 3, outer = 150, icon = 58, hit = 74, center = true, cancel = 3 }, -- 3 side: one big sector + CANCEL
  { n = 6, outer = 150, icon = 40, hit = 52, center = true, cancel = 5 }, -- 4 counts
  { n = 6, outer = 150, icon = 40, hit = 52, center = true, cancel = 5 }, -- 5 counts after a side change
}
W.RINGS = RINGS
local INNER_RATIO = 0.32 -- inner radius / outer radius, baked in the textures
local TEX_RATIO = 0.96   -- wheel diameter / texture size, baked in the textures
local ICON_RATIO = 0.66  -- icon distance from the center / outer radius

local COLOR_IDLE = { 0.07, 0.065, 0.06, 0.78 }
local COLOR_AIM = { 0.20, 0.19, 0.18, 0.80 }
local COLOR_PENDING = { 0.36, 0.35, 0.33, 0.75 }
local COLOR_HOT = { 0.60, 0.59, 0.56, 0.50 }
local COLOR_CANCEL_HOT = { 0.70, 0.12, 0.10, 0.70 }
local COLOR_LABEL = { 0.93, 0.93, 0.93, 1 }
local COLOR_WHITE = { 1, 1, 1, 1 }
-- Sides: blue = ours, red = theirs (never a word for the side).
local COLOR_SIDE = {
  ours = { 0.32, 0.63, 1.00, 1 },
  theirs = { 0.90, 0.22, 0.20, 1 },
  neutral = COLOR_WHITE,
}
local COLOR_CANCEL = COLOR_SIDE.theirs
W.COLOR_SIDE = COLOR_SIDE

---------------------------------------------------------------------------
-- Secure snippets (run in the restricted environment)
---------------------------------------------------------------------------

-- State on the wheel button (all attributes):
--   step        ring currently shown
--   path        what is picked so far, "a-b-..." (indices); msg = m<path>
--   base        path when the current ring opened
--   selN        picked sector on ring N (for drawing), a = picked action
--   next-<path> ring to open after picking <path> (from Data.lua)
--   result      outcome of the last release: none, sent, sent-me, undo, blocked
-- Options (set out of combat): prefix, pings, spam, dwell, exp-undo,
-- exp-me, fc-unit, undo-msg.

-- Pre-click on the wheel button. `button` is "LeftButton" for the main
-- binding, or an action key ("INC", ...) for the direct bindings.
local ON_CLICK = [[
  local root = owner:GetFrameRef("root")
  local screen = owner:GetFrameRef("screen")

  if down then
    if root:IsShown() then
      -- Second press while open (lost key-up): close without sending.
      root:Hide()
      self:SetAttribute("msg", "")
      self:SetAttribute("result", "none")
      self:SetAttribute("state", "closed")
      return false
    end
    local preset = self:GetAttribute("preset-" .. button)
    local first = preset and 2 or 1
    -- The wheel opens under the cursor, shifted in from the screen's edges
    -- just enough to stay whole on screen.
    local x, y = screen:GetMousePosition()
    local sw, sh = screen:GetWidth(), screen:GetHeight()
    local px, py, cx, cy
    root:ClearAllPoints()
    if x and y then
      px, py = x * sw, y * sh
      cx, cy = px, py
      local ring = owner:GetFrameRef("r" .. first)
      local k = ring:GetEffectiveScale() / screen:GetEffectiveScale()
      local r = ((self:GetAttribute("outer-" .. first) or 0) + 12) * k
      if sw > 2 * r then cx = max(r, min(sw - r, px)) else cx = sw / 2 end
      if sh > 2 * r then cy = max(r, min(sh - r, py)) else cy = sh / 2 end
      root:SetPoint("CENTER", screen, "BOTTOMLEFT", cx, cy)
    else
      root:SetPoint("CENTER", screen, "CENTER")
    end
    self:SetAttribute("guard", nil)
    self:SetAttribute("fit", "")
    local rings = self:GetAttribute("rings")
    for i = 2, rings do
      owner:GetFrameRef("r" .. i):Hide()
      self:SetAttribute("sel" .. i, 0)
    end
    self:SetAttribute("pending-ring", nil)
    self:SetAttribute("pending-idx", nil)
    local r1 = owner:GetFrameRef("r1")
    if preset then
      local base = "" .. preset
      self:SetAttribute("a", preset)
      self:SetAttribute("step", 2)
      self:SetAttribute("base", base)
      self:SetAttribute("path", base)
      self:SetAttribute("msg", self:GetAttribute("m" .. base) or "")
      r1:Hide()
      local r2 = owner:GetFrameRef("r2")
      r2:ClearAllPoints()
      r2:SetPoint("CENTER", root, "CENTER")
      r2:Show()
    else
      self:SetAttribute("a", 0)
      self:SetAttribute("step", 1)
      self:SetAttribute("base", "")
      self:SetAttribute("path", "")
      self:SetAttribute("msg", "")
      r1:ClearAllPoints()
      r1:SetPoint("CENTER", root, "CENTER")
      r1:Show()
    end
    root:Show()
    -- Shifted, the wheel can open with a sector under the cursor: that
    -- sector is not picked until the cursor has left it.
    if px and (cx ~= px or cy ~= py) then
      self:SetAttribute("fit", format("r%d:%d,%d", first, floor(cx - px + 0.5), floor(cy - py + 0.5)))
      local k = screen:GetEffectiveScale()
      for i = 1, self:GetAttribute("n-" .. first) or 0 do
        local node = owner:GetFrameRef("n" .. first .. "-" .. i)
        local l2, b2, w2, h2 = node:GetRect()
        local k2 = node:GetEffectiveScale() / k
        if l2 and px >= l2 * k2 and px <= (l2 + w2) * k2 and py >= b2 * k2 and py <= (b2 + h2) * k2 then
          self:SetAttribute("guard", first .. "-" .. i)
        end
      end
    end
    self:SetAttribute("state", "open")
    return false
  end

  if not root:IsShown() then
    return false
  end
  root:Hide()
  self:SetAttribute("pending-ring", nil)
  self:SetAttribute("pending-idx", nil)
  local path = self:GetAttribute("path") or ""
  local msg = self:GetAttribute("msg") or ""
  local result = "none"
  local ping
  if msg == "" then
    -- Nothing picked at all, shortly after a call: "Ignore my last call".
    local recent = owner:GetFrameRef("recent")
    if path == "" and self:GetAttribute("exp-undo") and recent:IsShown() then
      recent:Hide()
      msg = self:GetAttribute("undo-msg")
      result = "undo"
    end
  elseif self:GetAttribute("spam") and owner:GetFrameRef("spam"):IsShown() then
    result = "blocked"
  else
    result = "sent"
    ping = self:GetAttribute("p" .. path)
    -- Experimental: our carrier is you. UnitIsUnit is not in Blizzard's
    -- restricted environment (checked 20/11/2026), so this only works if
    -- Forever adds it; the self-test reports it.
    local unit = self:GetAttribute("fc-unit")
    if self:GetAttribute("exp-me") and unit and UnitIsUnit and UnitExists and UnitExists(unit)
        and UnitIsUnit(unit, "player") then
      local alt = self:GetAttribute("m!" .. path)
      if alt then
        msg = alt
        ping = self:GetAttribute("p!" .. path)
        result = "sent-me"
      end
    end
  end
  self:SetAttribute("msg", msg)
  self:SetAttribute("result", result)
  self:SetAttribute("state", "closed")
  if result == "none" or result == "blocked" then
    return false
  end
  local text = self:GetAttribute("prefix") .. " " .. msg
  if ping and self:GetAttribute("pings") then
    text = text .. "\n" .. ping
  end
  self:SetAttribute("macrotext", text)
  if self:GetAttribute("spam") then
    local t = owner:GetFrameRef("spam")
    t:Show()
    t:RegisterAutoHide(1)
  end
  if result ~= "undo" and self:GetAttribute("exp-undo") then
    local t = owner:GetFrameRef("recent")
    t:Show()
    t:RegisterAutoHide(3)
  end
]]

-- Picks sector idx of ring (idx 0 = center). Runs on the header (self),
-- from a node's OnEnter, or after the hover delay.
local PICK = [[
  local ring, idx = ...
  local send = self:GetFrameRef("send")
  if ring ~= send:GetAttribute("step") then
    return
  end
  local node = self:GetFrameRef("n" .. ring .. "-" .. idx)
  local base = send:GetAttribute("base")
  if node:GetAttribute("cancel") then
    -- CANCEL sector of an optional ring: nothing is sent unless the
    -- cursor moves on to another sector.
    send:SetAttribute("path", base)
    send:SetAttribute("sel" .. ring, idx)
    send:SetAttribute("msg", "")
  elseif idx == 0 then
    send:SetAttribute("path", base)
    send:SetAttribute("sel" .. ring, 0)
    send:SetAttribute("msg", send:GetAttribute("m" .. base) or "")
  else
    local path
    if base == "" then
      path = "" .. idx
    else
      path = base .. "-" .. idx
    end
    local msg = send:GetAttribute("m" .. path)
    local nextRing = send:GetAttribute("next-" .. path)
    if not msg and not nextRing then
      return -- empty sector
    end
    if ring == 1 then
      send:SetAttribute("a", idx)
    end
    send:SetAttribute("path", path)
    send:SetAttribute("sel" .. ring, idx)
    send:SetAttribute("msg", msg or "")
    if nextRing then
      send:SetAttribute("step", nextRing)
      send:SetAttribute("base", path)
      send:SetAttribute("sel" .. nextRing, 0)
      self:GetFrameRef("r" .. ring):Hide()
      local rn = self:GetFrameRef("r" .. nextRing)
      rn:ClearAllPoints()
      -- The next ring opens on the picked sector, shifted in from the
      -- screen's edges just enough to stay whole on screen.
      local dx, dy = 0, 0
      local screen = self:GetFrameRef("screen")
      local l, b, w, h = node:GetRect()
      local _, _, sw, sh = screen:GetRect()
      if l and sw then
        local k = node:GetEffectiveScale() / screen:GetEffectiveScale()
        local r = ((send:GetAttribute("outer-" .. nextRing) or 0) + 12) * k
        local cx, cy = (l + w / 2) * k, (b + h / 2) * k
        local tx, ty = cx, cy
        if sw > 2 * r then tx = max(r, min(sw - r, cx)) else tx = sw / 2 end
        if sh > 2 * r then ty = max(r, min(sh - r, cy)) else ty = sh / 2 end
        dx, dy = (tx - cx) / k, (ty - cy) / k
        if dx ~= 0 or dy ~= 0 then
          send:SetAttribute("fit", (send:GetAttribute("fit") or "") .. format(" r%d:%d,%d", nextRing, floor(tx - cx + 0.5), floor(ty - cy + 0.5)))
        end
      else
        send:SetAttribute("fit", (send:GetAttribute("fit") or "") .. format(" r%d:norect", nextRing))
      end
      rn:SetPoint("CENTER", node, "CENTER", dx, dy)
      rn:Show()
      -- Shifted, the ring can open with a sector under the cursor: that
      -- sector is not picked until the cursor has left it.
      send:SetAttribute("guard", nil)
      if dx ~= 0 or dy ~= 0 then
        local mx, my = screen:GetMousePosition()
        if mx and my then
          mx, my = mx * sw, my * sh
          local k = node:GetEffectiveScale() / screen:GetEffectiveScale()
          for i = 1, send:GetAttribute("n-" .. nextRing) or 0 do
            local l2, b2, w2, h2 = self:GetFrameRef("n" .. nextRing .. "-" .. i):GetRect()
            if l2 and mx >= l2 * k and mx <= (l2 + w2) * k and my >= b2 * k and my <= (b2 + h2) * k then
              send:SetAttribute("guard", nextRing .. "-" .. i)
            end
          end
        end
      end
    end
  end
  send:SetAttribute("state", send:GetAttribute("step") .. ":" .. send:GetAttribute("path"))
]]

-- Mouse reaches a node. With the hover delay (experimental), the pick
-- waits until the dwell frame hides itself, and is dropped if the mouse
-- leaves the node first.
local ON_ENTER = [[
  local send = owner:GetFrameRef("send")
  local ring = self:GetAttribute("ring")
  if ring ~= send:GetAttribute("step") then
    return
  end
  local idx = self:GetAttribute("idx")
  if send:GetAttribute("guard") == ring .. "-" .. idx then
    return -- under the cursor when its ring opened shifted: wait for a real move
  end
  local dwell = send:GetAttribute("dwell")
  if dwell then
    local timer = owner:GetFrameRef("dwell")
    send:SetAttribute("pending-ring", nil)
    timer:Hide()
    send:SetAttribute("pending-ring", ring)
    send:SetAttribute("pending-idx", idx)
    send:SetAttribute("state", "pending:" .. ring .. ":" .. idx)
    timer:Show()
    timer:RegisterAutoHide(dwell)
    return
  end
  owner:RunAttribute("pick", ring, idx)
]]

local ON_LEAVE = [[
  local send = owner:GetFrameRef("send")
  if send:GetAttribute("guard") == self:GetAttribute("ring") .. "-" .. self:GetAttribute("idx") then
    send:SetAttribute("guard", nil)
  end
  if send:GetAttribute("pending-ring") == self:GetAttribute("ring")
      and send:GetAttribute("pending-idx") == self:GetAttribute("idx") then
    send:SetAttribute("pending-ring", nil)
    send:SetAttribute("pending-idx", nil)
    send:SetAttribute("state", send:GetAttribute("step") .. ":" .. send:GetAttribute("path"))
  end
]]

-- The dwell frame hid itself: the mouse stayed on the node long enough.
local ON_DWELL_HIDE = [[
  local send = owner:GetFrameRef("send")
  local ring, idx = send:GetAttribute("pending-ring"), send:GetAttribute("pending-idx")
  send:SetAttribute("pending-ring", nil)
  send:SetAttribute("pending-idx", nil)
  if ring and owner:GetFrameRef("root"):IsShown() then
    owner:RunAttribute("pick", ring, idx)
  end
]]

-- Login self-test, out of combat (SecureHandlerExecute on the header).
local SELF_TEST = [[
  local probe = self:GetFrameRef("probe")
  probe:Show()
  probe:RegisterAutoHide(0.3)
  local send = self:GetFrameRef("send")
  send:SetAttribute("env-UnitIsUnit", UnitIsUnit and true or false)
  send:SetAttribute("env-UnitExists", UnitExists and true or false)
]]

W.ON_CLICK, W.ON_ENTER, W.PICK = ON_CLICK, ON_ENTER, PICK

---------------------------------------------------------------------------
-- Frames (built once, out of combat)
---------------------------------------------------------------------------

local function setColor(region, c)
  region:SetVertexColor(c[1], c[2], c[3], c[4])
end

-- Rotate a square texture around its center, counter-clockwise.
local function rotate(tex, angle)
  if tex.SetRotation then
    tex:SetRotation(angle)
    return
  end
  local c, s = math.cos(angle), math.sin(angle)
  local function uv(x, y)
    return 0.5 + x * c + y * s, 0.5 - (-x * s + y * c)
  end
  local ulx, uly = uv(-0.5, 0.5)
  local llx, lly = uv(-0.5, -0.5)
  local urx, ury = uv(0.5, 0.5)
  local lrx, lry = uv(0.5, -0.5)
  tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

local function makeText(parent, size)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(STANDARD_TEXT_FONT, size, "")
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 0.9)
  setColor(fs, COLOR_LABEL)
  return fs
end

-- Secure hit frame at the icon position, with the icon and label on it.
local function makeNode(parent, ringIndex, idx, spec)
  local f = CreateFrame("Frame", nil, parent, "SecureFrameTemplate")
  f:SetSize(spec.hit, spec.hit)
  if f.SetMouseMotionEnabled and f.SetMouseClickEnabled then
    f:SetMouseMotionEnabled(true)
    f:SetMouseClickEnabled(false) -- clicks go through to the game
  else
    f:EnableMouse(true)
  end
  f:SetAttribute("ring", ringIndex)
  f:SetAttribute("idx", idx)
  f:SetScript("OnEnter", function() end)
  f:SetScript("OnLeave", function() end)

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetPoint("CENTER")
  f.icon:SetSize(spec.icon, spec.icon)

  f.label = makeText(f, 12)
  f.label:SetPoint("TOP", f, "BOTTOM", 0, 1)

  f.big = makeText(f, 24) -- numbers on the count rings
  f.big:SetPoint("CENTER")
  return f
end

local function makeRing(root, ringIndex)
  local spec = RINGS[ringIndex]
  local ring = CreateFrame("Frame", nil, root, "SecureFrameTemplate")
  ring:SetSize(1, 1)
  ring:SetPoint("CENTER", root, "CENTER")
  ring:Hide()

  local side = 2 * spec.outer / TEX_RATIO
  local tex = ns.MEDIA .. "sector" .. spec.n
  ring.fills, ring.borders, ring.nodes = {}, {}, {}
  for i = 1, spec.n do
    local angle = -math.rad((i - 1) * 360 / spec.n) -- clockwise from the top
    local fill = ring:CreateTexture(nil, "BACKGROUND")
    fill:SetTexture(tex .. "_fill")
    fill:SetSize(side, side)
    fill:SetPoint("CENTER")
    rotate(fill, angle)
    setColor(fill, COLOR_IDLE)
    ring.fills[i] = fill

    local border = ring:CreateTexture(nil, "BORDER")
    border:SetTexture(tex .. "_border")
    border:SetSize(side, side)
    border:SetPoint("CENTER")
    rotate(border, angle)
    ring.borders[i] = border

    local bearing = math.rad((i - 1) * 360 / spec.n)
    local r = spec.outer * ICON_RATIO
    local node = makeNode(ring, ringIndex, i, spec)
    if i == spec.cancel then node:SetAttribute("cancel", true) end
    node:SetPoint("CENTER", ring, "CENTER", math.sin(bearing) * r, math.cos(bearing) * r)
    ring.nodes[i] = node
  end

  if spec.center then
    local inner = spec.outer * INNER_RATIO
    local disc = ring:CreateTexture(nil, "BORDER", nil, 1)
    disc:SetTexture(ns.MEDIA .. "center")
    disc:SetSize(2 * inner / 0.94, 2 * inner / 0.94)
    disc:SetPoint("CENTER")
    local center = makeNode(ring, ringIndex, 0, { hit = inner * 1.5, icon = 36 })
    center:SetPoint("CENTER", ring, "CENTER")
    ring.center = center
  end
  return ring
end

-- Tiny secure frame used as a timer (RegisterAutoHide), off screen.
local function makeTimer(name)
  local t = CreateFrame("Frame", name, UIParent, "SecureFrameTemplate")
  t:SetSize(1, 1)
  t:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
  t:Hide()
  return t
end

function W:Build()
  if self.built then return end

  local header = CreateFrame("Frame", "CnCWheelHeader", UIParent, "SecureHandlerBaseTemplate")

  local screen = CreateFrame("Frame", "CnCWheelScreen", UIParent, "SecureFrameTemplate")
  screen:SetAllPoints(UIParent)

  local root = CreateFrame("Frame", "CnCWheelRoot", UIParent, "SecureFrameTemplate")
  root:SetSize(1, 1)
  root:SetFrameStrata("FULLSCREEN_DIALOG")
  root:SetPoint("CENTER")
  root:Hide()

  local send = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
  send:SetSize(1, 1)
  send:SetPoint("TOPLEFT")
  send:RegisterForClicks("AnyUp", "AnyDown")
  send:SetAttribute("type", "macro")
  send:SetAttribute("useOnKeyDown", false) -- the macro runs on key release
  send:SetAttribute("prefix", "/bg")
  send:SetAttribute("undo-msg", ns.UNDO_MSG)
  send:Hide()

  local timers = {
    spam = makeTimer("CnCTimerSpam"),
    recent = makeTimer("CnCTimerRecent"),
    dwell = makeTimer("CnCTimerDwell"),
    probe = makeTimer("CnCTimerProbe"),
  }

  local rings = {}
  for r = 1, #RINGS do rings[r] = makeRing(root, r) end
  send:SetAttribute("rings", #RINGS)
  for r = 1, #RINGS do
    send:SetAttribute("outer-" .. r, RINGS[r].outer)
    send:SetAttribute("n-" .. r, RINGS[r].n)
  end

  -- Message table, as attributes the secure snippets can read.
  for a, action in ipairs(ns.ACTIONS) do
    send:SetAttribute("preset-" .. action.key, a)
  end
  local tree = ns.BuildTree()
  for path, msg in pairs(tree.msgs) do send:SetAttribute("m" .. path, msg) end
  for path, msg in pairs(tree.meMsgs) do send:SetAttribute("m!" .. path, msg) end
  for path, ring in pairs(tree.nexts) do send:SetAttribute("next-" .. path, ring) end
  send:SetAttribute("pings", true)

  header:SetFrameRef("send", send)
  header:SetFrameRef("root", root)
  header:SetFrameRef("screen", screen)
  for name, t in pairs(timers) do header:SetFrameRef(name, t) end
  for r = 1, #rings do header:SetFrameRef("r" .. r, rings[r]) end
  header:SetAttribute("pick", PICK)

  header:WrapScript(send, "OnClick", ON_CLICK)
  header:WrapScript(timers.dwell, "OnHide", ON_DWELL_HIDE)

  for r, ring in ipairs(rings) do
    local nodes = { [0] = ring.center }
    for i, node in ipairs(ring.nodes) do nodes[i] = node end
    for i, node in pairs(nodes) do
      header:SetFrameRef("n" .. r .. "-" .. i, node)
      header:WrapScript(node, "OnEnter", ON_ENTER)
      header:WrapScript(node, "OnLeave", ON_LEAVE)
    end
  end

  -- Cancel sectors: red cross, always bottom left of an optional ring.
  for r = 3, #rings do
    local node = rings[r].nodes[RINGS[r].cancel]
    node.icon:SetSize(34, 34)
  end

  -- Lights the sector the cursor points at, before it reaches the icon.
  -- Plain frame inside the root: shown only while the wheel is open.
  local aim = CreateFrame("Frame", nil, root)
  aim:SetSize(1, 1)
  aim:SetScript("OnUpdate", function() W:UpdateAim() end)

  -- What will be sent, above the active ring. Plain (insecure) frame so
  -- add-on code can move it in combat.
  local preview = CreateFrame("Frame", nil, UIParent)
  preview:SetSize(1, 1)
  preview:SetFrameStrata("FULLSCREEN_DIALOG")
  preview.text = makeText(preview, 14)
  preview.text:SetPoint("BOTTOM")
  preview.text:SetTextColor(1, 0.85, 0.3, 1)
  preview:Hide()

  -- Short confirmation after a send, where the wheel was.
  local toast = CreateFrame("Frame", nil, UIParent)
  toast:SetSize(1, 1)
  toast:SetFrameStrata("FULLSCREEN_DIALOG")
  toast.text = makeText(toast, 15)
  toast.text:SetPoint("CENTER")
  toast:Hide()
  toast:SetScript("OnUpdate", function(f, elapsed)
    f.left = f.left - elapsed
    if f.left <= 0 then f:Hide() else f:SetAlpha(math.min(1, f.left / 0.5)) end
  end)

  -- Runs the login self-test.
  local tester = CreateFrame("Frame")

  send:HookScript("OnAttributeChanged", function(_, name)
    if name == "state" then W:Refresh() end
  end)

  self.header, self.screen, self.root, self.send = header, screen, root, send
  self.rings, self.preview, self.toast, self.timers = rings, preview, toast, timers
  self.tree, self.tester = tree, tester
  self:ApplyPings({})
  self.built = true
end

---------------------------------------------------------------------------
-- Options (out of combat only: attributes of secure frames)
---------------------------------------------------------------------------

-- Ping lines for every path. opts: enemyUnit, friendUnit (experimental).
function W:ApplyPings(opts)
  if InCombatLockdown() then return false end
  local send = self.send
  for path in pairs(self.tree.msgs) do
    send:SetAttribute("p" .. path, ns.PingLine(self.tree.pings[path], opts))
  end
  for path in pairs(self.tree.meMsgs) do
    send:SetAttribute("p!" .. path, ns.PingLine(ns.PING_ME, opts))
  end
  return true
end

-- o: spam, dwell (seconds or nil), undo, me, fcUnit.
function W:SetOptions(o)
  if InCombatLockdown() then return false end
  local send = self.send
  send:SetAttribute("spam", o.spam and true or nil)
  send:SetAttribute("dwell", o.dwell)
  send:SetAttribute("exp-undo", o.undo and true or nil)
  send:SetAttribute("exp-me", o.me and true or nil)
  send:SetAttribute("fc-unit", o.fcUnit)
  return true
end

-- done(ok, detail, env): timers work? env = functions seen by secure code.
function W:SelfTest(done)
  if InCombatLockdown() or not SecureHandlerExecute then
    done(false, "SecureHandlerExecute unavailable or in combat", {})
    return
  end
  local ok, err = pcall(SecureHandlerExecute, self.header, SELF_TEST)
  local env = {
    UnitIsUnit = self.send:GetAttribute("env-UnitIsUnit"),
    UnitExists = self.send:GetAttribute("env-UnitExists"),
  }
  if not ok then
    done(false, "self-test snippet failed: " .. tostring(err), env)
    return
  end
  local start = GetTime()
  local probe = self.timers.probe
  self.tester:SetScript("OnUpdate", function(f)
    local t = GetTime() - start
    local hidden = not probe:IsShown()
    if hidden or t > 2 then
      f:SetScript("OnUpdate", nil)
      done(hidden and t >= 0.2, ("probe hid after %.2f s"):format(t), env)
    end
  end)
end

---------------------------------------------------------------------------
-- Visual mirror of the secure state
---------------------------------------------------------------------------

function W:Paint()
  local send = self.send
  local step = send:GetAttribute("step") or 1
  local pendingRing = send:GetAttribute("pending-ring")
  local pendingIdx = send:GetAttribute("pending-idx")
  local ring, spec = self.rings[step], RINGS[step]
  local aim = self.aim or 0
  local selected = (step > 1) and (send:GetAttribute("sel" .. step) or 0) or 0
  for i, fill in ipairs(ring.fills) do
    if i == selected then
      setColor(fill, i == spec.cancel and COLOR_CANCEL_HOT or COLOR_HOT)
    elseif pendingRing == step and pendingIdx == i then
      setColor(fill, COLOR_PENDING)
    elseif i == aim then
      setColor(fill, COLOR_AIM)
    else
      setColor(fill, COLOR_IDLE)
    end
  end
end

function W:UpdateAim()
  local step = self.send:GetAttribute("step") or 1
  local ring, spec = self.rings[step], RINGS[step]
  local cx, cy = ring:GetCenter()
  if not cx then return end
  local scale = ring:GetEffectiveScale()
  local mx, my = GetCursorPosition()
  local dx, dy = mx / scale - cx, my / scale - cy
  local aim = 0
  local inner = spec.outer * INNER_RATIO
  if dx * dx + dy * dy > inner * inner then
    local bearing = math.deg(math.atan2(dx, dy)) % 360
    aim = math.floor((bearing + 180 / spec.n) / (360 / spec.n)) % spec.n + 1
    if not (ring.used and ring.used[aim]) then aim = 0 end
  end
  if aim ~= self.aim or step ~= self.aimStep then
    self.aim, self.aimStep = aim, step
    self:Paint()
  end
end

-- Draws one node from its view entry (nil = empty sector).
local function showNode(node, info, spec)
  node.big:SetText("")
  node.label:SetText("")
  if not info then
    node.icon:Hide()
    return
  end
  if info.icon then
    node.icon:SetTexture(ns.IconPath(info.icon))
    local size = info.cancel and 34 or spec.icon
    node.icon:SetSize(size, size)
    setColor(node.icon, info.cancel and COLOR_CANCEL or (COLOR_SIDE[info.side] or COLOR_WHITE))
    node.icon:Show()
  else
    node.icon:Hide()
  end
  if info.count then
    node.big:SetText(info.label)
    node.big:SetFont(STANDARD_TEXT_FONT, #info.label > 2 and 17 or 24, "")
  else
    node.label:SetText(info.label or "")
  end
end

-- Fills a ring for the view that opens after `base`.
function W:ShowView(r, base)
  local ring, spec = self.rings[r], RINGS[r]
  local view = self.tree.views[base]
  if not view then return end
  ring.used = {}
  for i, node in ipairs(ring.nodes) do
    local info = view.nodes[i]
    ring.used[i] = info and true or false
    if info then
      ring.fills[i]:Show()
      ring.borders[i]:Show()
    else
      ring.fills[i]:Hide()
      ring.borders[i]:Hide()
    end
    showNode(node, info, spec)
  end
  if ring.center then
    showNode(ring.center, view.center and { icon = view.center.icon, side = view.center.side } or nil, { icon = 36 })
  end
end

function W:ShowToast(msg, color)
  local x, y = self.root:GetCenter()
  self.toast:ClearAllPoints()
  self.toast:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x or 0, (y or 0) + 40)
  self.toast.text:SetText(msg)
  local c = color or { 1, 0.85, 0.3, 1 }
  self.toast.text:SetTextColor(c[1], c[2], c[3], c[4])
  self.toast.left = 1.8
  self.toast:SetAlpha(1)
  self.toast:Show()
  if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
    pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
  end
end

function W:Refresh()
  local send = self.send
  local state = send:GetAttribute("state")
  ns.Debug("state %s (step %s, path %s)", tostring(state), tostring(send:GetAttribute("step")),
    tostring(send:GetAttribute("path")))

  if state == "closed" then
    self.preview:Hide()
    self.shownBase = nil
    local result = send:GetAttribute("result")
    local msg = send:GetAttribute("msg")
    if result == "blocked" then
      self:ShowToast("Too fast: 1 s between calls", COLOR_SIDE.theirs)
    elseif result ~= "none" and msg and msg ~= "" then
      self:ShowToast(msg)
    end
    if self.restoreLook then
      self.restoreLook = nil
      if IsMouseButtonDown and IsMouseButtonDown("RightButton") then MouselookStart() end
    end
    if self.OnClosed then self.OnClosed(result, msg, send:GetAttribute("path")) end
    return
  end

  if state == "open" then
    self.aim, self.aimStep = 0, nil
    -- The cursor is hidden while the camera is held with right click:
    -- free it so the gesture can be read, give the camera back on close.
    if IsMouselooking and IsMouselooking() then
      MouselookStop()
      self.restoreLook = true
    end
  end

  local step = send:GetAttribute("step") or 1
  local base = send:GetAttribute("base") or ""
  if self.shownBase ~= base or self.shownStep ~= step then
    self.shownBase, self.shownStep = base, step
    self:ShowView(step, base)
    self.aim = 0
  end

  self:Paint()

  local ring, spec = self.rings[step], RINGS[step]
  local x, y = ring:GetCenter()
  local msg = send:GetAttribute("msg") or ""
  if x and msg ~= "" then
    -- Ring coordinates are in the ring's own scale (/cnc scale).
    local k = ring:GetEffectiveScale() / UIParent:GetEffectiveScale()
    self.preview:ClearAllPoints()
    self.preview:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * k, (y + spec.outer + 10) * k)
    self.preview.text:SetText(msg)
    self.preview:Show()
  else
    self.preview:Hide()
  end
end

-- Rings are anchored with zero offsets, so scaling them keeps the wheel
-- centered on the cursor. Out of combat only.
function W:SetScale(scale)
  if InCombatLockdown() then return false end
  for _, ring in ipairs(self.rings) do ring:SetScale(scale) end
  return true
end

function W:SetPings(on)
  if InCombatLockdown() then return false end
  self.send:SetAttribute("pings", on and true or nil)
  return true
end

function W:SetPrefix(prefix)
  if InCombatLockdown() then return false end
  self.send:SetAttribute("prefix", prefix)
  return true
end

W.BUTTON_NAME = BUTTON_NAME

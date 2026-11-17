-- The wheel.
--
-- Forever blocks SendChatMessage from add-on code in battlegrounds, but a
-- secure action button running a "/bg ..." macro on a player key press
-- works. So the whole gesture runs in Blizzard's restricted (secure)
-- environment, and the message leaves on key release:
--
--   key down   -> secure snippet opens the wheel under the cursor
--   mouse move -> reaching the icon of a sector (secure OnEnter on a small
--                 hit frame) picks action, choice, count
--   key up     -> secure snippet writes the macro text, the button runs it
--   right click -> one step back; a second right click in a row closes
--                 (a screen-wide right-button catcher shown with the wheel)
--
-- Add-on (insecure) code only draws: it mirrors the secure state through
-- the button's "state" attribute and never decides what is sent.
--
-- Look: pie sectors with a thin bronze border, white icons, small caps
-- labels, lighter sector under the cursor (Dany's mockups, 17/11/2026).

local _, ns = ...

local W = {}
ns.Wheel = W

local BUTTON_NAME = "CnCWheelButton"

-- outer = wheel radius. Icons sit in the middle of the sector band. The
-- secure hit frame is only the icon area: the cursor must reach the icon
-- to pick a sector (v0.2 still felt too sensitive). Centers are dead
-- zones: cancel (ring 2), "skip this optional step" (rings 3+).
-- 6 sectors max per wheel (Dany, 17/11/2026: bigger targets, less mess).
local RINGS = {
  { n = 6, outer = 160, icon = 46, hit = 58 },                -- actions
  { n = 6, outer = 165, icon = 44, hit = 56, center = true }, -- choices
  { n = 5, outer = 140, icon = 0, hit = 52, center = true },  -- INC count
  { n = 6, outer = 150, icon = 0, hit = 52, center = true },  -- SCOUT / EFC count
  { n = 2, outer = 120, icon = 0, hit = 60, center = true },  -- side: theirs (top), ours (bottom)
}
local INNER_RATIO = 0.32 -- inner radius / outer radius, baked in the textures
local TEX_RATIO = 0.96   -- wheel diameter / texture size, baked in the textures
local ICON_RATIO = 0.66  -- icon distance from the center / outer radius

local COLOR_IDLE = { 0.07, 0.065, 0.06, 0.78 }
local COLOR_AIM = { 0.20, 0.19, 0.18, 0.80 }
local COLOR_HOT = { 0.60, 0.59, 0.56, 0.50 }
local COLOR_ENEMY = { 0.86, 0.20, 0.18, 1 }
local COLOR_LABEL = { 0.93, 0.93, 0.93, 1 }

---------------------------------------------------------------------------
-- Secure snippets (run in the restricted environment)
---------------------------------------------------------------------------

-- State on the wheel button (all attributes):
--   step       ring currently shown (1 actions, 2 choices, 3+ optional steps)
--   path       what is picked so far, "a-c-..." (indices); msg = m<path>
--   base       path when the current ring opened
--   prevN      ring that opened ring N; prevbaseN its base (for going back)
--   selN       picked sector on ring N (for drawing), a = picked action
--   next-<path> ring to open after picking <path> (set from Data.lua)
-- Steps after 2 are optional: releasing sends what is picked so far.

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
      self:SetAttribute("state", "closed")
      return false
    end
    local x, y = screen:GetMousePosition()
    root:ClearAllPoints()
    if x and y then
      root:SetPoint("CENTER", screen, "BOTTOMLEFT", x * screen:GetWidth(), y * screen:GetHeight())
    else
      root:SetPoint("CENTER", screen, "CENTER")
    end
    local rings = self:GetAttribute("rings")
    for i = 2, rings do
      owner:GetFrameRef("r" .. i):Hide()
      self:SetAttribute("sel" .. i, 0)
    end
    self:SetAttribute("msg", "")
    self:SetAttribute("backs", 0)
    local r1 = owner:GetFrameRef("r1")
    r1:ClearAllPoints()
    r1:SetPoint("CENTER", root, "CENTER")
    local preset = self:GetAttribute("preset-" .. button)
    if preset then
      self:SetAttribute("a", preset)
      self:SetAttribute("step", 2)
      self:SetAttribute("base", "" .. preset)
      self:SetAttribute("path", "" .. preset)
      self:SetAttribute("prev2", 1)
      self:SetAttribute("prevbase2", "")
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
      r1:Show()
    end
    root:Show()
    self:SetAttribute("state", "open")
    return false
  end

  if not root:IsShown() then
    return false
  end
  root:Hide()
  local msg = self:GetAttribute("msg")
  self:SetAttribute("state", "closed")
  if not msg or msg == "" then
    return false
  end
  self:SetAttribute("macrotext", self:GetAttribute("prefix") .. " " .. msg)
]]

-- Right click on the catcher (a screen-wide button shown with the wheel,
-- right button only). WoW does not let BUTTON2 be bound, so a key binding
-- could not do this (tested 17/11/2026).
local ON_RIGHT = [[
  local send = owner:GetFrameRef("send")
  local root = owner:GetFrameRef("root")
  local screen = owner:GetFrameRef("screen")
  -- One step back. A second right click in a row (no new pick in
  -- between) closes the wheel.
  if not root:IsShown() then
    return false
  end
  local step = send:GetAttribute("step")
  if step == 1 or send:GetAttribute("backs") == 1 then
    root:Hide()
    send:SetAttribute("msg", "")
    send:SetAttribute("state", "closed")
    return false
  end
  send:SetAttribute("backs", 1)
  local prev = send:GetAttribute("prev" .. step)
  local base = send:GetAttribute("prevbase" .. step)
  owner:GetFrameRef("r" .. step):Hide()
  send:SetAttribute("sel" .. step, 0)
  send:SetAttribute("sel" .. prev, 0)
  send:SetAttribute("step", prev)
  send:SetAttribute("base", base)
  send:SetAttribute("path", base)
  if prev <= 2 then
    send:SetAttribute("msg", "")
  else
    send:SetAttribute("msg", send:GetAttribute("m" .. base) or "")
  end
  if prev == 1 then
    send:SetAttribute("a", 0)
  end
  -- The previous ring comes back centered on the cursor, so the cursor
  -- sits in its dead center and picks nothing by accident.
  local back = owner:GetFrameRef("r" .. prev)
  local x, y = screen:GetMousePosition()
  back:ClearAllPoints()
  if x and y then
    back:SetPoint("CENTER", screen, "BOTTOMLEFT", x * screen:GetWidth(), y * screen:GetHeight())
  else
    back:SetPoint("CENTER", root, "CENTER")
  end
  back:Show()
  send:SetAttribute("state", "back:" .. prev .. ":" .. base)
  return false
]]

-- Mouse reaches a node. idx 0 = ring center: on ring 2 it cancels the
-- choice, on later rings it drops the optional pick of that ring.
local ON_ENTER = [[
  local send = owner:GetFrameRef("send")
  local ring = self:GetAttribute("ring")
  local idx = self:GetAttribute("idx")
  if ring ~= send:GetAttribute("step") then
    return
  end
  local base = send:GetAttribute("base")
  if idx == 0 then
    send:SetAttribute("path", base)
    send:SetAttribute("sel" .. ring, 0)
    if ring == 2 then
      send:SetAttribute("msg", "")
    else
      send:SetAttribute("msg", send:GetAttribute("m" .. base) or "")
    end
  else
    send:SetAttribute("backs", 0)
    local path
    if ring == 1 then
      path = "" .. idx
      send:SetAttribute("a", idx)
    else
      path = base .. "-" .. idx
    end
    send:SetAttribute("path", path)
    send:SetAttribute("sel" .. ring, idx)
    send:SetAttribute("msg", send:GetAttribute("m" .. path) or "")
    local nextRing = 2
    if ring > 1 then
      nextRing = send:GetAttribute("next-" .. path)
    end
    if nextRing then
      send:SetAttribute("step", nextRing)
      send:SetAttribute("prev" .. nextRing, ring)
      send:SetAttribute("prevbase" .. nextRing, base)
      send:SetAttribute("base", path)
      send:SetAttribute("sel" .. nextRing, 0)
      owner:GetFrameRef("r" .. ring):Hide()
      local rn = owner:GetFrameRef("r" .. nextRing)
      rn:ClearAllPoints()
      rn:SetPoint("CENTER", self, "CENTER")
      rn:Show()
    end
  end
  send:SetAttribute("state", send:GetAttribute("step") .. ":" .. send:GetAttribute("path"))
]]

W.ON_CLICK = ON_CLICK
W.ON_ENTER = ON_ENTER
W.ON_RIGHT = ON_RIGHT


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

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetPoint("CENTER")
  f.icon:SetSize(spec.icon > 0 and spec.icon or 1, spec.icon > 0 and spec.icon or 1)

  f.label = makeText(f, 12)
  f.label:SetPoint("TOP", f, "BOTTOM", 0, 1)

  f.big = makeText(f, 24) -- numbers on the count ring
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
  ring.fills, ring.nodes = {}, {}
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

    local bearing = math.rad((i - 1) * 360 / spec.n)
    local r = spec.outer * ICON_RATIO
    local node = makeNode(ring, ringIndex, i, spec)
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
  send:Hide()

  local rings = {}
  for r = 1, #RINGS do rings[r] = makeRing(root, r) end
  send:SetAttribute("rings", #RINGS)

  -- Message table, as attributes the secure snippets can read.
  for a, action in ipairs(ns.ACTIONS) do
    send:SetAttribute("preset-" .. action.key, a)
  end
  local msgs, nexts = ns.BuildTree()
  for path, msg in pairs(msgs) do send:SetAttribute("m" .. path, msg) end
  for path, ring in pairs(nexts) do send:SetAttribute("next-" .. path, ring) end

  header:SetFrameRef("send", send)
  header:SetFrameRef("root", root)
  header:SetFrameRef("screen", screen)
  header:SetFrameRef("r1", rings[1])
  header:SetFrameRef("r2", rings[2])
  for r = 3, #rings do header:SetFrameRef("r" .. r, rings[r]) end

  header:WrapScript(send, "OnClick", ON_CLICK)

  -- Right-click catcher: covers the screen while the wheel is open (child
  -- of the root), under the nodes so their OnEnter still fires. Left
  -- clicks pass through to the game when the client supports it.
  local catcher = CreateFrame("Button", "CnCWheelRightClick", root, "SecureActionButtonTemplate")
  catcher:SetAllPoints(screen)
  catcher:SetFrameLevel(root:GetFrameLevel())
  catcher:RegisterForClicks("RightButtonDown")
  catcher:SetScript("OnClick", function() end)
  if catcher.SetPassThroughButtons then
    pcall(catcher.SetPassThroughButtons, catcher, "LeftButton")
  end
  header:WrapScript(catcher, "OnClick", ON_RIGHT)
  for _, ring in ipairs(rings) do
    for _, node in ipairs(ring.nodes) do header:WrapScript(node, "OnEnter", ON_ENTER) end
    if ring.center then header:WrapScript(ring.center, "OnEnter", ON_ENTER) end
  end

  -- Static visuals: actions on ring 1. Count labels depend on the action
  -- (see Refresh).
  for a, action in ipairs(ns.ACTIONS) do
    local node = rings[1].nodes[a]
    node.icon:SetTexture(ns.IconPath(action.icon))
    node.label:SetText(action.label)
  end
  for r = 3, #rings do
    for _, node in ipairs(rings[r].nodes) do node.icon:Hide() end
  end
  for s, side in ipairs(ns.SIDES) do
    local node = rings[5].nodes[s]
    node.big:SetText(side)
    node.big:SetFont(STANDARD_TEXT_FONT, 16, "")
    if side == "THEIRS" then setColor(node.big, COLOR_ENEMY) end
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
  toast.text:SetTextColor(1, 0.85, 0.3, 1)
  toast:Hide()
  toast:SetScript("OnUpdate", function(f, elapsed)
    f.left = f.left - elapsed
    if f.left <= 0 then f:Hide() else f:SetAlpha(math.min(1, f.left / 0.5)) end
  end)

  send:HookScript("OnAttributeChanged", function(_, name)
    if name == "state" then W:Refresh() end
  end)

  self.header, self.screen, self.root, self.send = header, screen, root, send
  self.catcher = catcher
  self.rings, self.preview, self.toast = rings, preview, toast
  self.built = true
end

---------------------------------------------------------------------------
-- Visual mirror of the secure state
---------------------------------------------------------------------------

function W:Paint()
  local send = self.send
  local step = send:GetAttribute("step") or 1
  for r, ring in ipairs(self.rings) do
    local aim = (r == step) and self.aim or 0
    local selected = (r > 1) and (send:GetAttribute("sel" .. r) or 0) or 0
    for i, fill in ipairs(ring.fills) do
      if i == selected then
        setColor(fill, COLOR_HOT)
      elseif i == aim then
        setColor(fill, COLOR_AIM)
      else
        setColor(fill, COLOR_IDLE)
      end
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
  end
  if aim ~= self.aim or step ~= self.aimStep then
    self.aim, self.aimStep = aim, step
    self:Paint()
  end
end

local function setIcon(node, choiceOrAction)
  node.icon:SetTexture(ns.IconPath(choiceOrAction.icon))
  setColor(node.icon, choiceOrAction.enemy and COLOR_ENEMY or { 1, 1, 1, 1 })
end

function W:ShowToast(msg)
  local x, y = self.root:GetCenter()
  self.toast:ClearAllPoints()
  self.toast:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x or 0, (y or 0) + 40)
  self.toast.text:SetText(msg)
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

  if state == "closed" then
    self.preview:Hide()
    local msg = send:GetAttribute("msg")
    if msg and msg ~= "" then self:ShowToast(msg) end
    if self.restoreLook then
      self.restoreLook = nil
      if IsMouseButtonDown and IsMouseButtonDown("RightButton") then MouselookStart() end
    end
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

  local a = send:GetAttribute("a") or 0
  local c = send:GetAttribute("sel2") or 0
  local action = ns.ACTIONS[a]

  if action and self.labelsFor ~= a then
    self.labelsFor = a
    for i, node in ipairs(self.rings[2].nodes) do
      local choice = action.choices[i]
      setIcon(node, choice)
      node.label:SetText(choice.label)
    end
    setIcon(self.rings[2].center, action)
    if action.countRing then
      for k, node in ipairs(self.rings[action.countRing].nodes) do
        local count = action.counts[k]
        node.big:SetText(count)
        node.big:SetFont(STANDARD_TEXT_FONT, #count > 2 and 15 or 24, "")
      end
    end
  end

  -- Centers of the optional rings show the place picked at step 2.
  if action and c > 0 then
    for r = 3, #self.rings do setIcon(self.rings[r].center, action.choices[c]) end
  end

  self:Paint()

  local step = send:GetAttribute("step") or 1
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

function W:SetPrefix(prefix)
  if InCombatLockdown() then return false end
  self.send:SetAttribute("prefix", prefix)
  return true
end

W.BUTTON_NAME = BUTTON_NAME

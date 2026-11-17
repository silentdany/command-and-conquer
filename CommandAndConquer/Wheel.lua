-- The wheel.
--
-- Forever blocks SendChatMessage from add-on code in battlegrounds, but a
-- secure action button running a "/bg ..." macro on a player key press
-- works. So the whole gesture runs in Blizzard's restricted (secure)
-- environment, and the message leaves on key release:
--
--   key down   -> secure snippet opens the wheel under the cursor
--   mouse move -> entering a node (secure OnEnter) picks action, choice, count
--   key up     -> secure snippet writes the macro text, the button runs it
--
-- Add-on (insecure) code only draws: it mirrors the secure state through
-- the button's "state" attribute and never decides what is sent.

local _, ns = ...

local W = {}
ns.Wheel = W

local MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local BUTTON_NAME = "CnCWheelButton"

-- Big centers are dead zones: small hand jitter right after a ring opens
-- under the cursor picks nothing (v0.1 felt too sensitive in game).
local RINGS = {
  { n = 5, radius = 104, size = 78 },              -- actions
  { n = 8, radius = 112, size = 72, center = 80 }, -- choices (center = cancel)
  { n = 5, radius = 96, size = 58, center = 72 },  -- enemy count (center = no number)
}

local COLOR_IDLE = { 0.05, 0.05, 0.07, 0.62 }
local COLOR_HOT = { 0.95, 0.72, 0.15, 0.90 }
local COLOR_CENTER = { 0.0, 0.0, 0.0, 0.45 }

---------------------------------------------------------------------------
-- Secure snippets (run in the restricted environment)
---------------------------------------------------------------------------

-- Pre-click on the wheel button. `button` is "LeftButton" for the main
-- binding, or an action key ("INC", ...) for the direct bindings.
local ON_CLICK = [[
  local root = owner:GetFrameRef("root")
  local r1 = owner:GetFrameRef("r1")
  local r2 = owner:GetFrameRef("r2")
  local r3 = owner:GetFrameRef("r3")
  if down then
    if root:IsShown() then
      -- Second press while open (lost key-up): close without sending.
      root:Hide()
      self:SetAttribute("msg", "")
      self:SetAttribute("state", "closed")
      return false
    end
    local screen = owner:GetFrameRef("screen")
    local x, y = screen:GetMousePosition()
    root:ClearAllPoints()
    if x and y then
      root:SetPoint("CENTER", screen, "BOTTOMLEFT", x * screen:GetWidth(), y * screen:GetHeight())
    else
      root:SetPoint("CENTER", screen, "CENTER")
    end
    self:SetAttribute("c", 0)
    self:SetAttribute("k", 0)
    self:SetAttribute("msg", "")
    r3:Hide()
    local preset = self:GetAttribute("preset-" .. button)
    if preset then
      self:SetAttribute("a", preset)
      self:SetAttribute("step", 2)
      r1:Hide()
      r2:ClearAllPoints()
      r2:SetPoint("CENTER", root, "CENTER")
      r2:Show()
    else
      self:SetAttribute("a", 0)
      self:SetAttribute("step", 1)
      r2:Hide()
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

-- Mouse enters a node. Ring 1 = action, ring 2 = choice (idx 0 = center,
-- cancels), ring 3 = enemy count (idx 0 = center, no number).
local ON_ENTER = [[
  local send = owner:GetFrameRef("send")
  local ring = self:GetAttribute("ring")
  local idx = self:GetAttribute("idx")
  if ring ~= send:GetAttribute("step") then
    return
  end
  local a = send:GetAttribute("a")
  if ring == 1 then
    a = idx
    send:SetAttribute("a", a)
    send:SetAttribute("step", 2)
    local r2 = owner:GetFrameRef("r2")
    owner:GetFrameRef("r1"):Hide()
    r2:ClearAllPoints()
    r2:SetPoint("CENTER", self, "CENTER")
    r2:Show()
  elseif ring == 2 then
    if idx == 0 then
      send:SetAttribute("c", 0)
      send:SetAttribute("msg", "")
    else
      send:SetAttribute("c", idx)
      send:SetAttribute("msg", send:GetAttribute("m" .. a .. "-" .. idx))
      if send:GetAttribute("count" .. a) then
        send:SetAttribute("step", 3)
        local r3 = owner:GetFrameRef("r3")
        owner:GetFrameRef("r2"):Hide()
        r3:ClearAllPoints()
        r3:SetPoint("CENTER", self, "CENTER")
        r3:Show()
      end
    end
  else
    local c = send:GetAttribute("c")
    send:SetAttribute("k", idx)
    if idx == 0 then
      send:SetAttribute("msg", send:GetAttribute("m" .. a .. "-" .. c))
    else
      send:SetAttribute("msg", send:GetAttribute("m" .. a .. "-" .. c .. "-" .. idx))
    end
  end
  send:SetAttribute("state", send:GetAttribute("step") .. ":" .. a .. ":"
    .. send:GetAttribute("c") .. ":" .. send:GetAttribute("k"))
]]

W.ON_CLICK = ON_CLICK
W.ON_ENTER = ON_ENTER

---------------------------------------------------------------------------
-- Frames (built once, out of combat)
---------------------------------------------------------------------------

local function setColor(tex, c)
  tex:SetVertexColor(c[1], c[2], c[3], c[4])
end

local function makeNode(parent, ring, idx, size)
  local f = CreateFrame("Frame", nil, parent, "SecureFrameTemplate")
  f:SetSize(size, size)
  if f.SetMouseMotionEnabled and f.SetMouseClickEnabled then
    f:SetMouseMotionEnabled(true)
    f:SetMouseClickEnabled(false) -- clicks go through to the game
  else
    f:EnableMouse(true)
  end
  f:SetAttribute("ring", ring)
  f:SetAttribute("idx", idx)
  f:SetScript("OnEnter", function() end)

  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetTexture(MASK)
  f.bg:SetAllPoints()
  setColor(f.bg, COLOR_IDLE)

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetPoint("CENTER")
  f.icon:SetSize(size * 0.62, size * 0.62)
  if f.CreateMaskTexture then
    local mask = f:CreateMaskTexture()
    mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(f.icon)
    f.icon:AddMaskTexture(mask)
  end
  f.icon:Hide()

  f.text = f:CreateFontString(nil, "OVERLAY")
  f.text:SetFont(STANDARD_TEXT_FONT, ring == 3 and 16 or 12, "OUTLINE")
  f.text:SetPoint("CENTER")
  f.text:SetWidth(size - 4)

  f.label = f:CreateFontString(nil, "OVERLAY")
  f.label:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
  f.label:SetPoint("TOP", f, "BOTTOM", 0, -1)
  f.label:SetTextColor(0.85, 0.85, 0.85, 0.8)
  return f
end

local function makeRing(root, ringIndex)
  local spec = RINGS[ringIndex]
  local ring = CreateFrame("Frame", nil, root, "SecureFrameTemplate")
  ring:SetSize(1, 1)
  ring:SetPoint("CENTER", root, "CENTER")
  ring:Hide()
  ring.nodes = {}
  for i = 1, spec.n do
    local bearing = math.rad((i - 1) * 360 / spec.n)
    local node = makeNode(ring, ringIndex, i, spec.size)
    node:SetPoint("CENTER", ring, "CENTER", math.sin(bearing) * spec.radius, math.cos(bearing) * spec.radius)
    ring.nodes[i] = node
  end
  if spec.center then
    local center = makeNode(ring, ringIndex, 0, spec.center)
    center:SetPoint("CENTER", ring, "CENTER")
    setColor(center.bg, COLOR_CENTER)
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

  local rings = { makeRing(root, 1), makeRing(root, 2), makeRing(root, 3) }

  -- Message table, as attributes the secure snippets can read.
  for a, action in ipairs(ns.ACTIONS) do
    send:SetAttribute("preset-" .. action.key, a)
    if action.count then send:SetAttribute("count" .. a, true) end
    for c, choice in ipairs(action.choices) do
      send:SetAttribute("m" .. a .. "-" .. c, choice.msg)
      if action.count then
        for k, count in ipairs(ns.COUNTS) do
          send:SetAttribute("m" .. a .. "-" .. c .. "-" .. k, ns.CountMessage(choice.msg, count))
        end
      end
    end
  end

  header:SetFrameRef("send", send)
  header:SetFrameRef("root", root)
  header:SetFrameRef("screen", screen)
  header:SetFrameRef("r1", rings[1])
  header:SetFrameRef("r2", rings[2])
  header:SetFrameRef("r3", rings[3])

  header:WrapScript(send, "OnClick", ON_CLICK)
  for _, ring in ipairs(rings) do
    for _, node in ipairs(ring.nodes) do header:WrapScript(node, "OnEnter", ON_ENTER) end
    if ring.center then header:WrapScript(ring.center, "OnEnter", ON_ENTER) end
  end

  -- Static visuals: action icons on ring 1, counts on ring 3.
  for a, action in ipairs(ns.ACTIONS) do
    local node = rings[1].nodes[a]
    node.icon:SetTexture(ns.ResolveIcon(action.icon))
    node.icon:Show()
    node.label:SetText(action.label)
  end
  for k, count in ipairs(ns.COUNTS) do
    rings[3].nodes[k].text:SetText(count)
  end

  -- What will be sent, above the active ring. Plain (insecure) frame so
  -- add-on code can move it in combat.
  local preview = CreateFrame("Frame", nil, UIParent)
  preview:SetSize(1, 1)
  preview:SetFrameStrata("FULLSCREEN_DIALOG")
  preview.text = preview:CreateFontString(nil, "OVERLAY")
  preview.text:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
  preview.text:SetPoint("BOTTOM")
  preview.text:SetTextColor(1, 0.85, 0.3, 1)
  preview:Hide()

  -- Short confirmation after a send, where the wheel was.
  local toast = CreateFrame("Frame", nil, UIParent)
  toast:SetSize(1, 1)
  toast:SetFrameStrata("FULLSCREEN_DIALOG")
  toast.text = toast:CreateFontString(nil, "OVERLAY")
  toast.text:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
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
  self.rings, self.preview, self.toast = rings, preview, toast
  self.built = true
end

---------------------------------------------------------------------------
-- Visual mirror of the secure state
---------------------------------------------------------------------------

local function highlight(ring, selected)
  for i, node in ipairs(ring.nodes) do
    setColor(node.bg, i == selected and COLOR_HOT or COLOR_IDLE)
  end
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
    -- The cursor is hidden while the camera is held with right click:
    -- free it so the gesture can be read, give the camera back on close.
    if IsMouselooking and IsMouselooking() then
      MouselookStop()
      self.restoreLook = true
    end
  end

  local a = send:GetAttribute("a") or 0
  local c = send:GetAttribute("c") or 0
  local k = send:GetAttribute("k") or 0
  local action = ns.ACTIONS[a]

  -- Ring 3 center shows the place locked in by step 2.
  local center3 = self.rings[3].center
  center3.text:SetText(action and c > 0 and action.choices[c].label or "")

  if action and self.labelsFor ~= a then
    self.labelsFor = a
    for i, node in ipairs(self.rings[2].nodes) do
      node.text:SetText(action.choices[i].label)
    end
    local center = self.rings[2].center
    center.icon:SetTexture(ns.ResolveIcon(action.icon))
    center.icon:Show()
  end

  highlight(self.rings[2], c)
  highlight(self.rings[3], k)

  local step = send:GetAttribute("step") or 1
  local ring, spec = self.rings[step], RINGS[step]
  local x, y = ring:GetCenter()
  local msg = send:GetAttribute("msg") or ""
  if x and msg ~= "" then
    self.preview:ClearAllPoints()
    self.preview:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y + spec.radius + spec.size / 2 + 8)
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

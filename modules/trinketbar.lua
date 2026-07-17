-- Trinket Bar
-- A small movable bar that shows your two equipped trinkets with a live cooldown
-- swipe, so on-use trinkets are always visible at a glance. Left/right click uses
-- the trinket; hover shows its tooltip.
--
-- Uses only stock 1.12 inventory API (GetInventoryItem*) so it works everywhere.
-- pfUI's cooldown module hooks CooldownFrame_SetTimer, so the swipe automatically
-- picks up pfUI's cooldown text/animation styling when that module is enabled.
-- On clients with Nampower the cooldown remains millisecond-accurate through the
-- same standard events.
pfUI:RegisterNewModule("trinketbar", "Trinket Bar")
pfUI:RegisterModule("trinketbar", "vanilla:tbc", function ()
  -- Opt-in: only build the bar when explicitly enabled.
  if C.unitframes.trinketbar ~= "1" then return end

  local rawborder, border = GetBorderSize()
  local size = tonumber(C.unitframes.trinketbar_size) or 32

  -- Trinket inventory slots (13 = Trinket0Slot, 14 = Trinket1Slot).
  -- Each GetInventorySlotInfo() returns (slotID, texture, ...); assign through
  -- locals first so only the slotID is kept (a trailing call in a table
  -- constructor would otherwise expand all of its return values).
  local trinket0 = GetInventorySlotInfo("Trinket0Slot")
  local trinket1 = GetInventorySlotInfo("Trinket1Slot")
  local slots = { trinket0, trinket1 }

  local bar = CreateFrame("Frame", "pfTrinketBar", UIParent)
  bar:SetWidth(size * 2 + border * 3)
  bar:SetHeight(size)
  bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 120)
  UpdateMovable(bar, true)

  bar.buttons = {}
  for i = 1, table.getn(slots) do
    local b = CreateFrame("Button", "pfTrinketBarButton" .. i, bar)
    b:SetWidth(size)
    b:SetHeight(size)
    if i == 1 then
      b:SetPoint("LEFT", bar, "LEFT", 0, 0)
    else
      b:SetPoint("LEFT", bar.buttons[i-1], "RIGHT", border * 3, 0)
    end

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)
    b.icon:SetTexCoord(.08, .92, .08, .92)

    b.cd = CreateFrame(COOLDOWN_FRAME_TYPE, b:GetName() .. "Cooldown", b, "CooldownFrameTemplate")
    b.cd:SetAllPoints(b)

    CreateBackdrop(b)
    CreateBackdropShadow(b)

    b.slot = slots[i]
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function()
      UseInventoryItem(this.slot)
    end)
    b:SetScript("OnEnter", function()
      if not GetInventoryItemTexture("player", this.slot) then return end
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetInventoryItem("player", this.slot)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    bar.buttons[i] = b
  end

  local function UpdateButton(b)
    local tex = GetInventoryItemTexture("player", b.slot)
    if tex then
      b.icon:SetTexture(tex)
      local start, duration, enable = GetInventoryItemCooldown("player", b.slot)
      CooldownFrame_SetTimer(b.cd, start, duration, enable)
      b:Show()
    else
      -- Empty trinket slot: hide the button.
      b:Hide()
    end
  end

  local function UpdateAll()
    for i = 1, table.getn(bar.buttons) do
      UpdateButton(bar.buttons[i])
    end
  end

  bar:RegisterEvent("PLAYER_ENTERING_WORLD")
  bar:RegisterEvent("UNIT_INVENTORY_CHANGED")
  bar:RegisterEvent("BAG_UPDATE_COOLDOWN")
  bar:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
  bar:RegisterEvent("PLAYER_LOGOUT")
  bar:SetScript("OnEvent", function()
    -- Handle shutdown to prevent crash 132
    if event == "PLAYER_LOGOUT" then
      this:UnregisterAllEvents()
      this:SetScript("OnEvent", nil)
      return
    end
    -- Only care about our own inventory changes.
    if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end
    UpdateAll()
  end)

  UpdateAll()
end)

pfUI:RegisterModule("firstrun", "vanilla:tbc", function ()
  pfUI.firstrun = CreateFrame("Frame", "pfFirstRunWizard", UIParent)
  pfUI.firstrun.steps = {}

  pfUI.firstrun:RegisterEvent("PLAYER_ENTERING_WORLD")
  pfUI.firstrun:SetScript("OnEvent", function() pfUI.firstrun:NextStep() end)

  local autoconfig = false
  function pfUI.firstrun:AddStep(name, func)
    if not name then return end
    table.insert(pfUI.firstrun.steps, { name = name, func = func})
  end

  local cur, max = 0, 0
  function pfUI.firstrun:NextStep()
    local windowcount = 0
    for i, step in pairs(pfUI.firstrun.steps) do
      if not pfUI_init[step.name] then
        windowcount = windowcount + 1
      end
    end
    max = windowcount > max and windowcount or max

    for _, step in pairs(pfUI.firstrun.steps) do
      local name = step.name
      if not pfUI_init[name] then
        cur = cur + 1

        local f = step.func()
        f.progress:SetMinMaxValues(0, max)
        f.progress:SetValue(cur)
        f.ptext:SetText(cur .. " / " .. max)
        f.name = name
        f:Show()
        if autoconfig == true then
          f.next:Click()
        end

        if cur == max then
          f.next:SetText(T["Finish"])
          autoconfig = false
          cur = 0
          max = 0
        end

        return
      end
    end
  end

  -- main function to create wizard windows
  local function CreateFirstRunPage()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetPoint("CENTER", 0, 0)
    f:SetFrameStrata("TOOLTIP")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetWidth(380)
    f:SetHeight(180)
    f:SetScript("OnDragStart",function()
      this:StartMoving()
    end)

    f:SetScript("OnDragStop",function()
      this:StopMovingOrSizing()
    end)

    CreateBackdrop(f, nil, nil, .85)
    CreateBackdropShadow(f)

    -- text
    f.text = f:CreateFontString("Status", "OVERLAY", "GameFontNormal")
    f.text:SetFontObject(GameFontWhite)
    f.text:SetJustifyV("TOP")
    f.text:SetJustifyH("CENTER")
    f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
    f.text:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)

    f.progress = CreateFrame("StatusBar", nil, f)
    f.progress:SetPoint("BOTTOMLEFT", 100, 10)
    f.progress:SetPoint("BOTTOMRIGHT", -100, 10)
    f.progress:SetHeight(12)
    f.progress:SetStatusBarTexture(pfUI.media["img:bar"])
    f.progress:SetStatusBarColor(.2,1,.8,1)
    f.progress:SetMinMaxValues(1,9)
    f.progress:SetValue(3)
    CreateBackdrop(f.progress)

    f.ptext = f.progress:CreateFontString("Status", "LOW", "GameFontNormal")
    f.ptext:SetFontObject(GameFontWhite)
    f.ptext:SetAllPoints()
    f.ptext:SetText("0/0")

    f.next = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.next:SetWidth(80)
    f.next:SetHeight(20)
    f.next:SetPoint("BOTTOMLEFT", f.progress.backdrop, "BOTTOMRIGHT", 8, 0)
    f.next:SetText(T["Next"])
    f.next:SetScript("OnClick", function()
      if f.NextScript then f.NextScript() end
      pfUI_init[f.name] = true
      f:Hide()
      pfUI.firstrun:NextStep()
    end)
    SkinButton(f.next)

    f.abort = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.abort:SetWidth(80)
    f.abort:SetHeight(20)
    f.abort:SetPoint("BOTTOMRIGHT", f.progress.backdrop, "BOTTOMLEFT", -8, 0)
    f.abort:SetText(T["Cancel"])
    f.abort:SetScript("OnClick", function()
      f:Hide()
    end)
    SkinButton(f.abort)
    f:Hide()

    return f
  end

  -- welcome dialog
  pfUI.firstrun:AddStep("init", function()
    local f = CreateFirstRunPage()
    f.text:SetText(T["Welcome to |cff33ffccpf|cffffffffUI|r!\n\nI'm the first run wizard that will guide you through some basic configuration. If you're lazy, feel free to hit the \"Defaults\" button. If you wish to run this dialog again, go to the settings and hit the \"Reset Firstrun\" button.\n\nVisit |cff33ffcchttp://shagu.org|r to check for the latest version."])
    return f
  end)

  -- choose profile
  -- The list of built-in design profiles offered by the wizard. This is
  -- data-driven so adding a new prebuilt theme only requires:
  --   1. defining it in env/profiles.lua (pfUI_profiles["Name"])
  --   2. appending its key to this list
  -- The grid below lays the buttons out automatically (2 columns, top-to-bottom),
  -- so the window resizes to fit however many themes are listed here.
  local firstrun_profiles = { "Modern", "Slim", "Nostalgia", "Legacy", "Adapta", "Light", "Carbon" }

  pfUI.firstrun:AddStep("profile", function()
    local f = CreateFirstRunPage()

    -- Grid geometry
    local cols = 2
    local btnW, btnH = 120, 20
    local hgap, vgap = 12, 6
    local count = table.getn(firstrun_profiles)
    local rows = math.ceil(count / cols)

    -- Reserve vertical room: the scale slider sits at y=50 and the grid stacks
    -- upward from y=86. Grow the window so the description text never overlaps.
    local gridBottom = 86
    local gridTop = gridBottom + rows * (btnH + vgap)
    f:SetHeight(math.max(180, gridTop + 76))

    -- Keep the description text pinned to the top band above the grid.
    f.text:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, gridTop + 8)
    f.text:SetText(T["A new installation of |cff33ffccpf|rUI ships with several prebuilt design profiles. Click one below to load it, or hit \"Next\" to keep the defaults. You can switch or create your own profile any time via |cffffffaa/pfui|r > Settings > General > Profile."])

    -- Build the theme buttons from firstrun_profiles.
    f.profileButtons = {}
    for i = 1, count do
      local name = firstrun_profiles[i]
      local idx0 = i - 1
      local col = math.mod(idx0, cols)
      local rowFromTop = math.floor(idx0 / cols)
      local rowFromBottom = (rows - 1) - rowFromTop

      local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
      btn:SetWidth(btnW)
      btn:SetHeight(btnH)
      local xoff = (col == 0) and -(btnW/2 + hgap/2) or (btnW/2 + hgap/2)
      local yoff = gridBottom + rowFromBottom * (btnH + vgap)
      btn:SetPoint("BOTTOM", xoff, yoff)
      btn:SetTextColor(1,1,1)
      btn:SetText(name)
      btn:SetScript("OnClick", function()
        if not pfUI_profiles[name] then return end
        _G["pfUI_config"] = CopyTable(pfUI_profiles[name])
        pfUI_init.selected_profile = name
        pfUI:LoadConfig()
        ReloadUI()
      end)
      SkinButton(btn)
      f.profileButtons[name] = btn
    end

    f.Slider = CreateFrame("Slider", "pfFirstRunWizardScaleSlider", f, "OptionsSliderTemplate")
    f.Slider.text = f.Slider:CreateFontString("Status", "LOW", "GameFontWhite")
    f.Slider.text:SetPoint("TOP", f.Slider, "BOTTOM", 0, 2)
    f.Slider.text:SetText(T["Scale"])

    f.Slider:SetWidth(240)
    f.Slider:SetHeight(20)
    f.Slider:SetPoint("BOTTOM", 0, 50)
    f.Slider:SetOrientation('HORIZONTAL')
    f.Slider:SetMinMaxValues(0.5, 2.0)
    f.Slider:SetValue(UIParent:GetScale())

    f.Slider:SetScript("OnMouseUp", function()
      local scale = round(this:GetValue(),2)
      SetCVar("uiScale", scale)
      SetCVar("useUiScale", 1)
      UIParent:SetScale(scale)
      this:SetValue(scale)
    end)

    f.Slider:SetScript("OnValueChanged", function()
      local scale = round(this:GetValue(),2)
      this:SetValue(scale)
    end)

    f.Slider:SetScript("OnUpdate", function()
      local scale = round(this:GetValue(),2)
      this.text:SetText(T["Scale"] .. ": " .. scale * 100 .. "%")
    end)

    SkinSlider(f.Slider)

    return f
  end)

  -- optimized cvars dialog
  pfUI.firstrun:AddStep("cvars", function()
    local f = CreateFirstRunPage()
    f.text:SetText(T["|cff33ffccBlizzard: \"Interface Options\"|r\n\nDo you want me to set up the recommended Blizzard UI settings? This will enable settings that can be found in the Interface section of your client. Options like Buff Durations, Instant Quest Text, Auto Selfcast and others will be set."])

    f.checkbox = CreateFrame("CheckButton", "pfCheckBoxCVAR", f, "UICheckButtonTemplate")
    f.checkbox:SetChecked(true)
    f.checkbox.text = f:CreateFontString("Status", "LOW", "GameFontNormal")
    f.checkbox.text:SetPoint("LEFT", f.checkbox, "RIGHT", 5, 0)
    f.checkbox.text:SetText(" " .. T["Setup Optimized Game Settings"])
    f.checkbox:SetPoint("BOTTOMLEFT", (f:GetWidth() - f.checkbox.text:GetStringWidth() - 20) / 2, 50)
    SkinCheckbox(f.checkbox, 18)

    f.NextScript = function()
      if f.checkbox:GetChecked() then
        pfUI.SetupCVars()
      end
    end

    return f
  end)

  -- right chat dialog
  pfUI.firstrun:AddStep("chat_right", function()
    local f = CreateFirstRunPage()
    f.text:SetText(T["|cff33ffccChat: \"Loot & Spam\"|r\n\nDo you want me to create and manage a specific Chatframe called \"Loot & Spam\"? This chat will display world channels, loot information and miscellaneous messages, that would otherwise clutter your main chatframe."])

    f.checkbox = CreateFrame("CheckButton", "pfCheckBoxChatRight", f, "UICheckButtonTemplate")
    f.checkbox:SetChecked(true)
    f.checkbox.text = f:CreateFontString("Status", "LOW", "GameFontNormal")
    f.checkbox.text:SetPoint("LEFT", f.checkbox, "RIGHT", 5, 0)
    f.checkbox.text:SetText(" " .. T["Enable \"Loot & Spam\" Window"])
    f.checkbox:SetPoint("BOTTOMLEFT", (f:GetWidth() - f.checkbox.text:GetStringWidth() - 20) / 2, 50)
    SkinCheckbox(f.checkbox, 18)

    f.NextScript = function()
      if not pfUI.chat then message("Couldn't apply settings. Chat module is disabled.") end
      pfUI.chat.SetupRightChat(f.checkbox:GetChecked())
    end

    return f
  end)

  -- chat position dialog
  pfUI.firstrun:AddStep("chat_position", function()
    local f = CreateFirstRunPage()
    f.text:SetText(T["|cff33ffccChat: \"Layout\"|r\n\nDo you want me to adjust the layout of your chatframes? This would make sure, that every window is placed on its dedicated position."])
    f.checkbox = CreateFrame("CheckButton", "pfCheckBoxChatPosition", f, "UICheckButtonTemplate")
    f.checkbox:SetChecked(true)
    f.checkbox.text = f:CreateFontString("Status", "LOW", "GameFontNormal")
    f.checkbox.text:SetPoint("LEFT", f.checkbox, "RIGHT", 5, 0)
    f.checkbox.text:SetText(" " .. T["Align Chat Windows"])
    f.checkbox:SetPoint("BOTTOMLEFT", (f:GetWidth() - f.checkbox.text:GetStringWidth() - 20) / 2, 50)
    SkinCheckbox(f.checkbox, 18)

    f.NextScript = function()
      if not pfUI.chat then message("Couldn't apply settings. Chat module is disabled.") end
      if f.checkbox:GetChecked() then
        pfUI.chat.SetupPositions()
      end
    end

    return f
  end)

  -- chat channels dialog
  pfUI.firstrun:AddStep("chat_channels", function()
    local f = CreateFirstRunPage()
    f.text:SetText(T["|cff33ffccChat: \"Channels\"|r\n\nDo you want me to setup the chat channels of your chatframes? This would set important or personal messages to the left chat and world channels and lootinformation to the right chat."])
    f.checkbox = CreateFrame("CheckButton", "pfCheckBoxChatChannels", f, "UICheckButtonTemplate")
    f.checkbox:SetChecked(true)
    f.checkbox.text = f:CreateFontString("Status", "LOW", "GameFontNormal")
    f.checkbox.text:SetPoint("LEFT", f.checkbox, "RIGHT", 5, 0)
    f.checkbox.text:SetText(" " .. T["Setup All Chat Channels"])
    f.checkbox:SetPoint("BOTTOMLEFT", (f:GetWidth() - f.checkbox.text:GetStringWidth() - 20) / 2, 50)
    SkinCheckbox(f.checkbox, 18)

    f.NextScript = function()
      if not pfUI.chat then message("Couldn't apply settings. Chat module is disabled.") end
      if f.checkbox:GetChecked() then
        pfUI.chat.SetupChannels()
      end
    end

    return f
  end)

  -- finalize dialog
  pfUI.firstrun:AddStep("finalize", function()
    -- Set default positions for new modules based on the active profile.
    -- Only write positions that haven't been saved yet (don't override user preferences).
    local function SetDefaultPosition(name, anchor, xpos, ypos)
      if not pfUI_config.position[name] then
        pfUI_config.position[name] = {
          anchor = anchor,
          parent = "UIParent",
          xpos   = xpos,
          ypos   = ypos,
        }
      end
    end

    local positions = (pfUI_profiles[pfUI_init.selected_profile or "Modern"] or pfUI_profiles["Modern"]).new_module_positions
      or pfUI_profiles["Modern"].new_module_positions

    for frameName, pos in pairs(positions) do
      SetDefaultPosition(frameName, pos.anchor, pos.xpos, pos.ypos)
    end

    local f = CreateFirstRunPage()
    f.text:SetText(T["Your interface is now set up.\n\nFor advanced configuration, just open the |cff33ffccpf|rUI settings via the escape menu or type \"|cffffffaa/pfui|r\" into the chat.\n\n Have a nice trip!\n\n|cffaaaaaa- Shagu"])
    return f
  end)
end)

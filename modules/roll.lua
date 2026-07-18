pfUI:RegisterModule("roll", "vanilla:tbc", function ()
  pfUI.roll = CreateFrame("Frame", "pfLootRoll", UIParent)
  pfUI.roll.frames = {}

  -- squash vanilla item placeholders
  local LOOT_ROLL_GREED = string.gsub(LOOT_ROLL_GREED, "%%s|Hitem:%%d:%%d:%%d:%%d|h%[%%s%]|h%%s", "%%s")
  local LOOT_ROLL_NEED = string.gsub(LOOT_ROLL_NEED, "%%s|Hitem:%%d:%%d:%%d:%%d|h%[%%s%]|h%%s", "%%s")
  local LOOT_ROLL_PASSED = string.gsub(LOOT_ROLL_PASSED, "%%s|Hitem:%%d:%%d:%%d:%%d|h%[%%s%]|h%%s", "%%s")

  -- try to detect the everyone string
  local _, _, everyone, _ = strfind(LOOT_ROLL_ALL_PASSED, LOOT_ROLL_PASSED)
  pfUI.roll.blacklist = { YOU, everyone }

  pfUI.roll.cache = {}

  pfUI.roll.scan = CreateFrame("Frame", "pfLootRollMonitor", UIParent)
  pfUI.roll.scan:RegisterEvent("CHAT_MSG_LOOT")
  pfUI.roll.scan:SetScript("OnEvent", function()
    local player, item = cmatch(arg1, LOOT_ROLL_GREED)
    if player and item then
      pfUI.roll:AddCache(item, player, "GREED")
      return
    end

    local player, item = cmatch(arg1, LOOT_ROLL_NEED)
    if player and item then
      pfUI.roll:AddCache(item, player, "NEED")
      return
    end

    local player, item = cmatch(arg1, LOOT_ROLL_PASSED)
    if player and item then
      pfUI.roll:AddCache(item, player, "PASS")
      return
    end
  end)

  function pfUI.roll:AddCache(hyperlink, name, roll)
    -- skip invalid names
    for _, invalid in pairs(pfUI.roll.blacklist) do
      if name == invalid then return end
    end

    local _, _, itemLink = string.find(hyperlink, "(item:%d+:%d+:%d+:%d+)")
    local itemName = GetItemInfo(itemLink)

    -- delete obsolete tables
    if pfUI.roll.cache[itemName] and pfUI.roll.cache[itemName]["TIMESTAMP"] < GetTime() - 60 then
      pfUI.roll.cache[itemName] = nil
    end

    -- initialize itemtable
    if not pfUI.roll.cache[itemName] then
      pfUI.roll.cache[itemName] = { ["GREED"] = {}, ["NEED"] = {}, ["PASS"] = {}, ["TIMESTAMP"] = GetTime() }
    end

    -- ignore already listed names
    for _, existing in pairs(pfUI.roll.cache[itemName][roll]) do
      if name == existing then return end
    end

    table.insert(pfUI.roll.cache[itemName][roll], name)

    for id=1,4 do
      if pfUI.roll.frames[id]:IsVisible() and pfUI.roll.frames[id].itemname == itemName then
        local count_greed = pfUI.roll.cache[itemName] and table.getn(pfUI.roll.cache[itemName]["GREED"]) or 0
        local count_need  = pfUI.roll.cache[itemName] and table.getn(pfUI.roll.cache[itemName]["NEED"]) or 0
        local count_pass  = pfUI.roll.cache[itemName] and table.getn(pfUI.roll.cache[itemName]["PASS"]) or 0

        pfUI.roll.frames[id].greed.count:SetText(count_greed > 0 and count_greed or "")
        pfUI.roll.frames[id].need.count:SetText(count_need > 0 and count_need or "")
        pfUI.roll.frames[id].pass.count:SetText(count_pass > 0 and count_pass or "")
      end
    end
  end

  function pfUI.roll:CreateLootRoll(id)
    local size = 24
    local rawborder, border = GetBorderSize()
    local esize = size - border*2
    local f = CreateFrame("Frame", "pfLootRollFrame" .. id, UIParent)

    CreateBackdrop(f, nil, nil, .8)
    CreateBackdropShadow(f)

    f.backdrop:SetFrameStrata("BACKGROUND")
    f.hasItem = 1

    f:SetWidth(350)
    f:SetHeight(size)

    f.icon = CreateFrame("Button", "pfLootRollFrame" .. id .. "Icon", f)
    CreateBackdrop(f.icon, nil, true)
    f.icon:SetPoint("LEFT", border, 0)
    f.icon:SetWidth(esize)
    f.icon:SetHeight(esize)

    f.icon.tex = f.icon:CreateTexture("OVERLAY")
    f.icon.tex:SetTexCoord(.08, .92, .08, .92)
    f.icon.tex:SetAllPoints(f.icon)

    f.icon:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetLootRollItem(this:GetParent().rollID)
      CursorUpdate()
    end)

    f.icon:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    f.icon:SetScript("OnClick", function()
      if IsControlKeyDown() then
        DressUpItemLink(GetLootRollItemLink(this:GetParent().rollID))
      elseif IsShiftKeyDown() then
        if ChatEdit_InsertLink then
          ChatEdit_InsertLink(GetLootRollItemLink(this:GetParent().rollID))
        elseif ChatFrameEditBox:IsVisible() then
          ChatFrameEditBox:Insert(GetLootRollItemLink(this:GetParent().rollID))
        end
      end
    end)

    f.need = CreateFrame("Button", "pfLootRollFrame" .. id .. "Need", f)
    f.need:SetPoint("LEFT", f.icon, "RIGHT", border*3, -1)
    f.need:SetWidth(esize)
    f.need:SetHeight(esize)
    f.need:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up")
    f.need:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Highlight")

    f.need.count = f.need:CreateFontString("NEED")
    f.need.count:SetPoint("CENTER", f.need, "CENTER", 0, 0)
    f.need.count:SetJustifyH("CENTER")
    f.need.count:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")

    f.need:SetScript("OnClick", function()
      RollOnLoot(this:GetParent().rollID, 1)
    end)
    f.need:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetText("|cff33ffcc" .. NEED)
      if f.itemname and pfUI.roll.cache[f.itemname] then
        for _, player in pairs(pfUI.roll.cache[f.itemname]["NEED"]) do
          GameTooltip:AddLine(player)
        end
      end
      GameTooltip:Show()
    end)
    f.need:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    f.greed = CreateFrame("Button", "pfLootRollFrame" .. id .. "Greed", f)
    f.greed:SetPoint("LEFT", f.icon, "RIGHT", border*5+esize, -2)
    f.greed:SetWidth(esize)
    f.greed:SetHeight(esize)
    f.greed:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
    f.greed:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Highlight")

    f.greed.count = f.greed:CreateFontString("GREED")
    f.greed.count:SetPoint("CENTER", f.greed, "CENTER", 0, 1)
    f.greed.count:SetJustifyH("CENTER")
    f.greed.count:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")

    f.greed:SetScript("OnClick", function()
      RollOnLoot(this:GetParent().rollID, 2)
    end)
    f.greed:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetText("|cff33ffcc" .. GREED)
      if f.itemname and pfUI.roll.cache[f.itemname] then
        for _, player in pairs(pfUI.roll.cache[f.itemname]["GREED"]) do
          GameTooltip:AddLine(player)
        end
      end
      GameTooltip:Show()
    end)
    f.greed:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    f.pass = CreateFrame("Button", "pfLootRollFrame" .. id .. "Pass", f)
    f.pass:SetPoint("LEFT", f.icon, "RIGHT", border*7+esize*2, 0)
    f.pass:SetWidth(esize)
    f.pass:SetHeight(esize)
    f.pass:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    f.pass:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Highlight")

    f.pass.count = f.pass:CreateFontString("PASS")
    f.pass.count:SetPoint("CENTER", f.pass, "CENTER", 0, -1)
    f.pass.count:SetJustifyH("CENTER")
    f.pass.count:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")

    f.pass:SetScript("OnClick", function()
      RollOnLoot(this:GetParent().rollID, 0)
    end)
    f.pass:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetText("|cff33ffcc" .. PASS)
      if f.itemname and pfUI.roll.cache[f.itemname] then
        for _, player in pairs(pfUI.roll.cache[f.itemname]["PASS"]) do
          GameTooltip:AddLine(player)
        end
      end
      GameTooltip:Show()
    end)
    f.pass:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    f.boe = CreateFrame("Frame", "pfLootRollFrame" .. id .. "BOE", f)
    f.boe:SetPoint("LEFT", f.icon, "RIGHT", border*9+esize*3, 0)
    f.boe:SetWidth(esize*2)
    f.boe:SetHeight(esize)
    f.boe.text = f.boe:CreateFontString("BOE")
    f.boe.text:SetAllPoints(f.boe)
    f.boe.text:SetJustifyH("LEFT")
    f.boe.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")

    f.name = CreateFrame("Frame", "pfLootRollFrame" .. id .. "Name", f)
    f.name:SetPoint("LEFT", f.icon, "RIGHT", border*11+esize*4, 0)
    f.name:SetPoint("RIGHT", f, "RIGHT", border*2, 0)
    f.name:SetHeight(esize)
    f.name.text = f.name:CreateFontString("NAME")
    f.name.text:SetAllPoints(f.name)
    f.name.text:SetJustifyH("LEFT")
    f.name.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")

    f.time = CreateFrame("Frame", "pfLootRollFrame" .. id .. "Time", f)
    f.time:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.time:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    f.time:SetFrameStrata("LOW")
    f.time.bar = CreateFrame("StatusBar", "pfLootRollFrame" .. id .. "TimeBar", f.time)
    f.time.bar:SetAllPoints(f.time)
    f.time.bar:SetStatusBarTexture(pfUI.media["img:bar"])
    f.time.bar:SetMinMaxValues(0, 100)
    local r, g, b, a = strsplit(",", C.appearance.border.color)
    f.time.bar:SetStatusBarColor(r, g, b)
    f.time.bar:SetValue(20)
    f.time.bar:SetScript("OnUpdate", function()
      if not this:GetParent():GetParent().rollID then return end
      local left = GetLootRollTimeLeft(this:GetParent():GetParent().rollID)
      local min, max = this:GetMinMaxValues()
      if left < min or left > max then left = min end
      this:SetValue(left)
    end)

    return f
  end

  pfUI.roll:RegisterEvent("CANCEL_LOOT_ROLL")
  pfUI.roll:SetScript("OnEvent", function()
    for i=1,4 do
      if pfUI.roll.frames[i].rollID == arg1 then
        pfUI.roll.frames[i]:Hide()
      end
    end
  end)

  function _G.GroupLootFrame_OpenNewFrame(id, rollTime)
    -- clear cache if possible
    local visible = nil
    for i=1,4 do
      visible = visible or pfUI.roll.frames[i]:IsVisible()
    end
    if not visible then pfUI.roll.cache = {} end

    -- setup roll frames
    for i=1,4 do
      if not pfUI.roll.frames[i]:IsVisible() then
        pfUI.roll.frames[i].rollID = id
        pfUI.roll.frames[i].rollTime = rollTime
        pfUI.roll:UpdateLootRoll(i)
        return
      end
    end
  end

  function pfUI.roll:UpdateLootRoll(id)
    local texture, name, count, quality, bop = GetLootRollItemInfo(pfUI.roll.frames[id].rollID)
    local color = ITEM_QUALITY_COLORS[quality]

    pfUI.roll.frames[id].itemname = name

    local count_greed = pfUI.roll.cache[name] and table.getn(pfUI.roll.cache[name]["GREED"]) or 0
    local count_need  = pfUI.roll.cache[name] and table.getn(pfUI.roll.cache[name]["NEED"]) or 0
    local count_pass  = pfUI.roll.cache[name] and table.getn(pfUI.roll.cache[name]["PASS"]) or 0

    pfUI.roll.frames[id].greed.count:SetText(count_greed > 0 and count_greed or "")
    pfUI.roll.frames[id].need.count:SetText(count_need > 0 and count_need or "")
    pfUI.roll.frames[id].pass.count:SetText(count_pass > 0 and count_pass or "")

    pfUI.roll.frames[id].name.text:SetText(name)
    pfUI.roll.frames[id].name.text:SetTextColor(color.r, color.g, color.b, 1)
    pfUI.roll.frames[id].icon.tex:SetTexture(texture)
    pfUI.roll.frames[id].backdrop:SetBackdropBorderColor(color.r, color.g, color.b)
    pfUI.roll.frames[id].time.bar:SetMinMaxValues(0, pfUI.roll.frames[id].rollTime)

    if C.loot.raritytimer == "1" then
      pfUI.roll.frames[id].time.bar:SetStatusBarColor(color.r, color.g, color.b, .5)
    end

    if bop then
      pfUI.roll.frames[id].boe.text:SetText(T["BoP"])
      pfUI.roll.frames[id].boe.text:SetTextColor(1,.3,.3,1)
    else
      pfUI.roll.frames[id].boe.text:SetText(T["BoE"])
      pfUI.roll.frames[id].boe.text:SetTextColor(.3,1,.3,1)
    end

    pfUI.roll.frames[id]:Show()
  end

  for i=1,4 do
    if not pfUI.roll.frames[i] then
      pfUI.roll.frames[i] = pfUI.roll:CreateLootRoll(i)
      pfUI.roll.frames[i]:SetPoint("CENTER", 0, -i*35)
      UpdateMovable(pfUI.roll.frames[i])
      pfUI.roll.frames[i]:Hide()
    end
  end

  -- ===========================================================================
  -- Loot Council Roll Coordinator (SR / MS / OS / Transmog)
  -- Ported from the standalone "LootBlare" addon. This is UNRELATED to the
  -- native Need/Greed/Pass popup above: some guilds/raids distribute loot via
  -- manual "/roll" with specific number ranges standing for different
  -- categories (Soft-Reserve, Main-Spec, Off-Spec, Transmog) instead of
  -- Blizzard's native group loot roll. Off by default - opt in via Loot settings.
  -- ===========================================================================
  if C.loot.council.enable == "1" then
    local council = {}
    pfUI.lootcouncil = council

    local CAP_ORDER = { "SR", "MS", "OS", "TM" }
    local CAPS = {
      SR = { max = 101, color = {1, .2, .2} },
      MS = { max = 100, color = {1, 1, .2} },
      OS = { max = 99,  color = {.2, 1, .2} },
      TM = { max = 50,  color = {.2, 1, 1} },
    }

    local PREFIX = "pfUILootCouncil"
    local MSG_GET_DATA = "GET_ML"
    local MSG_SET_ML = "SET_ML:"
    local MSG_SET_TIME = "SET_TIME:"

    council.rolls = { SR = {}, MS = {}, OS = {}, TM = {} }
    council.rollers = {}
    council.isRolling = false
    council.masterLooter = nil
    council.itemLink = nil
    council.timeElapsed = 0

    local function ResetRolls()
      council.rolls = { SR = {}, MS = {}, OS = {}, TM = {} }
      council.rollers = {}
    end

    local function SortRolls()
      for _, cap in ipairs(CAP_ORDER) do
        table.sort(council.rolls[cap], function(a, b) return a.roll > b.roll end)
      end
    end

    -- Uses the real RAID_CLASS_COLORS (fileName-keyed, e.g. "WARRIOR"), unlike
    -- the original addon's own hardcoded English-only class-name color table
    -- which broke on non-English clients.
    local function ClassColor(fileName)
      local c = RAID_CLASS_COLORS[fileName]
      return c.r, c.g, c.b
    end

    local function IsMasterLooter(name)
      local method, mlPartyID = GetLootMethod()
      if method ~= "master" or not mlPartyID then return false end
      if mlPartyID == 0 then return name == UnitName("player") end
      return UnitName("party" .. mlPartyID) == name
    end

    local function ExtractItemLink(message)
      local _, _, link = string.find(message, "|c.-|H(item:.-)|h.-|h|r")
      return link
    end

    -- main frame
    local f = CreateFrame("Frame", "pfLootCouncilFrame", UIParent)
    f:SetWidth(200)
    f:SetHeight(230)
    f:SetPoint("CENTER", 0, 0)
    CreateBackdrop(f, nil, nil, .9)
    CreateBackdropShadow(f)
    f:Hide()
    UpdateMovable(f, true)

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", 2, 2)
    f.close:SetScript("OnClick", function()
      f:Hide()
      ResetRolls()
    end)

    f.icon = CreateFrame("Button", nil, f)
    f.icon:SetWidth(36)
    f.icon:SetHeight(36)
    f.icon:SetPoint("TOP", 0, -10)
    f.icon.tex = f.icon:CreateTexture(nil, "ARTWORK")
    f.icon.tex:SetAllPoints(f.icon)
    f.icon.tex:SetTexCoord(.08, .92, .08, .92)
    CreateBackdrop(f.icon)

    f.icon:SetScript("OnEnter", function()
      if not council.itemLink then return end
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(council.itemLink)
      GameTooltip:Show()
    end)
    f.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.icon:SetScript("OnClick", function()
      if not council.itemLink then return end
      if IsControlKeyDown() then
        DressUpItemLink(council.itemLink)
      elseif IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
        ChatFrameEditBox:Insert(council.itemLink)
      end
    end)

    f.name = f:CreateFontString(nil, "OVERLAY")
    f.name:SetPoint("TOP", f.icon, "BOTTOM", 0, -6)
    f.name:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")

    f.timer = f:CreateFontString(nil, "OVERLAY")
    f.timer:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
    f.timer:SetFont(pfUI.font_default, tonumber(C.global.font_size) + 6, "OUTLINE")

    f.rolls = f:CreateFontString(nil, "OVERLAY")
    f.rolls:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -80)
    f.rolls:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 36)
    f.rolls:SetJustifyH("LEFT")
    f.rolls:SetJustifyV("TOP")
    f.rolls:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")

    local buttons = {}
    for i, cap in ipairs(CAP_ORDER) do
      local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
      b:SetWidth(40)
      b:SetHeight(20)
      b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8 + (i-1)*44, 8)
      b:SetText(cap)
      b:SetScript("OnClick", function() RandomRoll(1, CAPS[cap].max) end)
      b:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText((T["Roll for"] or "Roll for") .. " " .. (cap or "?"))
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      SkinButton(b)
      buttons[cap] = b
    end

    local function UpdateRollsText()
      SortRolls()
      local text = ""
      local count = 0
      for _, cap in ipairs(CAP_ORDER) do
        for _, entry in ipairs(council.rolls[cap]) do
          if count < 12 then
            local r, g, b = ClassColor(entry.fileName)
            local cc = CAPS[cap].color
            text = text .. string.format("|cff%02x%02x%02x%s|r |cff%02x%02x%02x%s (%d)|r\n",
              r*255, g*255, b*255, entry.roller,
              cc[1]*255, cc[2]*255, cc[3]*255, cap, entry.roll)
            count = count + 1
          end
        end
      end
      f.rolls:SetText(text)
    end

    f:SetScript("OnUpdate", function()
      if not council.isRolling then return end
      council.timeElapsed = council.timeElapsed + arg1

      -- Freshly-seen items are not always cached client-side yet: GetItemInfo
      -- returns nil name/icon until the client finishes an async query to the
      -- server. Retry every ~0.5s until it resolves (or we give up after ~10s).
      if council.itemId and not council.iconResolved then
        council.iconRetryTick = (council.iconRetryTick or 0) - arg1
        if council.iconRetryTick <= 0 then
          council.iconRetryTick = 0.5
          council.iconRetries = (council.iconRetries or 0) + 1
          local name, _, _, _, _, _, _, _, icon = GetItemInfo(council.itemId)
          if name and icon then
            f.name:SetText(name)
            f.icon.tex:SetTexture(icon)
            council.iconResolved = true
          elseif council.iconRetries > 20 then
            council.iconResolved = true -- give up, keep placeholder
          end
        end
      end

      local remaining = (tonumber(C.loot.council.duration) or 15) - council.timeElapsed
      f.timer:SetText(remaining > 0 and format("%.1f", remaining) or "0.0")
      if remaining <= 0 then
        council.isRolling = false
        if C.loot.council.autoclose == "1" and not (council.masterLooter == UnitName("player")) then
          f:Hide()
        end
      end
    end)

    local msg = CreateFrame("Frame")
    msg:RegisterEvent("CHAT_MSG_SYSTEM")
    msg:RegisterEvent("CHAT_MSG_RAID_WARNING")
    msg:RegisterEvent("CHAT_MSG_RAID")
    msg:RegisterEvent("CHAT_MSG_RAID_LEADER")
    msg:RegisterEvent("CHAT_MSG_ADDON")
    msg:RegisterEvent("CHAT_MSG_LOOT")
    msg:RegisterEvent("PLAYER_ENTERING_WORLD")
    msg:RegisterEvent("PLAYER_LOGOUT")
    msg:SetScript("OnEvent", function()
      if event == "PLAYER_LOGOUT" then
        this:UnregisterAllEvents()
        this:SetScript("OnEvent", nil)
        return
      elseif event == "PLAYER_ENTERING_WORLD" then
        SendAddonMessage(PREFIX, MSG_GET_DATA, "RAID")
      elseif event == "CHAT_MSG_SYSTEM" then
        local _, _, newML = string.find(arg1, "(%S+) is now the loot master")
        if newML then
          council.masterLooter = newML
          if newML == UnitName("player") then
            SendAddonMessage(PREFIX, MSG_SET_ML .. newML, "RAID")
            SendAddonMessage(PREFIX, MSG_SET_TIME .. (C.loot.council.duration or "15"), "RAID")
          end
        end
      elseif event == "CHAT_MSG_RAID_WARNING" then
        if arg2 == council.masterLooter then
          local link = ExtractItemLink(arg1)
          if link
          and not string.find(arg1, "^No one has nee")
          and not string.find(arg1, "has been sent to")
          and not string.find(arg1, " received ") then
            ResetRolls()
            council.timeElapsed = 0
            council.isRolling = true
            council.itemLink = link

            local _, _, itemId = string.find(link, "(item:%d+:%d+:%d+:%d+)")
            council.itemId = itemId
            council.iconResolved = false
            council.iconRetryTick = 0
            council.iconRetries = 0

            local name, _, _, _, _, _, _, _, icon = GetItemInfo(itemId)
            if name and icon then
              f.name:SetText(name)
              f.icon.tex:SetTexture(icon)
              council.iconResolved = true
            else
              f.name:SetText(UNKNOWN)
              f.icon.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end

            UpdateRollsText()
            f:Show()
          end
        end
      elseif event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" then
        if council.isRolling and string.find(arg1, "rolls") then
          local _, _, roller, roll, minRoll, maxRoll = string.find(arg1, "(%S+) rolls (%d+) %((%d+)%-(%d+)%)")
          if roller and roll and not council.rollers[roller] then
            council.rollers[roller] = true
            local fileName
            for i = 1, GetNumRaidMembers() do
              local n, _, _, _, _, fn = GetRaidRosterInfo(i)
              if n == roller then fileName = fn end
            end
            for _, cap in ipairs(CAP_ORDER) do
              if maxRoll == tostring(CAPS[cap].max) then
                table.insert(council.rolls[cap], { roller = roller, roll = tonumber(roll), fileName = fileName or "WARRIOR" })
              end
            end
            UpdateRollsText()
          end
        end
      elseif event == "CHAT_MSG_LOOT" then
        if f:IsVisible() and council.masterLooter == UnitName("player") then
          local link = ExtractItemLink(arg1)
          if link and link == council.itemLink then
            ResetRolls()
            f:Hide()
          end
        end
      elseif event == "CHAT_MSG_ADDON" and arg1 == PREFIX then
        local message = arg2
        if message == MSG_GET_DATA and IsMasterLooter(UnitName("player")) then
          council.masterLooter = UnitName("player")
          SendAddonMessage(PREFIX, MSG_SET_ML .. council.masterLooter, "RAID")
          SendAddonMessage(PREFIX, MSG_SET_TIME .. (C.loot.council.duration or "15"), "RAID")
        elseif string.find(message, MSG_SET_ML) then
          council.masterLooter = string.sub(message, string.len(MSG_SET_ML) + 1)
        end
      end
    end)

    SLASH_PFLOOTCOUNCIL1 = "/pflootcouncil"
    SlashCmdList["PFLOOTCOUNCIL"] = function()
      if f:IsVisible() then f:Hide() else f:Show() end
    end
  end
end)

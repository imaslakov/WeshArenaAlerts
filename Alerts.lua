local _, WAA = ...

local Alerts = {}
WAA.Alerts = Alerts

local POSITION_KEYS = { "drinking", "innerFire", "shieldAbsorb", "enemyOverpower" }

local SPELLS = {
    drinking = 430,       -- Rank 1 Drink; only used to ask the client for its standard icon.
    innerFire = 25431,
    shieldAbsorb = 25218, -- TBC rank used for texture lookup only; detection will be rank-agnostic.
    enemyOverpower = 7384,
}

local FALLBACK_ICONS = {
    drinking = "Interface\\Icons\\INV_Drink_07",
    innerFire = "Interface\\Icons\\Spell_Holy_InnerFire",
    shieldAbsorb = "Interface\\Icons\\Spell_Holy_PowerWordShield",
    enemyOverpower = "Interface\\Icons\\Ability_MeleeDamage",
}

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

local function CreateBackdropFrame(parent)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", nil, parent, template)
    if frame.SetBackdrop then
        frame:SetBackdrop(BACKDROP)
    end
    return frame
end

local function SetFontSize(fontString, size)
    local font, _, flags = fontString:GetFont()
    if font then
        fontString:SetFont(font, size, flags)
    end
end

local function GetSpellIcon(spellID, fallback)
    local texture
    if C_Spell and C_Spell.GetSpellTexture then
        texture = C_Spell.GetSpellTexture(spellID)
    elseif GetSpellTexture then
        texture = GetSpellTexture(spellID)
    end
    return texture or fallback
end

local function PlayAlertSound()
    if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then
        PlaySound(SOUNDKIT.RAID_WARNING, "Master")
    end
end

local function GetOverpowerWindowSeconds()
    return WAA.EnemyOverpower.OVERPOWER_WINDOW_SECONDS
end

local function FormatShortNumber(value)
    if value >= 1000000 then
        return string.format("%.1fm", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fk", value / 1000)
    end
    return tostring(value)
end

function Alerts:Initialize()
    if self.initialized then
        return
    end

    self.frames = {}
    self.hideTokens = {}
    self.positioningMode = false
    self.drinkingDisplayMode = nil
    self.drinkingRuntimeActive = false
    self.innerFireDisplayMode = nil
    self.innerFireRuntimeActive = false
    self.shieldDisplayMode = nil
    self.shieldRuntimeActive = false
    self.overpowerDisplayMode = nil
    self.overpowerRuntimeActive = false
    self.overpowerUpdateElapsed = 0
    self.scatterDisplayMode = nil

    self:CreateDrinkingFrame()
    self:CreateInnerFireFrame()
    self:CreateShieldFrame()
    self:CreateOverpowerFrame()
    self:CreateScatterFrame()
    self:ApplyAllPositions()

    self.initialized = true
end

function Alerts:CreateMovableFrame(key, width, height)
    local frame = CreateBackdropFrame(UIParent)
    frame:SetSize(width, height)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(false)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(current)
        if WAA.isUnlocked then
            current:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(current)
        current:StopMovingOrSizing()
        self:SavePosition(key, current)
    end)
    frame:Hide()
    frame.positionKey = key
    self.frames[key] = frame
    self:SetPositioningStyle(frame, false)
    return frame
end

function Alerts:CreateIcon(frame, key)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(GetSpellIcon(SPELLS[key], FALLBACK_ICONS[key]))
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.icon = icon
    return icon
end

function Alerts:CreateDrinkingFrame()
    local frame = self:CreateMovableFrame("drinking", 430, 86)
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    text:SetPoint("CENTER")
    text:SetText("DRINKING!!!")
    text:SetTextColor(0.2, 0.75, 1)
    text:SetShadowOffset(2, -2)
    frame.text = text
end

function Alerts:CreateInnerFireFrame()
    local frame = self:CreateMovableFrame("innerFire", 116, 116)
    local icon = self:CreateIcon(frame, "innerFire")
    icon:SetPoint("CENTER")
    local count = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormalHuge")
    count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -3, 3)
    count:SetText("5")
    count:SetTextColor(1, 0.9, 0.2)
    frame.count = count

    local redOverlay = frame:CreateTexture(nil, "ARTWORK")
    redOverlay:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
    redOverlay:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    redOverlay:SetColorTexture(1, 0, 0, 0.18)
    frame.redOverlay = redOverlay

    local missing = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    missing:SetPoint("BOTTOM", icon, "BOTTOM", 0, 5)
    missing:SetText("MISSING")
    missing:SetTextColor(1, 0.15, 0.1)
    missing:SetShadowOffset(1, -1)
    missing:Hide()
    frame.missing = missing
end

function Alerts:CreateShieldFrame()
    local frame = self:CreateMovableFrame("shieldAbsorb", 220, 116)
    local icon = self:CreateIcon(frame, "shieldAbsorb")
    icon:SetPoint("LEFT", frame, "LEFT", 8, 0)

    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetFrameLevel(frame:GetFrameLevel() + 1)
    bar:SetSize(180, 24)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.2, 0.65, 1, 0.95)
    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.025, 0.08, 0.13, 0.9)
    bar.background = background
    frame.bar = bar

    local textLayer = CreateFrame("Frame", nil, frame)
    textLayer:SetAllPoints(frame)
    textLayer:SetFrameLevel(frame:GetFrameLevel() + 2)
    textLayer:EnableMouse(false)
    frame.textLayer = textLayer

    local value = textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    value:SetPoint("LEFT", icon, "RIGHT", 7, 0)
    value:SetText("1847")
    value:SetTextColor(0.75, 0.92, 1)
    value:SetShadowOffset(1, -1)
    frame.value = value
end

function Alerts:CreateOverpowerFrame()
    local frame = self:CreateMovableFrame("enemyOverpower", 150, 116)
    local icon = self:CreateIcon(frame, "enemyOverpower")
    icon:SetPoint("LEFT", frame, "LEFT", 8, 0)
    local countdown = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    countdown:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    countdown:SetText(string.format("%.1f", GetOverpowerWindowSeconds()))
    countdown:SetTextColor(1, 0.35, 0.2)
    frame.countdown = countdown
end

function Alerts:CreateScatterFrame()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(false)
    local texture = frame:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(1, 0, 0, 1)
    frame.texture = texture
    frame:Hide()
    self.frames.scatter = frame
end

function Alerts:ApplyPosition(key)
    local frame = self.frames[key]
    local position = WAA.db.positions[key]
    if not frame or not position then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(
        position.point or "CENTER",
        UIParent,
        position.relativePoint or position.point or "CENTER",
        position.x or 0,
        position.y or 0
    )
end

function Alerts:ApplyAllPositions()
    if not self.frames then
        return
    end
    for _, key in ipairs(POSITION_KEYS) do
        self:ApplyPosition(key)
    end
end

function Alerts:SavePosition(key, frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    local position = WAA.db.positions[key]
    position.point = point or "CENTER"
    position.relativePoint = relativePoint or point or "CENTER"
    position.x = math.floor((x or 0) + 0.5)
    position.y = math.floor((y or 0) + 0.5)
end

function Alerts:SetPositioningStyle(frame, unlocked)
    frame:EnableMouse(unlocked)
    if frame.SetBackdropColor then
        frame:SetBackdropColor(0.02, 0.02, 0.02, unlocked and 0.65 or 0)
        frame:SetBackdropBorderColor(0.2, 0.85, 1, unlocked and 1 or 0)
    end
end

function Alerts:UnlockFrames()
    WAA.isUnlocked = true
    self.positioningMode = true
    self:ShowDrinkingPreview(true, true)
    self:ShowInnerFirePreview(true)
    self:ShowShieldPreview(true)
    self:ShowOverpowerPreview(true, true)
    for _, key in ipairs(POSITION_KEYS) do
        self:SetPositioningStyle(self.frames[key], true)
    end
end

function Alerts:LockFrames()
    WAA.isUnlocked = false
    self.positioningMode = false
    for _, key in ipairs(POSITION_KEYS) do
        local frame = self.frames[key]
        self:SetPositioningStyle(frame, false)
        frame:Hide()
    end
    self.drinkingDisplayMode = nil
    self.innerFireDisplayMode = nil
    self.shieldDisplayMode = nil
    self.overpowerDisplayMode = nil
    if WAA.EnemyOverpower then
        WAA.EnemyOverpower:RefreshVisual(false)
    end
    if WAA.InnerFire then
        WAA.InnerFire:RefreshVisual()
    end
    if WAA.ShieldAbsorb then
        WAA.ShieldAbsorb:RefreshVisual()
    end
end

function Alerts:CancelHide(key)
    self.hideTokens[key] = (self.hideTokens[key] or 0) + 1
    local frame = self.frames[key]
    if frame then
        frame:SetScript("OnUpdate", nil)
    end
    return self.hideTokens[key]
end

function Alerts:ScheduleHide(key, duration)
    self.hideTokens[key] = (self.hideTokens[key] or 0) + 1
    local token = self.hideTokens[key]
    C_Timer.After(duration, function()
        if self.hideTokens[key] == token then
            if not self.positioningMode then
                self.frames[key]:Hide()
            end
            self.frames[key]:SetScript("OnUpdate", nil)
        end
    end)
end

function Alerts:ShowDrinkingPreview(persistent, silent)
    local settings = WAA.db.modules.drinking
    local frame = self.frames.drinking
    local token = self:CancelHide("drinking")
    self.drinkingDisplayMode = "preview"
    SetFontSize(frame.text, settings.textSize)
    frame:Show()
    if settings.playSound and not silent then
        PlayAlertSound()
    end
    if persistent then
        return
    end

    C_Timer.After(settings.duration, function()
        if self.hideTokens.drinking ~= token or self.drinkingDisplayMode ~= "preview" then
            return
        end
        self.drinkingDisplayMode = nil
        if not self.positioningMode then
            frame:Hide()
        end
    end)
end

function Alerts:ShowDrinkingRuntime(playSound)
    local settings = WAA.db.modules.drinking
    self.drinkingRuntimeActive = true

    if playSound and settings.playSound then
        PlayAlertSound()
    end
    if self.positioningMode or self.drinkingDisplayMode == "preview" then
        return
    end

    local frame = self.frames.drinking
    local token = self:CancelHide("drinking")
    self.drinkingDisplayMode = "runtime"
    SetFontSize(frame.text, settings.textSize)
    frame:Show()

    C_Timer.After(settings.duration, function()
        if self.hideTokens.drinking ~= token or self.drinkingDisplayMode ~= "runtime" then
            return
        end
        self.drinkingDisplayMode = nil
        if not self.positioningMode then
            frame:Hide()
        end
    end)
end

function Alerts:HideDrinkingRuntime()
    self.drinkingRuntimeActive = false
    if self.drinkingDisplayMode ~= "runtime" then
        return
    end
    self:CancelHide("drinking")
    self.frames.drinking:Hide()
    self.drinkingDisplayMode = nil
end

function Alerts:ShowScatterPreview()
    local settings = WAA.db.modules.scatter
    if not settings.flashEnabled then
        return
    end
    local frame = self.frames.scatter
    local token = self:CancelHide("scatter")
    self.scatterDisplayMode = "preview"
    frame:SetAlpha(settings.opacity)
    frame:Show()
    C_Timer.After(settings.duration, function()
        if self.hideTokens.scatter ~= token or self.scatterDisplayMode ~= "preview" then
            return
        end
        self.scatterDisplayMode = nil
        frame:Hide()
    end)
end

function Alerts:ShowScatterRuntime()
    local settings = WAA.db.modules.scatter
    if not settings.flashEnabled then
        return false
    end

    local frame = self.frames.scatter
    local token = self:CancelHide("scatter")
    self.scatterDisplayMode = "runtime"
    frame:SetAlpha(settings.opacity)
    frame:Show()
    C_Timer.After(settings.duration, function()
        if self.hideTokens.scatter ~= token or self.scatterDisplayMode ~= "runtime" then
            return
        end
        self.scatterDisplayMode = nil
        frame:Hide()
    end)
    return true
end

function Alerts:HideScatterRuntime()
    if self.scatterDisplayMode ~= "runtime" then
        return
    end
    self:CancelHide("scatter")
    self.frames.scatter:Hide()
    self.scatterDisplayMode = nil
end

function Alerts:ApplyInnerFireSettings(state, charges)
    local settings = WAA.db.modules.innerFire
    local frame = self.frames.innerFire
    frame:SetSize(settings.iconSize + 36, settings.iconSize + 36)
    frame.icon:SetSize(settings.iconSize, settings.iconSize)
    frame.redOverlay:Show()

    if state == "MISSING" then
        frame.count:Hide()
        frame.missing:Show()
    else
        frame.count:SetText(tostring(charges or settings.threshold))
        frame.missing:Hide()
        if settings.showStackCount then
            frame.count:Show()
        else
            frame.count:Hide()
        end
    end
end

function Alerts:ShowInnerFirePreview(persistent)
    local frame = self.frames.innerFire
    local token = self:CancelHide("innerFire")
    self.innerFireDisplayMode = "preview"
    self:ApplyInnerFireSettings("LOW", WAA.db.modules.innerFire.threshold)
    frame:Show()
    if persistent then
        return
    end

    C_Timer.After(4, function()
        if self.hideTokens.innerFire ~= token or self.innerFireDisplayMode ~= "preview" then
            return
        end
        self.innerFireDisplayMode = nil
        if self.innerFireRuntimeActive and WAA.InnerFire then
            WAA.InnerFire:RefreshVisual()
        elseif not self.positioningMode then
            frame:Hide()
        end
    end)
end

function Alerts:ShowInnerFireRuntime(state, charges)
    self.innerFireRuntimeActive = true
    if self.positioningMode or self.innerFireDisplayMode == "preview" then
        return
    end

    local frame = self.frames.innerFire
    self:CancelHide("innerFire")
    self.innerFireDisplayMode = "runtime"
    self:ApplyInnerFireSettings(state, charges)
    if not frame:IsShown() then
        frame:Show()
    end
end

function Alerts:HideInnerFireRuntime()
    self.innerFireRuntimeActive = false
    if self.innerFireDisplayMode ~= "runtime" then
        return
    end
    self:CancelHide("innerFire")
    self.frames.innerFire:Hide()
    self.innerFireDisplayMode = nil
end

function Alerts:FormatShortNumber(value)
    return FormatShortNumber(value)
end

function Alerts:TrySetShieldValue(value, isSecret)
    local frame = self.frames.shieldAbsorb
    if isSecret then
        local ok = pcall(function()
            frame.value:SetText(value)
        end)
        return ok
    end

    local text = "?"
    if value ~= nil then
        if WAA.db.modules.shieldAbsorb.numberFormat == "SHORT" then
            text = self:FormatShortNumber(value)
        else
            text = tostring(value)
        end
    end
    frame.value:SetText(text)
    return true
end

function Alerts:ApplyShieldLayout()
    local settings = WAA.db.modules.shieldAbsorb
    local frame = self.frames.shieldAbsorb
    local mode = settings.displayMode or "ICON_NUMBER"
    local barWidth = 150
    local barHeight = math.max(20, settings.textSize)

    frame.icon:ClearAllPoints()
    frame.bar:ClearAllPoints()
    frame.value:ClearAllPoints()
    frame.icon:SetSize(settings.iconSize, settings.iconSize)

    if mode == "BAR_NUMBER" then
        frame:SetSize(barWidth, barHeight)
        frame.icon:Hide()
        frame.bar:SetSize(barWidth, barHeight)
        frame.bar:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.value:SetPoint("CENTER", frame.bar, "CENTER", 0, 0)
        frame.bar:Show()
    elseif mode == "ICON_BAR" then
        frame:SetSize(settings.iconSize + barWidth + 24, math.max(settings.iconSize, barHeight))
        frame.icon:SetPoint("LEFT", frame, "LEFT", 8, 0)
        frame.icon:Show()
        frame.bar:SetSize(barWidth, barHeight)
        frame.bar:SetPoint("LEFT", frame.icon, "RIGHT", 8, 0)
        frame.value:SetPoint("CENTER", frame.bar, "CENTER", 0, 0)
        frame.bar:Show()
    else
        frame:SetSize(settings.iconSize + 86, settings.iconSize + 36)
        frame.icon:SetPoint("LEFT", frame, "LEFT", 8, 0)
        frame.icon:Show()
        frame.value:SetPoint("LEFT", frame.icon, "RIGHT", 7, 0)
        frame.bar:Hide()
    end
end

function Alerts:ApplyShieldBarFill(fillFraction)
    local bar = self.frames.shieldAbsorb.bar
    if type(fillFraction) ~= "number" then
        bar:SetValue(0)
        bar:SetStatusBarColor(0.28, 0.38, 0.46, 0.75)
        return
    end

    local clamped = math.max(0, math.min(1, fillFraction))
    bar:SetValue(clamped)
    bar:SetStatusBarColor(1 - clamped, clamped, 0, 0.95)
end

function Alerts:ApplyShieldSettings(value, isSecret, texture, fillFraction)
    local settings = WAA.db.modules.shieldAbsorb
    local frame = self.frames.shieldAbsorb
    self:ApplyShieldLayout()
    frame.icon:SetTexture(texture or GetSpellIcon(SPELLS.shieldAbsorb, FALLBACK_ICONS.shieldAbsorb))
    SetFontSize(frame.value, settings.textSize)
    self:ApplyShieldBarFill(fillFraction)
    return self:TrySetShieldValue(value, isSecret)
end

function Alerts:ShowShieldPreview(persistent)
    local frame = self.frames.shieldAbsorb
    local token = self:CancelHide("shieldAbsorb")
    self.shieldDisplayMode = "preview"
    self:ApplyShieldSettings(1847, false, nil, 1847 / 2500)
    frame:Show()
    if persistent then
        return
    end

    C_Timer.After(4, function()
        if self.hideTokens.shieldAbsorb ~= token or self.shieldDisplayMode ~= "preview" then
            return
        end
        self.shieldDisplayMode = nil
        if self.shieldRuntimeActive and WAA.ShieldAbsorb then
            WAA.ShieldAbsorb:RefreshVisual()
        elseif not self.positioningMode then
            frame:Hide()
        end
    end)
end

function Alerts:RefreshShieldPreview()
    if self.shieldDisplayMode == "preview" then
        self:ApplyShieldSettings(1847, false, nil, 1847 / 2500)
    end
end

function Alerts:ShowShieldRuntime(value, isSecret, texture, fillFraction)
    self.shieldRuntimeActive = true
    if self.positioningMode or self.shieldDisplayMode == "preview" then
        return true
    end

    local frame = self.frames.shieldAbsorb
    self:CancelHide("shieldAbsorb")
    self.shieldDisplayMode = "runtime"
    local displayed = self:ApplyShieldSettings(value, isSecret, texture, fillFraction)
    if not displayed then
        return false
    end
    if not frame:IsShown() then
        frame:Show()
    end
    return true
end

function Alerts:HideShieldRuntime()
    self.shieldRuntimeActive = false
    if self.shieldDisplayMode ~= "runtime" then
        return
    end
    self:CancelHide("shieldAbsorb")
    self.frames.shieldAbsorb:Hide()
    self.shieldDisplayMode = nil
end

function Alerts:ApplyOverpowerSettings()
    local settings = WAA.db.modules.enemyOverpower
    local frame = self.frames.enemyOverpower
    frame:SetSize(settings.iconSize + 82, settings.iconSize + 36)
    frame.icon:SetSize(settings.iconSize, settings.iconSize)
    if settings.showCountdown then
        frame.countdown:Show()
    else
        frame.countdown:Hide()
    end
end

function Alerts:ShowOverpowerPreview(persistent, silent)
    local settings = WAA.db.modules.enemyOverpower
    local frame = self.frames.enemyOverpower
    local token = self:CancelHide("enemyOverpower")
    self.overpowerDisplayMode = "preview"
    self:ApplyOverpowerSettings()
    local duration = GetOverpowerWindowSeconds()
    frame.countdown:SetText(string.format("%.1f", duration))
    frame:Show()
    if settings.playSound and not silent then
        PlayAlertSound()
    end

    if persistent then
        return
    end

    local startedAt = GetTime()
    self.overpowerUpdateElapsed = 0
    frame:SetScript("OnUpdate", function(current, elapsed)
        self.overpowerUpdateElapsed = self.overpowerUpdateElapsed + (elapsed or 0)
        if self.overpowerUpdateElapsed < 0.05 then
            return
        end
        self.overpowerUpdateElapsed = 0
        local remaining = math.max(0, duration - (GetTime() - startedAt))
        current.countdown:SetText(string.format("%.1f", remaining))
    end)
    C_Timer.After(duration, function()
        if self.hideTokens.enemyOverpower ~= token or self.overpowerDisplayMode ~= "preview" then
            return
        end
        frame:SetScript("OnUpdate", nil)
        self.overpowerDisplayMode = nil
        if self.overpowerRuntimeActive and WAA.EnemyOverpower then
            WAA.EnemyOverpower:RefreshVisual(false)
        elseif not self.positioningMode then
            frame:Hide()
        end
    end)
end

function Alerts:ShowOverpowerRuntime(remaining, playSound)
    local settings = WAA.db.modules.enemyOverpower
    self.overpowerRuntimeActive = true

    if playSound and settings.playSound then
        PlayAlertSound()
    end
    if self.positioningMode or self.overpowerDisplayMode == "preview" then
        return
    end

    if self.overpowerDisplayMode == "runtime" then
        self:UpdateOverpowerRuntime(remaining)
        return
    end

    local frame = self.frames.enemyOverpower
    self:CancelHide("enemyOverpower")
    self.overpowerDisplayMode = "runtime"
    self:ApplyOverpowerSettings()
    frame.countdown:SetText(string.format("%.1f", math.max(0, remaining or 0)))
    frame:Show()
    self.overpowerUpdateElapsed = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        self.overpowerUpdateElapsed = self.overpowerUpdateElapsed + (elapsed or 0)
        if self.overpowerUpdateElapsed < 0.05 then
            return
        end
        self.overpowerUpdateElapsed = 0
        if WAA.EnemyOverpower then
            WAA.EnemyOverpower:Update(GetTime())
        end
    end)
end

function Alerts:UpdateOverpowerRuntime(remaining)
    if self.overpowerDisplayMode ~= "runtime" then
        return
    end
    self:ApplyOverpowerSettings()
    self.frames.enemyOverpower.countdown:SetText(string.format("%.1f", math.max(0, remaining)))
end

function Alerts:HideOverpowerRuntime()
    self.overpowerRuntimeActive = false
    if self.overpowerDisplayMode ~= "runtime" then
        return
    end
    local frame = self.frames.enemyOverpower
    frame:SetScript("OnUpdate", nil)
    frame:Hide()
    self.overpowerDisplayMode = nil
end

function Alerts:TestAll()
    self:ShowDrinkingPreview()
    self:ShowScatterPreview()
    self:ShowInnerFirePreview()
    self:ShowShieldPreview()
    self:ShowOverpowerPreview()
end

function Alerts:HideAll()
    for key, frame in pairs(self.frames or {}) do
        self:CancelHide(key)
        frame:Hide()
    end
end

function Alerts:ClearRuntime()
    local keepPositioningMode = WAA.isUnlocked == true
    self:HideAll()
    self.drinkingRuntimeActive = false
    self.drinkingDisplayMode = nil
    self.innerFireRuntimeActive = false
    self.innerFireDisplayMode = nil
    self.shieldRuntimeActive = false
    self.shieldDisplayMode = nil
    self.overpowerRuntimeActive = false
    self.overpowerDisplayMode = nil
    self.scatterDisplayMode = nil

    if keepPositioningMode then
        self:UnlockFrames()
        return
    end

    self.positioningMode = false
    for _, key in ipairs(POSITION_KEYS) do
        self:SetPositioningStyle(self.frames[key], false)
    end
end

local _, WAA = ...

local Alerts = {}
WAA.Alerts = Alerts

local POSITION_KEYS = { "drinking", "innerFire", "shieldAbsorb", "enemyOverpower" }

local SPELLS = {
    drinking = 430,       -- Rank 1 Drink; only used to ask the client for its standard icon.
    scatter = 19503,
    innerFire = 25431,
    shieldAbsorb = 25218, -- TBC rank used for texture lookup only; detection will be rank-agnostic.
    enemyOverpower = 7384,
}

local FALLBACK_ICONS = {
    drinking = "Interface\\Icons\\INV_Drink_07",
    scatter = "Interface\\Icons\\Ability_GolemStormBolt",
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
    self.overpowerDisplayMode = nil
    self.overpowerRuntimeActive = false
    self.overpowerUpdateElapsed = 0

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
end

function Alerts:CreateShieldFrame()
    local frame = self:CreateMovableFrame("shieldAbsorb", 150, 116)
    local icon = self:CreateIcon(frame, "shieldAbsorb")
    icon:SetPoint("LEFT", frame, "LEFT", 8, 0)
    local value = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    value:SetPoint("LEFT", icon, "RIGHT", 7, 0)
    value:SetText("1847")
    value:SetTextColor(0.5, 0.85, 1)
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
    self.overpowerDisplayMode = nil
    if WAA.EnemyOverpower then
        WAA.EnemyOverpower:RefreshVisual(false)
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
    SetFontSize(frame.text, settings.textSize)
    frame:Show()
    if settings.playSound and not silent then
        PlayAlertSound()
    end
    if persistent then
        self:CancelHide("drinking")
    else
        self:ScheduleHide("drinking", settings.duration)
    end
end

function Alerts:ShowScatterPreview()
    local settings = WAA.db.modules.scatter
    if not settings.flashEnabled then
        return
    end
    local frame = self.frames.scatter
    frame:SetAlpha(settings.opacity)
    frame:Show()
    self:ScheduleHide("scatter", settings.duration)
end

function Alerts:ShowInnerFirePreview(persistent)
    local settings = WAA.db.modules.innerFire
    local frame = self.frames.innerFire
    frame:SetSize(settings.iconSize + 36, settings.iconSize + 36)
    frame.icon:SetSize(settings.iconSize, settings.iconSize)
    if settings.showStackCount then
        frame.count:Show()
    else
        frame.count:Hide()
    end
    frame:Show()
    if persistent then
        self:CancelHide("innerFire")
    else
        self:ScheduleHide("innerFire", 4)
    end
end

function Alerts:ShowShieldPreview(persistent)
    local settings = WAA.db.modules.shieldAbsorb
    local frame = self.frames.shieldAbsorb
    frame:SetSize(settings.iconSize + 86, settings.iconSize + 36)
    frame.icon:SetSize(settings.iconSize, settings.iconSize)
    SetFontSize(frame.value, settings.textSize)
    frame.value:SetText(settings.numberFormat == "SHORT" and FormatShortNumber(1847) or "1847")
    frame:Show()
    if persistent then
        self:CancelHide("shieldAbsorb")
    else
        self:ScheduleHide("shieldAbsorb", 4)
    end
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
    self.positioningMode = false
    WAA.isUnlocked = false
    self:HideAll()
    self.overpowerRuntimeActive = false
    self.overpowerDisplayMode = nil
    for _, key in ipairs(POSITION_KEYS) do
        self:SetPositioningStyle(self.frames[key], false)
    end
end

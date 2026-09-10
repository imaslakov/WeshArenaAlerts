local addonName, WAA = ...

local Options = {}
WAA.Options = Options

local NAV_ITEMS = {
    { key = "general", label = "General" },
    { key = "drinking", label = "Drinking" },
    { key = "scatter", label = "Scatter" },
    { key = "innerFire", label = "Inner Fire" },
    { key = "shieldAbsorb", label = "Shield Absorb" },
    { key = "enemyOverpower", label = "Enemy Overpower" },
}

local function AddBackground(frame, r, g, b, a)
    local texture = frame:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(r, g, b, a)
    return texture
end

local function CreateLabel(parent, text, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    label:SetText(text)
    label:SetJustifyH("LEFT")
    return label
end

function Options:Initialize()
    if self.initialized then
        return
    end

    self.refreshers = {}
    self.pages = {}
    self.navButtons = {}
    self:CreatePanel()
    self:RegisterSettingsCategory()
    self:RegisterSlashCommand()
    self.initialized = true
end

function Options:CreatePanel()
    local panel = CreateFrame("Frame")
    panel.name = addonName
    panel:SetSize(820, 610)
    panel.OnCommit = function() end
    panel.OnDefault = function()
        WAA:ResetAllSettings()
        self:Refresh()
    end
    panel.OnRefresh = function()
        self:Refresh()
    end
    self.panel = panel

    local title = CreateLabel(panel, "WeshArenaAlerts", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 22, -20)
    title:SetTextColor(0.2, 0.85, 1)

    local version = CreateLabel(panel, "Version " .. WAA.version, "GameFontHighlightSmall")
    version:SetPoint("LEFT", title, "RIGHT", 12, -2)
    version:SetTextColor(0.65, 0.65, 0.65)

    local subtitle = CreateLabel(panel, "Arena-only alerts • manual previews work anywhere", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -7)
    subtitle:SetTextColor(0.72, 0.72, 0.72)

    local nav = CreateFrame("Frame", nil, panel)
    nav:SetPoint("TOPLEFT", 22, -82)
    nav:SetPoint("BOTTOMLEFT", 22, 22)
    nav:SetWidth(174)
    AddBackground(nav, 0.025, 0.04, 0.055, 0.9)
    self.nav = nav

    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", nav, "TOPRIGHT", 14, 0)
    content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -22, 22)
    AddBackground(content, 0.035, 0.045, 0.055, 0.72)
    self.content = content

    for index, item in ipairs(NAV_ITEMS) do
        local button = CreateFrame("Button", nil, nav, "UIPanelButtonTemplate")
        button:SetSize(150, 34)
        button:SetPoint("TOP", 0, -12 - ((index - 1) * 42))
        button:SetText(item.label)
        button:SetScript("OnClick", function()
            self:SelectPage(item.key)
        end)
        self.navButtons[item.key] = button
    end

    self:BuildGeneralPage()
    self:BuildDrinkingPage()
    self:BuildScatterPage()
    self:BuildInnerFirePage()
    self:BuildShieldPage()
    self:BuildOverpowerPage()
    self:SelectPage("general")

    panel:SetScript("OnShow", function()
        self:Refresh()
    end)
end

function Options:CreatePage(key, titleText, description)
    local page = CreateFrame("Frame", nil, self.content)
    page:SetAllPoints()
    page:Hide()

    local title = CreateLabel(page, titleText, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 24, -20)
    title:SetTextColor(1, 0.82, 0.25)

    local body = CreateLabel(page, description, "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    body:SetPoint("RIGHT", page, "RIGHT", -24, 0)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetWordWrap(true)
    body:SetTextColor(0.68, 0.68, 0.68)

    self.pages[key] = page
    return page, -88
end

function Options:CreateCheckbox(parent, labelText, getter, setter, y)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", 20, y)
    checkbox:SetSize(28, 28)

    local label = CreateLabel(parent, labelText, "GameFontHighlight")
    label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)

    checkbox:SetScript("OnClick", function(current)
        setter(current:GetChecked() == true)
    end)
    table.insert(self.refreshers, function()
        checkbox:SetChecked(getter() == true)
    end)
    return checkbox
end

function Options:CreateButton(parent, labelText, onClick, x, y, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 150, 30)
    button:SetPoint("TOPLEFT", x or 20, y)
    button:SetText(labelText)
    button:SetScript("OnClick", onClick)
    return button
end

function Options:CreateSlider(parent, labelText, minimum, maximum, step, decimals, getter, setter, y)
    local label = CreateLabel(parent, labelText, "GameFontHighlight")
    label:SetPoint("TOPLEFT", 24, y)

    local valueLabel = CreateLabel(parent, "", "GameFontHighlight")
    valueLabel:SetPoint("TOPRIGHT", -28, y)
    valueLabel:SetTextColor(0.2, 0.85, 1)

    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(360, 18)
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -10)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", 0, 0)
    track:SetPoint("RIGHT", 0, 0)
    track:SetHeight(5)
    track:SetColorTexture(0.12, 0.18, 0.22, 1)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local thumb = slider:GetThumbTexture()
    if thumb then
        thumb:SetSize(18, 26)
    end

    slider:SetScript("OnValueChanged", function(_, value)
        local rounded = math.floor((value / step) + 0.5) * step
        valueLabel:SetText(string.format("%." .. decimals .. "f", rounded))
        setter(rounded)
    end)
    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(current, delta)
        current:SetValue(current:GetValue() + (delta * step))
    end)
    table.insert(self.refreshers, function()
        slider:SetValue(getter())
    end)
    return slider
end

function Options:CreateChoice(parent, labelText, choices, getter, setter, y)
    local label = CreateLabel(parent, labelText, "GameFontHighlight")
    label:SetPoint("TOPLEFT", 24, y)
    local buttons = {}

    for index, choice in ipairs(choices) do
        local button = self:CreateButton(parent, choice.label, function()
            setter(choice.value)
            self:Refresh()
        end, 24 + ((index - 1) * 126), y - 28, 116)
        buttons[choice.value] = button
    end

    table.insert(self.refreshers, function()
        local selected = getter()
        for value, button in pairs(buttons) do
            if value == selected then
                button:LockHighlight()
            else
                button:UnlockHighlight()
            end
        end
    end)
end

function Options:CreateTestArea(parent, callback, y)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 24, y)
    divider:SetPoint("RIGHT", parent, "RIGHT", -24, 0)
    divider:SetHeight(1)
    divider:SetColorTexture(0.16, 0.28, 0.34, 1)
    self:CreateButton(parent, "Test Alert", callback, 24, y - 24, 150)
end

function Options:BuildGeneralPage()
    local page = self:CreatePage(
        "general",
        "General & Positioning",
        "Automatic combat listeners are hard-limited to arena instances. Preview controls remain available everywhere."
    )
    self:CreateCheckbox(page, "Enable WeshArenaAlerts", function()
        return WAA.db.general.enabled
    end, function(value)
        WAA.db.general.enabled = value
    end, -92)

    local heading = CreateLabel(page, "Positioning / Preview", "GameFontNormal")
    heading:SetPoint("TOPLEFT", 24, -150)
    heading:SetTextColor(1, 0.82, 0.25)

    local help = CreateLabel(page, "Unlock shows the four positionable alerts. Drag each frame independently, then lock to save a clean screen.", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -7)
    help:SetPoint("RIGHT", page, "RIGHT", -24, 0)
    help:SetWordWrap(true)
    help:SetTextColor(0.68, 0.68, 0.68)

    self:CreateButton(page, "Unlock Frames", function()
        WAA.Alerts:UnlockFrames()
    end, 24, -213, 150)
    self:CreateButton(page, "Lock Frames", function()
        WAA.Alerts:LockFrames()
    end, 184, -213, 150)
    self:CreateButton(page, "Reset Positions", function()
        WAA:ResetPositions()
        if WAA.isUnlocked then
            WAA.Alerts:UnlockFrames()
        end
    end, 344, -213, 150)

    self:CreateButton(page, "Test All Alerts", function()
        WAA.Alerts:TestAll()
    end, 24, -269, 190)

    local status = CreateLabel(page, "", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", 24, -322)
    table.insert(self.refreshers, function()
        if WAA.isInArena then
            status:SetText("Arena runtime: ACTIVE")
            status:SetTextColor(0.25, 1, 0.35)
        else
            status:SetText("Arena runtime: inactive (previews still available)")
            status:SetTextColor(0.65, 0.65, 0.65)
        end
    end)
end

function Options:BuildDrinkingPage()
    local page = self:CreatePage("drinking", "Drinking", "Large warning text for an enemy player beginning to drink.")
    local db = function() return WAA.db.modules.drinking end
    self:CreateCheckbox(page, "Enabled", function() return db().enabled end, function(v) db().enabled = v end, -92)
    self:CreateCheckbox(page, "Play sound", function() return db().playSound end, function(v) db().playSound = v end, -128)
    self:CreateSlider(page, "Text size", 24, 72, 1, 0, function() return db().textSize end, function(v)
        db().textSize = v
        self:RefreshPositioningPreview("drinking")
    end, -184)
    self:CreateSlider(page, "Duration (seconds)", 0.5, 10, 0.5, 1, function() return db().duration end, function(v) db().duration = v end, -257)
    self:CreateTestArea(page, function() WAA.Alerts:ShowDrinkingPreview() end, -344)
end

function Options:BuildScatterPage()
    local page = self:CreatePage("scatter", "Scatter", "A brief red fullscreen flash. The overlay never accepts mouse input.")
    local db = function() return WAA.db.modules.scatter end
    self:CreateCheckbox(page, "Enabled", function() return db().enabled end, function(v) db().enabled = v end, -92)
    self:CreateCheckbox(page, "Flash enabled", function() return db().flashEnabled end, function(v) db().flashEnabled = v end, -128)
    self:CreateSlider(page, "Flash opacity", 0.1, 1, 0.05, 2, function() return db().opacity end, function(v) db().opacity = v end, -184)
    self:CreateSlider(page, "Flash duration (seconds)", 0.1, 3, 0.1, 1, function() return db().duration end, function(v) db().duration = v end, -257)
    self:CreateTestArea(page, function() WAA.Alerts:ShowScatterPreview() end, -344)
end

function Options:BuildInnerFirePage()
    local page = self:CreatePage("innerFire", "Inner Fire", "Priest self-warning foundation for low Inner Fire charges.")
    local db = function() return WAA.db.modules.innerFire end
    self:CreateCheckbox(page, "Enabled", function() return db().enabled end, function(v) db().enabled = v end, -92)
    self:CreateCheckbox(page, "Show stack count", function() return db().showStackCount end, function(v)
        db().showStackCount = v
        self:RefreshPositioningPreview("innerFire")
    end, -128)
    self:CreateSlider(page, "Warning threshold", 1, 20, 1, 0, function() return db().threshold end, function(v) db().threshold = v end, -184)
    self:CreateSlider(page, "Icon size", 32, 128, 2, 0, function() return db().iconSize end, function(v)
        db().iconSize = v
        self:RefreshPositioningPreview("innerFire")
    end, -257)
    self:CreateTestArea(page, function() WAA.Alerts:ShowInnerFirePreview() end, -344)
end

function Options:BuildShieldPage()
    local page = self:CreatePage("shieldAbsorb", "Shield Absorb", "Preview of remaining Power Word: Shield absorb on the player.")
    local db = function() return WAA.db.modules.shieldAbsorb end
    self:CreateCheckbox(page, "Enabled", function() return db().enabled end, function(v) db().enabled = v end, -92)
    self:CreateSlider(page, "Icon size", 32, 128, 2, 0, function() return db().iconSize end, function(v)
        db().iconSize = v
        self:RefreshPositioningPreview("shieldAbsorb")
    end, -148)
    self:CreateSlider(page, "Text size", 16, 48, 1, 0, function() return db().textSize end, function(v)
        db().textSize = v
        self:RefreshPositioningPreview("shieldAbsorb")
    end, -221)
    self:CreateChoice(page, "Number format", {
        { label = "Exact (1847)", value = "EXACT" },
        { label = "Short (1.8k)", value = "SHORT" },
    }, function() return db().numberFormat end, function(v)
        db().numberFormat = v
        self:RefreshPositioningPreview("shieldAbsorb")
    end, -294)
    self:CreateTestArea(page, function() WAA.Alerts:ShowShieldPreview() end, -381)
end

function Options:BuildOverpowerPage()
    local page = self:CreatePage(
        "enemyOverpower",
        "Enemy Overpower",
        "Shows a future opportunity window after an enemy Warrior's melee attack is dodged; it does not represent your own Overpower."
    )
    local db = function() return WAA.db.modules.enemyOverpower end
    self:CreateCheckbox(page, "Enabled", function() return db().enabled end, function(v) db().enabled = v end, -92)
    self:CreateCheckbox(page, "Show countdown", function() return db().showCountdown end, function(v)
        db().showCountdown = v
        self:RefreshPositioningPreview("enemyOverpower")
    end, -128)
    self:CreateCheckbox(page, "Play sound", function() return db().playSound end, function(v) db().playSound = v end, -164)
    self:CreateSlider(page, "Icon size", 32, 128, 2, 0, function() return db().iconSize end, function(v)
        db().iconSize = v
        self:RefreshPositioningPreview("enemyOverpower")
    end, -220)
    self:CreateTestArea(page, function() WAA.Alerts:ShowOverpowerPreview() end, -307)
end

function Options:RefreshPositioningPreview(key)
    if not WAA.isUnlocked then
        return
    end
    if key == "drinking" then
        WAA.Alerts:ShowDrinkingPreview(true, true)
    elseif key == "innerFire" then
        WAA.Alerts:ShowInnerFirePreview(true)
    elseif key == "shieldAbsorb" then
        WAA.Alerts:ShowShieldPreview(true)
    elseif key == "enemyOverpower" then
        WAA.Alerts:ShowOverpowerPreview(true, true)
    end
end

function Options:SelectPage(key)
    for pageKey, page in pairs(self.pages) do
        if pageKey == key then
            page:Show()
            self.navButtons[pageKey]:LockHighlight()
        else
            page:Hide()
            self.navButtons[pageKey]:UnlockHighlight()
        end
    end
    self.selectedPage = key
    self:Refresh()
end

function Options:Refresh()
    for _, refresh in ipairs(self.refreshers) do
        refresh()
    end
end

function Options:RegisterSettingsCategory()
    if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then
        WAA:Print("The Blizzard Settings API is unavailable; the options page could not be registered.")
        return
    end

    self.category = Settings.RegisterCanvasLayoutCategory(self.panel, addonName)
    if self.category then
        Settings.RegisterAddOnCategory(self.category)
    end
end

function Options:Open()
    if not self.category or not Settings or not Settings.OpenToCategory then
        WAA:Print("The settings page is not available yet.")
        return
    end

    local categoryID = self.category.GetID and self.category:GetID() or self.category.ID
    if categoryID then
        Settings.OpenToCategory(categoryID)
    else
        WAA:Print("The settings category has no valid ID.")
    end
end

function Options:RegisterSlashCommand()
    SLASH_WESHARENAALERTS1 = "/waa"
    SlashCmdList.WESHARENAALERTS = function()
        self:Open()
    end
end

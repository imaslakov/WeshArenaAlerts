local addonName, WAA = ...

WAA.name = addonName
WAA.version = "0.9.0"
WAA.isInArena = false
WAA.isUnlocked = false
WAA.initialized = false

local function CopyDefaults(defaults, target)
    if type(target) ~= "table" then
        target = {}
    end

    for key, defaultValue in pairs(defaults) do
        if type(defaultValue) == "table" then
            target[key] = CopyDefaults(defaultValue, target[key])
        elseif target[key] == nil then
            target[key] = defaultValue
        end
    end

    return target
end

local function CopyTable(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = type(value) == "table" and CopyTable(value) or value
    end
    return copy
end

function WAA:ApplyDefaults()
    if type(WeshArenaAlertsDB) ~= "table" then
        WeshArenaAlertsDB = {}
    end

    WeshArenaAlertsDB = CopyDefaults(self.Defaults, WeshArenaAlertsDB)
    WeshArenaAlertsDB.general.debug = nil
    WeshArenaAlertsDB.debugLog = nil
    self.db = WeshArenaAlertsDB
end

function WAA:ResetPositions()
    self.db.positions = CopyTable(self.Defaults.positions)
    if self.Alerts then
        self.Alerts:ApplyAllPositions()
    end
end

function WAA:ResetAllSettings()
    WeshArenaAlertsDB = CopyTable(self.Defaults)
    self.db = WeshArenaAlertsDB
    self.Alerts:ApplyAllPositions()
    if self.Drinking then
        self.Drinking:OnSettingsChanged()
    end
    if self.InnerFire then
        self.InnerFire:OnSettingsChanged()
    end
    if self.ShieldAbsorb then
        self.ShieldAbsorb:OnSettingsChanged()
    end
    if self.EnemyOverpower then
        self.EnemyOverpower:OnSettingsChanged()
    end
    if self.ExecuteRange then
        self.ExecuteRange:OnSettingsChanged()
    end
    if self.Scatter then
        self.Scatter:OnSettingsChanged()
    end
    if self.WyvernSting then
        self.WyvernSting:OnSettingsChanged()
    end
    if self.ClassIcon then
        self.ClassIcon:OnSettingsChanged()
    end
    if self.isUnlocked then
        self.Alerts:UnlockFrames()
    end
end

function WAA:IsModuleEnabled(moduleKey)
    local moduleSettings = self.db and self.db.modules and self.db.modules[moduleKey]
    return self.db
        and self.db.general.enabled == true
        and moduleSettings
        and moduleSettings.enabled == true
end

local function IsSecretDebugValue(value)
    if type(hasanysecretvalues) == "function" then
        local ok, result = pcall(hasanysecretvalues, value)
        if ok and result then
            return true
        end
    end
    if type(issecretvalue) == "function" then
        local ok, result = pcall(issecretvalue, value)
        if ok and result then
            return true
        end
    end
    return false
end

function WAA:Debug(...)
    if not self.db or not self.db.general or self.db.general.showDebugMessages ~= true then
        return
    end

    local parts = {}
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        parts[index] = IsSecretDebugValue(value) and "<secret>" or tostring(value)
    end
    print("|cff33ff99WAA:|r " .. table.concat(parts, " "))
end

function WAA:Print(message)
    print("|cff33ff99WeshArenaAlerts:|r " .. tostring(message))
end

function WAA:Initialize()
    if self.initialized then
        return
    end

    self:ApplyDefaults()
    self.Alerts:Initialize()
    self.Arena:Initialize()
    self.ClassIcon:Initialize()
    self.ExecuteRange:Initialize()
    self.EnemyOverpower:Initialize()
    self.Drinking:Initialize()
    self.InnerFire:Initialize()
    self.ShieldAbsorb:Initialize()
    self.Scatter:Initialize()
    self.WyvernSting:Initialize()
    self.initialized = true
    self:Debug("Initialized", self.version)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        WAA:Initialize()
        eventFrame:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        if not WAA.initialized then
            WAA:Initialize()
        end
        WAA.Options:Initialize()
        eventFrame:UnregisterEvent("PLAYER_LOGIN")
    end
end)

local addonName, WAA = ...

WAA.name = addonName
WAA.version = "0.1.0"
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
    self.db = WeshArenaAlertsDB
    self.debugEnabled = self.db.general.debug == true
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
    self.debugEnabled = self.db.general.debug == true
    self.Alerts:ApplyAllPositions()
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

function WAA:Debug(...)
    if not self.debugEnabled then
        return
    end

    local parts = {}
    for index = 1, select("#", ...) do
        parts[index] = tostring(select(index, ...))
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

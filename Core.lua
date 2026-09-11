local addonName, WAA = ...

WAA.name = addonName
WAA.version = "0.7.0"
WAA.isInArena = false
WAA.isUnlocked = false
WAA.initialized = false
WAA.DEBUG_LOG_MAX_ENTRIES = 500

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
    if self.Scatter then
        self.Scatter:OnSettingsChanged()
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

local function GetDebugTimestamp()
    if type(date) == "function" then
        local ok, timestamp = pcall(date, "%Y-%m-%d %H:%M:%S")
        if ok and type(timestamp) == "string" then
            return timestamp
        end
    end
    if type(GetTime) == "function" then
        local ok, elapsed = pcall(GetTime)
        if ok and type(elapsed) == "number" then
            return string.format("session+%.3f", elapsed)
        end
    end
    return "time-unavailable"
end

function WAA:IsDebugLogEnabled()
    return self.db
        and self.db.debugLog
        and self.db.debugLog.enabled == true
end

function WAA:AppendDebugLog(message)
    if not self:IsDebugLogEnabled() then
        return
    end

    local log = self.db.debugLog
    if type(log.entries) ~= "table" then
        log.entries = {}
    end
    log.entries[#log.entries + 1] = "[" .. GetDebugTimestamp() .. "] " .. tostring(message)
    while #log.entries > self.DEBUG_LOG_MAX_ENTRIES do
        table.remove(log.entries, 1)
    end
end

function WAA:StartDebugLog()
    self.db.debugLog.entries = {}
    self.db.debugLog.enabled = true
    self:AppendDebugLog("WeshArenaAlerts log started version=" .. tostring(self.version))
end

function WAA:StopDebugLog()
    if self:IsDebugLogEnabled() then
        self:AppendDebugLog("WeshArenaAlerts log stopped")
    end
    self.db.debugLog.enabled = false
end

function WAA:ClearDebugLog()
    self.db.debugLog.entries = {}
end

function WAA:GetDebugLogEntryCount()
    local entries = self.db and self.db.debugLog and self.db.debugLog.entries
    return type(entries) == "table" and #entries or 0
end

function WAA:Debug(...)
    local shouldPrint = self.debugEnabled == true
    if not shouldPrint and not self:IsDebugLogEnabled() then
        return
    end

    local parts = {}
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        parts[index] = IsSecretDebugValue(value) and "<secret>" or tostring(value)
    end
    local message = table.concat(parts, " ")
    if self:IsDebugLogEnabled() then
        self:AppendDebugLog(message)
    end
    if shouldPrint then
        print("|cff33ff99WAA:|r " .. message)
    end
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
    self.EnemyOverpower:Initialize()
    self.Drinking:Initialize()
    self.InnerFire:Initialize()
    self.ShieldAbsorb:Initialize()
    self.Scatter:Initialize()
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

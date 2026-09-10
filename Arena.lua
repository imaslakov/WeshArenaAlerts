local _, WAA = ...

local Arena = {}
WAA.Arena = Arena

local ARENA_UNITS = { "arena1", "arena2", "arena3", "arena4", "arena5" }

function Arena:Initialize()
    if self.initialized then
        return
    end

    self.opponents = {}
    self.opponentsByGUID = {}
    self.runtimeEvents = {}

    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            self:UpdateArenaState()
        elseif event == "ARENA_OPPONENT_UPDATE" then
            self:UpdateOpponent(...)
        else
            self:DispatchRuntimeEvent(event, ...)
        end
    end)

    self.initialized = true
    self:UpdateArenaState()
end

function Arena:UpdateArenaState()
    local inInstance, instanceType = IsInInstance()
    local isInArena = inInstance == true and instanceType == "arena"

    if isInArena == WAA.isInArena then
        if isInArena then
            self:RefreshOpponents()
        end
        return
    end

    WAA.isInArena = isInArena
    if isInArena then
        self:Activate()
    else
        self:Deactivate()
    end
end

function Arena:Activate()
    self.eventFrame:RegisterEvent("ARENA_OPPONENT_UPDATE")
    self:RefreshOpponents()
    self:RefreshRuntimeRegistrations()
    WAA:Debug("Arena runtime activated")
end

function Arena:Deactivate()
    self.eventFrame:UnregisterEvent("ARENA_OPPONENT_UPDATE")
    self:UnregisterRuntimeEvents()
    if WAA.EnemyOverpower then
        WAA.EnemyOverpower:ClearRuntime()
    end
    self:ClearOpponentData()
    WAA.Alerts:ClearRuntime()
    WAA:Debug("Arena runtime deactivated")
end

function Arena:ClearOpponentData()
    wipe(self.opponents)
    wipe(self.opponentsByGUID)
end

function Arena:UpdateOpponent(unitToken, updateType)
    if not WAA.isInArena or not unitToken then
        return
    end

    local wasRemoved = updateType == "cleared" or updateType == "destroyed"
    local guid = not wasRemoved and UnitGUID(unitToken) or nil
    local old = self.opponents[unitToken]
    if old and old.guid and old.guid ~= guid then
        self.opponentsByGUID[old.guid] = nil
        if WAA.EnemyOverpower then
            WAA.EnemyOverpower:RemoveOpponent(old.guid)
        end
    end

    if not guid then
        self.opponents[unitToken] = nil
        return
    end

    local className, classFile, classID = UnitClass(unitToken)
    local metadata = {
        unit = unitToken,
        guid = guid,
        className = className,
        classFile = classFile,
        classID = classID,
        name = UnitName and UnitName(unitToken) or nil,
    }
    self.opponents[unitToken] = metadata
    self.opponentsByGUID[guid] = metadata
    WAA:Debug(
        "Arena opponent mapped:",
        unitToken,
        guid,
        classFile or "UNKNOWN",
        metadata.name or "UNKNOWN"
    )
end

function Arena:RefreshOpponents()
    if not WAA.isInArena then
        return
    end
    for _, unitToken in ipairs(ARENA_UNITS) do
        self:UpdateOpponent(unitToken)
    end
end

function Arena:GetOpponentByGUID(guid)
    return guid and self.opponentsByGUID[guid] or nil
end

-- Future detector modules can declare combat events here. They are registered only
-- while the arena runtime is active, so CLEU can never idle in cities or battlegrounds.
function Arena:RegisterRuntimeEvent(owner, event, callback)
    if not owner or not event or type(callback) ~= "function" then
        return
    end
    self.runtimeEvents[event] = self.runtimeEvents[event] or {}
    self.runtimeEvents[event][owner] = callback
    if WAA.isInArena then
        self.eventFrame:RegisterEvent(event)
    end
end

function Arena:UnregisterRuntimeEvent(owner, event)
    local callbacks = self.runtimeEvents[event]
    if not callbacks then
        return
    end
    callbacks[owner] = nil
    if not next(callbacks) then
        self.runtimeEvents[event] = nil
        self.eventFrame:UnregisterEvent(event)
    end
end

function Arena:RefreshRuntimeRegistrations()
    for event in pairs(self.runtimeEvents) do
        self.eventFrame:RegisterEvent(event)
    end
end

function Arena:UnregisterRuntimeEvents()
    for event in pairs(self.runtimeEvents) do
        self.eventFrame:UnregisterEvent(event)
    end
end

function Arena:DispatchRuntimeEvent(event, ...)
    if not WAA.isInArena or not WAA.db.general.enabled then
        return
    end
    local callbacks = self.runtimeEvents[event]
    if not callbacks then
        return
    end
    for owner, callback in pairs(callbacks) do
        callback(owner, event, ...)
    end
end

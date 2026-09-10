local _, WAA = ...

local EnemyOverpower = {}
WAA.EnemyOverpower = EnemyOverpower

local OVERPOWER_WINDOW_SECONDS = 5.0
local OVERPOWER_SPELL_IDS = {
    [7384] = true,
    [7887] = true,
    [11584] = true,
    [11585] = true,
}

EnemyOverpower.OVERPOWER_WINDOW_SECONDS = OVERPOWER_WINDOW_SECONDS
EnemyOverpower.OVERPOWER_SPELL_IDS = OVERPOWER_SPELL_IDS

function EnemyOverpower:Initialize()
    if self.initialized then
        return
    end

    self.activeOpportunities = {}
    self.nextGeneration = 0
    WAA.Arena:RegisterRuntimeEvent(self, "COMBAT_LOG_EVENT_UNFILTERED", self.OnCombatLogEvent)
    self.initialized = true
end

function EnemyOverpower:ParseCombatLogEvent(...)
    local eventType = select(2, ...)
    local parsed = {
        eventType = eventType,
        sourceGUID = select(4, ...),
        destGUID = select(8, ...),
    }

    if eventType == "SWING_MISSED" then
        parsed.missType = select(12, ...)
    elseif eventType == "SPELL_MISSED" then
        parsed.spellID = select(12, ...)
        parsed.missType = select(15, ...)
    elseif eventType == "SPELL_CAST_SUCCESS" or eventType == "SPELL_DAMAGE" then
        parsed.spellID = select(12, ...)
    end

    return parsed
end

function EnemyOverpower:OnCombatLogEvent()
    self:HandleCombatLogEvent(self:ParseCombatLogEvent(CombatLogGetCurrentEventInfo()))
end

function EnemyOverpower:HandleCombatLogEvent(event)
    if not event or not WAA.isInArena or not WAA:IsModuleEnabled("enemyOverpower") then
        return
    end

    local isMissEvent = event.eventType == "SWING_MISSED" or event.eventType == "SPELL_MISSED"
    if isMissEvent then
        WAA:Debug(
            "CLEU " .. event.eventType .. ":",
            "source=" .. tostring(event.sourceGUID),
            "dest=" .. tostring(event.destGUID),
            "miss=" .. tostring(event.missType)
        )
    end

    local opponent = WAA.Arena:GetOpponentByGUID(event.sourceGUID)
    if not opponent or opponent.classFile ~= "WARRIOR" then
        if (isMissEvent and event.missType == "DODGE") or OVERPOWER_SPELL_IDS[event.spellID] then
            WAA:Debug("Enemy Overpower ignored: source is not mapped enemy Warrior", tostring(event.sourceGUID))
        end
        return
    end

    if OVERPOWER_SPELL_IDS[event.spellID]
        and (event.eventType == "SPELL_CAST_SUCCESS"
            or event.eventType == "SPELL_DAMAGE"
            or event.eventType == "SPELL_MISSED") then
        self:ConsumeOpportunity(event.sourceGUID, event.spellID)
        return
    end

    if isMissEvent
        and event.missType == "DODGE"
        and event.destGUID == UnitGUID("player") then
        self:StartOpportunity(event.sourceGUID, GetTime())
    end
end

function EnemyOverpower:StartOpportunity(warriorGUID, now)
    local existing = self.activeOpportunities[warriorGUID]
    self.nextGeneration = self.nextGeneration + 1
    local generation = self.nextGeneration
    local expiresAt = now + OVERPOWER_WINDOW_SECONDS

    self.activeOpportunities[warriorGUID] = {
        expiresAt = expiresAt,
        generation = generation,
    }

    if existing then
        WAA:Debug("Enemy Overpower opportunity REFRESH:", "warrior=" .. warriorGUID, "expires=" .. expiresAt)
    else
        WAA:Debug("Enemy Overpower opportunity START:", "warrior=" .. warriorGUID, "expires=" .. expiresAt)
    end

    C_Timer.After(OVERPOWER_WINDOW_SECONDS, function()
        local current = self.activeOpportunities[warriorGUID]
        if current and current.generation == generation then
            self:ExpireOpportunity(warriorGUID)
        end
    end)

    self:RefreshVisual(true, now)
end

function EnemyOverpower:ConsumeOpportunity(warriorGUID, spellID)
    if not self.activeOpportunities[warriorGUID] then
        return
    end
    self.activeOpportunities[warriorGUID] = nil
    WAA:Debug("Enemy Overpower opportunity CONSUMED:", "warrior=" .. warriorGUID, "spellID=" .. spellID)
    self:RefreshVisual(false)
end

function EnemyOverpower:ExpireOpportunity(warriorGUID)
    if not self.activeOpportunities[warriorGUID] then
        return
    end
    self.activeOpportunities[warriorGUID] = nil
    WAA:Debug("Enemy Overpower opportunity EXPIRED:", "warrior=" .. warriorGUID)
    self:RefreshVisual(false)
end

function EnemyOverpower:RemoveOpponent(warriorGUID)
    if self.activeOpportunities and self.activeOpportunities[warriorGUID] then
        self.activeOpportunities[warriorGUID] = nil
        self:RefreshVisual(false)
    end
end

function EnemyOverpower:GetDisplayRemaining(now)
    local longestRemaining
    for _, opportunity in pairs(self.activeOpportunities) do
        local remaining = opportunity.expiresAt - now
        if remaining > 0 and (not longestRemaining or remaining > longestRemaining) then
            longestRemaining = remaining
        end
    end
    return longestRemaining
end

function EnemyOverpower:Update(now)
    local expiredGUIDs = {}
    for warriorGUID, opportunity in pairs(self.activeOpportunities) do
        if opportunity.expiresAt <= now then
            expiredGUIDs[#expiredGUIDs + 1] = warriorGUID
        end
    end
    for _, warriorGUID in ipairs(expiredGUIDs) do
        self.activeOpportunities[warriorGUID] = nil
        WAA:Debug("Enemy Overpower opportunity EXPIRED:", "warrior=" .. warriorGUID)
    end
    self:RefreshVisual(false, now)
end

function EnemyOverpower:RefreshVisual(playSound, now)
    now = now or GetTime()
    if not WAA.isInArena or not WAA:IsModuleEnabled("enemyOverpower") then
        self:ClearRuntime()
        return
    end

    local remaining = self:GetDisplayRemaining(now)
    if remaining then
        WAA.Alerts:ShowOverpowerRuntime(remaining, playSound)
    else
        WAA.Alerts:UpdateOverpowerRuntime(0)
        WAA.Alerts:HideOverpowerRuntime()
    end
end

function EnemyOverpower:OnSettingsChanged()
    if not WAA:IsModuleEnabled("enemyOverpower") then
        self:ClearRuntime()
    else
        self:RefreshVisual(false)
    end
end

function EnemyOverpower:ClearRuntime()
    self.nextGeneration = (self.nextGeneration or 0) + 1
    if self.activeOpportunities then
        wipe(self.activeOpportunities)
    end
    if WAA.Alerts then
        WAA.Alerts:HideOverpowerRuntime()
    end
end

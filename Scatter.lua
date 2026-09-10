local _, WAA = ...

local Scatter = {}
WAA.Scatter = Scatter

local SCATTER_SHOT_SPELL_ID = 19503
local SCATTER_EVENT_DEDUP_SECONDS = 0.5
local ARENA_UNIT_PATTERN = "^arena[1-5]$"

Scatter.SCATTER_SHOT_SPELL_ID = SCATTER_SHOT_SPELL_ID
Scatter.SCATTER_EVENT_DEDUP_SECONDS = SCATTER_EVENT_DEDUP_SECONDS

local function IsArenaUnit(unit)
    return type(unit) == "string" and unit:match(ARENA_UNIT_PATTERN) ~= nil
end

local function FindSpellID(...)
    for index = select("#", ...), 1, -1 do
        local value = select(index, ...)
        if type(value) == "number" then
            return value
        end
    end
end

function Scatter:Initialize()
    if self.initialized then
        return
    end

    self.lastScatterCast = {}
    WAA.Arena:RegisterRuntimeEvent(self, "UNIT_SPELLCAST_SUCCEEDED", self.OnUnitSpellcastSucceeded)
    WAA.Arena:RegisterRuntimeEvent(self, "COMBAT_LOG_EVENT_UNFILTERED", self.OnCombatLogEvent)
    self.initialized = true
end

function Scatter:ParseUnitSpellcastSucceeded(unit, ...)
    return unit, FindSpellID(...)
end

function Scatter:ResolveUnitOpponent(unit)
    if not IsArenaUnit(unit) then
        return nil, nil
    end

    local guid = UnitGUID(unit)
    local opponent = guid and WAA.Arena:GetOpponentByGUID(guid) or nil
    if not guid or not opponent or opponent.unit ~= unit then
        WAA.Arena:UpdateOpponent(unit)
        guid = UnitGUID(unit)
        opponent = guid and WAA.Arena:GetOpponentByGUID(guid) or nil
    end

    if not opponent or opponent.unit ~= unit then
        return guid, nil
    end
    return guid, opponent
end

function Scatter:OnUnitSpellcastSucceeded(_, unit, ...)
    if not WAA.isInArena or not WAA:IsModuleEnabled("scatter") or not IsArenaUnit(unit) then
        return
    end

    local parsedUnit, spellID = self:ParseUnitSpellcastSucceeded(unit, ...)
    if spellID ~= SCATTER_SHOT_SPELL_ID then
        return
    end

    local guid = UnitGUID(parsedUnit)
    WAA:Debug(
        "Scatter UNIT_SPELLCAST_SUCCEEDED:",
        "unit=" .. tostring(parsedUnit),
        "spellID=" .. tostring(spellID),
        "guid=" .. tostring(guid)
    )

    local opponent
    guid, opponent = self:ResolveUnitOpponent(parsedUnit)
    if not opponent or opponent.classFile ~= "HUNTER" then
        WAA:Debug("Scatter ignored: source is not mapped enemy Hunter", tostring(guid))
        return
    end

    self:HandleCast(guid, parsedUnit, "UNIT_SPELLCAST_SUCCEEDED")
end

function Scatter:ParseCombatLogEvent(...)
    return {
        eventType = select(2, ...),
        sourceGUID = select(4, ...),
        spellID = select(12, ...),
    }
end

function Scatter:OnCombatLogEvent()
    self:HandleCombatLogEvent(self:ParseCombatLogEvent(CombatLogGetCurrentEventInfo()))
end

function Scatter:HandleCombatLogEvent(event)
    if not event
        or event.eventType ~= "SPELL_CAST_SUCCESS"
        or event.spellID ~= SCATTER_SHOT_SPELL_ID
        or not WAA.isInArena
        or not WAA:IsModuleEnabled("scatter") then
        return false
    end

    WAA:Debug(
        "Scatter SPELL_CAST_SUCCESS:",
        "guid=" .. tostring(event.sourceGUID),
        "spellID=" .. tostring(event.spellID)
    )
    return self:HandleCast(event.sourceGUID, nil, "CLEU")
end

function Scatter:HandleCast(sourceGUID, unit, sourceType)
    if not WAA.isInArena or not WAA:IsModuleEnabled("scatter") or not sourceGUID then
        return false
    end

    local opponent = WAA.Arena:GetOpponentByGUID(sourceGUID)
    if not opponent
        or opponent.classFile ~= "HUNTER"
        or (unit and opponent.unit ~= unit) then
        WAA:Debug("Scatter ignored: source is not mapped enemy Hunter", tostring(sourceGUID))
        return false
    end

    local now = GetTime()
    local lastCastAt = self.lastScatterCast[sourceGUID]
    if lastCastAt and now - lastCastAt < SCATTER_EVENT_DEDUP_SECONDS then
        WAA:Debug(
            "Scatter duplicate cast ignored:",
            "guid=" .. sourceGUID,
            "source=" .. tostring(sourceType)
        )
        return false
    end

    self.lastScatterCast[sourceGUID] = now
    WAA:Debug(
        "Scatter CAST:",
        "hunter=" .. tostring(opponent.unit),
        "guid=" .. sourceGUID,
        "source=" .. tostring(sourceType)
    )

    if WAA.db.modules.scatter.flashEnabled and WAA.Alerts:ShowScatterRuntime() then
        WAA:Debug("Scatter FLASH")
    end
    return true
end

function Scatter:RemoveOpponent(guid)
    if self.lastScatterCast and guid then
        self.lastScatterCast[guid] = nil
    end
end

function Scatter:OnSettingsChanged()
    if not WAA:IsModuleEnabled("scatter") then
        self:ClearRuntime()
    elseif not WAA.db.modules.scatter.flashEnabled and WAA.Alerts then
        WAA.Alerts:HideScatterRuntime()
    end
end

function Scatter:ClearRuntime()
    if self.lastScatterCast then
        wipe(self.lastScatterCast)
    end
    if WAA.Alerts then
        WAA.Alerts:HideScatterRuntime()
    end
end

local _, WAA = ...

local WyvernSting = {}
WAA.WyvernSting = WyvernSting

local WYVERN_STING_SPELL_IDS = {
    [19386] = true,
    [24132] = true,
    [24133] = true,
    [27068] = true,
}
local WYVERN_STING_EVENT_DEDUP_SECONDS = 0.5
local ARENA_UNIT_PATTERN = "^arena[1-5]$"

WyvernSting.WYVERN_STING_SPELL_IDS = WYVERN_STING_SPELL_IDS
WyvernSting.WYVERN_STING_EVENT_DEDUP_SECONDS = WYVERN_STING_EVENT_DEDUP_SECONDS

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

function WyvernSting:Initialize()
    if self.initialized then
        return
    end

    self.lastCast = {}
    WAA.Arena:RegisterRuntimeEvent(self, "UNIT_SPELLCAST_SUCCEEDED", self.OnUnitSpellcastSucceeded)
    WAA.Arena:RegisterRuntimeEvent(self, "COMBAT_LOG_EVENT_UNFILTERED", self.OnCombatLogEvent)
    self.initialized = true
end

function WyvernSting:ParseUnitSpellcastSucceeded(unit, ...)
    return unit, FindSpellID(...)
end

function WyvernSting:ResolveUnitOpponent(unit)
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

function WyvernSting:OnUnitSpellcastSucceeded(_, unit, ...)
    if not WAA.isInArena or not WAA:IsModuleEnabled("wyvernSting") or not IsArenaUnit(unit) then
        return
    end

    local parsedUnit, spellID = self:ParseUnitSpellcastSucceeded(unit, ...)
    if not WYVERN_STING_SPELL_IDS[spellID] then
        return
    end

    local guid = UnitGUID(parsedUnit)
    WAA:Debug(
        "Wyvern Sting UNIT_SPELLCAST_SUCCEEDED:",
        "unit=" .. tostring(parsedUnit),
        "spellID=" .. tostring(spellID),
        "guid=" .. tostring(guid)
    )

    local opponent
    guid, opponent = self:ResolveUnitOpponent(parsedUnit)
    if not opponent or opponent.classFile ~= "HUNTER" then
        WAA:Debug("Wyvern Sting ignored: source is not mapped enemy Hunter", tostring(guid))
        return
    end

    self:HandleCast(guid, parsedUnit, spellID, "UNIT_SPELLCAST_SUCCEEDED")
end

function WyvernSting:ParseCombatLogEvent(...)
    return {
        eventType = select(2, ...),
        sourceGUID = select(4, ...),
        spellID = select(12, ...),
    }
end

function WyvernSting:OnCombatLogEvent()
    self:HandleCombatLogEvent(self:ParseCombatLogEvent(CombatLogGetCurrentEventInfo()))
end

function WyvernSting:HandleCombatLogEvent(event)
    if not event
        or event.eventType ~= "SPELL_CAST_SUCCESS"
        or not WYVERN_STING_SPELL_IDS[event.spellID]
        or not WAA.isInArena
        or not WAA:IsModuleEnabled("wyvernSting") then
        return false
    end

    WAA:Debug(
        "Wyvern Sting SPELL_CAST_SUCCESS:",
        "guid=" .. tostring(event.sourceGUID),
        "spellID=" .. tostring(event.spellID)
    )
    return self:HandleCast(event.sourceGUID, nil, event.spellID, "CLEU")
end

function WyvernSting:HandleCast(sourceGUID, unit, spellID, sourceType)
    if not WAA.isInArena or not WAA:IsModuleEnabled("wyvernSting") or not sourceGUID then
        return false
    end

    local opponent = WAA.Arena:GetOpponentByGUID(sourceGUID)
    if not opponent
        or opponent.classFile ~= "HUNTER"
        or (unit and opponent.unit ~= unit) then
        WAA:Debug("Wyvern Sting ignored: source is not mapped enemy Hunter", tostring(sourceGUID))
        return false
    end

    local now = GetTime()
    local lastCastAt = self.lastCast[sourceGUID]
    if lastCastAt and now - lastCastAt < WYVERN_STING_EVENT_DEDUP_SECONDS then
        WAA:Debug(
            "Wyvern Sting duplicate cast ignored:",
            "guid=" .. sourceGUID,
            "source=" .. tostring(sourceType)
        )
        return false
    end

    self.lastCast[sourceGUID] = now
    WAA:Debug(
        "Wyvern Sting CAST:",
        "hunter=" .. tostring(opponent.unit),
        "guid=" .. sourceGUID,
        "spellID=" .. tostring(spellID),
        "source=" .. tostring(sourceType)
    )

    if WAA.db.modules.wyvernSting.flashEnabled and WAA.Alerts:ShowWyvernStingRuntime() then
        WAA:Debug("Wyvern Sting FLASH")
    end
    return true
end

function WyvernSting:RemoveOpponent(guid)
    if self.lastCast and guid then
        self.lastCast[guid] = nil
    end
end

function WyvernSting:OnSettingsChanged()
    if not WAA:IsModuleEnabled("wyvernSting") then
        self:ClearRuntime()
    elseif not WAA.db.modules.wyvernSting.flashEnabled and WAA.Alerts then
        WAA.Alerts:HideWyvernStingRuntime()
    end
end

function WyvernSting:ClearRuntime()
    if self.lastCast then
        wipe(self.lastCast)
    end
    if WAA.Alerts then
        WAA.Alerts:HideWyvernStingRuntime()
    end
end

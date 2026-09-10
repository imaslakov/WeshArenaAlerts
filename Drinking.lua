local _, WAA = ...

local Drinking = {}
WAA.Drinking = Drinking

local CANONICAL_DRINK_SPELL_ID = 46755
local KNOWN_DRINK_SPELL_IDS = {
    [430] = true,
    [431] = true,
    [432] = true,
    [1133] = true,
    [1135] = true,
    [1137] = true,
    [10250] = true,
    [22734] = true,
    [24355] = true,
    [25696] = true,
    [27089] = true,
    [43154] = true,
}
local KNOWN_DRINK_SPELL_ID_ORDER = {
    430, 431, 432, 1133, 1135, 1137, 10250, 22734, 24355, 25696, 27089, 43154,
}
local ARENA_UNIT_PATTERN = "^arena[1-5]$"
local MAX_HELPFUL_AURAS = 40

Drinking.CANONICAL_DRINK_SPELL_ID = CANONICAL_DRINK_SPELL_ID
Drinking.KNOWN_DRINK_SPELL_IDS = KNOWN_DRINK_SPELL_IDS

local function GetLocalizedSpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(spellID)
        if name then
            return name
        end
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if type(info) == "table" and info.name then
            return info.name
        elseif type(info) == "string" then
            return info
        end
    end

    if GetSpellInfo then
        return GetSpellInfo(spellID)
    end
end

local function GetHelpfulAura(unit, index)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")
        if aura then
            return aura.name, aura.spellId or aura.spellID
        end
        return nil
    end

    if UnitAura then
        local name, _, _, _, _, _, _, _, _, spellID = UnitAura(unit, index, "HELPFUL")
        return name, spellID
    end
end

function Drinking:Initialize()
    if self.initialized then
        return
    end

    self.drinkingByGUID = {}
    self.drinkAuraName = GetLocalizedSpellName(CANONICAL_DRINK_SPELL_ID)
    if not self.drinkAuraName then
        for _, spellID in ipairs(KNOWN_DRINK_SPELL_ID_ORDER) do
            self.drinkAuraName = GetLocalizedSpellName(spellID)
            if self.drinkAuraName then
                break
            end
        end
    end

    WAA.Arena:RegisterRuntimeEvent(self, "UNIT_AURA", self.OnUnitAura)
    WAA.Arena:RegisterRuntimeEvent(self, "COMBAT_LOG_EVENT_UNFILTERED", self.OnCombatLogEvent)
    self.initialized = true

    if WAA.isInArena and WAA:IsModuleEnabled("drinking") then
        self:ScanAllOpponents("initial scan")
    end
end

function Drinking:IsDrinkAura(spellName, spellID)
    return (self.drinkAuraName and spellName == self.drinkAuraName)
        or KNOWN_DRINK_SPELL_IDS[spellID] == true
end

function Drinking:IsArenaUnit(unit)
    return type(unit) == "string" and unit:match(ARENA_UNIT_PATTERN) ~= nil
end

function Drinking:HasActiveDrinker()
    return self.drinkingByGUID and next(self.drinkingByGUID) ~= nil
end

function Drinking:StartDrinking(guid, unit, spellID, source)
    if not WAA.isInArena or not WAA:IsModuleEnabled("drinking") or not guid then
        return false
    end

    local opponent = WAA.Arena:GetOpponentByGUID(guid)
    if not opponent or opponent.unit ~= unit then
        return false
    end

    if self.drinkingByGUID[guid] then
        WAA:Debug("Drinking duplicate START ignored:", guid, "source=" .. tostring(source))
        return false
    end

    self.drinkingByGUID[guid] = {
        unit = unit,
        spellID = spellID,
        startedAt = GetTime(),
        source = source,
    }
    WAA:Debug(
        "Drinking START:",
        unit,
        guid,
        "spellID=" .. tostring(spellID),
        "source=" .. tostring(source)
    )
    WAA.Alerts:ShowDrinkingRuntime(true)
    return true
end

function Drinking:StopDrinking(guid, source)
    local state = guid and self.drinkingByGUID[guid]
    if not state then
        return false
    end

    self.drinkingByGUID[guid] = nil
    WAA:Debug("Drinking STOP:", state.unit or "UNKNOWN", guid, "source=" .. tostring(source))
    if not self:HasActiveDrinker() then
        WAA.Alerts:HideDrinkingRuntime()
    end
    return true
end

function Drinking:StopUnit(unit, source)
    local guids = {}
    for guid, state in pairs(self.drinkingByGUID) do
        if state.unit == unit then
            guids[#guids + 1] = guid
        end
    end
    for _, guid in ipairs(guids) do
        self:StopDrinking(guid, source)
    end
end

function Drinking:ScanUnit(unit, source)
    source = source or "UNIT_AURA"
    if not WAA.isInArena or not WAA:IsModuleEnabled("drinking") or not self:IsArenaUnit(unit) then
        return false
    end

    if UnitExists and not UnitExists(unit) then
        self:StopUnit(unit, source)
        return false
    end

    local guid = UnitGUID(unit)
    local opponent = WAA.Arena:GetOpponentByGUID(guid)
    if not guid or not opponent or opponent.unit ~= unit then
        self:StopUnit(unit, source)
        return false
    end

    for index = 1, MAX_HELPFUL_AURAS do
        local spellName, spellID = GetHelpfulAura(unit, index)
        if not spellName then
            break
        end
        if self:IsDrinkAura(spellName, spellID) then
            WAA:Debug(
                "Drink aura candidate:",
                "unit=" .. unit,
                "guid=" .. guid,
                "spellID=" .. tostring(spellID),
                "name=" .. tostring(spellName)
            )
            return self:StartDrinking(guid, unit, spellID, source)
        end
    end

    self:StopDrinking(guid, source)
    return false
end

function Drinking:ScanAllOpponents(reason)
    if not WAA.isInArena or not WAA:IsModuleEnabled("drinking") then
        return
    end
    for index = 1, 5 do
        local unit = "arena" .. index
        if WAA.Arena.opponents[unit] then
            WAA:Debug("Drinking " .. tostring(reason or "initial scan") .. ":", unit)
            self:ScanUnit(unit, "UNIT_AURA")
        end
    end
end

function Drinking:OnOpponentMapped(unit)
    if self.initialized and WAA.isInArena and WAA:IsModuleEnabled("drinking") then
        WAA:Debug("Drinking initial scan:", unit)
        self:ScanUnit(unit, "UNIT_AURA")
    end
end

function Drinking:OnUnitAura(_, unit)
    self:ScanUnit(unit, "UNIT_AURA")
end

function Drinking:ParseCombatLogEvent(...)
    return {
        eventType = select(2, ...),
        destGUID = select(8, ...),
        spellID = select(12, ...),
        spellName = select(13, ...),
    }
end

function Drinking:OnCombatLogEvent()
    self:HandleCombatLogEvent(self:ParseCombatLogEvent(CombatLogGetCurrentEventInfo()))
end

function Drinking:HandleCombatLogEvent(event)
    if not event or not WAA.isInArena or not WAA:IsModuleEnabled("drinking") then
        return
    end

    local isApplied = event.eventType == "SPELL_AURA_APPLIED"
        or event.eventType == "SPELL_AURA_REFRESH"
    local isRemoved = event.eventType == "SPELL_AURA_REMOVED"
    if (not isApplied and not isRemoved) or not self:IsDrinkAura(event.spellName, event.spellID) then
        return
    end

    local opponent = WAA.Arena:GetOpponentByGUID(event.destGUID)
    if not opponent then
        return
    end

    local action = isRemoved and "REMOVED" or (event.eventType == "SPELL_AURA_REFRESH" and "REFRESH" or "APPLIED")
    WAA:Debug(
        "Drinking CLEU " .. action .. ":",
        "dest=" .. tostring(event.destGUID),
        "spellID=" .. tostring(event.spellID)
    )

    if isRemoved then
        self:StopDrinking(event.destGUID, "CLEU")
    else
        self:StartDrinking(event.destGUID, opponent.unit, event.spellID, "CLEU")
    end
end

function Drinking:RemoveOpponent(guid, reason)
    if self.drinkingByGUID and self.drinkingByGUID[guid] then
        self:StopDrinking(guid, reason or "opponent removed")
        WAA:Debug("Drinking state cleared:", reason or "opponent removed")
    end
end

function Drinking:OnSettingsChanged()
    if not WAA.isInArena or not WAA:IsModuleEnabled("drinking") then
        self:ClearRuntime()
        return
    end
    self:ScanAllOpponents("initial scan")
end

function Drinking:ClearRuntime()
    if self.drinkingByGUID then
        wipe(self.drinkingByGUID)
    end
    if WAA.Alerts then
        WAA.Alerts:HideDrinkingRuntime()
    end
end

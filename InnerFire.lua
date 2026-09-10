local _, WAA = ...

local InnerFire = {}
WAA.InnerFire = InnerFire

local INNER_FIRE_SPELL_IDS = {
    [588] = true,
    [7128] = true,
    [602] = true,
    [1006] = true,
    [10951] = true,
    [10952] = true,
    [25431] = true,
}
local MAX_HELPFUL_AURAS = 40

InnerFire.STATE_OK = "OK"
InnerFire.STATE_LOW = "LOW"
InnerFire.STATE_MISSING = "MISSING"
InnerFire.STATE_PRESENT_COUNT_UNKNOWN = "PRESENT_COUNT_UNKNOWN"
InnerFire.INNER_FIRE_SPELL_IDS = INNER_FIRE_SPELL_IDS

local function NormalizeApplications(value)
    if type(value) ~= "number" or value <= 0 or value ~= math.floor(value) then
        return nil
    end
    return value
end

local function GetHelpfulAura(index)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
        if not aura then
            return nil
        end
        return {
            found = true,
            spellID = aura.spellId or aura.spellID,
            applications = NormalizeApplications(aura.applications),
        }
    end

    if UnitAura then
        local name, _, count, _, _, _, _, _, _, spellID = UnitAura("player", index, "HELPFUL")
        if not name then
            return nil
        end
        return {
            found = true,
            spellID = spellID,
            applications = NormalizeApplications(count),
        }
    end
end

function InnerFire:Initialize()
    if self.initialized then
        return
    end

    self:ResetState()
    WAA.Arena:RegisterRuntimeEvent(self, "UNIT_AURA", self.OnUnitAura)
    self.initialized = true

    if self:IsRuntimeEligible() then
        self:ScanPlayer("initial scan")
    end
end

function InnerFire:ResetState()
    self.isPresent = false
    self.charges = nil
    self.state = nil
    self.spellID = nil
end

function InnerFire:IsRuntimeEligible()
    if not WAA.isInArena or not WAA:IsModuleEnabled("innerFire") then
        return false
    end

    local _, classFile = UnitClass("player")
    return classFile == "PRIEST"
end

function InnerFire:GetPlayerAura()
    for index = 1, MAX_HELPFUL_AURAS do
        local aura = GetHelpfulAura(index)
        if not aura then
            break
        end
        if INNER_FIRE_SPELL_IDS[aura.spellID] then
            return aura
        end
    end

    return { found = false }
end

function InnerFire:EvaluateSnapshot(aura)
    if not aura or not aura.found then
        return self.STATE_MISSING, false, nil, nil
    end

    if aura.applications == nil then
        return self.STATE_PRESENT_COUNT_UNKNOWN, true, nil, aura.spellID
    end

    local threshold = WAA.db.modules.innerFire.threshold
    local state = aura.applications <= threshold and self.STATE_LOW or self.STATE_OK
    return state, true, aura.applications, aura.spellID
end

function InnerFire:ApplySnapshot(aura)
    local oldState = self.state
    local oldCharges = self.charges
    local oldSpellID = self.spellID
    local oldPresent = self.isPresent
    local state, isPresent, charges, spellID = self:EvaluateSnapshot(aura)
    local threshold = WAA.db.modules.innerFire.threshold

    if isPresent and (oldState ~= state or oldCharges ~= charges or oldSpellID ~= spellID) then
        WAA:Debug(
            "Inner Fire found:",
            "spellID=" .. tostring(spellID),
            "applications=" .. tostring(charges)
        )
    elseif not isPresent and oldPresent then
        WAA:Debug("Inner Fire removed")
    end

    if isPresent and charges == nil
        and (oldState ~= self.STATE_PRESENT_COUNT_UNKNOWN or oldSpellID ~= spellID) then
        WAA:Debug("Inner Fire count unavailable:", "spellID=" .. tostring(spellID))
    end

    if oldCharges and charges and oldCharges ~= charges then
        WAA:Debug("Inner Fire charges:", tostring(oldCharges) .. " -> " .. tostring(charges))
    end

    self.state = state
    self.isPresent = isPresent
    self.charges = charges
    self.spellID = spellID

    if oldState ~= state then
        local detail = ""
        if charges then
            detail = " charges=" .. tostring(charges)
            if state == self.STATE_LOW or oldState == self.STATE_LOW then
                detail = detail .. " threshold=" .. tostring(threshold)
            end
        end
        WAA:Debug(
            "Inner Fire state:",
            tostring(oldState or "NONE") .. " -> " .. tostring(state) .. detail
        )
    elseif state == self.STATE_LOW and oldCharges ~= charges then
        WAA:Debug("Inner Fire LOW UPDATE:", tostring(oldCharges) .. " -> " .. tostring(charges))
    end

    local changed = oldState ~= state or oldCharges ~= charges or oldSpellID ~= spellID
    if changed then
        self:RefreshVisual()
    end
    return changed
end

function InnerFire:ScanPlayer(reason)
    if not self:IsRuntimeEligible() then
        self:ClearRuntime()
        return false
    end

    if reason == "initial scan" then
        WAA:Debug("Inner Fire initial scan")
    end
    self:ApplySnapshot(self:GetPlayerAura())
    return true
end

function InnerFire:RefreshVisual()
    if not WAA.Alerts then
        return
    end

    if self.state == self.STATE_LOW or self.state == self.STATE_MISSING then
        WAA.Alerts:ShowInnerFireRuntime(self.state, self.charges)
    else
        WAA.Alerts:HideInnerFireRuntime()
    end
end

function InnerFire:OnUnitAura(_, unit)
    if unit ~= "player" then
        return
    end
    if not self:IsRuntimeEligible() then
        self:ClearRuntime()
        return
    end
    self:ScanPlayer("UNIT_AURA")
end

function InnerFire:OnArenaActivated()
    if self.initialized then
        self:ScanPlayer("initial scan")
    end
end

function InnerFire:OnSettingsChanged()
    if not self:IsRuntimeEligible() then
        self:ClearRuntime()
        return
    end

    if not self.state then
        self:ScanPlayer("initial scan")
        return
    end

    local aura = {
        found = self.isPresent,
        spellID = self.spellID,
        applications = self.charges,
    }
    local changed = self:ApplySnapshot(aura)
    if not changed then
        self:RefreshVisual()
    end
end

function InnerFire:ClearRuntime()
    self:ResetState()
    if WAA.Alerts then
        WAA.Alerts:HideInnerFireRuntime()
    end
end

local _, WAA = ...

local ShieldAbsorb = {}
WAA.ShieldAbsorb = ShieldAbsorb

local POWER_WORD_SHIELD_SPELL_IDS = {
    [17] = true,
    [592] = true,
    [600] = true,
    [3747] = true,
    [6065] = true,
    [6066] = true,
    [10898] = true,
    [10899] = true,
    [10900] = true,
    [10901] = true,
    [25217] = true,
    [25218] = true,
}
local MAX_HELPFUL_AURAS = 40
local AURA_POINTS_ABSORB_INDEX = 1

ShieldAbsorb.STATE_ABSENT = "ABSENT"
ShieldAbsorb.STATE_KNOWN = "KNOWN"
ShieldAbsorb.STATE_UNKNOWN = "UNKNOWN"
ShieldAbsorb.SOURCE_AURA_POINTS = "AURA_POINTS"
ShieldAbsorb.SOURCE_TOTAL_ABSORB = "TOTAL_ABSORB_FALLBACK"
ShieldAbsorb.SOURCE_UNKNOWN = "UNKNOWN"
ShieldAbsorb.POWER_WORD_SHIELD_SPELL_IDS = POWER_WORD_SHIELD_SPELL_IDS
ShieldAbsorb.AURA_POINTS_ABSORB_INDEX = AURA_POINTS_ABSORB_INDEX

local function IsUsableAccessibleAmount(value)
    local ok, usable = pcall(function()
        return type(value) == "number" and value > 0 and value < math.huge and value == value
    end)
    return ok and usable == true
end

local function SafeAmountText(value, isSecret)
    if isSecret then
        return "<secret>"
    end
    return tostring(value)
end

function ShieldAbsorb:Initialize()
    if self.initialized then
        return
    end

    self:ResetState()
    WAA.Arena:RegisterRuntimeEvent(self, "UNIT_AURA", self.OnUnitAura)
    WAA.Arena:RegisterRuntimeEvent(self, "UNIT_ABSORB_AMOUNT_CHANGED", self.OnAbsorbAmountChanged)
    self.initialized = true

    if self:IsRuntimeEligible() then
        self:ScanPlayer("initial scan")
    end
end

function ShieldAbsorb:ResetState()
    self.state = nil
    self.isPresent = false
    self.spellID = nil
    self.auraInstanceID = nil
    self.texture = nil
    self.amount = nil
    self.amountIsSecret = false
    self.amountSource = nil
    self.observedMaximum = nil
    self.fillFraction = nil
end

function ShieldAbsorb:IsRuntimeEligible()
    if not WAA.isInArena or not WAA:IsModuleEnabled("shieldAbsorb") then
        return false
    end
    local _, classFile = UnitClass("player")
    return classFile == "PRIEST"
end

-- Kept as a method so the secret branch can be simulated without requiring the
-- Blizzard restricted-value VM in the smoke tests.
function ShieldAbsorb:IsSecretValue(value)
    if self.secretValueDetector then
        return self.secretValueDetector(value) == true
    end

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

function ShieldAbsorb:GetHelpfulAura(index)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
        if not aura then
            return nil
        end
        return {
            found = true,
            spellID = aura.spellId or aura.spellID,
            auraInstanceID = aura.auraInstanceID,
            texture = aura.icon,
            points = aura.points,
        }
    end

    if UnitAura then
        local name, texture, _, _, _, _, _, _, _, spellID = UnitAura("player", index, "HELPFUL")
        if not name then
            return nil
        end
        return {
            found = true,
            spellID = spellID,
            texture = texture,
        }
    end
end

function ShieldAbsorb:GetPlayerAura()
    for index = 1, MAX_HELPFUL_AURAS do
        local aura = self:GetHelpfulAura(index)
        if not aura then
            break
        end
        if POWER_WORD_SHIELD_SPELL_IDS[aura.spellID] then
            return aura
        end
    end
    return { found = false }
end

-- This function is called only after canonical PW:S spell-ID validation. Index 1
-- is the Anniversary payload assumption that must be confirmed in the live client.
function ShieldAbsorb:ExtractAuraAbsorb(aura)
    if not aura or not POWER_WORD_SHIELD_SPELL_IDS[aura.spellID] then
        return nil, "not canonical Power Word: Shield"
    end
    if type(aura.points) ~= "table" then
        return nil, "AuraData.points unavailable"
    end

    local value = aura.points[AURA_POINTS_ABSORB_INDEX]
    if self:IsSecretValue(value) then
        WAA:Debug("Shield AuraData.points[1] is secret; trying total absorb fallback")
        return nil, "AuraData.points[1] is secret and cannot be validated"
    end
    if IsUsableAccessibleAmount(value) then
        return { value = value, isSecret = false }
    end
    return nil, "AuraData.points[1] missing, zero, or unusable"
end

function ShieldAbsorb:GetTotalAbsorbFallback()
    if type(UnitGetTotalAbsorbs) ~= "function" then
        return nil, "UnitGetTotalAbsorbs unavailable"
    end
    local ok, value = pcall(UnitGetTotalAbsorbs, "player")
    if not ok then
        return nil, "UnitGetTotalAbsorbs failed"
    end
    if self:IsSecretValue(value) then
        return { value = value, isSecret = true }
    end
    if IsUsableAccessibleAmount(value) then
        return { value = value, isSecret = false }
    end
    return nil, "UnitGetTotalAbsorbs returned zero or unusable value"
end

function ShieldAbsorb:BuildSnapshot()
    local aura = self:GetPlayerAura()
    if not aura.found then
        return { state = self.STATE_ABSENT, isPresent = false }
    end

    local amount, auraReason = self:ExtractAuraAbsorb(aura)
    local source = self.SOURCE_AURA_POINTS
    local fallbackReason
    if not amount then
        amount, fallbackReason = self:GetTotalAbsorbFallback()
        source = self.SOURCE_TOTAL_ABSORB
        if amount then
            WAA:Debug("Shield fallback source=TOTAL_ABSORB")
        end
    end

    if not amount then
        WAA:Debug("Shield amount unavailable:", auraReason or "unknown", fallbackReason or "")
        return {
            state = self.STATE_UNKNOWN,
            isPresent = true,
            spellID = aura.spellID,
            auraInstanceID = aura.auraInstanceID,
            texture = aura.texture,
            amountSource = self.SOURCE_UNKNOWN,
        }
    end

    if amount.isSecret then
        WAA:Debug("Shield amount is secret")
    end
    WAA:Debug(
        "Shield amount source=" .. source,
        "amount=" .. SafeAmountText(amount.value, amount.isSecret)
    )
    return {
        state = self.STATE_KNOWN,
        isPresent = true,
        spellID = aura.spellID,
        auraInstanceID = aura.auraInstanceID,
        texture = aura.texture,
        amount = amount.value,
        amountIsSecret = amount.isSecret,
        amountSource = source,
    }
end

function ShieldAbsorb:ApplySnapshot(snapshot)
    local oldState = self.state
    local oldAmount = self.amount
    local oldAmountIsSecret = self.amountIsSecret
    local oldAmountSource = self.amountSource
    local oldSpellID = self.spellID
    local oldAuraInstanceID = self.auraInstanceID
    local oldFillFraction = self.fillFraction
    local oldPresent = self.isPresent

    if snapshot.isPresent and (not oldPresent or oldSpellID ~= snapshot.spellID) then
        WAA:Debug("PW:S found:", "spellID=" .. tostring(snapshot.spellID))
    elseif not snapshot.isPresent and oldPresent then
        WAA:Debug("Power Word: Shield removed")
    end

    local amountChanged = false
    if oldState == self.STATE_KNOWN and snapshot.state == self.STATE_KNOWN then
        if oldAmountIsSecret or snapshot.amountIsSecret then
            amountChanged = true
        else
            amountChanged = oldAmount ~= snapshot.amount
        end
    end

    local observedMaximum = self.observedMaximum
    local fillFraction
    if not snapshot.isPresent then
        observedMaximum = nil
    elseif snapshot.state == self.STATE_KNOWN and not snapshot.amountIsSecret then
        local auraChanged = snapshot.auraInstanceID ~= oldAuraInstanceID
            and (snapshot.auraInstanceID ~= nil or oldAuraInstanceID ~= nil)
        if not oldPresent or auraChanged or type(observedMaximum) ~= "number" then
            observedMaximum = snapshot.amount
            WAA:Debug("Shield bar baseline initialized:", tostring(observedMaximum))
        elseif snapshot.amount > observedMaximum then
            observedMaximum = snapshot.amount
            WAA:Debug("Shield bar baseline updated:", tostring(observedMaximum))
        end

        if observedMaximum > 0 then
            fillFraction = snapshot.amount / observedMaximum
        else
            fillFraction = 0
        end
    end

    self.state = snapshot.state
    self.isPresent = snapshot.isPresent
    self.spellID = snapshot.spellID
    self.auraInstanceID = snapshot.auraInstanceID
    self.texture = snapshot.texture
    self.amount = snapshot.amount
    self.amountIsSecret = snapshot.amountIsSecret == true
    self.amountSource = snapshot.amountSource
    self.observedMaximum = observedMaximum
    self.fillFraction = fillFraction

    if oldState ~= self.state then
        WAA:Debug("Shield state:", tostring(oldState or "NONE") .. " -> " .. tostring(self.state))
    elseif amountChanged then
        WAA:Debug(
            "Shield amount changed:",
            SafeAmountText(oldAmount, oldAmountIsSecret) .. " -> " .. SafeAmountText(self.amount, self.amountIsSecret),
            "source=" .. tostring(self.amountSource)
        )
    end

    local changed = oldState ~= self.state
        or oldSpellID ~= self.spellID
        or oldAuraInstanceID ~= self.auraInstanceID
        or amountChanged
        or oldAmountSource ~= self.amountSource
        or oldFillFraction ~= self.fillFraction
    if changed then
        self:RefreshVisual()
    end
    return changed
end

function ShieldAbsorb:MarkSecretDisplayUnavailable()
    local oldState = self.state
    self.state = self.STATE_UNKNOWN
    self.amount = nil
    self.amountIsSecret = false
    self.amountSource = self.SOURCE_UNKNOWN
    self.fillFraction = nil
    WAA:Debug("Shield amount unavailable: secret value cannot be displayed safely")
    if oldState ~= self.state then
        WAA:Debug("Shield state:", tostring(oldState) .. " -> " .. self.state)
    end
    WAA.Alerts:ShowShieldRuntime(nil, false, self.texture, nil)
end

function ShieldAbsorb:ScanPlayer(reason)
    if not self:IsRuntimeEligible() then
        self:ClearRuntime()
        return false
    end
    if reason == "initial scan" then
        WAA:Debug("Shield initial scan")
    end
    self:ApplySnapshot(self:BuildSnapshot())
    return true
end

function ShieldAbsorb:RefreshVisual()
    if not WAA.Alerts then
        return
    end
    if self.state == self.STATE_KNOWN then
        local displayed = WAA.Alerts:ShowShieldRuntime(
            self.amount,
            self.amountIsSecret,
            self.texture,
            self.fillFraction
        )
        if not displayed and self.amountIsSecret then
            self:MarkSecretDisplayUnavailable()
        elseif displayed and self.amountIsSecret then
            WAA:Debug("Shield secret value displayed without arithmetic")
        end
    elseif self.state == self.STATE_UNKNOWN then
        WAA.Alerts:ShowShieldRuntime(nil, false, self.texture, nil)
    else
        WAA.Alerts:HideShieldRuntime()
    end
end

function ShieldAbsorb:OnUnitAura(_, unit)
    if unit ~= "player" then
        return
    end
    self:ScanPlayer("UNIT_AURA")
end

function ShieldAbsorb:OnAbsorbAmountChanged(_, unit)
    if unit ~= "player" then
        return
    end
    WAA:Debug("UNIT_ABSORB_AMOUNT_CHANGED: player")
    self:ScanPlayer("UNIT_ABSORB_AMOUNT_CHANGED")
end

function ShieldAbsorb:OnArenaActivated()
    if self.initialized then
        self:ScanPlayer("initial scan")
    end
end

function ShieldAbsorb:OnSettingsChanged()
    if not self:IsRuntimeEligible() then
        self:ClearRuntime()
        return
    end
    if not self.state then
        self:ScanPlayer("initial scan")
    else
        self:RefreshVisual()
    end
end

function ShieldAbsorb:ClearRuntime()
    self:ResetState()
    if WAA.Alerts then
        WAA.Alerts:HideShieldRuntime()
    end
end

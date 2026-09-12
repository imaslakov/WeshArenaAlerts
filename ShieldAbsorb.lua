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
local POWER_WORD_SHIELD_BASE_ABSORB = {
    [17] = 48,
    [592] = 94,
    [600] = 166,
    [3747] = 244,
    [6065] = 313,
    [6066] = 394,
    [10898] = 499,
    [10899] = 622,
    [10900] = 783,
    [10901] = 964,
    [25217] = 1144,
    [25218] = 1265,
}
local POWER_WORD_SHIELD_RANK_LEVEL = {
    [17] = 6,
    [592] = 12,
    [600] = 18,
    [3747] = 24,
    [6065] = 30,
    [6066] = 36,
    [10898] = 42,
    [10899] = 48,
    [10900] = 54,
    [10901] = 60,
    [25217] = 65,
    [25218] = 70,
}
local POWER_WORD_SHIELD_HEALING_COEFFICIENT = 0.30
local IMPROVED_POWER_WORD_SHIELD_RANK_3_SPELL_ID = 14769
local MAX_HELPFUL_AURAS = 40
local MAX_AURA_POINT_CANDIDATES = 5
local SHIELD_COMBAT_LOG_EVENTS = {
    SWING_DAMAGE = true,
    RANGE_DAMAGE = true,
    SPELL_DAMAGE = true,
    SPELL_PERIODIC_DAMAGE = true,
    DAMAGE_SHIELD = true,
    DAMAGE_SPLIT = true,
    ENVIRONMENTAL_DAMAGE = true,
    SWING_MISSED = true,
    RANGE_MISSED = true,
    SPELL_MISSED = true,
    SPELL_PERIODIC_MISSED = true,
    SPELL_ABSORBED = true,
}
local unpackValues = table.unpack or unpack

ShieldAbsorb.STATE_ABSENT = "ABSENT"
ShieldAbsorb.STATE_KNOWN = "KNOWN"
ShieldAbsorb.STATE_UNKNOWN = "UNKNOWN"
ShieldAbsorb.SOURCE_AURA_POINTS = "AURA_POINTS"
ShieldAbsorb.SOURCE_TOTAL_ABSORB = "TOTAL_ABSORB_FALLBACK"
ShieldAbsorb.SOURCE_CALCULATED_COMBAT_LOG = "CALCULATED_COMBAT_LOG"
ShieldAbsorb.SOURCE_UNKNOWN = "UNKNOWN"
ShieldAbsorb.POWER_WORD_SHIELD_SPELL_IDS = POWER_WORD_SHIELD_SPELL_IDS
ShieldAbsorb.MAX_AURA_POINT_CANDIDATES = MAX_AURA_POINT_CANDIDATES

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
    WAA.Arena:RegisterRuntimeEvent(self, "COMBAT_LOG_EVENT_UNFILTERED", self.OnCombatLogEvent)
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
    self.amountIndex = nil
    self.sourceUnit = nil
    self.expirationTime = nil
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
            sourceUnit = aura.sourceUnit,
            expirationTime = aura.expirationTime,
        }
    end

    if UnitAura then
        local name, texture, _, _, _, expirationTime, sourceUnit, _, _, spellID = UnitAura("player", index, "HELPFUL")
        if not name then
            return nil
        end
        return {
            found = true,
            spellID = spellID,
            texture = texture,
            sourceUnit = sourceUnit,
            expirationTime = expirationTime,
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

-- This function is called only after canonical PW:S spell-ID validation. AuraData
-- does not define one stable absorb index, so accept only one unambiguous positive
-- candidate instead of guessing among multiple spell-effect values.
function ShieldAbsorb:ExtractAuraAbsorb(aura)
    if not aura or not POWER_WORD_SHIELD_SPELL_IDS[aura.spellID] then
        return nil, "not canonical Power Word: Shield"
    end
    if type(aura.points) ~= "table" then
        return nil, "AuraData.points unavailable"
    end

    local candidates = {}
    local secretCount = 0
    local diagnosticPoints = {}
    for index = 1, MAX_AURA_POINT_CANDIDATES do
        local value = aura.points[index]
        if self:IsSecretValue(value) then
            secretCount = secretCount + 1
            diagnosticPoints[index] = "<secret>"
            WAA:Debug("Shield aura point secret:", "index=" .. tostring(index))
        else
            diagnosticPoints[index] = value == nil and "<nil>" or tostring(value)
            if IsUsableAccessibleAmount(value) then
                candidates[#candidates + 1] = { value = value, index = index }
                WAA:Debug(
                    "Shield aura point candidate:",
                    "index=" .. tostring(index),
                    "amount=" .. tostring(value)
                )
            end
        end
    end
    WAA:Debug("Shield aura points raw:", table.concat(diagnosticPoints, ","))

    if #candidates == 1 and secretCount == 0 then
        return {
            value = candidates[1].value,
            isSecret = false,
            index = candidates[1].index,
        }
    end
    if #candidates > 1 then
        WAA:Debug("Shield aura points ambiguous:", "positiveCandidates=" .. tostring(#candidates))
        return nil, "AuraData.points has multiple positive candidates"
    end
    if secretCount > 0 then
        return nil, "AuraData.points candidates are secret and cannot be validated"
    end
    return nil, "AuraData.points has no positive usable candidate"
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
        WAA:Debug("Shield total absorb raw:", "<secret>")
        return { value = value, isSecret = true }
    end
    WAA:Debug("Shield total absorb raw:", value == nil and "<nil>" or tostring(value))
    if IsUsableAccessibleAmount(value) then
        return { value = value, isSecret = false }
    end
    return nil, "UnitGetTotalAbsorbs returned zero or unusable value"
end

function ShieldAbsorb:IsPlayerAuraCaster(sourceUnit)
    if not sourceUnit then
        return false
    end
    if type(UnitIsUnit) == "function" then
        local ok, isPlayer = pcall(UnitIsUnit, sourceUnit, "player")
        if ok then
            return isPlayer == true
        end
    end
    return sourceUnit == "player"
end

function ShieldAbsorb:GetImprovedPowerWordShieldRank()
    if type(GetNumTalentTabs) ~= "function"
        or type(GetNumTalents) ~= "function"
        or type(GetTalentInfo) ~= "function" then
        return 0
    end

    local talentName = type(GetSpellInfo) == "function"
        and GetSpellInfo(IMPROVED_POWER_WORD_SHIELD_RANK_3_SPELL_ID)
        or nil
    if not talentName then
        return 0
    end

    local tabCount = GetNumTalentTabs() or 0
    for tab = 1, tabCount do
        local talentCount = GetNumTalents(tab) or 0
        for index = 1, talentCount do
            local name, _, _, _, rank = GetTalentInfo(tab, index)
            if name == talentName then
                rank = tonumber(rank) or 0
                return math.max(0, math.min(3, rank))
            end
        end
    end
    return 0
end

function ShieldAbsorb:ComputePowerWordShieldMaximum(aura)
    if not aura or not POWER_WORD_SHIELD_SPELL_IDS[aura.spellID] then
        return nil, "not canonical Power Word: Shield"
    end
    if not self:IsPlayerAuraCaster(aura.sourceUnit) then
        return nil, "shield caster is not the player or is unavailable"
    end

    local base = POWER_WORD_SHIELD_BASE_ABSORB[aura.spellID]
    local rankLevel = POWER_WORD_SHIELD_RANK_LEVEL[aura.spellID]
    if not base or not rankLevel then
        return nil, "shield rank data unavailable"
    end

    local bonusHealing = 0
    if type(GetSpellBonusHealing) == "function" then
        local ok, value = pcall(GetSpellBonusHealing)
        if not ok or self:IsSecretValue(value) then
            return nil, "bonus healing unavailable"
        end
        if type(value) == "number" and value >= 0 and value < math.huge and value == value then
            bonusHealing = value
        end
    end

    local downrankFactor = math.max(0, math.min(1, 1 - (20 - rankLevel) * 0.0375))
    local talentRank = self:GetImprovedPowerWordShieldRank()
    local talentMultiplier = 1 + talentRank * 0.05
    local maximum = math.floor(
        (base + bonusHealing * POWER_WORD_SHIELD_HEALING_COEFFICIENT * downrankFactor)
            * talentMultiplier
            + 0.5
    )
    if maximum <= 0 then
        return nil, "calculated shield amount is unusable"
    end

    WAA:Debug(
        "Shield calculated maximum:",
        "amount=" .. tostring(maximum),
        "base=" .. tostring(base),
        "bonusHealing=" .. tostring(bonusHealing),
        "talentRank=" .. tostring(talentRank),
        "downrank=" .. tostring(downrankFactor)
    )
    return maximum
end

function ShieldAbsorb:GetCalculatedCombatLogFallback(aura)
    local sameAura = self.isPresent and self.spellID == aura.spellID
    if sameAura and (aura.auraInstanceID ~= nil or self.auraInstanceID ~= nil) then
        sameAura = aura.auraInstanceID == self.auraInstanceID
    elseif sameAura
        and type(aura.expirationTime) == "number"
        and type(self.expirationTime) == "number" then
        sameAura = math.abs(aura.expirationTime - self.expirationTime) < 0.1
    end

    if sameAura
        and self.amountSource == self.SOURCE_CALCULATED_COMBAT_LOG
        and type(self.amount) == "number"
        and self.amount >= 0 then
        return {
            value = self.amount,
            isSecret = false,
            maximum = self.observedMaximum,
        }
    end

    local maximum, reason = self:ComputePowerWordShieldMaximum(aura)
    if not maximum then
        return nil, reason
    end
    return {
        value = maximum,
        isSecret = false,
        maximum = maximum,
    }
end

function ShieldAbsorb:BuildSnapshot()
    local aura = self:GetPlayerAura()
    if not aura.found then
        return { state = self.STATE_ABSENT, isPresent = false }
    end

    local amount, auraReason = self:ExtractAuraAbsorb(aura)
    local source = self.SOURCE_AURA_POINTS
    local fallbackReason
    local calculatedReason
    if not amount then
        amount, fallbackReason = self:GetTotalAbsorbFallback()
        source = self.SOURCE_TOTAL_ABSORB
        if amount then
            WAA:Debug("Shield fallback source=TOTAL_ABSORB")
        end
    end
    if not amount then
        amount, calculatedReason = self:GetCalculatedCombatLogFallback(aura)
        source = self.SOURCE_CALCULATED_COMBAT_LOG
        if amount then
            WAA:Debug("Shield fallback source=CALCULATED_COMBAT_LOG")
        end
    end

    if not amount then
        WAA:Debug(
            "Shield amount unavailable:",
            auraReason or "unknown",
            fallbackReason or "",
            calculatedReason or ""
        )
        return {
            state = self.STATE_UNKNOWN,
            isPresent = true,
            spellID = aura.spellID,
            auraInstanceID = aura.auraInstanceID,
            texture = aura.texture,
            sourceUnit = aura.sourceUnit,
            expirationTime = aura.expirationTime,
            amountSource = self.SOURCE_UNKNOWN,
        }
    end

    if amount.isSecret then
        WAA:Debug("Shield amount is secret")
    end
    WAA:Debug(
        "Shield amount source=" .. source,
        "amount=" .. SafeAmountText(amount.value, amount.isSecret),
        amount.index and ("index=" .. tostring(amount.index)) or ""
    )
    return {
        state = self.STATE_KNOWN,
        isPresent = true,
        spellID = aura.spellID,
        auraInstanceID = aura.auraInstanceID,
        texture = aura.texture,
        sourceUnit = aura.sourceUnit,
        expirationTime = aura.expirationTime,
        amount = amount.value,
        amountIsSecret = amount.isSecret,
        amountSource = source,
        amountIndex = amount.index,
        maximum = amount.maximum,
    }
end

function ShieldAbsorb:ApplySnapshot(snapshot)
    local oldState = self.state
    local oldAmount = self.amount
    local oldAmountIsSecret = self.amountIsSecret
    local oldAmountSource = self.amountSource
    local oldAmountIndex = self.amountIndex
    local oldSpellID = self.spellID
    local oldAuraInstanceID = self.auraInstanceID
    local oldExpirationTime = self.expirationTime
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
        if not auraChanged
            and type(snapshot.expirationTime) == "number"
            and type(oldExpirationTime) == "number" then
            auraChanged = snapshot.expirationTime > oldExpirationTime + 0.1
        end
        if not oldPresent or auraChanged or type(observedMaximum) ~= "number" then
            observedMaximum = snapshot.maximum or snapshot.amount
            WAA:Debug("Shield bar baseline initialized:", tostring(observedMaximum))
        elseif type(snapshot.maximum) == "number" and snapshot.maximum > observedMaximum then
            observedMaximum = snapshot.maximum
            WAA:Debug("Shield bar baseline updated:", tostring(observedMaximum))
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
    self.sourceUnit = snapshot.sourceUnit
    self.expirationTime = snapshot.expirationTime
    self.amount = snapshot.amount
    self.amountIsSecret = snapshot.amountIsSecret == true
    self.amountSource = snapshot.amountSource
    self.amountIndex = snapshot.amountIndex
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
        or oldAmountIndex ~= self.amountIndex
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
    self.amountIndex = nil
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

function ShieldAbsorb:GetCombatLogAbsorbAmount(eventType, ...)
    local amount
    local exactShieldMatch = false

    if eventType == "SPELL_ABSORBED" then
        local shieldSpellIndex
        for index = 12, select("#", ...) do
            local value = select(index, ...)
            local ok, isShieldSpell = pcall(function()
                return POWER_WORD_SHIELD_SPELL_IDS[value] == true
            end)
            if ok and isShieldSpell then
                shieldSpellIndex = index
            end
        end
        if not shieldSpellIndex then
            return nil, false
        end
        exactShieldMatch = true
        for index = select("#", ...), shieldSpellIndex + 1, -1 do
            local value = select(index, ...)
            if IsUsableAccessibleAmount(value) then
                amount = value
                break
            end
        end
    elseif eventType == "SWING_DAMAGE" then
        amount = select(17, ...)
    elseif eventType == "RANGE_DAMAGE"
        or eventType == "SPELL_DAMAGE"
        or eventType == "SPELL_PERIODIC_DAMAGE"
        or eventType == "DAMAGE_SHIELD"
        or eventType == "DAMAGE_SPLIT" then
        amount = select(20, ...)
        if amount == nil then
            amount = select(19, ...)
        end
    elseif eventType == "ENVIRONMENTAL_DAMAGE" then
        amount = select(18, ...)
    elseif eventType == "SWING_MISSED"
        or eventType == "RANGE_MISSED"
        or eventType == "SPELL_MISSED"
        or eventType == "SPELL_PERIODIC_MISSED" then
        local absorbMarker
        for index = 12, select("#", ...) do
            local value = select(index, ...)
            if value == "ABSORB" then
                absorbMarker = index
                break
            end
        end
        if absorbMarker then
            for index = select("#", ...), absorbMarker + 1, -1 do
                local value = select(index, ...)
                if IsUsableAccessibleAmount(value) then
                    amount = value
                    break
                end
            end
        end
    end

    if self:IsSecretValue(amount) or not IsUsableAccessibleAmount(amount) then
        return nil, exactShieldMatch
    end
    return amount, exactShieldMatch
end

function ShieldAbsorb:ApplyCombatLogAbsorb(eventType, ...)
    if self.amountSource ~= self.SOURCE_CALCULATED_COMBAT_LOG
        or type(self.amount) ~= "number"
        or self.amount <= 0 then
        return false
    end

    local absorbed, exactShieldMatch = self:GetCombatLogAbsorbAmount(eventType, ...)
    if not absorbed then
        return false
    end

    local before = self.amount
    self.amount = math.max(0, before - math.min(absorbed, before))
    if type(self.observedMaximum) == "number" and self.observedMaximum > 0 then
        self.fillFraction = self.amount / self.observedMaximum
    else
        self.fillFraction = nil
    end
    WAA:Debug(
        "Shield combat absorb:",
        "event=" .. tostring(eventType),
        "absorbed=" .. tostring(absorbed),
        "before=" .. tostring(before),
        "after=" .. tostring(self.amount),
        "attribution=" .. (exactShieldMatch and "PW:S" or "active-shield-estimate")
    )
    self:RefreshVisual()
    return true
end

function ShieldAbsorb:OnCombatLogEvent()
    self:LogCombatLogEvent(CombatLogGetCurrentEventInfo())
end

function ShieldAbsorb:LogCombatLogEvent(...)
    if not self:IsRuntimeEligible() or not self.isPresent then
        return
    end

    local eventType = select(2, ...)
    local sourceGUID = select(4, ...)
    local destGUID = select(8, ...)
    if not SHIELD_COMBAT_LOG_EVENTS[eventType] or destGUID ~= UnitGUID("player") then
        return
    end

    local diagnostic = {
        "Shield CLEU raw:",
        "event=" .. tostring(eventType),
        "source=", sourceGUID or "<nil>",
        "dest=", destGUID or "<nil>",
    }
    for index = 12, select("#", ...) do
        local value = select(index, ...)
        diagnostic[#diagnostic + 1] = "arg" .. tostring(index) .. "="
        diagnostic[#diagnostic + 1] = value == nil and "<nil>" or value
    end
    WAA:Debug(unpackValues(diagnostic))
    self:ApplyCombatLogAbsorb(eventType, ...)
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

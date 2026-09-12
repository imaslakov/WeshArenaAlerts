local _, WAA = ...

local ExecuteRange = {}
WAA.ExecuteRange = ExecuteRange

ExecuteRange.WARRIOR = "WARRIOR"
ExecuteRange.PALADIN = "PALADIN"

local function IsUsableHealthValue(value)
    return type(value) == "number" and value >= 0
end

function ExecuteRange:Initialize()
    if self.initialized then
        return
    end

    self:ResetState()
    WAA.Arena:RegisterRuntimeEvent(self, "UNIT_HEALTH", self.OnPlayerHealthChanged)
    WAA.Arena:RegisterRuntimeEvent(self, "UNIT_MAXHEALTH", self.OnPlayerHealthChanged)
    self.initialized = true

    if WAA.isInArena then
        self:Evaluate("initial scan")
    end
end

function ExecuteRange:ResetState()
    self.hasWarrior = false
    self.hasPaladin = false
    self.isInDanger = false
    self.threatLabel = nil
end

function ExecuteRange:RefreshEnemyClasses()
    local hasWarrior = false
    local hasPaladin = false

    if WAA.Arena and WAA.Arena.opponents then
        for _, opponent in pairs(WAA.Arena.opponents) do
            if opponent.classFile == self.WARRIOR then
                hasWarrior = true
            elseif opponent.classFile == self.PALADIN then
                hasPaladin = true
            end
        end
    end

    self.hasWarrior = hasWarrior
    self.hasPaladin = hasPaladin
    return hasWarrior or hasPaladin
end

function ExecuteRange:IsRuntimeEligible()
    return WAA.isInArena and WAA:IsModuleEnabled("executeRange")
end

function ExecuteRange:GetDangerState(currentHealth, maxHealth)
    if not IsUsableHealthValue(currentHealth)
        or not IsUsableHealthValue(maxHealth)
        or currentHealth <= 0
        or maxHealth <= 0 then
        return false, nil
    end

    -- Multiplication preserves the exact boundary without percentage rounding:
    -- Hammer of Wrath works at 20% or below; Execute requires strictly below 20%.
    local scaledHealth = currentHealth * 5
    local paladinDanger = self.hasPaladin and scaledHealth <= maxHealth
    local warriorDanger = self.hasWarrior and scaledHealth < maxHealth

    if paladinDanger and warriorDanger then
        return true, "Warrior: Execute / Paladin: Hammer of Wrath"
    elseif paladinDanger then
        return true, "Paladin: Hammer of Wrath"
    elseif warriorDanger then
        return true, "Warrior: Execute"
    end
    return false, nil
end

function ExecuteRange:Evaluate(reason)
    if not self:IsRuntimeEligible() then
        self:ClearRuntime()
        return false
    end

    if not self:RefreshEnemyClasses() then
        self:SetDangerState(false, nil, reason)
        return false
    end

    local currentHealth = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    local ok, isInDanger, threatLabel = pcall(
        self.GetDangerState,
        self,
        currentHealth,
        maxHealth
    )
    if not ok then
        WAA:Debug("Execute range health values unavailable")
        self:SetDangerState(false, nil, reason)
        return false
    end

    self:SetDangerState(isInDanger, threatLabel, reason)
    return isInDanger
end

function ExecuteRange:SetDangerState(isInDanger, threatLabel, reason)
    local changed = self.isInDanger ~= isInDanger or self.threatLabel ~= threatLabel
    self.isInDanger = isInDanger
    self.threatLabel = threatLabel

    if changed then
        WAA:Debug(
            "Execute range:",
            isInDanger and "DANGER" or "SAFE",
            threatLabel or "no matching threat",
            reason or "update"
        )
    end
    self:RefreshVisual()
end

function ExecuteRange:RefreshVisual()
    if not WAA.Alerts then
        return
    end
    if self.isInDanger and self.threatLabel then
        WAA.Alerts:ShowExecuteRangeRuntime(self.threatLabel)
    else
        WAA.Alerts:HideExecuteRangeRuntime()
    end
end

function ExecuteRange:OnPlayerHealthChanged(_, unit)
    if unit == "player" then
        self:Evaluate("player health")
    end
end

function ExecuteRange:OnOpponentMappingChanged()
    if self.initialized and WAA.isInArena then
        self:Evaluate("opponent mapping")
    end
end

function ExecuteRange:OnArenaActivated()
    if self.initialized then
        self:Evaluate("arena activated")
    end
end

function ExecuteRange:OnSettingsChanged()
    if self:IsRuntimeEligible() then
        self:Evaluate("settings")
    else
        self:ClearRuntime()
    end
end

function ExecuteRange:ClearRuntime()
    self:ResetState()
    if WAA.Alerts then
        WAA.Alerts:HideExecuteRangeRuntime()
    end
end

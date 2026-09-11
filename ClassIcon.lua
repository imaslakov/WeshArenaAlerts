local _, WAA = ...

local ClassIcon = {}
WAA.ClassIcon = ClassIcon

local CLASS_TEXTURE = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local ARENA_PET_UNITS = { "arenapet1", "arenapet2", "arenapet3", "arenapet4", "arenapet5" }
local FRIENDLY_PET_UNITS = {
    { pet = "pet", owner = "player" },
    { pet = "partypet1", owner = "party1" },
    { pet = "partypet2", owner = "party2" },
    { pet = "partypet3", owner = "party3" },
    { pet = "partypet4", owner = "party4" },
}
local TBC_CLASSES = {
    WARRIOR = true,
    PALADIN = true,
    HUNTER = true,
    ROGUE = true,
    PRIEST = true,
    SHAMAN = true,
    MAGE = true,
    WARLOCK = true,
    DRUID = true,
}
local FALLBACK_TCOORDS = {
    WARRIOR = { 0, 0.25, 0, 0.25 },
    MAGE = { 0.25, 0.49609375, 0, 0.25 },
    ROGUE = { 0.49609375, 0.7421875, 0, 0.25 },
    DRUID = { 0.7421875, 0.98828125, 0, 0.25 },
    HUNTER = { 0, 0.25, 0.25, 0.5 },
    SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
    PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 },
    WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
    PALADIN = { 0, 0.25, 0.5, 0.75 },
}

ClassIcon.TBC_CLASSES = TBC_CLASSES
ClassIcon.FALLBACK_TCOORDS = FALLBACK_TCOORDS
ClassIcon.CLASS_TEXTURE = CLASS_TEXTURE

local function IsNameplateToken(unitToken)
    return type(unitToken) == "string" and unitToken:match("^nameplate%d+$") ~= nil
end

local function CreateBorderTexture(frame)
    local texture = frame:CreateTexture(nil, "OVERLAY")
    texture:SetColorTexture(0.04, 0.04, 0.04, 1)
    return texture
end

function ClassIcon:Initialize()
    if self.initialized then
        return
    end

    self.activeByUnit = {}
    self.activeByGUID = {}
    self.activeByNamePlate = {}
    self.activeByAnchor = {}
    self.activeByPetUnit = {}
    self.visibleUnits = {}
    self.pendingByUnit = {}
    self.pool = {}
    WAA.Arena:RegisterRuntimeEvent(self, "NAME_PLATE_UNIT_ADDED", self.OnNamePlateEvent)
    WAA.Arena:RegisterRuntimeEvent(self, "NAME_PLATE_UNIT_REMOVED", self.OnNamePlateEvent)
    WAA.Arena:RegisterRuntimeEvent(self, "UNIT_PET", self.OnPetEvent)
    WAA.Arena:RegisterRuntimeEvent(self, "UNIT_HEALTH", self.OnPetHealthEvent)
    WAA.Arena:RegisterRuntimeEvent(self, "UNIT_MAXHEALTH", self.OnPetHealthEvent)
    self.initialized = true

    if WAA.isInArena then
        self:OnArenaActivated()
    end
end

function ClassIcon:CreateIconFrame(parent)
    local frame = CreateFrame("Frame", nil, parent or UIParent)
    frame:EnableMouse(false)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

    local healthBar = CreateFrame("StatusBar", nil, frame)
    healthBar:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
    healthBar:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 2)
    healthBar:SetHeight(5)
    healthBar:SetMinMaxValues(0, 1)
    healthBar:SetValue(1)
    healthBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    healthBar:EnableMouse(false)
    local healthBackground = healthBar:CreateTexture(nil, "BACKGROUND")
    healthBackground:SetAllPoints(healthBar)
    healthBackground:SetColorTexture(0.04, 0.04, 0.04, 0.95)
    healthBar.background = healthBackground
    healthBar:Hide()
    frame.healthBar = healthBar

    frame.border = {
        top = CreateBorderTexture(frame),
        bottom = CreateBorderTexture(frame),
        left = CreateBorderTexture(frame),
        right = CreateBorderTexture(frame),
    }
    frame.border.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.border.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.border.top:SetHeight(1)
    frame.border.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.border.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.border.bottom:SetHeight(1)
    frame.border.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.border.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.border.left:SetWidth(1)
    frame.border.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.border.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.border.right:SetWidth(1)
    frame:Hide()
    return frame
end

function ClassIcon:SetClassTexture(texture, classFile)
    if not texture then
        return false
    end

    texture:SetTexture(nil)
    texture:SetTexCoord(0, 1, 0, 1)
    if not TBC_CLASSES[classFile] then
        WAA:Debug("ClassIcon texture unavailable: class=" .. tostring(classFile))
        return false
    end

    local coordinates = (CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile])
        or FALLBACK_TCOORDS[classFile]
    if not coordinates then
        WAA:Debug("ClassIcon texture unavailable: class=" .. tostring(classFile))
        return false
    end

    local ok = pcall(function()
        texture:SetTexture(CLASS_TEXTURE)
        texture:SetTexCoord(coordinates[1], coordinates[2], coordinates[3], coordinates[4])
    end)
    if not ok then
        texture:SetTexture(nil)
        WAA:Debug("ClassIcon texture unavailable: class=" .. tostring(classFile))
        return false
    end
    return true
end

function ClassIcon:SetPetTexture(texture, petUnit)
    if not texture then
        return false
    end

    texture:SetTexture(nil)
    texture:SetTexCoord(0, 1, 0, 1)
    if type(SetPortraitTexture) ~= "function" then
        WAA:Debug("ClassIcon pet portrait API unavailable: unit=" .. tostring(petUnit))
        return false
    end

    local ok = pcall(SetPortraitTexture, texture, petUnit)
    if not ok then
        texture:SetTexture(nil)
        WAA:Debug("ClassIcon pet portrait unavailable: unit=" .. tostring(petUnit))
        return false
    end
    return true
end

function ClassIcon:GetArenaPetByGUID(guid)
    if not guid then
        return nil
    end
    for index, petUnit in ipairs(ARENA_PET_UNITS) do
        if WAA.Arena.opponents["arena" .. index] and UnitGUID(petUnit) == guid then
            return petUnit
        end
    end
    return nil
end

function ClassIcon:GetFriendlyPetByGUID(guid)
    if not guid then
        return nil
    end
    for _, units in ipairs(FRIENDLY_PET_UNITS) do
        if UnitGUID(units.owner) and UnitGUID(units.pet) == guid then
            return units.pet
        end
    end
    return nil
end

function ClassIcon:GetPetByGUID(guid, unitToken)
    local petUnit = self:GetArenaPetByGUID(guid)
    if petUnit then
        return petUnit, "ENEMY"
    end
    petUnit = self:GetFriendlyPetByGUID(guid)
    if petUnit then
        return petUnit, "FRIENDLY"
    end

    if type(guid) == "string" and guid:match("^Pet%-") then
        local playerControlled = type(UnitPlayerControlled) ~= "function"
            or UnitPlayerControlled(unitToken) == true
        if playerControlled then
            local friendly = type(UnitIsFriend) == "function" and UnitIsFriend("player", unitToken) == true
            return unitToken, friendly and "FRIENDLY" or "ENEMY"
        end
    end
    return nil, nil
end

function ClassIcon:UpdatePetHealth(frame)
    if not frame or frame.iconKind ~= "PET" or not frame.petUnit then
        if frame and frame.healthBar then
            frame.healthBar:Hide()
        end
        return
    end
    if type(UnitHealth) ~= "function" or type(UnitHealthMax) ~= "function" then
        frame.healthBar:Hide()
        return
    end

    local health = UnitHealth(frame.petUnit)
    local maximum = UnitHealthMax(frame.petUnit)
    if type(issecretvalue) == "function"
        and (issecretvalue(health) or issecretvalue(maximum))
    then
        frame.healthBar:Hide()
        return
    end
    if type(health) ~= "number" or type(maximum) ~= "number" or maximum <= 0 then
        frame.healthBar:Hide()
        return
    end

    frame.healthBar:SetMinMaxValues(0, maximum)
    frame.healthBar:SetValue(math.max(0, math.min(health, maximum)))
    if frame.petRelation == "FRIENDLY" then
        frame.healthBar:SetStatusBarColor(0.1, 0.85, 0.2, 1)
    else
        frame.healthBar:SetStatusBarColor(0.85, 0.15, 0.1, 1)
    end
    frame.healthBar:Show()
end

function ClassIcon:SetBorderShown(frame, shown)
    for _, texture in pairs(frame.border or {}) do
        texture:SetShown(shown == true)
    end
end

function ClassIcon:ResolveNamePlateAnchor(namePlate)
    if not namePlate then
        return nil
    end
    if namePlate.UnitFrame then
        return namePlate.UnitFrame
    end
    return namePlate
end

function ClassIcon:ResolveNamePlateUnit(namePlate)
    if not namePlate then
        return nil
    end
    local unitToken = namePlate.namePlateUnitToken or namePlate.unitToken
    if not unitToken and namePlate.UnitFrame then
        unitToken = namePlate.UnitFrame.unit or namePlate.UnitFrame.unitToken
    end
    return IsNameplateToken(unitToken) and unitToken or nil
end

function ClassIcon:ApplyVisualSettings(frame, anchor)
    local settings = WAA.db.modules.classIcon
    frame:SetSize(settings.iconSize, settings.iconSize)
    frame:EnableMouse(false)
    self:SetBorderShown(frame, settings.showBorder)
    if anchor then
        frame:SetParent(anchor)
        if anchor.GetFrameLevel and frame.SetFrameLevel then
            local ok, level = pcall(anchor.GetFrameLevel, anchor)
            if ok and type(level) == "number" then
                frame:SetFrameLevel(level + 10)
            end
        end
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOM", anchor, "TOP", settings.offsetX, settings.offsetY)
    end
end

function ClassIcon:AcquireFrame()
    local frame = table.remove(self.pool)
    if not frame then
        frame = self:CreateIconFrame(UIParent)
    end
    frame.isPooled = false
    frame:EnableMouse(false)
    return frame
end

function ClassIcon:ReleaseFrame(frame)
    if not frame or frame.isPooled then
        return
    end

    if frame.unitToken and self.activeByUnit[frame.unitToken] == frame then
        self.activeByUnit[frame.unitToken] = nil
    end
    if frame.guid and self.activeByGUID[frame.guid] == frame then
        self.activeByGUID[frame.guid] = nil
    end
    if frame.namePlate and self.activeByNamePlate[frame.namePlate] == frame then
        self.activeByNamePlate[frame.namePlate] = nil
    end
    if frame.anchor and self.activeByAnchor[frame.anchor] == frame then
        self.activeByAnchor[frame.anchor] = nil
    end
    if frame.petUnit and self.activeByPetUnit[frame.petUnit] == frame then
        self.activeByPetUnit[frame.petUnit] = nil
    end
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetParent(UIParent)
    frame.icon:SetTexture(nil)
    frame.icon:SetTexCoord(0, 1, 0, 1)
    frame.unitToken = nil
    frame.guid = nil
    frame.classFile = nil
    frame.iconKind = nil
    frame.petUnit = nil
    frame.petRelation = nil
    frame.healthBar:Hide()
    frame.healthBar:SetMinMaxValues(0, 1)
    frame.healthBar:SetValue(1)
    frame.namePlate = nil
    frame.anchor = nil
    frame.isPooled = true
    table.insert(self.pool, frame)
end

function ClassIcon:ReleaseUnit(unitToken)
    self:ReleaseFrame(self.activeByUnit[unitToken])
end

function ClassIcon:CanRun()
    return WAA.isInArena == true and WAA:IsModuleEnabled("classIcon")
end

function ClassIcon:ShowForUnit(unitToken, refreshReason)
    if not self:CanRun() or not IsNameplateToken(unitToken) then
        self:ReleaseUnit(unitToken)
        return false
    end

    local guid = UnitGUID(unitToken)
    self.visibleUnits[unitToken] = guid
    if not guid then
        self:ReleaseUnit(unitToken)
        return false
    end

    if not C_NamePlate or type(C_NamePlate.GetNamePlateForUnit) ~= "function" then
        self:ReleaseUnit(unitToken)
        WAA:Debug("ClassIcon nameplate API unavailable")
        return false
    end
    local namePlate = C_NamePlate.GetNamePlateForUnit(unitToken)
    local anchor = self:ResolveNamePlateAnchor(namePlate)
    if not anchor then
        self:ReleaseUnit(unitToken)
        WAA:Debug("ClassIcon nameplate frame unavailable: unit=" .. unitToken)
        return false
    end

    local staleFrame = self.activeByNamePlate[namePlate] or self.activeByAnchor[anchor]
    if staleFrame and (staleFrame.unitToken ~= unitToken or staleFrame.guid ~= guid) then
        WAA:Debug(
            "ClassIcon recycled nameplate cleanup:",
            tostring(staleFrame.unitToken),
            "->",
            unitToken
        )
        self:ReleaseFrame(staleFrame)
    end

    local petUnit, petRelation = self:GetPetByGUID(guid, unitToken)
    local explicitlyNotPlayer = false
    if type(UnitIsPlayer) == "function" then
        local ok, isPlayer = pcall(UnitIsPlayer, unitToken)
        explicitlyNotPlayer = ok and isPlayer == false
    end
    local opponent = not petUnit and not explicitlyNotPlayer and WAA.Arena:GetOpponentByGUID(guid) or nil
    if not opponent and not petUnit then
        self:ReleaseUnit(unitToken)
        self.pendingByUnit[unitToken] = guid
        WAA:Debug("ClassIcon ignored: GUID is not mapped arena opponent")
        return false
    end
    if opponent and not TBC_CLASSES[opponent.classFile] then
        self:ReleaseUnit(unitToken)
        self.pendingByUnit[unitToken] = nil
        WAA:Debug("ClassIcon texture unavailable: class=" .. tostring(opponent.classFile))
        return false
    end

    local existing = self.activeByUnit[unitToken]
    if existing and (existing.guid ~= guid or existing.namePlate ~= namePlate) then
        self:ReleaseFrame(existing)
        existing = nil
    end
    local duplicate = self.activeByGUID[guid]
    if duplicate and duplicate ~= existing then
        self:ReleaseFrame(duplicate)
    end

    local frame = existing or self:AcquireFrame()
    local textureReady
    if opponent then
        textureReady = self:SetClassTexture(frame.icon, opponent.classFile)
    else
        textureReady = self:SetPetTexture(frame.icon, petUnit)
    end
    if not textureReady then
        self:ReleaseFrame(frame)
        return false
    end

    if frame.petUnit and self.activeByPetUnit[frame.petUnit] == frame then
        self.activeByPetUnit[frame.petUnit] = nil
    end

    frame.unitToken = unitToken
    frame.guid = guid
    frame.classFile = opponent and opponent.classFile or nil
    frame.iconKind = opponent and "CLASS" or "PET"
    frame.petUnit = petUnit
    frame.petRelation = petRelation
    frame.namePlate = namePlate
    frame.anchor = anchor
    self.activeByUnit[unitToken] = frame
    self.activeByGUID[guid] = frame
    self.activeByNamePlate[namePlate] = frame
    self.activeByAnchor[anchor] = frame
    if petUnit then
        self.activeByPetUnit[petUnit] = frame
    end
    self:ApplyVisualSettings(frame, anchor)
    self:UpdatePetHealth(frame)
    frame:Show()

    local wasPending = self.pendingByUnit[unitToken] == guid
    self.pendingByUnit[unitToken] = nil
    if refreshReason == "mapping" and wasPending then
        WAA:Debug("ClassIcon late mapping resolved: " .. unitToken .. " -> " .. tostring(opponent and opponent.unit or petUnit))
    end
    if opponent then
        WAA:Debug("ClassIcon matched: " .. unitToken .. " -> " .. tostring(opponent.unit) .. " -> " .. opponent.classFile)
        WAA:Debug("ClassIcon shown: unit=" .. unitToken .. " class=" .. opponent.classFile)
    else
        WAA:Debug("ClassIcon matched pet: " .. unitToken .. " -> " .. petUnit .. " relation=" .. petRelation)
        WAA:Debug("ClassIcon shown: unit=" .. unitToken .. " pet=" .. petUnit)
    end
    return true
end

function ClassIcon:OnNamePlateEvent(event, unitToken)
    if event == "NAME_PLATE_UNIT_ADDED" then
        if not self:CanRun() or not IsNameplateToken(unitToken) then
            return
        end
        local guid = UnitGUID(unitToken)
        WAA:Debug("ClassIcon NAME_PLATE_UNIT_ADDED: unit=" .. unitToken .. " guid=" .. tostring(guid))
        self:ReleaseUnit(unitToken)
        self.visibleUnits[unitToken] = guid
        self:ShowForUnit(unitToken)
    elseif event == "NAME_PLATE_UNIT_REMOVED" and IsNameplateToken(unitToken) then
        local frame = self.activeByUnit[unitToken]
        local guid = (frame and frame.guid) or self.visibleUnits[unitToken] or UnitGUID(unitToken)
        self:ReleaseUnit(unitToken)
        self.visibleUnits[unitToken] = nil
        self.pendingByUnit[unitToken] = nil
        WAA:Debug("ClassIcon removed: unit=" .. unitToken .. " guid=" .. tostring(guid))
    end
end

function ClassIcon:OnPetEvent(_, ownerUnit)
    if type(ownerUnit) == "string"
        and (ownerUnit == "player" or ownerUnit:match("^arena[1-5]$") or ownerUnit:match("^party[1-4]$"))
    then
        WAA:Debug("ClassIcon pet changed: owner=" .. ownerUnit)
        self:RefreshVisibleNameplates("pet")
    end
end

function ClassIcon:OnPetHealthEvent(_, unitToken)
    local frame = self.activeByPetUnit[unitToken] or self.activeByUnit[unitToken]
    if frame and frame.iconKind == "PET" then
        self:UpdatePetHealth(frame)
    end
end

function ClassIcon:RefreshVisibleNameplates(reason)
    if not self:CanRun() then
        self:ClearRuntime()
        return
    end

    WAA:Debug("ClassIcon refresh visible nameplates")
    local resolved = {}
    if C_NamePlate and type(C_NamePlate.GetNamePlates) == "function" then
        local plates = C_NamePlate.GetNamePlates() or {}
        for _, namePlate in ipairs(plates) do
            local unitToken = self:ResolveNamePlateUnit(namePlate)
            if unitToken then
                resolved[unitToken] = true
                self.visibleUnits[unitToken] = UnitGUID(unitToken)
                self:ShowForUnit(unitToken, reason == "mapping" and "mapping" or nil)
            else
                WAA:Debug("ClassIcon visible nameplate has no safe unit token")
            end
        end
    else
        WAA:Debug("ClassIcon visible nameplate scan API unavailable")
    end

    for unitToken in pairs(self.visibleUnits) do
        if not resolved[unitToken] then
            self:ShowForUnit(unitToken, reason == "mapping" and "mapping" or nil)
        end
    end
end

function ClassIcon:OnOpponentMappingChanged()
    if self:CanRun() then
        self:RefreshVisibleNameplates("mapping")
    end
end

function ClassIcon:OnArenaActivated()
    if self:CanRun() then
        self:RefreshVisibleNameplates("arena start")
    else
        self:ClearRuntime()
    end
end

function ClassIcon:OnSettingsChanged()
    if not self:CanRun() then
        self:ClearRuntime()
        return
    end

    for _, frame in pairs(self.activeByUnit) do
        self:ApplyVisualSettings(frame, frame.anchor)
    end
    self:RefreshVisibleNameplates("settings")
end

function ClassIcon:ClearRuntime()
    local active = {}
    for _, frame in pairs(self.activeByUnit or {}) do
        active[#active + 1] = frame
    end
    for _, frame in ipairs(active) do
        self:ReleaseFrame(frame)
    end
    wipe(self.activeByUnit or {})
    wipe(self.activeByGUID or {})
    wipe(self.activeByNamePlate or {})
    wipe(self.activeByAnchor or {})
    wipe(self.activeByPetUnit or {})
    wipe(self.visibleUnits or {})
    wipe(self.pendingByUnit or {})
end

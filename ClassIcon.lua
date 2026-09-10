local _, WAA = ...

local ClassIcon = {}
WAA.ClassIcon = ClassIcon

local CLASS_TEXTURE = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
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
    self.visibleUnits = {}
    self.pendingByUnit = {}
    self.pool = {}
    WAA.Arena:RegisterRuntimeEvent(self, "NAME_PLATE_UNIT_ADDED", self.OnNamePlateEvent)
    WAA.Arena:RegisterRuntimeEvent(self, "NAME_PLATE_UNIT_REMOVED", self.OnNamePlateEvent)
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
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetParent(UIParent)
    frame.icon:SetTexture(nil)
    frame.icon:SetTexCoord(0, 1, 0, 1)
    frame.unitToken = nil
    frame.guid = nil
    frame.classFile = nil
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

    local opponent = WAA.Arena:GetOpponentByGUID(guid)
    if not opponent then
        self:ReleaseUnit(unitToken)
        self.pendingByUnit[unitToken] = guid
        WAA:Debug("ClassIcon ignored: GUID is not mapped arena opponent")
        return false
    end
    if not TBC_CLASSES[opponent.classFile] then
        self:ReleaseUnit(unitToken)
        self.pendingByUnit[unitToken] = nil
        WAA:Debug("ClassIcon texture unavailable: class=" .. tostring(opponent.classFile))
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
    if not self:SetClassTexture(frame.icon, opponent.classFile) then
        self:ReleaseFrame(frame)
        return false
    end

    frame.unitToken = unitToken
    frame.guid = guid
    frame.classFile = opponent.classFile
    frame.namePlate = namePlate
    frame.anchor = anchor
    self.activeByUnit[unitToken] = frame
    self.activeByGUID[guid] = frame
    self:ApplyVisualSettings(frame, anchor)
    frame:Show()

    local wasPending = self.pendingByUnit[unitToken] == guid
    self.pendingByUnit[unitToken] = nil
    if refreshReason == "mapping" and wasPending then
        WAA:Debug("ClassIcon late mapping resolved: " .. unitToken .. " -> " .. tostring(opponent.unit))
    end
    WAA:Debug("ClassIcon matched: " .. unitToken .. " -> " .. tostring(opponent.unit) .. " -> " .. opponent.classFile)
    WAA:Debug("ClassIcon shown: unit=" .. unitToken .. " class=" .. opponent.classFile)
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
    wipe(self.visibleUnits or {})
    wipe(self.pendingByUnit or {})
end

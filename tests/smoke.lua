local frames = {}
local timers = {}
local arenaState = false
local now = 100
local soundCount = 0
local openedSettings = 0
local printed = {}
local playerGUID = "Player-Self"
local playerClassFile = "PRIEST"
local arenaUnits = {}
local nameplateUnits = {}
local nameplates = {}
local unitAuras = {}
local unitAuraCalls = 0
local totalAbsorb
local cleuPayload
local unpackValues = table.unpack or unpack

local Object = {}
Object.__index = function(_, key)
    local method = rawget(Object, key)
    if method then
        return method
    end
    return function() end
end

local function NewObject()
    return setmetatable({ events = {}, scripts = {}, shown = false }, Object)
end

function Object:RegisterEvent(event) self.events[event] = true end
function Object:UnregisterEvent(event) self.events[event] = nil end
function Object:SetScript(script, callback) self.scripts[script] = callback end
function Object:CreateTexture() return NewObject() end
function Object:CreateFontString() return NewObject() end
function Object:GetFont() return "mock-font", 12, "" end
function Object:SetFont(font, size, flags) self.font, self.fontSize, self.fontFlags = font, size, flags end
function Object:GetFrameLevel() return rawget(self, "frameLevel") or 0 end
function Object:SetFrameLevel(level) self.frameLevel = level end
function Object:SetPoint(point, _, relativePoint, x, y)
    self.point = { point, relativePoint or point, x or 0, y or 0 }
end
function Object:ClearAllPoints() self.point = nil end
function Object:GetPoint()
    local point = self.point or { "CENTER", "CENTER", 0, 0 }
    return point[1], UIParent, point[2], point[3], point[4]
end
function Object:SetText(text)
    if type(text) == "table" and text.failDisplay then
        error("mock secret display rejected")
    end
    self.text = text
end
function Object:SetChecked(value) self.checked = value end
function Object:GetChecked() return self.checked end
function Object:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
function Object:SetValueStep(step) self.step = step end
function Object:SetValue(value)
    self.value = value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
function Object:GetValue() return self.value or self.minimum or 0 end
function Object:SetThumbTexture() self.thumb = NewObject() end
function Object:GetThumbTexture() return self.thumb end
function Object:Show()
    self.shown = true
    self.showCount = (rawget(self, "showCount") or 0) + 1
end
function Object:Hide() self.shown = false end
function Object:SetShown(value) self.shown = value end
function Object:IsShown() return self.shown end
function Object:SetAlpha(value) self.alpha = value end
function Object:SetSize(width, height) self.width, self.height = width, height end
function Object:EnableMouse(value) self.mouseEnabled = value end
function Object:StartMoving() self.moving = true end
function Object:StopMovingOrSizing() self.moving = false end
function Object:SetParent(parent) self.parent = parent end
function Object:GetParent() return self.parent end
function Object:SetTexture(texture) self.texture = texture end
function Object:SetStatusBarTexture(texture) self.statusBarTexture = texture end
function Object:SetStatusBarColor(...) self.statusBarColor = { ... } end
function Object:SetTexCoord(...) self.texCoord = { ... } end
function Object:SetColorTexture(...) self.colorTexture = { ... } end
function Object:LockHighlight() self.highlighted = true end
function Object:UnlockHighlight() self.highlighted = false end
function Object:GetID() return self.id or 77 end

function CreateFrame()
    local frame = NewObject()
    frames[#frames + 1] = frame
    return frame
end

UIParent = NewObject()
BackdropTemplateMixin = {}
GameFontNormal = NewObject()
GameFontHighlight = NewObject()
SlashCmdList = {}
SOUNDKIT = { RAID_WARNING = 1 }
C_Timer = {
    After = function(duration, callback)
        timers[#timers + 1] = { due = now + duration, callback = callback, fired = false }
    end,
}
C_NamePlate = {
    GetNamePlateForUnit = function(unitToken)
        return nameplates[unitToken]
    end,
    GetNamePlates = function()
        local result = {}
        for _, namePlate in pairs(nameplates) do
            result[#result + 1] = namePlate
        end
        return result
    end,
}
Settings = {
    RegisterCanvasLayoutCategory = function()
        local category = NewObject()
        category.id = 77
        return category, NewObject()
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(categoryID)
        assert(categoryID == 77)
        openedSettings = openedSettings + 1
    end,
}

function GetSpellTexture() return nil end
function SetPortraitTexture(texture, unit)
    texture:SetTexture("PORTRAIT:" .. tostring(unit))
    texture:SetTexCoord(0, 1, 0, 1)
end
function GetSpellInfo(spellID)
    if spellID == 46755 then return "Drink", nil, nil, nil, nil, nil, spellID end
    return nil
end
function PlaySound() soundCount = soundCount + 1 end
function GetTime() return now end
function UnitExists(unit)
    return unit == "player" or arenaUnits[unit] ~= nil
end
function UnitGUID(unit)
    if unit == "player" then return playerGUID end
    if nameplateUnits[unit] then return nameplateUnits[unit].guid end
    return arenaUnits[unit] and arenaUnits[unit].guid or nil
end
function UnitClass(unit)
    if unit == "player" then return "Priest", playerClassFile, 5 end
    local opponent = arenaUnits[unit]
    if not opponent then return nil end
    return opponent.className, opponent.classFile, opponent.classID
end
function UnitName(unit) return arenaUnits[unit] and arenaUnits[unit].name or nil end
function UnitAura(unit, index)
    unitAuraCalls = unitAuraCalls + 1
    local aura = unitAuras[unit] and unitAuras[unit][index]
    if not aura then return nil end
    return aura.name, aura.texture, aura.applications, nil, nil, nil, nil, nil, nil, aura.spellID
end
function UnitIsPlayer(unit)
    local metadata = nameplateUnits[unit]
    return metadata and metadata.isPlayer
end
function UnitPlayerControlled(unit)
    local metadata = nameplateUnits[unit]
    return metadata and metadata.playerControlled
end
function UnitIsFriend(_, unit)
    return nameplateUnits[unit] and nameplateUnits[unit].friendly or false
end
function UnitHealth(unit)
    local metadata = arenaUnits[unit] or nameplateUnits[unit]
    return metadata and metadata.health or nil
end
function UnitHealthMax(unit)
    local metadata = arenaUnits[unit] or nameplateUnits[unit]
    return metadata and metadata.maxHealth or nil
end
function UnitGetTotalAbsorbs() return totalAbsorb end
function IsInInstance() return arenaState, arenaState and "arena" or "none" end
function CombatLogGetCurrentEventInfo() return unpackValues(cleuPayload) end
function wipe(target) for key in pairs(target) do target[key] = nil end end

local realPrint = print
function print(message)
    printed[#printed + 1] = tostring(message)
end

local namespace = {}
local files = {
    "Defaults.lua",
    "Core.lua",
    "Alerts.lua",
    "Arena.lua",
    "ClassIcon.lua",
    "EnemyOverpower.lua",
    "Drinking.lua",
    "InnerFire.lua",
    "ShieldAbsorb.lua",
    "Scatter.lua",
    "Options.lua",
}
for _, file in ipairs(files) do
    local chunk = assert(loadfile(file))
    chunk("WeshArenaAlerts", namespace)
end

local function Fire(event, ...)
    local count = #frames
    for index = 1, count do
        local callback = frames[index].scripts.OnEvent
        if callback and frames[index].events[event] then
            callback(frames[index], event, ...)
        end
    end
end

local function RunTimersThrough(targetTime)
    now = targetTime
    local ranTimer
    repeat
        ranTimer = false
        for _, timer in ipairs(timers) do
            if not timer.fired and timer.due <= now then
                timer.fired = true
                timer.callback()
                ranTimer = true
            end
        end
    until not ranTimer
end

local function CountEntries(target)
    local count = 0
    for _ in pairs(target) do count = count + 1 end
    return count
end

local function PrintedContains(fragment)
    for _, message in ipairs(printed) do
        if message:find(fragment, 1, true) then
            return true
        end
    end
    return false
end

local function AssertNoOpportunity(message)
    assert(CountEntries(namespace.EnemyOverpower.activeOpportunities) == 0, message)
    assert(not namespace.Alerts.frames.enemyOverpower:IsShown(), message .. " (frame visible)")
end

local function ResetRuntime()
    namespace.db.general.enabled = true
    namespace.db.modules.enemyOverpower.enabled = true
    namespace.db.modules.enemyOverpower.playSound = true
    namespace.db.modules.enemyOverpower.showCountdown = true
    namespace.EnemyOverpower:ClearRuntime()
end

local function ResetDrinking()
    namespace.db.general.enabled = true
    namespace.db.modules.drinking.enabled = true
    namespace.db.modules.drinking.playSound = true
    namespace.db.modules.drinking.duration = 3.0
    namespace.Drinking:ClearRuntime()
    unitAuras = {}
end

local function ResetScatter()
    namespace.db.general.enabled = true
    namespace.db.modules.scatter.enabled = true
    namespace.db.modules.scatter.flashEnabled = true
    namespace.db.modules.scatter.opacity = 0.55
    namespace.db.modules.scatter.duration = 0.45
    namespace.Scatter:ClearRuntime()
    namespace.Alerts:CancelHide("scatter")
    namespace.Alerts.scatterDisplayMode = nil
    namespace.Alerts.frames.scatter:Hide()
    namespace.Alerts.frames.scatter.showCount = 0
end

local function AssertNoScatter(message)
    assert(namespace.Alerts.frames.scatter.showCount == 0, message)
    assert(not namespace.Alerts.frames.scatter:IsShown(), message .. " (frame visible)")
end

local function MissEvent(eventType, sourceGUID, destGUID, missType, spellID)
    return {
        eventType = eventType,
        sourceGUID = sourceGUID,
        destGUID = destGUID,
        missType = missType,
        spellID = spellID,
    }
end

local function SpellEvent(eventType, sourceGUID, destGUID, spellID)
    return {
        eventType = eventType,
        sourceGUID = sourceGUID,
        destGUID = destGUID,
        spellID = spellID,
    }
end

local function AuraEvent(eventType, destGUID, spellID, spellName)
    return {
        eventType = eventType,
        destGUID = destGUID,
        spellID = spellID,
        spellName = spellName,
    }
end

local function SetAura(unit, spellName, spellID, applications, points, texture, auraInstanceID)
    unitAuras[unit] = spellName and {
        {
            name = spellName,
            spellID = spellID,
            applications = applications,
            points = points,
            texture = texture,
            auraInstanceID = auraInstanceID,
        },
    } or nil
end

local function UseModernAuras()
    C_UnitAuras = {
        GetAuraDataByIndex = function(unit, index)
            local aura = unitAuras[unit] and unitAuras[unit][index]
            if not aura then return nil end
            return {
                spellId = aura.spellID,
                applications = aura.applications,
                points = aura.points,
                icon = aura.texture,
                auraInstanceID = aura.auraInstanceID,
            }
        end,
    }
end

local function SetNameplate(unitToken, guid, useUnitFrameToken, traits)
    local namePlate = NewObject()
    namePlate.UnitFrame = NewObject()
    if useUnitFrameToken then
        namePlate.namePlateUnitToken = false
        namePlate.unitToken = false
        namePlate.UnitFrame.unit = unitToken
    else
        namePlate.namePlateUnitToken = unitToken
    end
    nameplates[unitToken] = namePlate
    nameplateUnits[unitToken] = {
        guid = guid,
        isPlayer = traits and traits.isPlayer,
        playerControlled = traits and traits.playerControlled,
        friendly = traits and traits.friendly or false,
        health = traits and traits.health or nil,
        maxHealth = traits and traits.maxHealth or nil,
    }
    return namePlate
end

local function RemoveNameplate(unitToken)
    nameplates[unitToken] = nil
    nameplateUnits[unitToken] = nil
    Fire("NAME_PLATE_UNIT_REMOVED", unitToken)
end

Fire("ADDON_LOADED", "WeshArenaAlerts")
Fire("PLAYER_LOGIN")

-- Milestone 0.1 compatibility smoke checks.
assert(namespace.initialized)
assert(namespace.version == "0.7.0")
assert(namespace.Drinking.drinkAuraName == "Drink")
assert(namespace.Drinking.KNOWN_DRINK_SPELL_IDS[430])
assert(namespace.Drinking.KNOWN_DRINK_SPELL_IDS[43154])
assert(namespace.EnemyOverpower.OVERPOWER_WINDOW_SECONDS == 5.0)
assert(namespace.EnemyOverpower.OVERPOWER_SPELL_IDS[7384])
assert(namespace.EnemyOverpower.OVERPOWER_SPELL_IDS[7887])
assert(namespace.EnemyOverpower.OVERPOWER_SPELL_IDS[11584])
assert(namespace.EnemyOverpower.OVERPOWER_SPELL_IDS[11585])
assert(namespace.Scatter.SCATTER_SHOT_SPELL_ID == 19503)
assert(namespace.Scatter.SCATTER_EVENT_DEDUP_SECONDS == 0.5)
assert(namespace.InnerFire.INNER_FIRE_SPELL_IDS[588])
assert(namespace.InnerFire.INNER_FIRE_SPELL_IDS[25431])
assert(namespace.ShieldAbsorb.POWER_WORD_SHIELD_SPELL_IDS[17])
assert(namespace.ShieldAbsorb.POWER_WORD_SHIELD_SPELL_IDS[25218])
assert(namespace.db.modules.shieldAbsorb.displayMode == "ICON_NUMBER")
assert(namespace.Alerts.frames.scatter.mouseEnabled == false)
assert(namespace.db.modules.enemyOverpower.showCountdown)
assert(namespace.Options.category:GetID() == 77)
assert(type(SlashCmdList.WESHARENAALERTS) == "function")
namespace.Alerts:TestAll()
namespace.Alerts:UnlockFrames()
namespace.Alerts:ClearRuntime()
assert(namespace.isUnlocked)
assert(namespace.Alerts.positioningMode)
for _, key in ipairs({ "drinking", "innerFire", "shieldAbsorb", "enemyOverpower" }) do
    assert(namespace.Alerts.frames[key]:IsShown())
    assert(namespace.Alerts.frames[key].mouseEnabled)
end
namespace.Options.panel.scripts.OnHide()
assert(namespace.isUnlocked and namespace.Alerts.positioningMode)
local movableFrame = namespace.Alerts.frames.drinking
movableFrame.scripts.OnDragStart(movableFrame)
assert(movableFrame.moving)
movableFrame.scripts.OnDragStop(movableFrame)
assert(not movableFrame.moving)
namespace.Alerts:LockFrames()
namespace:ResetPositions()
SlashCmdList.WESHARENAALERTS("")
assert(openedSettings == 1)
SlashCmdList.WESHARENAALERTS(" debug ")
assert(namespace.debugEnabled and namespace.db.general.debug)
assert(printed[#printed] == "WeshArenaAlerts debug: ON")
SlashCmdList.WESHARENAALERTS("debug")
assert(not namespace.debugEnabled and not namespace.db.general.debug)
assert(printed[#printed] == "WeshArenaAlerts debug: OFF")

arenaUnits.arena1 = { guid = "Enemy-Warrior-1", className = "Warrior", classFile = "WARRIOR", classID = 1, name = "ArmsOne" }
arenaUnits.arena2 = { guid = "Enemy-Rogue", className = "Rogue", classFile = "ROGUE", classID = 4, name = "Sneaky" }
arenaUnits.arena3 = { guid = "Enemy-Warrior-2", className = "Warrior", classFile = "WARRIOR", classID = 1, name = "ArmsTwo" }
local initialNamePlate = SetNameplate("nameplate1", "Enemy-Warrior-1", true)
arenaState = true
namespace.Arena:UpdateArenaState()
assert(namespace.isInArena)
assert(namespace.Arena.eventFrame.events.COMBAT_LOG_EVENT_UNFILTERED)
assert(namespace.Arena.eventFrame.events.UNIT_AURA)
assert(namespace.Arena.eventFrame.events.UNIT_ABSORB_AMOUNT_CHANGED)
assert(namespace.Arena.eventFrame.events.UNIT_SPELLCAST_SUCCEEDED)
assert(namespace.Arena.eventFrame.events.UNIT_HEALTH)
assert(namespace.Arena.eventFrame.events.UNIT_MAXHEALTH)
assert(namespace.Arena:GetOpponentByGUID("Enemy-Warrior-1").classFile == "WARRIOR")

-- Milestone 0.6: an already-visible mapped arena opponent is resolved during
-- arena-start refresh and anchored to the actual nameplate UnitFrame.
local warriorIcon = namespace.ClassIcon.activeByUnit.nameplate1
assert(warriorIcon and warriorIcon:IsShown())
assert(warriorIcon.classFile == "WARRIOR" and warriorIcon.guid == "Enemy-Warrior-1")
assert(warriorIcon.parent == initialNamePlate.UnitFrame)
assert(warriorIcon.point[1] == "BOTTOM" and warriorIcon.point[2] == "TOP")
assert(warriorIcon.point[3] == 0 and warriorIcon.point[4] == 4)
assert(warriorIcon.mouseEnabled == false)
assert(warriorIcon.icon.texture == namespace.ClassIcon.CLASS_TEXTURE)
assert(not warriorIcon.healthBar:IsShown())

-- Every TBC class has usable standard-sheet coordinates, including the local
-- fallback path when the client global is absent.
for _, classFile in ipairs({
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}) do
    local texture = NewObject()
    assert(namespace.ClassIcon:SetClassTexture(texture, classFile))
    assert(texture.texture == namespace.ClassIcon.CLASS_TEXTURE)
    assert(#texture.texCoord == 4)
end
assert(not namespace.ClassIcon:SetClassTexture(NewObject(), "DEATHKNIGHT"))

-- A second mapped class is selected from authoritative arena GUID metadata.
arenaUnits.arena4 = { guid = "Enemy-Priest", className = "Priest", classFile = "PRIEST", classID = 5, name = "DiscOne" }
Fire("ARENA_OPPONENT_UPDATE", "arena4", "seen")
SetNameplate("nameplate2", "Enemy-Priest")
Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
assert(namespace.ClassIcon.activeByUnit.nameplate2.classFile == "PRIEST")

-- Pets, NPCs/totems, friendly players, and unrelated enemies have no arena
-- GUID match and therefore cannot create a visual.
for _, guid in ipairs({ "Pet-Enemy", "Creature-Totem", "Player-Friendly", "Player-Unmapped" }) do
    SetNameplate("nameplate3", guid)
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
    assert(not namespace.ClassIcon.activeByUnit.nameplate3)
end

-- A nameplate can precede arena mapping; the mapping event triggers a one-shot
-- refresh and resolves it without polling.
SetNameplate("nameplate3", "Enemy-Late-Priest")
Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
assert(not namespace.ClassIcon.activeByUnit.nameplate3)
arenaUnits.arena5 = { guid = "Enemy-Late-Priest", className = "Priest", classFile = "PRIEST", classID = 5, name = "LateDisc" }
Fire("ARENA_OPPONENT_UPDATE", "arena5", "seen")
assert(namespace.ClassIcon.activeByUnit.nameplate3.classFile == "PRIEST")

-- Reusing the same token for another GUID revalidates and clears stale class
-- state even if Blizzard emits ADDED before a defensive REMOVED cleanup.
local priestFrame = namespace.ClassIcon.activeByUnit.nameplate3
SetNameplate("nameplate3", "Enemy-Warrior-2")
Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
assert(namespace.ClassIcon.activeByUnit.nameplate3.classFile == "WARRIOR")
assert(namespace.ClassIcon.activeByUnit.nameplate3.guid == "Enemy-Warrior-2")
assert(not namespace.ClassIcon.activeByGUID["Enemy-Late-Priest"])
assert(namespace.ClassIcon.activeByUnit.nameplate3 == priestFrame)

-- Removal releases into the bounded pool; acquisition scrubs and replaces all
-- unit/GUID/class metadata.
RemoveNameplate("nameplate3")
assert(not namespace.ClassIcon.activeByUnit.nameplate3)
assert(priestFrame.isPooled and not priestFrame:IsShown())
assert(rawget(priestFrame, "guid") == nil and rawget(priestFrame, "classFile") == nil)
SetNameplate("nameplate4", "Enemy-Rogue")
Fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
assert(namespace.ClassIcon.activeByUnit.nameplate4 == priestFrame)
assert(priestFrame.guid == "Enemy-Rogue" and priestFrame.classFile == "ROGUE")
assert(priestFrame.icon.texCoord[1] == namespace.ClassIcon.FALLBACK_TCOORDS.ROGUE[1])

-- Enemy arena pets use their own Blizzard unit portrait instead of inheriting
-- an owner's class icon. The owner slot must itself be a mapped arena opponent.
arenaUnits.arenapet1 = { guid = "Enemy-Pet-1", name = "ArenaPetOne", health = 700, maxHealth = 1000 }
SetNameplate("nameplate6", "Enemy-Pet-1")
Fire("NAME_PLATE_UNIT_ADDED", "nameplate6")
local petIcon = namespace.ClassIcon.activeByUnit.nameplate6
assert(petIcon and petIcon:IsShown())
assert(petIcon.iconKind == "PET" and petIcon.petUnit == "arenapet1")
assert(rawget(petIcon, "classFile") == nil)
assert(petIcon.icon.texture == "PORTRAIT:arenapet1")
assert(petIcon.mouseEnabled == false)
assert(petIcon.healthBar:IsShown())
assert(petIcon.healthBar.minimum == 0 and petIcon.healthBar.maximum == 1000)
assert(petIcon.healthBar.value == 700)
assert(petIcon.healthBar.statusBarColor[1] == 0.85)
arenaUnits.arenapet1.health = 325
Fire("UNIT_HEALTH", "arenapet1")
assert(petIcon.healthBar.value == 325)

-- Pet identity wins even if an inconsistent arena GUID map would otherwise
-- suggest the owner's WARLOCK class. An explicitly non-player unit can never
-- receive a class texture.
local felhunterGUID = "Pet-0-Enemy-Felhunter"
arenaUnits.arenapet5 = { guid = felhunterGUID, name = "Felhunter", health = 900, maxHealth = 1100 }
namespace.Arena.opponentsByGUID[felhunterGUID] = { unit = "arena5", guid = felhunterGUID, classFile = "WARLOCK" }
SetNameplate("nameplate13", felhunterGUID, false, {
    isPlayer = false,
    playerControlled = true,
    friendly = false,
})
Fire("NAME_PLATE_UNIT_ADDED", "nameplate13")
local felhunterIcon = namespace.ClassIcon.activeByUnit.nameplate13
assert(felhunterIcon and felhunterIcon.iconKind == "PET")
assert(felhunterIcon.petUnit == "arenapet5")
assert(rawget(felhunterIcon, "classFile") == nil)
assert(felhunterIcon.icon.texture == "PORTRAIT:arenapet5")
namespace.Arena.opponentsByGUID[felhunterGUID] = nil
RemoveNameplate("nameplate13")

local nonPlayerGUID = "Creature-Explicit-Non-Player"
namespace.Arena.opponentsByGUID[nonPlayerGUID] = {
    unit = "arena5",
    guid = nonPlayerGUID,
    classFile = "WARLOCK",
}
SetNameplate("nameplate14", nonPlayerGUID, false, {
    isPlayer = false,
    playerControlled = true,
    friendly = false,
})
Fire("NAME_PLATE_UNIT_ADDED", "nameplate14")
assert(not namespace.ClassIcon.activeByUnit.nameplate14)
namespace.Arena.opponentsByGUID[nonPlayerGUID] = nil
RemoveNameplate("nameplate14")

-- A real Pet GUID still receives its own portrait when arenapetN is temporarily
-- unavailable; the visible nameplate token becomes the portrait/health source.
SetNameplate("nameplate15", "Pet-0-Enemy-Fallback", false, {
    isPlayer = false,
    playerControlled = true,
    friendly = false,
    health = 500,
    maxHealth = 800,
})
Fire("NAME_PLATE_UNIT_ADDED", "nameplate15")
local fallbackPetIcon = namespace.ClassIcon.activeByUnit.nameplate15
assert(fallbackPetIcon and fallbackPetIcon.iconKind == "PET")
assert(fallbackPetIcon.petUnit == "nameplate15")
assert(fallbackPetIcon.icon.texture == "PORTRAIT:nameplate15")
assert(fallbackPetIcon.healthBar.value == 500)

-- A friendly party pet (including a Mage Water Elemental when exposed as
-- partypetN) receives its own portrait and a green health bar.
arenaUnits.party1 = { guid = "Friendly-Mage", name = "FrostMage" }
arenaUnits.partypet1 = {
    guid = "Friendly-Water-Elemental",
    name = "Water Elemental",
    health = 850,
    maxHealth = 1200,
}
SetNameplate("nameplate11", "Friendly-Water-Elemental")
Fire("NAME_PLATE_UNIT_ADDED", "nameplate11")
local friendlyPetIcon = namespace.ClassIcon.activeByUnit.nameplate11
assert(friendlyPetIcon and friendlyPetIcon:IsShown())
assert(friendlyPetIcon.iconKind == "PET" and friendlyPetIcon.petRelation == "FRIENDLY")
assert(friendlyPetIcon.petUnit == "partypet1")
assert(friendlyPetIcon.icon.texture == "PORTRAIT:partypet1")
assert(friendlyPetIcon.healthBar:IsShown())
assert(friendlyPetIcon.healthBar.value == 850 and friendlyPetIcon.healthBar.maximum == 1200)
assert(friendlyPetIcon.healthBar.statusBarColor[2] == 0.85)
arenaUnits.partypet1.health = 400
Fire("UNIT_HEALTH", "nameplate11")
assert(friendlyPetIcon.healthBar.value == 400)
arenaUnits.partypet1.maxHealth = 1500
Fire("UNIT_MAXHEALTH", "partypet1")
assert(friendlyPetIcon.healthBar.maximum == 1500)

-- A newly summoned friendly pet is picked up by UNIT_PET even when its
-- nameplate arrived before the partypet token became available.
arenaUnits.party2 = { guid = "Friendly-Mage-Two", name = "SecondMage" }
SetNameplate("nameplate12", "Friendly-Water-Elemental-Late")
Fire("NAME_PLATE_UNIT_ADDED", "nameplate12")
assert(not namespace.ClassIcon.activeByUnit.nameplate12)
arenaUnits.partypet2 = {
    guid = "Friendly-Water-Elemental-Late",
    name = "Water Elemental",
    health = 600,
    maxHealth = 900,
}
Fire("UNIT_PET", "party2")
assert(namespace.ClassIcon.activeByUnit.nameplate12.petUnit == "partypet2")
assert(namespace.ClassIcon.activeByUnit.nameplate12.healthBar.value == 600)

-- The physical Blizzard nameplate frame can be recycled under a different
-- nameplate token. Its former Warrior visual is released before the pet portrait
-- is attached, even if REMOVED was not observed first.
local recycledPlate = SetNameplate("nameplate7", "Enemy-Warrior-2")
Fire("NAME_PLATE_UNIT_ADDED", "nameplate7")
local recycledFrame = namespace.ClassIcon.activeByUnit.nameplate7
assert(recycledFrame and recycledFrame.classFile == "WARRIOR")
nameplates.nameplate7 = nil
nameplateUnits.nameplate7 = nil
local recycledWrapper = NewObject()
recycledWrapper.UnitFrame = recycledPlate.UnitFrame
recycledWrapper.namePlateUnitToken = "nameplate8"
nameplates.nameplate8 = recycledWrapper
nameplateUnits.nameplate8 = { guid = "Enemy-Pet-2" }
arenaUnits.arenapet2 = { guid = "Enemy-Pet-2", name = "ArenaPetTwo" }
Fire("NAME_PLATE_UNIT_ADDED", "nameplate8")
assert(not namespace.ClassIcon.activeByUnit.nameplate7)
assert(namespace.ClassIcon.activeByUnit.nameplate8 == recycledFrame)
assert(recycledFrame.iconKind == "PET" and recycledFrame.petUnit == "arenapet2")
assert(rawget(recycledFrame, "classFile") == nil)
assert(recycledFrame.icon.texture == "PORTRAIT:arenapet2")
RemoveNameplate("nameplate8")

-- If the client portrait helper is unavailable, pet handling fails closed.
local savedSetPortraitTexture = SetPortraitTexture
SetPortraitTexture = nil
arenaUnits.arenapet3 = { guid = "Enemy-Pet-No-Portrait", name = "NoPortrait" }
SetNameplate("nameplate9", "Enemy-Pet-No-Portrait")
assert(pcall(function() Fire("NAME_PLATE_UNIT_ADDED", "nameplate9") end))
assert(not namespace.ClassIcon.activeByUnit.nameplate9)
SetPortraitTexture = savedSetPortraitTexture
RemoveNameplate("nameplate9")

-- UNIT_PET resolves a pet whose arena token becomes available after its visible
-- nameplate, without periodic scanning.
SetNameplate("nameplate10", "Enemy-Pet-Late")
Fire("NAME_PLATE_UNIT_ADDED", "nameplate10")
assert(not namespace.ClassIcon.activeByUnit.nameplate10)
arenaUnits.arenapet4 = { guid = "Enemy-Pet-Late", name = "LateArenaPet" }
Fire("UNIT_PET", "arena4")
assert(namespace.ClassIcon.activeByUnit.nameplate10.iconKind == "PET")
assert(namespace.ClassIcon.activeByUnit.nameplate10.icon.texture == "PORTRAIT:arenapet4")

-- Size, offsets, and border apply live to existing frames without recreation.
namespace.db.modules.classIcon.iconSize = 40
namespace.db.modules.classIcon.offsetX = 13
namespace.db.modules.classIcon.offsetY = 19
namespace.db.modules.classIcon.showBorder = false
namespace.ClassIcon:OnSettingsChanged()
assert(warriorIcon.width == 40 and warriorIcon.height == 40)
assert(warriorIcon.point[3] == 13 and warriorIcon.point[4] == 19)
assert(not warriorIcon.border.top:IsShown())
namespace.db.modules.classIcon.showBorder = true
namespace.ClassIcon:OnSettingsChanged()
assert(warriorIcon.border.top:IsShown())

-- Module/master disable clean immediately, and re-enable in an arena performs
-- a visible-nameplate refresh without requiring reload.
namespace.db.modules.classIcon.enabled = false
namespace.ClassIcon:OnSettingsChanged()
assert(not next(namespace.ClassIcon.activeByUnit))
namespace.db.modules.classIcon.enabled = true
namespace.ClassIcon:OnSettingsChanged()
assert(namespace.ClassIcon.activeByUnit.nameplate1)
namespace.db.general.enabled = false
namespace.ClassIcon:OnSettingsChanged()
assert(not next(namespace.ClassIcon.activeByUnit))
namespace.db.general.enabled = true
namespace.ClassIcon:OnSettingsChanged()
assert(namespace.ClassIcon.activeByUnit.nameplate1)

-- Missing nameplate APIs and unsafe initial-scan tokens fail closed.
local savedNamePlateAPI = C_NamePlate
C_NamePlate = nil
assert(pcall(function() namespace.ClassIcon:RefreshVisibleNameplates("test") end))
assert(not next(namespace.ClassIcon.activeByUnit))
C_NamePlate = savedNamePlateAPI
local unsafePlate = NewObject()
nameplates.unsafe = unsafePlate
assert(pcall(function() namespace.ClassIcon:RefreshVisibleNameplates("test") end))
nameplates.unsafe = nil
namespace.ClassIcon:RefreshVisibleNameplates("test")
assert(namespace.ClassIcon.activeByUnit.nameplate1)

-- The settings preview is independent and never enters runtime associations.
assert(namespace.Options.classIconPreview.iconFrame:IsShown())
assert(rawget(namespace.Options.classIconPreview.iconFrame, "classFile") == nil)

-- Debug mode exposes event, match, show, removal, late mapping, and refresh flow.
namespace.debugEnabled = true
namespace.db.general.debug = true
RemoveNameplate("nameplate4")
SetNameplate("nameplate4", "Enemy-Rogue")
Fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
namespace.ClassIcon:RefreshVisibleNameplates("test")
SetNameplate("nameplate5", "Enemy-Debug-Late")
Fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
arenaUnits.arena5 = { guid = "Enemy-Debug-Late", className = "Priest", classFile = "PRIEST", classID = 5, name = "DebugDisc" }
Fire("ARENA_OPPONENT_UPDATE", "arena5", "seen")
assert(PrintedContains("ClassIcon NAME_PLATE_UNIT_ADDED: unit=nameplate4 guid=Enemy-Rogue"))
assert(PrintedContains("ClassIcon matched: nameplate4 -> arena2 -> ROGUE"))
assert(PrintedContains("ClassIcon shown: unit=nameplate4 class=ROGUE"))
assert(PrintedContains("ClassIcon removed: unit=nameplate4 guid=Enemy-Rogue"))
assert(PrintedContains("ClassIcon refresh visible nameplates"))
assert(PrintedContains("ClassIcon late mapping resolved: nameplate5 -> arena5"))
assert(PrintedContains("ClassIcon matched pet: nameplate6 -> arenapet1"))
RemoveNameplate("nameplate5")
namespace.debugEnabled = false
namespace.db.general.debug = false

-- Restore defaults for later regression scenarios.
namespace.db.modules.classIcon.iconSize = 28
namespace.db.modules.classIcon.offsetX = 0
namespace.db.modules.classIcon.offsetY = 4
namespace.db.modules.classIcon.showBorder = true

-- Arena exit unregisters both nameplate events and clears every runtime visual;
-- the static Settings preview remains available. Re-entry refreshes visible plates.
arenaState = false
namespace.Arena:UpdateArenaState()
assert(not next(namespace.ClassIcon.activeByUnit))
assert(not namespace.Arena.eventFrame.events.NAME_PLATE_UNIT_ADDED)
assert(not namespace.Arena.eventFrame.events.NAME_PLATE_UNIT_REMOVED)
assert(not namespace.Arena.eventFrame.events.UNIT_PET)
assert(not namespace.Arena.eventFrame.events.UNIT_HEALTH)
assert(not namespace.Arena.eventFrame.events.UNIT_MAXHEALTH)
assert(namespace.Options.classIconPreview.iconFrame:IsShown())
Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
assert(not next(namespace.ClassIcon.activeByUnit))
arenaState = true
namespace.Arena:UpdateArenaState()
assert(namespace.Arena.eventFrame.events.NAME_PLATE_UNIT_ADDED)
assert(namespace.Arena.eventFrame.events.NAME_PLATE_UNIT_REMOVED)
assert(namespace.Arena.eventFrame.events.UNIT_PET)
assert(namespace.Arena.eventFrame.events.UNIT_HEALTH)
assert(namespace.Arena.eventFrame.events.UNIT_MAXHEALTH)
assert(namespace.ClassIcon.activeByUnit.nameplate1)

-- Milestone 0.5: the player aura is the only source of truth for the persistent
-- Priest Inner Fire OK / LOW / MISSING state machine.
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_MISSING)
assert(namespace.Alerts.frames.innerFire:IsShown())
assert(namespace.Alerts.frames.innerFire.missing:IsShown())
assert(not namespace.Alerts.frames.innerFire.count:IsShown())

SetAura("player", "Inner Fire", 25431, 20)
Fire("UNIT_AURA", "player")
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_OK)
assert(namespace.InnerFire.isPresent and namespace.InnerFire.charges == 20)
assert(namespace.InnerFire.spellID == 25431)
assert(not namespace.Alerts.frames.innerFire:IsShown())

SetAura("player", "Inner Fire", 25431, 6)
Fire("UNIT_AURA", "player")
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_OK)
SetAura("player", "Inner Fire", 25431, 5)
Fire("UNIT_AURA", "player")
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_LOW)
assert(namespace.Alerts.frames.innerFire:IsShown())
assert(namespace.Alerts.frames.innerFire.count.text == "5")
assert(namespace.Alerts.frames.innerFire.count:IsShown())
assert(not namespace.Alerts.frames.innerFire.missing:IsShown())
local innerShowCount = namespace.Alerts.frames.innerFire.showCount
Fire("UNIT_AURA", "player")
assert(namespace.Alerts.frames.innerFire.showCount == innerShowCount)

for charges = 4, 1, -1 do
    SetAura("player", "Inner Fire", 25431, charges)
    Fire("UNIT_AURA", "player")
    assert(namespace.InnerFire.state == namespace.InnerFire.STATE_LOW)
    assert(namespace.InnerFire.charges == charges)
    assert(namespace.Alerts.frames.innerFire.count.text == tostring(charges))
    assert(namespace.Alerts.frames.innerFire.showCount == innerShowCount)
end

SetAura("player", "Inner Fire", 25431, 20)
Fire("UNIT_AURA", "player")
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_OK)
assert(not namespace.Alerts.frames.innerFire:IsShown())

-- LOW -> MISSING and MISSING -> LOW reuse the same visible frame without a hide/show.
SetAura("player", "Inner Fire", 10952, 3)
Fire("UNIT_AURA", "player")
innerShowCount = namespace.Alerts.frames.innerFire.showCount
SetAura("player")
Fire("UNIT_AURA", "player")
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_MISSING)
assert(namespace.Alerts.frames.innerFire:IsShown())
assert(namespace.Alerts.frames.innerFire.showCount == innerShowCount)
assert(namespace.Alerts.frames.innerFire.missing:IsShown())
assert(not namespace.Alerts.frames.innerFire.count:IsShown())
Fire("UNIT_AURA", "player")
assert(namespace.Alerts.frames.innerFire.showCount == innerShowCount)
SetAura("player", "Inner Fire", 588, 4)
Fire("UNIT_AURA", "player")
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_LOW)
assert(namespace.InnerFire.spellID == 588)
assert(namespace.Alerts.frames.innerFire.showCount == innerShowCount)
assert(not namespace.Alerts.frames.innerFire.missing:IsShown())
assert(namespace.Alerts.frames.innerFire.count.text == "4")

-- A present aura with an unusable count is neither LOW nor MISSING.
SetAura("player", "Inner Fire", 7128, nil)
Fire("UNIT_AURA", "player")
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_PRESENT_COUNT_UNKNOWN)
assert(namespace.InnerFire.isPresent and namespace.InnerFire.charges == nil)
assert(not namespace.Alerts.frames.innerFire:IsShown())

-- A different five-stack buff cannot be mistaken for Inner Fire.
SetAura("player", "Other Buff", 12345, 5)
Fire("UNIT_AURA", "player")
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_MISSING)
assert(namespace.Alerts.frames.innerFire.missing:IsShown())

-- Live threshold and presentation settings use tracked aura data; no reload or rescan.
SetAura("player", "Inner Fire", 602, 6)
Fire("UNIT_AURA", "player")
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_OK)
namespace.db.modules.innerFire.threshold = 7
namespace.InnerFire:OnSettingsChanged()
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_LOW)
assert(namespace.Alerts.frames.innerFire.count.text == "6")
namespace.db.modules.innerFire.showStackCount = false
namespace.InnerFire:OnSettingsChanged()
assert(namespace.Alerts.frames.innerFire:IsShown())
assert(not namespace.Alerts.frames.innerFire.count:IsShown())
namespace.db.modules.innerFire.showStackCount = true
namespace.InnerFire:OnSettingsChanged()
assert(namespace.Alerts.frames.innerFire.count:IsShown())
namespace.db.modules.innerFire.iconSize = 96
namespace.InnerFire:OnSettingsChanged()
assert(namespace.Alerts.frames.innerFire.icon.width == 96)
namespace.db.modules.innerFire.threshold = 5
namespace.InnerFire:OnSettingsChanged()
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_OK)
assert(not namespace.Alerts.frames.innerFire:IsShown())

SetAura("player")
Fire("UNIT_AURA", "player")
namespace.db.modules.innerFire.threshold = 7
namespace.InnerFire:OnSettingsChanged()
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_MISSING)
assert(not namespace.Alerts.frames.innerFire.count:IsShown())

-- Disable cleanup and in-arena re-enable both perform the expected lifecycle work.
namespace.db.modules.innerFire.enabled = false
namespace.InnerFire:OnSettingsChanged()
assert(namespace.InnerFire.state == nil and not namespace.InnerFire.isPresent)
assert(not namespace.Alerts.frames.innerFire:IsShown())
SetAura("player", "Inner Fire", 1006, 4)
namespace.db.modules.innerFire.enabled = true
namespace.InnerFire:OnSettingsChanged()
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_LOW)
assert(namespace.InnerFire.charges == 4)
namespace.db.general.enabled = false
namespace.InnerFire:OnSettingsChanged()
assert(namespace.InnerFire.state == nil)
assert(not namespace.Alerts.frames.innerFire:IsShown())
SetAura("player")
namespace.db.general.enabled = true
namespace.InnerFire:OnSettingsChanged()
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_MISSING)

-- Non-Priests are rejected before any aura scan, including the MISSING case.
namespace.InnerFire:ClearRuntime()
playerClassFile = "MAGE"
unitAuraCalls = 0
Fire("UNIT_AURA", "player")
assert(unitAuraCalls == 0)
assert(namespace.InnerFire.state == nil)
assert(not namespace.Alerts.frames.innerFire:IsShown())
playerClassFile = "PRIEST"

-- Arena exit clears LOW immediately; re-entry performs a fresh one-time scan.
SetAura("player", "Inner Fire", 10952, 4)
Fire("UNIT_AURA", "player")
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_LOW)
arenaState = false
namespace.Arena:UpdateArenaState()
assert(namespace.InnerFire.state == nil)
assert(not namespace.Alerts.frames.innerFire:IsShown())
SetAura("player", "Inner Fire", 25431, 20)
arenaState = true
namespace.Arena:UpdateArenaState()
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_OK)
assert(namespace.InnerFire.charges == 20)
assert(not namespace.Alerts.frames.innerFire:IsShown())

-- Modern AuraData is preferred; removing it exercises the legacy UnitAura fallback.
local modernAura = { spellId = 10951, applications = 4 }
C_UnitAuras = {
    GetAuraDataByIndex = function(_, index)
        if index == 1 then return modernAura end
        return nil
    end,
}
unitAuraCalls = 0
Fire("UNIT_AURA", "player")
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_LOW)
assert(namespace.InnerFire.spellID == 10951 and namespace.InnerFire.charges == 4)
assert(unitAuraCalls == 0)
C_UnitAuras = nil
SetAura("player", "Inner Fire", 25431, 20)
Fire("UNIT_AURA", "player")
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_OK)
assert(unitAuraCalls > 0)

-- Debug mode exposes state transitions, charge updates, removal, and bad counts.
namespace.db.modules.innerFire.threshold = 5
namespace.InnerFire:OnSettingsChanged()
namespace.debugEnabled = true
namespace.db.general.debug = true
SetAura("player", "Inner Fire", 25431, 6)
Fire("UNIT_AURA", "player")
SetAura("player", "Inner Fire", 25431, 5)
Fire("UNIT_AURA", "player")
SetAura("player", "Inner Fire", 25431, 4)
Fire("UNIT_AURA", "player")
SetAura("player")
Fire("UNIT_AURA", "player")
SetAura("player", "Inner Fire", 25431, 20)
Fire("UNIT_AURA", "player")
SetAura("player", "Inner Fire", 25431, nil)
Fire("UNIT_AURA", "player")
assert(PrintedContains("Inner Fire charges: 6 -> 5"))
assert(PrintedContains("Inner Fire state: OK -> LOW charges=5 threshold=5"))
assert(PrintedContains("Inner Fire LOW UPDATE: 5 -> 4"))
assert(PrintedContains("Inner Fire removed"))
assert(PrintedContains("Inner Fire state: LOW -> MISSING"))
assert(PrintedContains("Inner Fire state: MISSING -> OK charges=20"))
assert(PrintedContains("Inner Fire count unavailable: spellID=25431"))
namespace.debugEnabled = false
namespace.db.general.debug = false

-- Preview is independent of the tracked runtime snapshot.
local previewState, previewCharges = namespace.InnerFire.state, namespace.InnerFire.charges
namespace.Alerts:ShowInnerFirePreview()
assert(namespace.Alerts.frames.innerFire:IsShown())
assert(namespace.InnerFire.state == previewState and namespace.InnerFire.charges == previewCharges)

-- Milestone 0.7: self Power Word: Shield remaining absorb. AuraData is
-- authoritative, UnitGetTotalAbsorbs is used only after a canonical aura match.
UseModernAuras()
totalAbsorb = nil
SetAura("player")
namespace.ShieldAbsorb:ScanPlayer("initial scan")
assert(namespace.ShieldAbsorb.state == namespace.ShieldAbsorb.STATE_ABSENT)
assert(not namespace.Alerts.frames.shieldAbsorb:IsShown())

SetAura("player", "Power Word: Shield", 25218, nil, { 1847 }, "PWSTexture", 101)
Fire("UNIT_AURA", "player")
assert(namespace.ShieldAbsorb.state == namespace.ShieldAbsorb.STATE_KNOWN)
assert(namespace.ShieldAbsorb.amount == 1847)
assert(namespace.ShieldAbsorb.observedMaximum == 1847)
assert(namespace.ShieldAbsorb.fillFraction == 1)
assert(namespace.ShieldAbsorb.amountSource == namespace.ShieldAbsorb.SOURCE_AURA_POINTS)
assert(namespace.ShieldAbsorb.spellID == 25218 and namespace.ShieldAbsorb.auraInstanceID == 101)
assert(namespace.Alerts.frames.shieldAbsorb:IsShown())
assert(namespace.Alerts.frames.shieldAbsorb.value.text == "1847")
assert(namespace.Alerts.frames.shieldAbsorb.icon.texture == "PWSTexture")

local shieldFrame = namespace.Alerts.frames.shieldAbsorb
local shieldShowCount = shieldFrame.showCount
assert(shieldFrame.bar.statusBarColor[1] == 0 and shieldFrame.bar.statusBarColor[2] == 1)
SetAura("player", "Power Word: Shield", 25218, nil, { 1320 }, "PWSTexture", 101)
Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
assert(namespace.ShieldAbsorb.amount == 1320 and shieldFrame.value.text == "1320")
assert(math.abs(namespace.ShieldAbsorb.fillFraction - (1320 / 1847)) < 0.0001)
assert(math.abs(shieldFrame.bar.value - (1320 / 1847)) < 0.0001)
assert(math.abs(shieldFrame.bar.statusBarColor[1] - (1 - (1320 / 1847))) < 0.0001)
assert(math.abs(shieldFrame.bar.statusBarColor[2] - (1320 / 1847)) < 0.0001)
assert(shieldFrame.showCount == shieldShowCount)
SetAura("player", "Power Word: Shield", 25218, nil, { 215 }, "PWSTexture", 101)
Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
assert(namespace.ShieldAbsorb.amount == 215 and shieldFrame.value.text == "215")
assert(math.abs(namespace.ShieldAbsorb.fillFraction - (215 / 1847)) < 0.0001)
assert(shieldFrame.bar.statusBarColor[1] > shieldFrame.bar.statusBarColor[2])
assert(shieldFrame.showCount == shieldShowCount)
SetAura("player", "Power Word: Shield", 25218, nil, { 1200 }, "PWSTexture", 102)
Fire("UNIT_AURA", "player")
assert(namespace.ShieldAbsorb.observedMaximum == 1200)
assert(namespace.ShieldAbsorb.fillFraction == 1)
assert(shieldFrame.value.text == "1200")

-- Removal and dispel both converge on the aura-absent transition. A recast uses
-- the new API value and aura instance rather than a reconstructed maximum.
SetAura("player")
Fire("UNIT_AURA", "player")
assert(namespace.ShieldAbsorb.state == namespace.ShieldAbsorb.STATE_ABSENT)
assert(namespace.ShieldAbsorb.amount == nil and namespace.ShieldAbsorb.amountSource == nil)
assert(not shieldFrame:IsShown())
SetAura("player", "Power Word: Shield", 10901, nil, { 900 }, nil, 201)
Fire("UNIT_AURA", "player")
SetAura("player")
Fire("UNIT_AURA", "player")
assert(namespace.ShieldAbsorb.state == namespace.ShieldAbsorb.STATE_ABSENT and not shieldFrame:IsShown())
SetAura("player", "Power Word: Shield", 25218, nil, { 1900 }, nil, 202)
Fire("UNIT_AURA", "player")
assert(namespace.ShieldAbsorb.amount == 1900 and namespace.ShieldAbsorb.auraInstanceID == 202)

-- Every canonical TBC player rank is accepted, while unrelated or noncanonical
-- spell IDs cannot activate the frame.
for _, spellID in ipairs({ 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901, 25217, 25218 }) do
    SetAura("player", "Power Word: Shield", spellID, nil, { spellID })
    Fire("UNIT_AURA", "player")
    assert(namespace.ShieldAbsorb.state == namespace.ShieldAbsorb.STATE_KNOWN)
    assert(namespace.ShieldAbsorb.spellID == spellID and namespace.ShieldAbsorb.amount == spellID)
end
SetAura("player", "Unrelated Priest Buff", 12345, nil, { 777 })
Fire("UNIT_AURA", "player")
assert(namespace.ShieldAbsorb.state == namespace.ShieldAbsorb.STATE_ABSENT and not shieldFrame:IsShown())
SetAura("player", "NPC Shield", 999999, nil, { 888 })
Fire("UNIT_AURA", "player")
assert(namespace.ShieldAbsorb.state == namespace.ShieldAbsorb.STATE_ABSENT and not shieldFrame:IsShown())

-- Specific aura points win over a larger total. The total fallback is permitted
-- only while PW:S itself is confirmed present.
totalAbsorb = 1500
SetAura("player", "Power Word: Shield", 25218, nil, { 1000 })
Fire("UNIT_AURA", "player")
assert(namespace.ShieldAbsorb.amount == 1000)
assert(namespace.ShieldAbsorb.amountSource == namespace.ShieldAbsorb.SOURCE_AURA_POINTS)
SetAura("player", "Power Word: Shield", 25218, nil, nil)
Fire("UNIT_AURA", "player")
assert(namespace.ShieldAbsorb.amount == 1500)
assert(namespace.ShieldAbsorb.amountSource == namespace.ShieldAbsorb.SOURCE_TOTAL_ABSORB)

-- Legacy UnitAura still confirms the canonical aura, with the unit total as its
-- only available amount source because the legacy tuple has no points payload.
C_UnitAuras = nil
unitAuraCalls = 0
totalAbsorb = 444
SetAura("player", "Power Word: Shield", 592, nil, nil, "LegacyPWSTexture")
Fire("UNIT_AURA", "player")
assert(unitAuraCalls > 0)
assert(namespace.ShieldAbsorb.state == namespace.ShieldAbsorb.STATE_KNOWN)
assert(namespace.ShieldAbsorb.amount == 444)
assert(namespace.ShieldAbsorb.amountSource == namespace.ShieldAbsorb.SOURCE_TOTAL_ABSORB)
assert(shieldFrame.icon.texture == "LegacyPWSTexture")
UseModernAuras()
totalAbsorb = 1500
SetAura("player", "Other Absorb", 12345, nil, nil)
Fire("UNIT_AURA", "player")
assert(namespace.ShieldAbsorb.state == namespace.ShieldAbsorb.STATE_ABSENT and not shieldFrame:IsShown())

-- Missing/restricted sources are explicit UNKNOWN and always replace stale text.
totalAbsorb = nil
SetAura("player", "Power Word: Shield", 25218, nil, { 700 })
Fire("UNIT_AURA", "player")
assert(namespace.ShieldAbsorb.state == namespace.ShieldAbsorb.STATE_KNOWN)
SetAura("player", "Power Word: Shield", 25218, nil, nil)
Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
assert(namespace.ShieldAbsorb.state == namespace.ShieldAbsorb.STATE_UNKNOWN)
assert(namespace.ShieldAbsorb.amount == nil)
assert(shieldFrame:IsShown() and shieldFrame.value.text == "?")

-- Normal number formatting is live, and visual settings update the existing frame.
SetAura("player", "Power Word: Shield", 25218, nil, { 1847 })
Fire("UNIT_AURA", "player")
namespace.db.modules.shieldAbsorb.numberFormat = "SHORT"
namespace.ShieldAbsorb:OnSettingsChanged()
assert(shieldFrame.value.text == "1.8k")
SetAura("player", "Power Word: Shield", 25218, nil, { 963 })
Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
assert(shieldFrame.value.text == "963")
namespace.db.modules.shieldAbsorb.numberFormat = "EXACT"
namespace.db.modules.shieldAbsorb.iconSize = 96
namespace.db.modules.shieldAbsorb.textSize = 34
namespace.ShieldAbsorb:OnSettingsChanged()
assert(shieldFrame.value.text == "963")
assert(shieldFrame.icon.width == 96, "shield icon width=" .. tostring(shieldFrame.icon.width))
assert(shieldFrame.value.fontSize == 34)

-- Display variants switch live on the same saved-position frame. The bar uses
-- the highest accessible API amount observed for the current aura as its scale.
namespace.db.modules.shieldAbsorb.displayMode = "BAR_NUMBER"
namespace.ShieldAbsorb:OnSettingsChanged()
assert(not shieldFrame.icon:IsShown() and shieldFrame.bar:IsShown())
assert(shieldFrame.value.text == "963")
assert(math.abs(shieldFrame.bar.value - (963 / 1847)) < 0.0001)
assert(shieldFrame.width == 150 and shieldFrame.height == 34)
assert(shieldFrame.bar.width == 150 and shieldFrame.bar.height == 34)
namespace.db.modules.shieldAbsorb.displayMode = "ICON_BAR"
namespace.ShieldAbsorb:OnSettingsChanged()
assert(shieldFrame.icon:IsShown() and shieldFrame.bar:IsShown())
assert(shieldFrame.value.point[1] == "CENTER")
assert(shieldFrame.width == 270 and shieldFrame.height == 96)
namespace.db.modules.shieldAbsorb.displayMode = "ICON_NUMBER"
namespace.ShieldAbsorb:OnSettingsChanged()
assert(shieldFrame.icon:IsShown() and not shieldFrame.bar:IsShown())
assert(shieldFrame.value.point[1] == "LEFT")

-- A mocked secret fallback never reaches the arithmetic formatter. Supported
-- direct FontString display retains KNOWN; a rejected direct display becomes UNKNOWN.
local secretValue = { secret = true }
namespace.ShieldAbsorb.secretValueDetector = function(value)
    return type(value) == "table" and value.secret == true
end
local originalShortFormatter = namespace.Alerts.FormatShortNumber
local shortFormatterCalls = 0
namespace.Alerts.FormatShortNumber = function(self, value)
    shortFormatterCalls = shortFormatterCalls + 1
    return originalShortFormatter(self, value)
end
namespace.db.modules.shieldAbsorb.numberFormat = "SHORT"
namespace.db.modules.shieldAbsorb.displayMode = "BAR_NUMBER"
totalAbsorb = secretValue
SetAura("player", "Power Word: Shield", 25218, nil, nil)
Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
assert(namespace.ShieldAbsorb.state == namespace.ShieldAbsorb.STATE_KNOWN)
assert(namespace.ShieldAbsorb.amountSource == namespace.ShieldAbsorb.SOURCE_TOTAL_ABSORB)
assert(namespace.ShieldAbsorb.amount == secretValue and namespace.ShieldAbsorb.amountIsSecret)
assert(shieldFrame.value.text == secretValue and shortFormatterCalls == 0)
assert(namespace.ShieldAbsorb.fillFraction == nil and shieldFrame.bar.value == 0)

local rejectedSecretValue = { secret = true, failDisplay = true }
totalAbsorb = rejectedSecretValue
Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
assert(namespace.ShieldAbsorb.state == namespace.ShieldAbsorb.STATE_UNKNOWN)
assert(namespace.ShieldAbsorb.amount == nil and shieldFrame.value.text == "?")
assert(shortFormatterCalls == 0)
namespace.Alerts.FormatShortNumber = originalShortFormatter
namespace.ShieldAbsorb.secretValueDetector = nil
namespace.db.modules.shieldAbsorb.numberFormat = "EXACT"
namespace.db.modules.shieldAbsorb.displayMode = "ICON_NUMBER"
totalAbsorb = nil

-- Preview data is isolated from runtime data. Its timer restores a newer runtime
-- snapshot and cannot hide it; a runtime removal does not end the preview early.
SetAura("player", "Power Word: Shield", 25218, nil, { 900 })
Fire("UNIT_AURA", "player")
local runtimeState, runtimeAmount = namespace.ShieldAbsorb.state, namespace.ShieldAbsorb.amount
now = 1100
namespace.Alerts:ShowShieldPreview()
assert(shieldFrame.value.text == "1847")
assert(namespace.ShieldAbsorb.state == runtimeState and namespace.ShieldAbsorb.amount == runtimeAmount)
SetAura("player", "Power Word: Shield", 25218, nil, { 800 })
Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
assert(shieldFrame.value.text == "1847" and namespace.ShieldAbsorb.amount == 800)
RunTimersThrough(1104)
assert(shieldFrame:IsShown() and shieldFrame.value.text == "800")
now = 1110
namespace.Alerts:ShowShieldPreview()
SetAura("player")
Fire("UNIT_AURA", "player")
assert(shieldFrame:IsShown() and shieldFrame.value.text == "1847")
RunTimersThrough(1114)
assert(not shieldFrame:IsShown())

-- Module/master/class/arena lifecycle gates automatic work and one-shot scans
-- restore an already-active PW:S after re-enable or reload-style initialization.
SetAura("player", "Power Word: Shield", 25218, nil, { 777 })
namespace.db.modules.shieldAbsorb.enabled = false
namespace.ShieldAbsorb:OnSettingsChanged()
assert(namespace.ShieldAbsorb.state == nil and not shieldFrame:IsShown())
namespace.db.modules.shieldAbsorb.enabled = true
namespace.ShieldAbsorb:OnSettingsChanged()
assert(namespace.ShieldAbsorb.state == namespace.ShieldAbsorb.STATE_KNOWN and namespace.ShieldAbsorb.amount == 777)
namespace.db.general.enabled = false
namespace.ShieldAbsorb:OnSettingsChanged()
assert(namespace.ShieldAbsorb.state == nil and not shieldFrame:IsShown())
namespace.db.general.enabled = true
namespace.ShieldAbsorb:OnSettingsChanged()
assert(namespace.ShieldAbsorb.amount == 777)
playerClassFile = "MAGE"
namespace.ShieldAbsorb:OnSettingsChanged()
assert(namespace.ShieldAbsorb.state == nil and not shieldFrame:IsShown())
playerClassFile = "PRIEST"
namespace.ShieldAbsorb:OnSettingsChanged()
assert(namespace.ShieldAbsorb.amount == 777)
arenaState = false
namespace.Arena:UpdateArenaState()
assert(namespace.ShieldAbsorb.state == nil and not shieldFrame:IsShown())
assert(not namespace.Arena.eventFrame.events.UNIT_ABSORB_AMOUNT_CHANGED)
namespace.Alerts:ShowShieldPreview()
assert(shieldFrame:IsShown() and namespace.ShieldAbsorb.state == nil)
namespace.Alerts:CancelHide("shieldAbsorb")
shieldFrame:Hide()
namespace.Alerts.shieldDisplayMode = nil
arenaState = true
namespace.Arena:UpdateArenaState()
assert(namespace.Arena.eventFrame.events.UNIT_ABSORB_AMOUNT_CHANGED)
assert(namespace.ShieldAbsorb.amount == 777 and shieldFrame:IsShown())
namespace.ShieldAbsorb:ClearRuntime()
namespace.ShieldAbsorb:ScanPlayer("initial scan")
assert(namespace.ShieldAbsorb.amount == 777 and shieldFrame:IsShown())

-- Debug output identifies events, source selection, changes, removal, secrets,
-- unavailable amounts, and state transitions without stringifying secret data.
namespace.debugEnabled = true
namespace.db.general.debug = true
namespace.ShieldAbsorb:ClearRuntime()
SetAura("player", "Power Word: Shield", 25218, nil, { 1847 })
namespace.ShieldAbsorb:ScanPlayer("initial scan")
SetAura("player", "Power Word: Shield", 25218, nil, { 1320 })
Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
totalAbsorb = 1200
SetAura("player", "Power Word: Shield", 25218, nil, nil)
Fire("UNIT_AURA", "player")
totalAbsorb = nil
Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
SetAura("player")
Fire("UNIT_AURA", "player")
assert(PrintedContains("Shield initial scan"))
assert(PrintedContains("PW:S found: spellID=25218"))
assert(PrintedContains("Shield amount source=AURA_POINTS amount=1847"))
assert(PrintedContains("UNIT_ABSORB_AMOUNT_CHANGED: player"))
assert(PrintedContains("Shield amount changed: 1847 -> 1320 source=AURA_POINTS"))
assert(PrintedContains("Shield fallback source=TOTAL_ABSORB"))
assert(PrintedContains("Shield amount unavailable"))
assert(PrintedContains("Shield state: KNOWN -> UNKNOWN"))
assert(PrintedContains("Power Word: Shield removed"))
namespace.debugEnabled = false
namespace.db.general.debug = false
totalAbsorb = nil
C_UnitAuras = nil

-- Milestone 0.4: a mapped enemy Hunter's successful Scatter cast flashes
-- immediately from UNIT_SPELLCAST_SUCCEEDED without any destination or aura.
arenaUnits.arena3 = { guid = "Enemy-Hunter-1", className = "Hunter", classFile = "HUNTER", classID = 3, name = "MarksOne" }
Fire("ARENA_OPPONENT_UPDATE", "arena3", "seen")
ResetScatter()
now = 1000
Fire("UNIT_SPELLCAST_SUCCEEDED", "arena3", "Cast-1", 19503)
assert(namespace.Alerts.frames.scatter.showCount == 1)
assert(namespace.Alerts.frames.scatter:IsShown())
assert(namespace.Alerts.frames.scatter.alpha == 0.55)
assert(namespace.Alerts.scatterDisplayMode == "runtime")
assert(namespace.Scatter.lastScatterCast["Enemy-Hunter-1"] == 1000)

-- The UNIT payload parser tolerates compatibility fields and takes the final
-- numeric spell ID rather than assuming one fixed client signature.
local parsedUnit, parsedSpellID = namespace.Scatter:ParseUnitSpellcastSucceeded(
    "arena3", "Scatter Shot", "Rank 1", "Cast-compat", 17, 19503
)
assert(parsedUnit == "arena3" and parsedSpellID == 19503)

-- UNIT and CLEU notifications for the same cast converge through per-GUID dedup.
cleuPayload = {
    now, "SPELL_CAST_SUCCESS", false, "Enemy-Hunter-1", "MarksOne", 0, 0,
    "Arena-Teammate", "Friend", 0, 0, 19503, "Scatter Shot", 1,
}
Fire("COMBAT_LOG_EVENT_UNFILTERED")
assert(namespace.Alerts.frames.scatter.showCount == 1)

-- CLEU can arrive first, and destination is intentionally irrelevant.
ResetScatter()
now = 1001
cleuPayload = {
    now, "SPELL_CAST_SUCCESS", false, "Enemy-Hunter-1", "MarksOne", 0, 0,
    "Arena-Teammate", "Friend", 0, 0, 19503, "Scatter Shot", 1,
}
Fire("COMBAT_LOG_EVENT_UNFILTERED")
Fire("UNIT_SPELLCAST_SUCCEEDED", "arena3", "Cast-2", 19503)
assert(namespace.Alerts.frames.scatter.showCount == 1)

-- A new notification after the short merge window is a new cast, not blocked
-- by a fabricated ability cooldown. A stale hide timer cannot hide its flash.
ResetScatter()
namespace.db.modules.scatter.duration = 1.0
now = 1010
Fire("UNIT_SPELLCAST_SUCCEEDED", "arena3", "Cast-3", 19503)
now = 1010.6
Fire("UNIT_SPELLCAST_SUCCEEDED", "arena3", "Cast-4", 19503)
assert(namespace.Alerts.frames.scatter.showCount == 2)
RunTimersThrough(1011)
assert(namespace.Alerts.frames.scatter:IsShown())
RunTimersThrough(1011.6)
assert(not namespace.Alerts.frames.scatter:IsShown())

-- A preview timer is likewise invalidated when a runtime cast takes over.
ResetScatter()
namespace.db.modules.scatter.duration = 1.0
now = 1020
namespace.Alerts:ShowScatterPreview()
assert(not next(namespace.Scatter.lastScatterCast))
now = 1020.2
Fire("UNIT_SPELLCAST_SUCCEEDED", "arena3", "Cast-5", 19503)
RunTimersThrough(1021)
assert(namespace.Alerts.frames.scatter:IsShown())
RunTimersThrough(1021.2)
assert(not namespace.Alerts.frames.scatter:IsShown())

-- A subsequent MISS/IMMUNE outcome neither triggers nor retracts the cast alert.
ResetScatter()
now = 1030
namespace.Scatter:HandleCombatLogEvent(SpellEvent(
    "SPELL_CAST_SUCCESS", "Enemy-Hunter-1", "Arena-Teammate", 19503
))
namespace.Scatter:HandleCombatLogEvent(MissEvent(
    "SPELL_MISSED", "Enemy-Hunter-1", "Arena-Teammate", "IMMUNE", 19503
))
assert(namespace.Alerts.frames.scatter.showCount == 1)
assert(namespace.Scatter.lastScatterCast["Enemy-Hunter-1"] == 1030)

-- Late arena-unit metadata is refreshed safely from the unit token.
ResetScatter()
arenaUnits.arena4 = { guid = "Enemy-Hunter-Late", className = "Hunter", classFile = "HUNTER", classID = 3, name = "LateMap" }
now = 1040
Fire("UNIT_SPELLCAST_SUCCEEDED", "arena3", "Cast-same-time", 19503)
Fire("UNIT_SPELLCAST_SUCCEEDED", "arena4", "Cast-late", 19503)
assert(namespace.Arena:GetOpponentByGUID("Enemy-Hunter-Late").unit == "arena4")
assert(namespace.Alerts.frames.scatter.showCount == 2)

-- flashEnabled suppresses only presentation; the detector still accepts/dedups.
ResetScatter()
namespace.db.modules.scatter.flashEnabled = false
now = 1050
assert(namespace.Scatter:HandleCombatLogEvent(SpellEvent(
    "SPELL_CAST_SUCCESS", "Enemy-Hunter-1", "Any-Destination", 19503
)))
assert(namespace.Scatter.lastScatterCast["Enemy-Hunter-1"] == 1050)
AssertNoScatter("flashEnabled=false must suppress the visual")

-- Negative source, class, spell, and mapping filters.
ResetScatter()
Fire("UNIT_SPELLCAST_SUCCEEDED", "arena2", "Rogue-cast", 19503)
Fire("UNIT_SPELLCAST_SUCCEEDED", "arenapet3", "Pet-cast", 19503)
Fire("UNIT_SPELLCAST_SUCCEEDED", "arena3", "Other-spell", 12345)
namespace.Scatter:HandleCombatLogEvent(SpellEvent(
    "SPELL_CAST_SUCCESS", "Friendly-Hunter", playerGUID, 19503
))
namespace.Scatter:HandleCombatLogEvent(SpellEvent(
    "SPELL_CAST_SUCCESS", "Enemy-Hunter-Pet", playerGUID, 19503
))
namespace.Scatter:HandleCombatLogEvent(SpellEvent(
    "SPELL_CAST_SUCCESS", "NPC-Hunter", playerGUID, 19503
))
namespace.Scatter:HandleCombatLogEvent(SpellEvent(
    "SPELL_CAST_SUCCESS", "Unknown-Hunter", playerGUID, 19503
))
AssertNoScatter("only a mapped enemy Hunter using Scatter may flash")

-- Module/master disable clears cast state and any active runtime visual.
ResetScatter()
now = 1060
Fire("UNIT_SPELLCAST_SUCCEEDED", "arena3", "Cast-disable", 19503)
namespace.db.modules.scatter.enabled = false
namespace.Scatter:OnSettingsChanged()
assert(not next(namespace.Scatter.lastScatterCast))
assert(not namespace.Alerts.frames.scatter:IsShown(), "module disable must hide Scatter runtime")
namespace.db.modules.scatter.enabled = true
namespace.Alerts.frames.scatter.showCount = 0
now = 1061
Fire("UNIT_SPELLCAST_SUCCEEDED", "arena3", "Cast-master-disable", 19503)
namespace.db.general.enabled = false
namespace.Scatter:OnSettingsChanged()
assert(not next(namespace.Scatter.lastScatterCast))
assert(not namespace.Alerts.frames.scatter:IsShown(), "master disable must hide Scatter runtime")
namespace.db.general.enabled = true

-- Restore the Warrior used by the existing Drinking and Overpower regressions.
arenaUnits.arena3 = { guid = "Enemy-Warrior-2", className = "Warrior", classFile = "WARRIOR", classID = 1, name = "ArmsTwo" }
Fire("ARENA_OPPONENT_UPDATE", "arena3", "seen")

-- Milestone 0.3: primary UNIT_AURA detection uses localized names, transitions,
-- independent GUID states, and the existing single Drinking frame.
ResetDrinking()
SetAura("arena2", "Drink", 99999)
local drinkSoundBefore = soundCount
Fire("UNIT_AURA", "arena2")
assert(namespace.Drinking.drinkingByGUID["Enemy-Rogue"])
assert(namespace.Drinking.drinkingByGUID["Enemy-Rogue"].spellID == 99999)
assert(namespace.Alerts.frames.drinking:IsShown())
assert(namespace.Alerts.frames.drinking.text.text == "DRINKING!!!")
assert(soundCount == drinkSoundBefore + 1)

-- Repeated scans and aura refreshes are idempotent while the aura remains.
Fire("UNIT_AURA", "arena2")
assert(soundCount == drinkSoundBefore + 1)
SetAura("arena2")
Fire("UNIT_AURA", "arena2")
assert(not namespace.Drinking.drinkingByGUID["Enemy-Rogue"])
assert(not namespace.Alerts.frames.drinking:IsShown())

-- Stop followed by a real new start alerts and sounds again.
SetAura("arena2", "Drink", 10250)
Fire("UNIT_AURA", "arena2")
assert(namespace.Drinking.drinkingByGUID["Enemy-Rogue"])
assert(soundCount == drinkSoundBefore + 2)

-- Multiple enemies retain independent state and share one visual.
SetAura("arena3", "Drink", 27089)
Fire("UNIT_AURA", "arena3")
assert(CountEntries(namespace.Drinking.drinkingByGUID) == 2)
assert(namespace.Alerts.frames.drinking:IsShown())
SetAura("arena2")
Fire("UNIT_AURA", "arena2")
assert(not namespace.Drinking.drinkingByGUID["Enemy-Rogue"])
assert(namespace.Drinking.drinkingByGUID["Enemy-Warrior-2"])
assert(namespace.Alerts.frames.drinking:IsShown())
SetAura("arena3")
Fire("UNIT_AURA", "arena3")
assert(not namespace.Drinking:HasActiveDrinker())
assert(not namespace.Alerts.frames.drinking:IsShown())

-- CLEU is a fallback and converges through the same idempotent state API.
drinkSoundBefore = soundCount
cleuPayload = {
    now, "SPELL_AURA_APPLIED", false, "Enemy-Rogue", "Sneaky", 0, 0,
    "Enemy-Rogue", "Sneaky", 0, 0, 43154, "Refreshment", 1, "BUFF",
}
Fire("COMBAT_LOG_EVENT_UNFILTERED")
assert(namespace.Drinking.drinkingByGUID["Enemy-Rogue"])
assert(soundCount == drinkSoundBefore + 1)
SetAura("arena2", "Drink", 43154)
Fire("UNIT_AURA", "arena2")
namespace.Drinking:HandleCombatLogEvent(AuraEvent(
    "SPELL_AURA_REFRESH", "Enemy-Rogue", 43154, "Refreshment"
))
assert(soundCount == drinkSoundBefore + 1)
namespace.Drinking:HandleCombatLogEvent(AuraEvent(
    "SPELL_AURA_REMOVED", "Enemy-Rogue", 43154, "Refreshment"
))
assert(not namespace.Drinking.drinkingByGUID["Enemy-Rogue"])

-- Late opponent mapping performs a one-shot scan and catches an existing aura.
SetAura("arena4", "Drink", 1137)
arenaUnits.arena4 = { guid = "Enemy-Mage", className = "Mage", classFile = "MAGE", classID = 8, name = "WaterMage" }
Fire("ARENA_OPPONENT_UPDATE", "arena4", "seen")
assert(namespace.Drinking.drinkingByGUID["Enemy-Mage"])
arenaUnits.arena4 = nil
SetAura("arena4")
Fire("ARENA_OPPONENT_UPDATE", "arena4", "destroyed")
assert(not namespace.Drinking.drinkingByGUID["Enemy-Mage"])

-- Negative filters: only a mapped arena unit/GUID with a Drink aura can alert.
ResetDrinking()
SetAura("player", "Drink", 430)
SetAura("party1", "Drink", 430)
SetAura("arenapet1", "Drink", 430)
Fire("UNIT_AURA", "player")
Fire("UNIT_AURA", "party1")
Fire("UNIT_AURA", "arenapet1")
namespace.Drinking:HandleCombatLogEvent(AuraEvent("SPELL_AURA_APPLIED", "NPC-1", 430, "Drink"))
namespace.Drinking:HandleCombatLogEvent(AuraEvent("SPELL_AURA_APPLIED", "Unknown-Enemy", 430, "Drink"))
SetAura("arena2", "Mana Regeneration", 12345)
Fire("UNIT_AURA", "arena2")
namespace.Drinking:HandleCombatLogEvent(AuraEvent("SPELL_AURA_APPLIED", "Enemy-Rogue", 12345, "Mana Regeneration"))
assert(not namespace.Drinking:HasActiveDrinker())
assert(not namespace.Alerts.frames.drinking:IsShown())

-- A known ID is only a fallback path, and the existing sound setting is honored.
ResetDrinking()
namespace.db.modules.drinking.playSound = false
SetAura("arena1", "Localized Refreshment", 430)
drinkSoundBefore = soundCount
Fire("UNIT_AURA", "arena1")
assert(namespace.Drinking.drinkingByGUID["Enemy-Warrior-1"])
assert(namespace.Alerts.frames.drinking:IsShown())
assert(soundCount == drinkSoundBefore)

-- The duration limits only the visual. A later START refreshes the protected timer.
ResetDrinking()
now = 400
SetAura("arena2", "Drink", 430)
Fire("UNIT_AURA", "arena2")
now = 401
SetAura("arena3", "Drink", 431)
Fire("UNIT_AURA", "arena3")
RunTimersThrough(403)
assert(namespace.Alerts.frames.drinking:IsShown())
RunTimersThrough(404)
assert(not namespace.Alerts.frames.drinking:IsShown())
assert(CountEntries(namespace.Drinking.drinkingByGUID) == 2)
drinkSoundBefore = soundCount
Fire("UNIT_AURA", "arena3")
assert(not namespace.Alerts.frames.drinking:IsShown())
assert(soundCount == drinkSoundBefore)

-- Module/master switches clear active state and re-enable performs a one-shot scan.
namespace.db.modules.drinking.enabled = false
namespace.Drinking:OnSettingsChanged()
assert(not namespace.Drinking:HasActiveDrinker())
assert(not namespace.Alerts.frames.drinking:IsShown())
namespace.db.modules.drinking.enabled = true
namespace.Drinking:OnSettingsChanged()
assert(CountEntries(namespace.Drinking.drinkingByGUID) == 2)
namespace.db.general.enabled = false
namespace.Drinking:OnSettingsChanged()
assert(not namespace.Drinking:HasActiveDrinker())
assert(not namespace.Alerts.frames.drinking:IsShown())
namespace.db.general.enabled = true
SetAura("arena2")
SetAura("arena3")
namespace.Drinking:OnSettingsChanged()

-- Event-specific parser positions: SWING missType is arg 12; SPELL missType is arg 15.
local swingParsed = namespace.EnemyOverpower:ParseCombatLogEvent(
    now, "SWING_MISSED", false, "Enemy-Warrior-1", "ArmsOne", 0, 0,
    playerGUID, "Self", 0, 0, "DODGE", false, 0
)
assert(swingParsed.missType == "DODGE" and swingParsed.spellID == nil)
local spellParsed = namespace.EnemyOverpower:ParseCombatLogEvent(
    now, "SPELL_MISSED", false, "Enemy-Warrior-1", "ArmsOne", 0, 0,
    playerGUID, "Self", 0, 0, 12345, "Melee Special", 1, "DODGE", false, 0
)
assert(spellParsed.spellID == 12345 and spellParsed.missType == "DODGE")

-- 1. Raw SWING_MISSED from a mapped enemy Warrior to player starts the alert.
ResetRuntime()
cleuPayload = {
    now, "SWING_MISSED", false, "Enemy-Warrior-1", "ArmsOne", 0, 0,
    playerGUID, "Self", 0, 0, "DODGE", false, 0,
}
local soundBefore = soundCount
Fire("COMBAT_LOG_EVENT_UNFILTERED")
assert(namespace.EnemyOverpower.activeOpportunities["Enemy-Warrior-1"])
assert(namespace.Alerts.frames.enemyOverpower:IsShown())
assert(soundCount == soundBefore + 1)

-- 2. SPELL_MISSED DODGE uses its distinct payload offset and also starts.
ResetRuntime()
namespace.EnemyOverpower:HandleCombatLogEvent(MissEvent(
    "SPELL_MISSED", "Enemy-Warrior-1", playerGUID, "DODGE", 12345
))
assert(namespace.EnemyOverpower.activeOpportunities["Enemy-Warrior-1"])

-- Existing visual and sound settings apply to the automatic alert.
ResetRuntime()
namespace.db.modules.enemyOverpower.showCountdown = false
namespace.db.modules.enemyOverpower.playSound = false
soundBefore = soundCount
namespace.EnemyOverpower:HandleCombatLogEvent(MissEvent(
    "SWING_MISSED", "Enemy-Warrior-1", playerGUID, "DODGE"
))
assert(namespace.Alerts.frames.enemyOverpower:IsShown())
assert(not namespace.Alerts.frames.enemyOverpower.countdown:IsShown())
assert(soundCount == soundBefore)

-- 3. A repeat dodge refreshes expiry; the first timer cannot clear the new generation.
ResetRuntime()
now = 200
local refreshSoundBefore = soundCount
namespace.EnemyOverpower:HandleCombatLogEvent(MissEvent(
    "SWING_MISSED", "Enemy-Warrior-1", playerGUID, "DODGE"
))
local firstExpiry = namespace.EnemyOverpower.activeOpportunities["Enemy-Warrior-1"].expiresAt
now = 202
namespace.EnemyOverpower:HandleCombatLogEvent(MissEvent(
    "SWING_MISSED", "Enemy-Warrior-1", playerGUID, "DODGE"
))
local refreshedExpiry = namespace.EnemyOverpower.activeOpportunities["Enemy-Warrior-1"].expiresAt
assert(firstExpiry == 205 and refreshedExpiry == 207)
RunTimersThrough(205)
assert(namespace.EnemyOverpower.activeOpportunities["Enemy-Warrior-1"])
assert(namespace.Alerts.frames.enemyOverpower:IsShown())
assert(soundCount == refreshSoundBefore + 2)

-- 4-5. Two Warriors retain independent states; the visual follows the longest window.
ResetRuntime()
now = 300
namespace.EnemyOverpower:HandleCombatLogEvent(MissEvent(
    "SWING_MISSED", "Enemy-Warrior-1", playerGUID, "DODGE"
))
now = 301
namespace.EnemyOverpower:HandleCombatLogEvent(MissEvent(
    "SPELL_MISSED", "Enemy-Warrior-2", playerGUID, "DODGE", 12345
))
assert(CountEntries(namespace.EnemyOverpower.activeOpportunities) == 2)
assert(namespace.Alerts.frames.enemyOverpower:IsShown())
assert(namespace.Alerts.frames.enemyOverpower.countdown.text == "5.0")
RunTimersThrough(305)
assert(not namespace.EnemyOverpower.activeOpportunities["Enemy-Warrior-1"])
assert(namespace.EnemyOverpower.activeOpportunities["Enemy-Warrior-2"])
assert(namespace.Alerts.frames.enemyOverpower:IsShown())
namespace.EnemyOverpower:Update(305.5)
assert(namespace.Alerts.frames.enemyOverpower.countdown.text == "0.5")

-- 6 and 16. Actual Overpower use consumes only its state; duplicate CLEU is harmless.
namespace.EnemyOverpower:HandleCombatLogEvent(SpellEvent(
    "SPELL_CAST_SUCCESS", "Enemy-Warrior-2", "Other-Target", 11585
))
AssertNoOpportunity("Overpower use should consume opportunity")
assert(namespace.Alerts.frames.enemyOverpower.countdown.text == "0.0")
namespace.EnemyOverpower:HandleCombatLogEvent(SpellEvent(
    "SPELL_DAMAGE", "Enemy-Warrior-2", "Other-Target", 11585
))
AssertNoOpportunity("duplicate Overpower event should be idempotent")

-- 7-11 and 15. Source, destination, mapping, and miss type filters.
ResetRuntime()
namespace.EnemyOverpower:HandleCombatLogEvent(MissEvent("SWING_MISSED", "Enemy-Rogue", playerGUID, "DODGE"))
AssertNoOpportunity("enemy Rogue must be ignored")
namespace.EnemyOverpower:HandleCombatLogEvent(MissEvent("SWING_MISSED", "Enemy-Warrior-1", "Arena-Teammate", "DODGE"))
AssertNoOpportunity("teammate dodge must be ignored")
namespace.EnemyOverpower:HandleCombatLogEvent(MissEvent("SWING_MISSED", "Friendly-Warrior", playerGUID, "DODGE"))
AssertNoOpportunity("friendly Warrior must be ignored")
for _, missType in ipairs({
    "MISS", "PARRY", "BLOCK", "EVADE", "IMMUNE", "ABSORB", "RESIST",
    "DEFLECT", "REFLECT",
}) do
    namespace.EnemyOverpower:HandleCombatLogEvent(MissEvent(
        "SWING_MISSED", "Enemy-Warrior-1", playerGUID, missType
    ))
    AssertNoOpportunity(missType .. " must be ignored")
end
namespace.EnemyOverpower:HandleCombatLogEvent(MissEvent("SWING_MISSED", "Unknown-Warrior", playerGUID, "DODGE"))
AssertNoOpportunity("unknown GUID must be ignored")

-- 13-14. Both module and master switches gate automatic detection.
namespace.db.modules.enemyOverpower.enabled = false
namespace.EnemyOverpower:HandleCombatLogEvent(MissEvent("SWING_MISSED", "Enemy-Warrior-1", playerGUID, "DODGE"))
AssertNoOpportunity("disabled module must not alert")
namespace.db.modules.enemyOverpower.enabled = true
namespace.db.general.enabled = false
namespace.EnemyOverpower:HandleCombatLogEvent(MissEvent("SWING_MISSED", "Enemy-Warrior-1", playerGUID, "DODGE"))
AssertNoOpportunity("disabled master switch must not alert")
namespace.db.general.enabled = true

-- Opponent removal invalidates its mapping and opportunity without polling.
namespace.EnemyOverpower:HandleCombatLogEvent(MissEvent("SWING_MISSED", "Enemy-Warrior-1", playerGUID, "DODGE"))
arenaUnits.arena1 = nil
Fire("ARENA_OPPONENT_UPDATE", "arena1", "cleared")
AssertNoOpportunity("removed opponent opportunity must be cleared")
assert(not namespace.Arena:GetOpponentByGUID("Enemy-Warrior-1"))
arenaUnits.arena1 = { guid = "Enemy-Warrior-1", className = "Warrior", classFile = "WARRIOR", classID = 1, name = "ArmsOne" }
Fire("ARENA_OPPONENT_UPDATE", "arena1", "seen")

-- 17. Arena exit clears states, mappings, listener, updater, and frame.
namespace.EnemyOverpower:HandleCombatLogEvent(MissEvent("SWING_MISSED", "Enemy-Warrior-1", playerGUID, "DODGE"))
assert(namespace.Alerts.frames.enemyOverpower.scripts.OnUpdate)
SetAura("player")
Fire("UNIT_AURA", "player")
assert(namespace.InnerFire.state == namespace.InnerFire.STATE_MISSING)
assert(namespace.Alerts.frames.innerFire:IsShown())
SetAura("arena2", "Drink", 430)
Fire("UNIT_AURA", "arena2")
assert(namespace.Drinking.drinkingByGUID["Enemy-Rogue"])
arenaUnits.arena5 = { guid = "Enemy-Hunter-Exit", className = "Hunter", classFile = "HUNTER", classID = 3, name = "ExitMarks" }
Fire("ARENA_OPPONENT_UPDATE", "arena5", "seen")
ResetScatter()
Fire("UNIT_SPELLCAST_SUCCEEDED", "arena5", "Cast-before-exit", 19503)
assert(namespace.Alerts.frames.scatter:IsShown())
assert(namespace.Scatter.lastScatterCast["Enemy-Hunter-Exit"])
arenaState = false
namespace.Arena:UpdateArenaState()
assert(not namespace.isInArena)
AssertNoOpportunity("arena exit must clean runtime")
assert(not namespace.Drinking:HasActiveDrinker())
assert(not namespace.Alerts.frames.drinking:IsShown())
assert(not next(namespace.Scatter.lastScatterCast))
assert(not namespace.Alerts.frames.scatter:IsShown())
assert(namespace.InnerFire.state == nil and not namespace.InnerFire.isPresent)
assert(namespace.InnerFire.charges == nil and namespace.InnerFire.spellID == nil)
assert(not namespace.Alerts.frames.innerFire:IsShown())
assert(not namespace.Arena:GetOpponentByGUID("Enemy-Warrior-1"))
assert(not namespace.Arena.eventFrame.events.COMBAT_LOG_EVENT_UNFILTERED)
assert(not namespace.Arena.eventFrame.events.UNIT_AURA)
assert(not namespace.Arena.eventFrame.events.UNIT_SPELLCAST_SUCCEEDED)
assert(not namespace.Arena.eventFrame.events.UNIT_HEALTH)
assert(not namespace.Arena.eventFrame.events.UNIT_MAXHEALTH)
assert(namespace.Alerts.frames.enemyOverpower.scripts.OnUpdate == nil)

-- 12 and manual-preview compatibility: detector input outside arena is ignored,
-- while the existing Test Alert remains available.
namespace.EnemyOverpower:HandleCombatLogEvent(MissEvent("SWING_MISSED", "Enemy-Warrior-1", playerGUID, "DODGE"))
AssertNoOpportunity("combat log outside arena must be ignored")
namespace.Drinking:HandleCombatLogEvent(AuraEvent("SPELL_AURA_APPLIED", "Enemy-Rogue", 430, "Drink"))
namespace.Drinking:ScanUnit("arena2", "UNIT_AURA")
assert(not namespace.Drinking:HasActiveDrinker())
assert(not namespace.Alerts.frames.drinking:IsShown())
namespace.Alerts.frames.scatter.showCount = 0
namespace.Scatter:HandleCombatLogEvent(SpellEvent(
    "SPELL_CAST_SUCCESS", "Enemy-Hunter-Exit", playerGUID, 19503
))
Fire("UNIT_SPELLCAST_SUCCEEDED", "arena5", "Cast-outside", 19503)
AssertNoScatter("Scatter outside arena must be ignored")
namespace.Alerts:ShowDrinkingPreview()
assert(namespace.Alerts.frames.drinking:IsShown())
namespace.Alerts:ShowOverpowerPreview()
assert(namespace.Alerts.frames.enemyOverpower:IsShown())
namespace.Alerts:ShowScatterPreview()
assert(namespace.Alerts.frames.scatter:IsShown())
SetAura("player", "Inner Fire", 25431, 2)
Fire("UNIT_AURA", "player")
assert(namespace.InnerFire.state == nil)
assert(not namespace.Alerts.frames.innerFire:IsShown())
namespace.Alerts:ShowInnerFirePreview()
assert(namespace.Alerts.frames.innerFire:IsShown())
assert(namespace.InnerFire.state == nil and namespace.InnerFire.charges == nil)

realPrint("WeshArenaAlerts smoke test passed")

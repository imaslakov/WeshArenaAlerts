local frames = {}
local timers = {}
local arenaState = false
local now = 100
local soundCount = 0
local openedSettings = 0
local printed = {}
local playerGUID = "Player-Self"
local arenaUnits = {}
local unitAuras = {}
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
function Object:SetPoint(point, _, relativePoint, x, y)
    self.point = { point, relativePoint or point, x or 0, y or 0 }
end
function Object:GetPoint()
    local point = self.point or { "CENTER", "CENTER", 0, 0 }
    return point[1], UIParent, point[2], point[3], point[4]
end
function Object:SetText(text) self.text = text end
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
function Object:Show() self.shown = true end
function Object:Hide() self.shown = false end
function Object:SetShown(value) self.shown = value end
function Object:IsShown() return self.shown end
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
    return arenaUnits[unit] and arenaUnits[unit].guid or nil
end
function UnitClass(unit)
    local opponent = arenaUnits[unit]
    if not opponent then return nil end
    return opponent.className, opponent.classFile, opponent.classID
end
function UnitName(unit) return arenaUnits[unit] and arenaUnits[unit].name or nil end
function UnitAura(unit, index)
    local aura = unitAuras[unit] and unitAuras[unit][index]
    if not aura then return nil end
    return aura.name, nil, nil, nil, nil, nil, nil, nil, nil, aura.spellID
end
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
    "EnemyOverpower.lua",
    "Drinking.lua",
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

local function SetAura(unit, spellName, spellID)
    unitAuras[unit] = spellName and { { name = spellName, spellID = spellID } } or nil
end

Fire("ADDON_LOADED", "WeshArenaAlerts")
Fire("PLAYER_LOGIN")

-- Milestone 0.1 compatibility smoke checks.
assert(namespace.initialized)
assert(namespace.version == "0.3.0")
assert(namespace.Drinking.drinkAuraName == "Drink")
assert(namespace.Drinking.KNOWN_DRINK_SPELL_IDS[430])
assert(namespace.Drinking.KNOWN_DRINK_SPELL_IDS[43154])
assert(namespace.EnemyOverpower.OVERPOWER_WINDOW_SECONDS == 5.0)
assert(namespace.EnemyOverpower.OVERPOWER_SPELL_IDS[7384])
assert(namespace.EnemyOverpower.OVERPOWER_SPELL_IDS[7887])
assert(namespace.EnemyOverpower.OVERPOWER_SPELL_IDS[11584])
assert(namespace.EnemyOverpower.OVERPOWER_SPELL_IDS[11585])
assert(namespace.db.modules.enemyOverpower.showCountdown)
assert(namespace.Options.category:GetID() == 77)
assert(type(SlashCmdList.WESHARENAALERTS) == "function")
namespace.Alerts:TestAll()
namespace.Alerts:UnlockFrames()
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
arenaState = true
namespace.Arena:UpdateArenaState()
assert(namespace.isInArena)
assert(namespace.Arena.eventFrame.events.COMBAT_LOG_EVENT_UNFILTERED)
assert(namespace.Arena.eventFrame.events.UNIT_AURA)
assert(namespace.Arena:GetOpponentByGUID("Enemy-Warrior-1").classFile == "WARRIOR")

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
SetAura("arena2", "Drink", 430)
Fire("UNIT_AURA", "arena2")
assert(namespace.Drinking.drinkingByGUID["Enemy-Rogue"])
arenaState = false
namespace.Arena:UpdateArenaState()
assert(not namespace.isInArena)
AssertNoOpportunity("arena exit must clean runtime")
assert(not namespace.Drinking:HasActiveDrinker())
assert(not namespace.Alerts.frames.drinking:IsShown())
assert(not namespace.Arena:GetOpponentByGUID("Enemy-Warrior-1"))
assert(not namespace.Arena.eventFrame.events.COMBAT_LOG_EVENT_UNFILTERED)
assert(not namespace.Arena.eventFrame.events.UNIT_AURA)
assert(namespace.Alerts.frames.enemyOverpower.scripts.OnUpdate == nil)

-- 12 and manual-preview compatibility: detector input outside arena is ignored,
-- while the existing Test Alert remains available.
namespace.EnemyOverpower:HandleCombatLogEvent(MissEvent("SWING_MISSED", "Enemy-Warrior-1", playerGUID, "DODGE"))
AssertNoOpportunity("combat log outside arena must be ignored")
namespace.Drinking:HandleCombatLogEvent(AuraEvent("SPELL_AURA_APPLIED", "Enemy-Rogue", 430, "Drink"))
namespace.Drinking:ScanUnit("arena2", "UNIT_AURA")
assert(not namespace.Drinking:HasActiveDrinker())
assert(not namespace.Alerts.frames.drinking:IsShown())
namespace.Alerts:ShowDrinkingPreview()
assert(namespace.Alerts.frames.drinking:IsShown())
namespace.Alerts:ShowOverpowerPreview()
assert(namespace.Alerts.frames.enemyOverpower:IsShown())

realPrint("WeshArenaAlerts smoke test passed")

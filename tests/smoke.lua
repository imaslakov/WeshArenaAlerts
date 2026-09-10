local frames = {}
local timers = {}
local arenaState = false

local Object = {}
Object.__index = function(_, key)
    local method = rawget(Object, key)
    if method then
        return method
    end
    return function() end
end

local function NewObject()
    local object = setmetatable({ events = {}, scripts = {}, shown = false }, Object)
    return object
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
    table.insert(frames, frame)
    return frame
end

UIParent = NewObject()
BackdropTemplateMixin = {}
GameFontNormal = NewObject()
GameFontHighlight = NewObject()
SlashCmdList = {}
SOUNDKIT = { RAID_WARNING = 1 }
C_Timer = { After = function(_, callback) table.insert(timers, callback) end }
Settings = {
    RegisterCanvasLayoutCategory = function()
        local category = NewObject()
        category.id = 77
        return category, NewObject()
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(categoryID) assert(categoryID == 77) end,
}

function GetSpellTexture() return nil end
function PlaySound() end
function GetTime() return 100 end
function UnitGUID() return nil end
function UnitClass() return "Warrior", "WARRIOR", 1 end
function IsInInstance() return arenaState, arenaState and "arena" or "none" end
function wipe(target) for key in pairs(target) do target[key] = nil end end

local namespace = {}
local files = { "Defaults.lua", "Core.lua", "Alerts.lua", "Arena.lua", "Options.lua" }
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

Fire("ADDON_LOADED", "WeshArenaAlerts")
Fire("PLAYER_LOGIN")

assert(namespace.initialized)
assert(namespace.db.modules.enemyOverpower.showCountdown)
assert(namespace.Options.category:GetID() == 77)
assert(type(SlashCmdList.WESHARENAALERTS) == "function")

namespace.Alerts:TestAll()
namespace.Alerts:UnlockFrames()
namespace.Alerts:LockFrames()
namespace:ResetPositions()
SlashCmdList.WESHARENAALERTS()

arenaState = true
namespace.Arena:UpdateArenaState()
assert(namespace.isInArena)
arenaState = false
namespace.Arena:UpdateArenaState()
assert(not namespace.isInArena)

for _, callback in ipairs(timers) do callback() end

print("WeshArenaAlerts smoke test passed")

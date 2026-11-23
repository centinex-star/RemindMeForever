-- RemindMeForever - core: namespace, saved variables, character roster, event wiring.
local addonName, ns = ...

ns.ADDON = addonName
ns.version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(addonName, "Version") or "dev"

local PREFIX = "|cffe6cc80RemindMeForever|r: "
local TICK_SECONDS = 30

-------------------------------------------------------------------------------
-- Small utilities
-------------------------------------------------------------------------------

-- Some unit APIs return "secret" values in restricted contexts on the modern
-- client (Forever inherits Midnight's secret-value system). Reading one is
-- fine; doing arithmetic or comparison on it throws. Everything we read from
-- the client goes through this so a restricted value degrades to nil instead
-- of taking the addon down.
function ns.SafeValue(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then
        if canaccessvalue and not canaccessvalue(v) then return nil end
    end
    return v
end

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

function ns.PrintError(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "|cffff5555" .. tostring(msg) .. "|r")
end

function ns.Debug(...)
    if not (RMFCharDB and RMFCharDB.debug) then return end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring((select(i, ...)))
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff888888[RMF debug]|r " .. table.concat(parts, " "))
end

-- Locale-independent, never nil, never secret.
function ns.PlayerName()
    local name = ns.SafeValue(UnitName("player"))
    if type(name) ~= "string" then return "Unknown" end
    return name:match("^[^-]+") or name
end

function ns.RealmName()
    local realm = ns.SafeValue(GetRealmName())
    if type(realm) ~= "string" then return "Unknown" end
    return realm
end

function ns.CharacterKey()
    return ns.PlayerName() .. "-" .. ns.RealmName()
end

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------

local function GlobalDefaults()
    return {
        version = 1,
        reminders = {},
        nextId = 0,
        characters = {},
        profile = {
            -- When true, reset times come from the client (C_DateAndTime) and the
            -- manual hour/day below are ignored. Andy asked for manual control, so
            -- this defaults to false once a reset hour has been detected; until
            -- detection runs, server values are used.
            useServerReset = true,
            resetHour = 15,   -- server time (UTC), 0-23
            resetDay = 3,     -- 1 = Sunday ... 7 = Saturday (3 = Tuesday)
            detectedResetHour = nil,
            detectedResetDay = nil,
            grainAllCharacters = true,
        },
    }
end

local function CharDefaults()
    return {
        debug = false,
        snoozeMinutes = 10,
        migrated = false,
    }
end

local function ApplyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            ApplyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
    return target
end

-------------------------------------------------------------------------------
-- Character roster
-------------------------------------------------------------------------------

-- Cached attributes so a condition can be evaluated for an offline alt.
function ns.CaptureCharacter()
    local key = ns.CharacterKey()
    local chars = RMFDB.characters
    local char = chars[key]
    if not char then
        char = {}
        chars[key] = char
    end

    char.name = ns.PlayerName()
    char.realm = ns.RealmName()
    char.level = ns.SafeValue(UnitLevel("player"))

    local className = ns.SafeValue(UnitClass("player"))
    char.class = type(className) == "string" and className or nil
    local raceName = ns.SafeValue(UnitRace("player"))
    char.race = type(raceName) == "string" and raceName or nil
    char.faction = UnitFactionGroup and ns.SafeValue(UnitFactionGroup("player")) or nil
    char.ilevel = ns.SafeValue(GetAverageItemLevel())
    char.guild = (GetGuildInfo and ns.SafeValue((GetGuildInfo("player")))) or nil

    char.professions = {}
    if GetProfessions then
        local slots = { GetProfessions() }
        for i = 1, #slots do
            local index = slots[i]
            if index then
                local profName = ns.SafeValue(GetProfessionInfo(index))
                if type(profName) == "string" then
                    char.professions[#char.professions + 1] = profName
                end
            end
        end
    end

    char.pending = char.pending or {}
    char.dismissals = char.dismissals or {}
    char.lastSeen = time()
    return char
end

function ns.CurrentCharacter()
    local key = ns.CharacterKey()
    local char = RMFDB.characters[key]
    if not char then char = ns.CaptureCharacter() end
    char.pending = char.pending or {}
    char.dismissals = char.dismissals or {}
    return char
end

-------------------------------------------------------------------------------
-- Reset-time detection
-------------------------------------------------------------------------------

-- Ask the client where its reset boundary actually is, then remember the hour
-- so the options panel can show a real number to override.
function ns.DetectResetTimes()
    local profile = RMFDB.profile
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
        local ok, secs = pcall(C_DateAndTime.GetSecondsUntilDailyReset)
        if ok and type(secs) == "number" and secs > 0 then
            local anchor = GetServerTime() + secs
            profile.detectedResetHour = math.floor((anchor % 86400) / 3600)
            profile.detectedResetDay = ns.WeekdayForEpoch(anchor)
            ns.Debug("detected daily reset hour", profile.detectedResetHour,
                     "day", profile.detectedResetDay)
        end
    end
end

-------------------------------------------------------------------------------
-- Evaluation loop
-------------------------------------------------------------------------------

local pendingCombatEval = false

function ns.EvaluateAll()
    if UnitAffectingCombat("player") then
        pendingCombatEval = true
        ns.Debug("in combat, deferring evaluation")
        return
    end
    pendingCombatEval = false

    ns.CaptureCharacter()

    local due = {}
    for _, reminder in pairs(RMFDB.reminders) do
        local rows = ns.CollectDue(reminder)
        for _, row in ipairs(rows) do
            due[#due + 1] = row
        end
    end

    if #due > 0 then
        ns.ShowPopup(due)
    end
end

-------------------------------------------------------------------------------
-- Event handling
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
ns.eventFrame = eventFrame

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= addonName then return end
        ns.OnLoad()
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.CaptureCharacter()
        ns.EvaluateAll()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingCombatEval then ns.EvaluateAll() end
    elseif event == "PLAYER_AVG_ITEM_LEVEL_UPDATE" or event == "SKILL_LINES_CHANGED"
        or event == "PLAYER_LEVEL_UP" or event == "PLAYER_GUILD_UPDATE" then
        ns.CaptureCharacter()
        if ns.RefreshMainWindow then ns.RefreshMainWindow() end
    end
end)

function ns.OnLoad()
    if type(RMFDB) ~= "table" then RMFDB = GlobalDefaults() end
    ApplyDefaults(RMFDB, GlobalDefaults())
    if type(RMFCharDB) ~= "table" then RMFCharDB = CharDefaults() end
    ApplyDefaults(RMFCharDB, CharDefaults())

    -- Guards keep this loadable by the offline test harness, which loads only
    -- the logic files (the UI files need a real client).
    if ns.RegisterSlashCommands then ns.RegisterSlashCommands() end

    ns.CaptureCharacter()
    ns.DetectResetTimes()

    -- One-time move of any pending entries out of the old per-character table.
    if not RMFCharDB.migrated then
        RMFCharDB.migrated = true
    end

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")

    -- A single ticker replaces the original addon's per-reminder timers: fewer
    -- moving parts, and it survives /reload without any schedule repair.
    if ns.ticker then ns.ticker:Cancel() end
    ns.ticker = C_Timer.NewTicker(TICK_SECONDS, function()
        ns.EvaluateAll()
        if ns.RefreshMainWindow then ns.RefreshMainWindow() end
    end)

    ns.Print("v" .. ns.version .. " loaded. |cffffd100/rmf|r opens the window.")
end

eventFrame:RegisterEvent("ADDON_LOADED")

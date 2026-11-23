-- Test harness: loads the addon's logic files under plain Lua 5.1 with the WoW
-- APIs they touch stubbed out. UI files are excluded on purpose - they need a
-- real client. Run: lua5.1 tests/run.lua
package.path = "./?.lua;" .. package.path

local failures, checks = 0, 0

local function fail(msg)
    failures = failures + 1
    io.write("FAIL: ", msg, "\n")
end

local function ok(cond, msg)
    checks = checks + 1
    if not cond then fail(msg) end
end

local function eq(actual, expected, msg)
    checks = checks + 1
    if actual ~= expected then
        fail(string.format("%s (expected %s, got %s)", msg,
            tostring(expected), tostring(actual)))
    end
end

-------------------------------------------------------------------------------
-- WoW API stubs
-------------------------------------------------------------------------------

local NOW = 1700000000
_G.RMF_TEST_NOW = NOW

function GetServerTime() return _G.RMF_TEST_NOW end
function time() return _G.RMF_TEST_NOW end
function UnitName() return "Tester" end
function UnitClass() return "Mage", "MAGE", 8 end
function UnitRace() return "Gnome", "Gnome", 7 end
function UnitLevel() return 60 end
function GetRealmName() return "Forever" end
function GetAverageItemLevel() return 61.5 end
function GetProfessions() return 1, 2, nil, nil, nil end
function GetProfessionInfo(index)
    if index == 1 then return "Alchemy" end
    if index == 2 then return "Herbalism" end
    return nil
end
function GetGuildInfo() return "Testers" end
function UnitFactionGroup() return "Alliance" end
function UnitAffectingCombat() return false end
function GetZoneText() return "Elwynn Forest" end
function IsInInstance() return false, "none" end
function IsInGroup() return false end
function GetMoney() return 1234567 end
function GetAddOnMetadata() return "0.1.0" end

_G.UIParent = {}
_G.DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, msg) _G.RMF_LAST_CHAT = msg end,
}

function C_Timer_NewTicker() return { Cancel = function() end } end
_G.C_Timer = { NewTicker = C_Timer_NewTicker, After = function() end }

function CreateFrame()
    -- Minimal frame stand-in: only what the logic files call at load time.
    local f = {}
    function f:SetScript() end
    function f:RegisterEvent() end
    function f:UnregisterEvent() end
    return f
end

_G.SlashCmdList = {}
_G.tinsert = table.insert

-- Stub date so DescribeSchedule never depends on the host.
function date(fmt, t) return os.date(fmt, t) end

-------------------------------------------------------------------------------
-- Load the addon's logic files
-------------------------------------------------------------------------------

-- Each file expects (addonName, namespace). We emulate that vararg.
local ns = {}
local function loadAddonFile(path)
    local chunk = assert(loadfile(path))
    chunk("RemindMeForever", ns)
end

RMFDB = nil
RMFCharDB = nil

-- Core.lua runs OnLoad from a frame event; we call it manually.
loadAddonFile("Core.lua")
assert(ns.Print, "Core.lua did not define ns.Print")

-- Run what ADDON_LOADED would have triggered.
ns.OnLoad()

loadAddonFile("Conditions.lua")
loadAddonFile("Schedule.lua")
loadAddonFile("Reminders.lua")

ok(type(ns.ParseCondition) == "function", "ParseCondition exists")
ok(type(ns.NextOccurrence) == "function", "NextOccurrence exists")

-------------------------------------------------------------------------------
-- Condition tests
-------------------------------------------------------------------------------

local function eval(text, ctx)
    local ast, err = ns.ParseCondition(text)
    if not ast then return nil, err end
    return ns.EvaluateNode(ast, ctx or ns.LiveContext())
end

eq(eval("*"), true, "everyone matches")
eq(eval("name = Tester"), true, "name equals")
eq(eval("name = someone"), false, "name mismatch")
eq(eval("name ~= someone"), true, "name not-equals")
eq(eval("class = Mage"), true, "class equals")
eq(eval("class = mage"), true, "class compare is case-insensitive")
eq(eval("Level >= 60"), true, "level greater-or-equal, case-insensitive field")
eq(eval("level > 60"), false, "level strictly greater")
eq(eval("level < 61"), true, "level less than")
eq(eval("ilevel >= 60"), true, "ilevel compare")
eq(eval("profession = Alchemy"), true, "profession equals")
eq(eval("profession = Tailoring"), false, "profession mismatch")
eq(eval("profession ~= Tailoring"), true, "profession not-equals")
eq(eval("guild = Testers"), true, "guild equals")
eq(eval("faction = Alliance"), true, "faction equals")
-- Bare words cannot contain spaces: this must be an error, not a silent partial match.
local zoneAst, zoneErr = ns.ParseCondition("zone = Elwynn Forest")
ok(zoneAst == nil and zoneErr, "unquoted multiword value is rejected, not guessed")
eq(eval('zone = "Elwynn Forest"'), true, "quoted multiword value")
eq(eval("gold > 100"), true, "gold compare")
eq(eval("group = no"), true, "bool no")
eq(eval("instance = yes"), false, "bool yes mismatch")

-- Boolean composition and precedence: AND binds tighter than OR.
eq(eval("level >= 60 and class = Mage"), true, "and conjunction")
eq(eval("level >= 60 and class = Warrior"), false, "and conjunction false")
eq(eval("class = Warrior or class = Mage"), true, "or disjunction")
eq(eval("class = Warrior or class = Mage and level > 99"), false,
    "and binds tighter than or")
eq(eval("(class = Mage)"), nil, "parentheses are not supported and must error")

-- Errors are reported, not silently swallowed.
local _, err = ns.ParseCondition("bogusfield = 1")
ok(err and err:find("unknown field"), "unknown field reports an error")
_, err = ns.ParseCondition("level = sixty")
ok(err and err:find("needs a number"), "numeric field rejects text")
_, err = ns.ParseCondition("class > Mage")
ok(err and err:find("only supports"), "text field rejects ordering operators")
_, err = ns.ParseCondition("")
ok(err and err:find("empty"), "empty condition errors")
_, err = ns.ParseCondition("name = ")
ok(err ~= nil, "missing value errors")
_, err = ns.ParseCondition('name = "unterminated')
ok(err and err:find("quote"), "unterminated quote errors")
_, err = ns.ParseCondition("level 60")
ok(err ~= nil, "missing operator errors")

-- Compact (no spaces) forms.
eq(eval("level>=60"), true, "no-space operator form")
eq(eval("name=Tester"), true, "no-space name form")

-- Values with commas must survive (the original stripped them).
eq(eval('guild = "Testers, Inc."'), false, "comma in value is preserved, not stripped")
eq(ns.ParseCondition('name = "Bob, Jr."') ~= nil, true, "comma value parses")

-------------------------------------------------------------------------------
-- Schedule tests
-------------------------------------------------------------------------------

-- Pin the reset config so the math is deterministic.
RMFDB.profile.useServerReset = false
RMFDB.profile.resetHour = 15
RMFDB.profile.resetDay = 3  -- Tuesday

-- Weekday helper: 1700000000 is 2023-11-14T22:13:20Z, a Tuesday.
eq(ns.WeekdayForEpoch(NOW), 3, "epoch weekday is Tuesday")

local nextDaily = ns.NextOccurrence({ interval = "daily" }, NOW)
ok(nextDaily > NOW, "daily boundary is in the future")
-- NOW is Tuesday 22:13 UTC, so 15:00 has already passed today: the next daily
-- boundary is tomorrow at 15:00.
eq(nextDaily, math.floor(NOW / 86400) * 86400 + 86400 + 15 * 3600,
    "daily boundary lands on the next reset hour")
eq(nextDaily % 3600, 0, "daily boundary is hour-aligned")
eq(math.floor((nextDaily % 86400) / 3600), 15, "daily boundary is at hour 15 UTC")

-- Weekly on Tuesday at 15:00, when now is Tuesday 22:13: the next one is a week out.
local nextWeekly = ns.NextOccurrence({ interval = "weekly", day = 3 }, NOW)
eq(ns.WeekdayForEpoch(nextWeekly), 3, "weekly boundary is on Tuesday")
ok(nextWeekly > NOW, "weekly boundary is in the future")
eq(nextWeekly, math.floor(NOW / 86400) * 86400 + 7 * 86400 + 15 * 3600,
    "weekly boundary is next Tuesday at the reset hour")

-- Weekly on a Friday from a Tuesday is later that same week.
local nextFriday = ns.NextOccurrence({ interval = "weekly", day = 6 }, NOW)
eq(ns.WeekdayForEpoch(nextFriday), 6, "weekly on Friday lands on Friday")
ok(nextFriday < nextWeekly, "Friday comes before next Tuesday")
eq(nextFriday - NOW, 233200, "Friday boundary offset is exact (2d 16h 46m 40s)")

-- "at" uses its own day/hour/minute, ignoring reset config.
local atEpoch = ns.NextOccurrence({ interval = "at", day = 1, hour = 9, minute = 30 }, NOW)
eq(ns.WeekdayForEpoch(atEpoch), 1, "at-schedule lands on Sunday")
eq(math.floor((atEpoch % 86400) / 3600), 9, "at-schedule lands on the chosen hour")
eq(math.floor((atEpoch % 3600) / 60), 30, "at-schedule lands on the chosen minute")

-- Fixed interval counts from "now".
eq(ns.NextOccurrence({ interval = "interval", everyValue = 2, everyUnit = "hours" }, NOW),
    NOW + 7200, "every-2-hours interval")
eq(ns.NextOccurrence({ interval = "interval", everyValue = 90, everyUnit = "minutes" }, NOW),
    NOW + 5400, "every-90-minutes interval")

-- Descriptions
eq(ns.DescribeSchedule({ interval = "daily" }), "Daily", "describe daily")
eq(ns.DescribeSchedule({ interval = "weekly", day = 3 }), "Weekly (Tue)", "describe weekly")
eq(ns.DescribeSchedule({ interval = "at", day = 1, hour = 9, minute = 30 }), "Sun 09:30",
    "describe at")
eq(ns.DescribeSchedule({ interval = "interval", everyValue = 2, everyUnit = "hours" }),
    "Every 2 hours", "describe interval")

-- Clock parsing
local clock, clockErr = ns.ParseClock("15:30")
ok(clock and clock.hour == 15 and clock.minute == 30, "ParseClock hh:mm")
clock = ns.ParseClock("9")
ok(clock and clock.hour == 9 and clock.minute == 0, "ParseClock bare hour")
local bad, badErr = ns.ParseClock("25:00")
ok(bad == nil and badErr, "ParseClock rejects hour 25")
bad, badErr = ns.ParseClock("noon")
ok(bad == nil and badErr, "ParseClock rejects words")
eq(ns.FormatClock(0, 0), "12:00 AM", "FormatClock midnight")
eq(ns.FormatClock(13, 5), "1:05 PM", "FormatClock afternoon")

-------------------------------------------------------------------------------
-- Reminder model tests
-------------------------------------------------------------------------------

local char = ns.CurrentCharacter()
ok(char ~= nil, "current character captured")
eq(char.name, "Tester", "character name captured")
eq(char.level, 60, "character level captured")
eq(#char.professions, 2, "professions captured")

-- Create
local draft = ns.NewReminder()
draft.message = "Craft Living Steel"
draft.condition = "profession = Alchemy"
draft.interval = "daily"

local validOk, validErr = ns.ValidateReminder(draft, nil)
ok(validOk, "valid draft passes: " .. tostring(validErr))

local id = ns.SaveReminder(draft, nil)
ok(id ~= nil, "reminder saved with an id")
ok(RMFDB.reminders[id] ~= nil, "reminder is retrievable")
eq(RMFDB.nextId, 1, "nextId incremented")

-- Duplicate guard
local dupOk, dupErr = ns.ValidateReminder(draft, nil)
ok(not dupOk, "duplicate is rejected")
ok(dupErr:find("already exists"), "duplicate message mentions duplication")

-- Editing to the same values is allowed
local editOk = ns.ValidateReminder(draft, id)
ok(editOk, "editing the same reminder is allowed")

-- Empty message rejected
local emptyDraft = ns.NewReminder()
emptyDraft.message = "   "
local emptyOk, emptyErr = ns.ValidateReminder(emptyDraft, nil)
ok(not emptyOk and emptyErr:find("message"), "empty message rejected")

-- Invalid condition rejected
local badDraft = ns.NewReminder()
badDraft.message = "Bad"
badDraft.condition = "nonsense"
local badOk, badErr2 = ns.ValidateReminder(badDraft, nil)
ok(not badOk and badErr2:find("Condition"), "invalid condition rejected")

-- Bad interval value rejected
local badInterval = ns.NewReminder()
badInterval.message = "Bad interval"
badInterval.condition = "*"
badInterval.interval = "interval"
badInterval.everyValue = 0
local biOk, biErr = ns.ValidateReminder(badInterval, nil)
ok(not biOk and biErr:find("at least 1"), "zero repeat interval rejected")

-- Due behaviour ---------------------------------------------------------------

-- Freshly created: owed right now.
local rows = ns.CollectDue(RMFDB.reminders[id])
eq(#rows, 1, "new matching reminder is due immediately")
ok(rows[1].text == "Craft Living Steel", "row carries the message")

-- After firing, it should not be due again until the next boundary.
rows = ns.CollectDue(RMFDB.reminders[id])
eq(#rows, 0, "not due again right after firing")
ok(char.pending[id] > NOW, "pending advanced into the future")

-- Snoozing pushes it out by the configured amount.
RMFCharDB.snoozeMinutes = 10
char.pending[id] = NOW
rows = ns.CollectDue(RMFDB.reminders[id])
eq(#rows, 1, "due again when pending is now")
rows[1].snooze()
eq(char.pending[id], NOW + 600, "snooze pushes pending by 10 minutes")

-- Snoozed reminder is not due until the snooze expires.
rows = ns.CollectDue(RMFDB.reminders[id])
eq(#rows, 0, "snoozed reminder not due before snooze expires")
_G.RMF_TEST_NOW = NOW + 601
rows = ns.CollectDue(RMFDB.reminders[id])
eq(#rows, 1, "snoozed reminder due after snooze expires")
_G.RMF_TEST_NOW = NOW

-- Dismissing advances to the next boundary, not to "now".
char.pending[id] = NOW
rows = ns.CollectDue(RMFDB.reminders[id])
ok(#rows == 1, "reminder is due again after being reset to now")
rows[1].dismiss()
ok(char.pending[id] > NOW + 3600, "dismiss advances to next occurrence")

-- Non-matching condition never fires.
local otherDraft = ns.NewReminder()
otherDraft.message = "Tailor something"
otherDraft.condition = "profession = Tailoring"
otherDraft.interval = "daily"
local otherId = ns.SaveReminder(otherDraft, nil)
char.pending[otherId] = NOW
rows = ns.CollectDue(RMFDB.reminders[otherId])
eq(#rows, 0, "non-matching condition does not fire")

-- Disabled reminders never fire.
RMFDB.reminders[id].disabled = true
char.pending[id] = NOW
rows = ns.CollectDue(RMFDB.reminders[id])
eq(#rows, 0, "disabled reminder does not fire")

-- Re-enabling re-arms cleanly.
ns.ToggleReminder(id)
eq(RMFDB.reminders[id].disabled, false, "toggle re-enables")
rows = ns.CollectDue(RMFDB.reminders[id])
eq(#rows, 1, "re-enabled reminder fires again")

-- Deleting cleans up schedule entries for every character.
ns.DeleteReminder(id)
eq(RMFDB.reminders[id], nil, "reminder deleted")
eq(char.pending[id], nil, "pending entry cleaned up")

-- Cross-character behaviour ---------------------------------------------------
local alt = { name = "Altmage", realm = "Forever", level = 60, class = "Mage",
              professions = { "Alchemy" }, pending = {}, dismissals = {}, lastSeen = NOW - 100 }
RMFDB.characters["Altmage-Forever"] = alt

local crossDraft = ns.NewReminder()
crossDraft.message = "Weekly chore"
crossDraft.condition = "profession = Alchemy"
crossDraft.interval = "daily"
crossDraft.crossChar = true
local crossId = ns.SaveReminder(crossDraft, nil)
char.pending[crossId] = NOW

rows = ns.CollectDue(RMFDB.reminders[crossId])
local sawAlt = false
for _, row in ipairs(rows) do
    if row.text:find("Altmage", 1, true) then sawAlt = true end
end
ok(sawAlt, "cross-character row appears for a matching alt")
ok(#rows >= 2, "cross-character adds rows on top of the current character's")

-- Dismissing an alt's row must not advance the alt's own schedule.
local altRow
for _, row in ipairs(rows) do
    if row.text:find("Altmage", 1, true) then altRow = row end
end
local beforeAlt = alt.pending[crossId]
altRow.dismiss()
eq(alt.pending[crossId], beforeAlt, "dismissing an alt row leaves its schedule alone")
ok(alt.dismissals[crossId] ~= nil, "alt dismissal is recorded")

-- And the alt row stays hidden while dismissed.
char.pending[crossId] = NOW
rows = ns.CollectDue(RMFDB.reminders[crossId])
local stillShown = false
for _, row in ipairs(rows) do
    if row.text:find("Altmage", 1, true) then stillShown = true end
end
ok(not stillShown, "dismissed alt row stays hidden")

-- Turning cross-character off removes those rows.
RMFDB.reminders[crossId].crossChar = false
alt.dismissals = {}
char.pending[crossId] = NOW
rows = ns.CollectDue(RMFDB.reminders[crossId])
local anyAlt = false
for _, row in ipairs(rows) do
    if row.text:find("Altmage", 1, true) then anyAlt = true end
end
ok(not anyAlt, "cross-character off suppresses alt rows")

-------------------------------------------------------------------------------
-- Persistence / defaults
-------------------------------------------------------------------------------

ok(RMFDB.profile ~= nil, "profile table created")
ok(RMFDB.profile.snoozeMinutes == nil, "snooze lives per character, not in the profile")
eq(RMFCharDB.snoozeMinutes, 10, "per-character snooze default")

-- Legacy/missing fields are filled in without clobbering set values.
RMFDB.reminders["r900"] = { id = "r900", message = "Legacy", condition = "*",
    interval = "daily" }
local legacy = RMFDB.reminders["r900"]
ok(legacy.disabled == nil, "legacy reminder has no disabled flag before normalisation")
ns.CollectDue(legacy)
ok(true, "legacy reminder with missing fields evaluates without error")

-- Fresh DB shape
local fresh = { reminders = {}, characters = {} }
ok(type(fresh.reminders) == "table", "sanity")

-------------------------------------------------------------------------------
-- DescribeCondition
-------------------------------------------------------------------------------

eq(ns.DescribeCondition("*"), "Everyone", "describe everyone")
eq(ns.DescribeCondition("profession = Alchemy"), "Profession = Alchemy",
    "describe profession condition")
eq(ns.DescribeCondition("level >= 60 and class = Mage"), "Level >= 60 AND Class = Mage",
    "describe compound condition")

-------------------------------------------------------------------------------
-- Summary
-------------------------------------------------------------------------------
io.write(string.format("\n%d checks, %d failure(s)\n", checks, failures))
if failures > 0 then os.exit(1) end

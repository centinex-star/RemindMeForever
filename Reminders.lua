-- RemindMeForever - reminder model, due checking, and state changes.
--
-- State lives in two places:
--   RMFDB.reminders[id]         the definition, account-wide
--   RMFDB.characters[key].pending[id]   when this character next owes it
--
-- Keeping the schedule account-wide is what lets one character see that an alt
-- still owes a chore. Each character's own entry is the only thing that moves
-- when they do the thing, so you cannot clear an alt's chore from your main.

local addonName, ns = ...

local GROUP_WINDOW = 10  -- seconds; near-simultaneous reminders share one popup

-------------------------------------------------------------------------------
-- Definition helpers
-------------------------------------------------------------------------------

function ns.NewReminder()
    return {
        message = "",
        condition = "*",
        interval = "daily",
        day = select(2, ns.ResetConfig()),
        hour = 15,
        minute = 0,
        everyValue = 2,
        everyUnit = "hours",
        disabled = false,
        crossChar = false,
        createdAt = ns.Now(),
    }
end

function ns.SaveReminder(reminder, existingId)
    local id = existingId
    if not id then
        RMFDB.nextId = (RMFDB.nextId or 0) + 1
        id = "r" .. RMFDB.nextId
        reminder.createdAt = ns.Now()
    end

    RMFDB.reminders[id] = {
        id = id,
        message = reminder.message,
        condition = reminder.condition,
        interval = reminder.interval,
        day = reminder.day,
        hour = reminder.hour,
        minute = reminder.minute,
        everyValue = reminder.everyValue,
        everyUnit = reminder.everyUnit,
        disabled = reminder.disabled and true or false,
        crossChar = reminder.crossChar and true or false,
        createdAt = reminder.createdAt,
    }

    -- A brand new reminder is owed immediately by every character that matches,
    -- which matches the original addon's behaviour ("remind on first login").
    if not existingId then
        local char = ns.CurrentCharacter()
        char.pending[id] = ns.Now()
    end

    return id
end

function ns.DeleteReminder(id)
    if not id then return false end
    RMFDB.reminders[id] = nil
    for _, char in pairs(RMFDB.characters) do
        if char.pending then char.pending[id] = nil end
        if char.dismissals then char.dismissals[id] = nil end
    end
    return true
end

function ns.GetReminder(id)
    return id and RMFDB.reminders[id] or nil
end

-------------------------------------------------------------------------------
-- Due checking
-------------------------------------------------------------------------------

-- Does this character owe this reminder right now?
local function IsDue(reminder, char)
    if reminder.disabled then return false end
    if type(char.pending) ~= "table" then char.pending = {} end
    local pendingAt = char.pending[reminder.id]
    if pendingAt == nil then
        -- Never recorded on this character. New reminders start owing
        -- immediately; older ones (created before this character existed, or a
        -- condition that only just started matching) wait for the next boundary
        -- so a fresh alt does not get spammed with every historical chore.
        local created = reminder.createdAt or 0
        if created > (char.lastSeen or 0) then
            return true
        end
        return false
    end
    return ns.Now() + GROUP_WINDOW >= pendingAt
end

-- Advance this character's entry to its next occurrence and record it.
local function Advance(reminder, char, fromEpoch)
    char.pending[reminder.id] = ns.NextOccurrence(reminder, fromEpoch or ns.Now())
end

-- Dismissal bookkeeping for characters other than the one being played.
local function IsDismissed(char, id)
    local untilEpoch = char.dismissals and char.dismissals[id]
    if not untilEpoch then return false end
    if ns.Now() >= untilEpoch then
        char.dismissals[id] = nil
        return false
    end
    return true
end

-------------------------------------------------------------------------------
-- Collecting rows for the popup
-------------------------------------------------------------------------------

local function SnoozeRow(reminder, char, label)
    return function()
        local minutes = RMFCharDB.snoozeMinutes or 10
        char.pending[reminder.id] = ns.Now() + minutes * 60
        ns.Print("Snoozed \"|cffffd100" .. label .. "|r\" for " .. minutes .. " minutes.")
    end
end

local function DismissRow(reminder, char, label, otherCharacter)
    return function()
        if otherCharacter then
            -- Silence the nag until this reminder next comes due, without
            -- touching the alt's own schedule.
            char.dismissals = char.dismissals or {}
            char.dismissals[reminder.id] = ns.NextOccurrence(reminder, ns.Now())
        else
            Advance(reminder, char)
        end
        ns.Print("Dismissed \"|cffffd100" .. label .. "|r\".")
    end
end

-- Rows this reminder produces for the currently played character.
function ns.CollectDue(reminder)
    local rows = {}
    if reminder.disabled then return rows end

    local ast, err = ns.ParseCondition(reminder.condition)
    if not ast then
        -- A reminder with an unparseable condition is a bug in the data, not a
        -- reason to break evaluation of everything else.
        ns.Debug("reminder", reminder.id, "has an invalid condition:", err)
        return rows
    end

    local char = ns.CurrentCharacter()
    local ctx = ns.LiveContext()

    if ns.EvaluateNode(ast, ctx) and IsDue(reminder, char) then
        Advance(reminder, char)
        rows[#rows + 1] = {
            text = reminder.message,
            reminderId = reminder.id,
            snooze = SnoozeRow(reminder, char, reminder.message),
            dismiss = DismissRow(reminder, char, reminder.message, false),
        }
    end

    -- Other characters that still owe this reminder.
    if reminder.crossChar and RMFDB.profile.grainAllCharacters then
        local currentKey = ns.CharacterKey()
        for key, other in pairs(RMFDB.characters) do
            if key ~= currentKey and not IsDismissed(other, reminder.id) then
                local otherCtx = ns.RosterContext(other)
                if ns.EvaluateNode(ast, otherCtx) and IsDue(reminder, other) then
                    local label = "(" .. (other.name or "?") .. ") " .. reminder.message
                    rows[#rows + 1] = {
                        text = label,
                        reminderId = reminder.id,
                        snooze = SnoozeRow(reminder, other, label),
                        dismiss = DismissRow(reminder, other, label, true),
                    }
                end
            end
        end
    end

    return rows
end

-------------------------------------------------------------------------------
-- Manual actions
-------------------------------------------------------------------------------

function ns.ToggleReminder(id)
    local reminder = ns.GetReminder(id)
    if not reminder then return end
    reminder.disabled = not reminder.disabled

    if reminder.disabled then
        local char = ns.CurrentCharacter()
        char.pending[id] = nil
    else
        -- Re-arm from now so re-enabling does not fire a stale backlog.
        local char = ns.CurrentCharacter()
        char.pending[id] = ns.Now()
    end

    ns.Print((reminder.disabled and "Disabled" or "Enabled") .. " \"|cffffd100"
        .. reminder.message .. "|r\".")
end

-- Force one reminder to evaluate immediately, for testing.
function ns.TriggerReminder(id)
    local reminder = ns.GetReminder(id)
    if not reminder then return end
    local char = ns.CurrentCharacter()
    char.pending[id] = 0
    ns.EvaluateAll()
end

-- Clear this character's pending entry so it fires again at the next check.
function ns.ResetReminderForMe(id)
    local reminder = ns.GetReminder(id)
    if not reminder then return end
    ns.CurrentCharacter().pending[id] = 0
    ns.Print("Reset \"|cffffd100" .. reminder.message .. "|r\" for this character.")
end

-------------------------------------------------------------------------------
-- Validation used by the editor
-------------------------------------------------------------------------------

-- Returns ok, message. Keeps a reminder from being saved when it could never
-- fire or would fire on every single tick.
function ns.ValidateReminder(draft, existingId)
    local message = (draft.message or ""):match("^%s*(.-)%s*$")
    if message == "" then return false, "Enter a message to be reminded about." end

    local ast, err = ns.ParseCondition(draft.condition)
    if not ast then return false, "Condition: " .. tostring(err) end

    if draft.interval == "at" then
        if not draft.day or draft.day < 1 or draft.day > 7 then
            return false, "Choose a day of the week."
        end
        if not draft.hour or draft.hour < 0 or draft.hour > 23 then
            return false, "Choose an hour from 0 to 23."
        end
    elseif draft.interval == "interval" then
        local amount = tonumber(draft.everyValue)
        if not amount or amount < 1 then
            return false, "Repeat interval must be at least 1."
        end
    end

    -- Duplicate check: same message, condition and interval is almost always a
    -- double-click, so refuse it the way the original did.
    for id, existing in pairs(RMFDB.reminders) do
        if id ~= existingId
            and existing.message:lower() == message:lower()
            and existing.condition:lower() == (draft.condition or ""):lower()
            and existing.interval == draft.interval then
            return false, "A reminder with that message, condition and schedule already exists."
        end
    end

    return true
end

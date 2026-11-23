-- RemindMeForever - schedule math.
--
-- All boundaries are computed in epoch seconds from server time. Day-of-week and
-- hour are derived arithmetically from the epoch (UTC), never from date(), so a
-- player's local timezone can never shift a reset.
--
-- Intervals:
--   daily     - every day at the reset hour
--   weekly    - once a week on the reset day at the reset hour
--   at        - once a week on a chosen day/hour/minute
--   interval  - every N minutes/hours, counted from when it last fired

local addonName, ns = ...

local DAY = 86400
local HOUR = 3600
local MINUTE = 60

ns.DAY_NAMES = {
    "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
}

ns.DAY_SHORT = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

function ns.Now()
    if GetServerTime then
        local t = GetServerTime()
        if type(t) == "number" and t > 0 then return t end
    end
    return time()
end

-- UTC midnight of the day containing `epoch`.
local function DayStart(epoch)
    return math.floor(epoch / DAY) * DAY
end

-- 1 (Sunday) .. 7 (Saturday) for an epoch, using UTC.
local function Weekday(epoch)
    local days = math.floor(epoch / DAY)
    return (days + 4) % 7 + 1
end

ns.WeekdayForEpoch = Weekday

-------------------------------------------------------------------------------
-- Reset-time resolution
-------------------------------------------------------------------------------

-- Returns hour (0-23, UTC) and day (1-7) that "daily" and "weekly" boundaries
-- hang off. Manual values win when the player has turned detection off.
function ns.ResetConfig()
    local profile = RMFDB.profile
    if profile.useServerReset then
        return profile.detectedResetHour or 15, profile.detectedResetDay or 3
    end
    return profile.resetHour or 15, profile.resetDay or 3
end

-------------------------------------------------------------------------------
-- Next occurrence
-------------------------------------------------------------------------------

-- Daily boundary strictly after `fromEpoch`.
local function NextDaily(fromEpoch)
    local hour = ns.ResetConfig()
    local candidate = DayStart(fromEpoch) + hour * HOUR
    while candidate <= fromEpoch do
        candidate = candidate + DAY
    end
    return candidate
end

-- Weekly boundary on `day` (1-7) at `hour` strictly after `fromEpoch`.
local function NextOnDay(fromEpoch, day, hour, minute)
    minute = minute or 0
    local base = DayStart(fromEpoch)
    for offset = 0, 7 do
        local candidate = base + offset * DAY + hour * HOUR + minute * MINUTE
        if candidate > fromEpoch and Weekday(candidate) == day then
            return candidate
        end
    end
    -- Unreachable for a valid day, but never return nil to callers.
    return base + 7 * DAY + hour * HOUR + minute * MINUTE
end

-- The boundary a reminder should be waiting on, given the moment it last fired
-- (or nil if it has never fired on this character).
function ns.NextOccurrence(reminder, fromEpoch)
    fromEpoch = fromEpoch or ns.Now()
    local interval = reminder.interval or "daily"

    if interval == "daily" then
        return NextDaily(fromEpoch)
    elseif interval == "weekly" then
        local hour, resetDay = ns.ResetConfig()
        return NextOnDay(fromEpoch, reminder.day or resetDay, hour, 0)
    elseif interval == "at" then
        return NextOnDay(fromEpoch, reminder.day or 3, reminder.hour or 15, reminder.minute or 0)
    elseif interval == "interval" then
        local unit = reminder.everyUnit or "hours"
        local amount = tonumber(reminder.everyValue) or 1
        if amount < 1 then amount = 1 end
        local seconds = (unit == "minutes") and (amount * MINUTE) or (amount * HOUR)
        return fromEpoch + seconds
    end

    return NextDaily(fromEpoch)
end

-------------------------------------------------------------------------------
-- Human-readable description
-------------------------------------------------------------------------------

function ns.DescribeSchedule(reminder)
    local interval = reminder.interval or "daily"
    if interval == "daily" then
        return "Daily"
    elseif interval == "weekly" then
        local day = reminder.day or select(2, ns.ResetConfig())
        return "Weekly (" .. (ns.DAY_SHORT[day] or "?") .. ")"
    elseif interval == "at" then
        local day = reminder.day or 3
        local hour = reminder.hour or 15
        local minute = reminder.minute or 0
        return string.format("%s %02d:%02d", ns.DAY_SHORT[day] or "?", hour, minute)
    elseif interval == "interval" then
        local amount = tonumber(reminder.everyValue) or 1
        local unit = reminder.everyUnit or "hours"
        return string.format("Every %d %s", amount, unit)
    end
    return "Daily"
end

-- Short "time until" text for the list rows, e.g. "in 3h", "due now".
function ns.DescribeCountdown(epoch)
    if not epoch then return "" end
    local delta = epoch - ns.Now()
    if delta <= 0 then return "due" end
    if delta < 60 then return "<1m" end
    if delta < HOUR then return string.format("%dm", math.floor(delta / MINUTE)) end
    if delta < DAY then return string.format("%dh", math.floor(delta / HOUR)) end
    return string.format("%dd", math.floor(delta / DAY))
end

-------------------------------------------------------------------------------
-- Formatting helpers used by the schedule editor
-------------------------------------------------------------------------------

function ns.FormatClock(hour, minute)
    hour = hour or 0
    minute = minute or 0
    local suffix = (hour < 12) and "AM" or "PM"
    local display = hour % 12
    if display == 0 then display = 12 end
    return string.format("%d:%02d %s", display, minute, suffix)
end

-- Validated setter used by the UI; returns true on success, or false plus a
-- message when the input cannot be understood.
function ns.ParseClock(text)
    if type(text) ~= "string" then return nil, "enter a time like 15:00" end
    local h, m = text:match("^(%d%d?):(%d%d)$")
    if not h then
        h = text:match("^(%d%d?)$")
        m = "0"
    end
    if not h then return nil, "enter a time like 15:00" end
    h, m = tonumber(h), tonumber(m)
    if not h or h < 0 or h > 23 then return nil, "hour must be 0-23" end
    if not m or m < 0 or m > 59 then return nil, "minute must be 0-59" end
    return { hour = h, minute = m }
end

-- RemindMeForever - options panel.
--
-- Deliberately not wired into Blizzard's Settings panel: that API has changed
-- shape several times and Forever inherited the newest one. A standalone themed
-- window is fewer moving parts and works on any build.

local addonName, ns = ...

local THEME = ns.Theme

local optionsFrame
local resetModeCheck, resetHourBox, resetDayDrop
local snoozeBox, debugCheck, grainCheck
local statusText

local function RefreshOptions()
    local profile = RMFDB.profile

    resetModeCheck:SetCheckedState(not profile.useServerReset)
    resetHourBox:SetText(tostring(profile.resetHour or 15))
    resetDayDrop:SetOptions(ns.DayOptions(), profile.resetDay or 3)
    resetHourBox:SetShown(not profile.useServerReset)
    resetDayDrop:SetShown(not profile.useServerReset)

    snoozeBox:SetText(tostring(RMFCharDB.snoozeMinutes or 10))
    debugCheck:SetCheckedState(RMFCharDB.debug)
    grainCheck:SetCheckedState(profile.grainAllCharacters)

    local detectedHour = profile.detectedResetHour
    local detectedDay = profile.detectedResetDay
    if detectedHour then
        statusText:SetText(string.format(
            "Server reports daily reset at %s (server time), weekly on %s.",
            ns.FormatClock(detectedHour, 0),
            ns.DAY_NAMES[detectedDay or 3] or "?"))
    else
        statusText:SetText("Server reset time not detected yet. It is read once per login.")
    end
end

local function ApplyResetHour()
    local value = tonumber(resetHourBox:GetText())
    if not value or value < 0 or value > 23 then
        resetHourBox:SetInvalid(true)
        ns.PrintError("Reset hour must be a number from 0 to 23 (server time).")
        return
    end
    resetHourBox:SetInvalid(false)
    RMFDB.profile.resetHour = math.floor(value)
    ns.Print("Reset hour set to " .. ns.FormatClock(RMFDB.profile.resetHour, 0) .. " server time.")
    RefreshOptions()
end

local function ApplySnooze()
    local value = tonumber(snoozeBox:GetText())
    if not value or value < 1 or value > 720 then
        snoozeBox:SetInvalid(true)
        ns.PrintError("Snooze must be between 1 and 720 minutes.")
        return
    end
    snoozeBox:SetInvalid(false)
    RMFCharDB.snoozeMinutes = math.floor(value)
    RefreshOptions()
end

function ns.CreateOptionsPanel()
    if optionsFrame then return optionsFrame end

    local frame = ns.CreatePanel("RemindMeForeverOptions", "RemindMeForever Options", 460, 430, true)
    frame:SetPoint("CENTER", UIParent, "CENTER", 420, 0)

    local y = -12

    -- Reset section -----------------------------------------------------------
    local resetHeader = ns.CreateLabel(frame.content, "RESET TIMES", 11, THEME.gold)
    resetHeader:SetPoint("TOPLEFT", 14, y)
    y = y - 18

    statusText = ns.CreateLabel(frame.content, "", 11, THEME.textDim)
    statusText:SetPoint("TOPLEFT", 14, y)
    statusText:SetPoint("TOPRIGHT", -14, y)
    statusText:SetJustifyH("LEFT")
    statusText:SetWordWrap(true)
    statusText:SetHeight(30)
    y = y - 34

    resetModeCheck = ns.CreateCheckbox(frame.content, "Set the reset hour myself")
    resetModeCheck:SetPoint("TOPLEFT", 14, y)
    resetModeCheck:SetSize(300, 20)
    resetModeCheck.OnValueChanged = function(checked)
        RMFDB.profile.useServerReset = not checked
        RefreshOptions()
    end
    y = y - 26

    local hourLabel = ns.CreateLabel(frame.content, "Reset hour (server time, 0-23)", 11, THEME.goldDim)
    hourLabel:SetPoint("TOPLEFT", 32, y)

    local dayLabel = ns.CreateLabel(frame.content, "Weekly reset day", 11, THEME.goldDim)
    dayLabel:SetPoint("TOPLEFT", 190, y)
    y = y - 26

    resetHourBox = ns.CreateEditBox(frame.content, 70, 22)
    resetHourBox:SetPoint("TOPLEFT", 30, y)
    resetHourBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        ApplyResetHour()
    end)
    resetHourBox:SetScript("OnEditFocusLost", ApplyResetHour)

    resetDayDrop = ns.CreateDropdown(frame.content, 130)
    resetDayDrop:SetPoint("TOPLEFT", 188, y)
    resetDayDrop:SetOptions(ns.DayOptions(), 3)
    resetDayDrop.OnSelect = function(value)
        RMFDB.profile.resetDay = value
        ns.Print("Weekly reset day set to " .. (ns.DAY_NAMES[value] or "?") .. ".")
    end
    y = y - 34

    -- Divider
    local d1 = frame:CreateTexture(nil, "ARTWORK")
    d1:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 0.4)
    d1:SetPoint("TOPLEFT", 14, y)
    d1:SetPoint("TOPRIGHT", -14, y)
    d1:SetHeight(1)
    y = y - 14

    -- Behaviour section -------------------------------------------------------
    local behaviorHeader = ns.CreateLabel(frame.content, "BEHAVIOUR", 11, THEME.gold)
    behaviorHeader:SetPoint("TOPLEFT", 14, y)
    y = y - 22

    local snoozeLabel = ns.CreateLabel(frame.content, "Snooze length (minutes)", 11, THEME.goldDim)
    snoozeLabel:SetPoint("TOPLEFT", 14, y)

    snoozeBox = ns.CreateEditBox(frame.content, 70, 22)
    snoozeBox:SetPoint("TOPLEFT", 188, y + 4)
    snoozeBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        ApplySnooze()
    end)
    snoozeBox:SetScript("OnEditFocusLost", ApplySnooze)
    y = y - 28

    grainCheck = ns.CreateCheckbox(frame.content, "Show reminders owed by my other characters")
    grainCheck:SetPoint("TOPLEFT", 14, y)
    grainCheck:SetSize(400, 20)
    grainCheck.OnValueChanged = function(checked)
        RMFDB.profile.grainAllCharacters = checked
    end
    y = y - 24

    debugCheck = ns.CreateCheckbox(frame.content, "Debug messages in chat")
    debugCheck:SetPoint("TOPLEFT", 14, y)
    debugCheck:SetSize(400, 20)
    debugCheck.OnValueChanged = function(checked)
        RMFCharDB.debug = checked
        if checked then ns.Print("Debug on.") else ns.Print("Debug off.") end
    end
    y = y - 32

    local d2 = frame:CreateTexture(nil, "ARTWORK")
    d2:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 0.4)
    d2:SetPoint("TOPLEFT", 14, y)
    d2:SetPoint("TOPRIGHT", -14, y)
    d2:SetHeight(1)
    y = y - 16

    -- Data section ------------------------------------------------------------
    local dataHeader = ns.CreateLabel(frame.content, "DATA", 11, THEME.gold)
    dataHeader:SetPoint("TOPLEFT", 14, y)
    y = y - 22

    local clearButton = ns.CreateButton(frame.content, "Delete all reminders", 150, 22)
    clearButton:SetPoint("TOPLEFT", 14, y)
    clearButton:SetScript("OnClick", function()
        ns.ConfirmResetAll()
    end)

    local exportButton = ns.CreateButton(frame.content, "Show saved data", 130, 22)
    exportButton:SetPoint("LEFT", clearButton, "RIGHT", 8, 0)
    exportButton:SetScript("OnClick", function()
        ns.PrintSummary()
    end)

    local versionLabel = ns.CreateLabel(frame.content, "v" .. ns.version, 10, THEME.textDim)
    versionLabel:SetPoint("BOTTOMRIGHT", -12, 10)

    frame.OnShown = RefreshOptions

    optionsFrame = frame
    return frame
end

function ns.OpenOptions()
    local frame = ns.CreateOptionsPanel()
    frame:Show()
    RefreshOptions()
end

-- Print a compact summary of what is stored; useful when reporting a bug.
function ns.PrintSummary()
    local count = 0
    for _ in pairs(RMFDB.reminders) do count = count + 1 end
    local chars = 0
    for _ in pairs(RMFDB.characters) do chars = chars + 1 end
    ns.Print(string.format("%d reminder(s), %d character(s) known. Character: %s.",
        count, chars, ns.CharacterKey()))
    for _, reminder in pairs(RMFDB.reminders) do
        ns.Print(string.format("  %s | %s | %s | %s",
            reminder.id or "?",
            reminder.message or "",
            ns.DescribeCondition(reminder.condition),
            ns.DescribeSchedule(reminder)))
    end
end

-- RemindMeForever - slash commands.

local addonName, ns = ...

local THEME = ns.Theme

local USAGE = table.concat({
    "|cffffd100/rmf|r - open or close the window",
    "|cffffd100/rmf eval|r - check every reminder now",
    "|cffffd100/rmf opts|r - open options",
    "|cffffd100/rmf list|r - print your reminders",
    "|cffffd100/rmf test <id>|r - fire a reminder immediately",
    "|cffffd100/rmf on <id>|r / |cffffd100/rmf off <id>|r - enable or disable",
    "|cffffd100/rmf reset <id>|r - make this character owe it again",
    "|cffffd100/rmf delete <id>|r - delete one reminder",
    "|cffffd100/rmf debug|r - toggle debug output",
    "|cffffd100/rmf wipe|r - delete every reminder",
}, "\n")

local function SplitArgs(input)
    local args = {}
    for token in tostring(input or ""):gmatch("%S+") do
        args[#args + 1] = token
    end
    return args
end

local function ResolveId(token)
    if not token then return nil end
    -- Accept the bare number as well as the stored "rN" form.
    local id = token:match("^[rR]%d+$") and token:lower() or ("r" .. token)
    if RMFDB.reminders[id] then return id end
    if RMFDB.reminders[token] then return token end
    return nil
end

local function HandleCommand(input)
    local args = SplitArgs(input)
    local command = (args[1] or ""):lower()

    if command == "" or command == "toggle" then
        ns.ToggleMainWindow()
    elseif command == "show" or command == "open" then
        ns.OpenMainWindow()
    elseif command == "eval" then
        ns.EvaluateAll()
        ns.Print("Checked all reminders.")
    elseif command == "opts" or command == "options" or command == "config" then
        ns.OpenOptions()
    elseif command == "list" then
        ns.PrintSummary()
    elseif command == "debug" then
        RMFCharDB.debug = not RMFCharDB.debug
        ns.Print("Debug " .. (RMFCharDB.debug and "on" or "off") .. ".")
    elseif command == "wipe" then
        ns.ConfirmResetAll()
    elseif command == "delete" then
        local id = ResolveId(args[2])
        if not id then
            ns.PrintError("No reminder with that id. Try /rmf list.")
            return
        end
        local reminder = RMFDB.reminders[id]
        ns.DeleteReminder(id)
        ns.Print("Deleted \"" .. (reminder.message or "") .. "\".")
        ns.RefreshMainWindow()
    elseif command == "test" then
        local id = ResolveId(args[2])
        if not id then
            ns.PrintError("No reminder with that id. Try /rmf list.")
            return
        end
        ns.TriggerReminder(id)
    elseif command == "on" or command == "off" then
        local id = ResolveId(args[2])
        if not id then
            ns.PrintError("No reminder with that id. Try /rmf list.")
            return
        end
        local reminder = RMFDB.reminders[id]
        local wantDisabled = (command == "off")
        if (reminder.disabled and true or false) == wantDisabled then
            ns.Print("Already " .. (wantDisabled and "off" or "on") .. ".")
            return
        end
        ns.ToggleReminder(id)
        ns.RefreshMainWindow()
    elseif command == "reset" then
        local id = ResolveId(args[2])
        if not id then
            ns.PrintError("No reminder with that id. Try /rmf list.")
            return
        end
        ns.ResetReminderForMe(id)
    elseif command == "help" then
        ns.Print(USAGE)
    else
        ns.Print(USAGE)
    end
end

function ns.RegisterSlashCommands()
    SLASH_REMINDBEFOREFOREVER1 = "/rmf"
    SLASH_REMINDBEFOREFOREVER2 = "/remindmeforever"
    SlashCmdList["REMINDBEFOREFOREVER"] = HandleCommand
end

-------------------------------------------------------------------------------
-- Reset-all confirmation
-------------------------------------------------------------------------------

local wipeFrame

function ns.ConfirmResetAll()
    if not wipeFrame then
        local frame = ns.CreatePanel("RemindMeForeverWipe", "Delete all reminders?", 360, 150, true)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)

        local text = ns.CreateLabel(frame.content,
            "This deletes every reminder and every character's schedule. There is no undo.",
            12, THEME.text)
        text:SetPoint("TOPLEFT", 14, -12)
        text:SetPoint("TOPRIGHT", -14, -12)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(true)

        local yes = ns.CreateButton(frame.content, "Delete all", 100, 22)
        yes:SetPoint("BOTTOMRIGHT", -12, 12)
        yes:SetScript("OnClick", function()
            RMFDB.reminders = {}
            RMFDB.nextId = 0
            for _, char in pairs(RMFDB.characters) do
                char.pending = {}
                char.dismissals = {}
            end
            frame:Hide()
            ns.RefreshMainWindow()
            ns.Print("All reminders deleted.")
        end)

        local no = ns.CreateButton(frame.content, "Cancel", 90, 22)
        no:SetPoint("RIGHT", yes, "LEFT", -8, 0)
        no:SetScript("OnClick", function() frame:Hide() end)

        wipeFrame = frame
    end
    wipeFrame:Show()
end

-------------------------------------------------------------------------------
-- First-run hint
-------------------------------------------------------------------------------

local hintShown = false

function ns.MaybeShowFirstRunHint()
    if hintShown then return end
    hintShown = true
    local count = 0
    for _ in pairs(RMFDB.reminders) do count = count + 1 end
    if count == 0 then
        ns.Print("Type |cffffd100/rmf|r to create your first reminder.")
    end
end

local hintFrame = CreateFrame("Frame")
hintFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
hintFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    ns.MaybeShowFirstRunHint()
end)

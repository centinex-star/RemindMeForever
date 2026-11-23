-- RemindMeForever - main window and the reminder editor.

local addonName, ns = ...

local THEME = ns.Theme
local ROW_HEIGHT = 46

local mainFrame
local messageBox, conditionDrop, operationDrop, valueBox, valueDrop
local intervalDrop, dayDrop, timeBox, valueLabel
local createButton, cancelButton, crossCharCheck
local listScroll, listContent
local rowPool = {}
local emptyState
local editingId

-------------------------------------------------------------------------------
-- Window position persistence
-------------------------------------------------------------------------------

function ns.SaveWindowPosition(frame)
    if not frame or not frame.GetPoint then return end
    local point, _, relPoint, x, y = frame:GetPoint(1)
    RMFDB.profile.window = {
        point = point, relPoint = relPoint, x = x, y = y,
    }
end

local function RestoreWindowPosition(frame)
    local saved = RMFDB.profile.window
    frame:ClearAllPoints()
    if saved and saved.point then
        frame:SetPoint(saved.point, UIParent, saved.relPoint or saved.point,
            saved.x or 0, saved.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-------------------------------------------------------------------------------
-- Editor state
-------------------------------------------------------------------------------

local function ResetEditor()
    editingId = nil
    ns.editorDraft = ns.NewReminder()
    if messageBox then messageBox:SetText("") end
    if conditionDrop then conditionDrop:SetOptions(ns.FieldChoiceOptions(), "name") end
    if operationDrop then operationDrop:SetOptions(ns.OperationOptions(), "eq") end
    if valueBox then valueBox:SetText("") end
    if intervalDrop then intervalDrop:SetOptions(ns.IntervalOptions(), "daily") end
    if crossCharCheck then crossCharCheck:SetCheckedState(false) end
    if createButton then createButton.label:SetText("Create") end
    if cancelButton then cancelButton:Hide() end
    ns.UpdateEditorWidgets()
end

function ns.LoadIntoEditor(id)
    local reminder = ns.GetReminder(id)
    if not reminder then return end

    editingId = id
    ns.editorDraft = {
        message = reminder.message,
        condition = reminder.condition,
        interval = reminder.interval,
        day = reminder.day,
        hour = reminder.hour,
        minute = reminder.minute,
        everyValue = reminder.everyValue,
        everyUnit = reminder.everyUnit,
        disabled = reminder.disabled,
        crossChar = reminder.crossChar,
        createdAt = reminder.createdAt,
    }

    -- Split "field op value" back into the widgets when it is a single clause;
    -- anything more complex stays in the value box as raw text.
    local field, op, value = (reminder.condition or ""):match("^(%a+)%s*([=~<>!]+)%s*(.-)%s*$")
    if field and ns.Fields[field:lower()] and not value:find("%s+(and|or)%s+") then
        conditionDrop:SetOptions(ns.FieldChoiceOptions(), field:lower())
        operationDrop:SetOptions(ns.OperationOptions(), ns.OperatorKey(op))
        valueBox:SetText((value:gsub('^"(.*)"$', "%1")))
    else
        conditionDrop:SetOptions(ns.FieldChoiceOptions(), "name")
        valueBox:SetText(reminder.condition or "")
    end

    messageBox:SetText(reminder.message or "")
    intervalDrop:SetOptions(ns.IntervalOptions(), reminder.interval or "daily")
    crossCharCheck:SetCheckedState(reminder.crossChar)

    createButton.label:SetText("Save")
    cancelButton:Show()
    ns.UpdateEditorWidgets()
end

-------------------------------------------------------------------------------
-- Option lists
-------------------------------------------------------------------------------

function ns.FieldChoiceOptions()
    local options = {}
    for _, key in ipairs(ns.FieldOrder) do
        options[#options + 1] = { value = key, text = ns.FieldLabel(key) }
    end
    options[#options + 1] = { value = "*", text = "Everyone" }
    return options
end

function ns.OperationOptions()
    return {
        { value = "eq", text = "Equals" },
        { value = "ne", text = "Not Equals" },
        { value = "gt", text = "Greater Than" },
        { value = "ge", text = "Greater or Equal" },
        { value = "lt", text = "Less Than" },
        { value = "le", text = "Less or Equal" },
    }
end

function ns.OperatorKey(symbol)
    local map = {
        ["="] = "eq", ["=="] = "eq",
        ["~="] = "ne", ["!="] = "ne",
        [">"] = "gt", [">="] = "ge",
        ["<"] = "lt", ["<="] = "le",
    }
    return map[symbol] or "eq"
end

local function OperatorSymbol(key)
    local map = {
        eq = "=", ne = "~=", gt = ">", ge = ">=", lt = "<", le = "<=",
    }
    return map[key] or "="
end

function ns.IntervalOptions()
    return {
        { value = "daily", text = "Daily" },
        { value = "weekly", text = "Weekly" },
        { value = "at", text = "Weekly (time)" },
        { value = "interval", text = "Every N" },
    }
end

function ns.DayOptions()
    local options = {}
    for index, name in ipairs(ns.DAY_NAMES) do
        options[#options + 1] = { value = index, text = name }
    end
    return options
end

-------------------------------------------------------------------------------
-- Value widget, which changes shape with the chosen field
-------------------------------------------------------------------------------

local PROFESSIONS = {
    "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering",
    "Fishing", "Herbalism", "Inscription", "Jewelcrafting", "Leatherworking",
    "Mining", "Skinning", "Tailoring",
}

local CLASS_NAMES = {
    "Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman",
    "Mage", "Warlock", "Druid",
}

local function ProfessionOptions()
    local options = {}
    for _, name in ipairs(PROFESSIONS) do
        options[#options + 1] = { value = name, text = name }
    end
    return options
end

local function ClassOptions()
    local options = {}
    for _, name in ipairs(CLASS_NAMES) do
        options[#options + 1] = { value = name, text = name }
    end
    return options
end

local function BooleanOptions()
    return {
        { value = "yes", text = "yes" },
        { value = "no", text = "no" },
    }
end

function ns.UpdateEditorWidgets()
    local draft = ns.editorDraft or ns.NewReminder()
    local fieldKey = conditionDrop and conditionDrop:GetValue() or "name"
    local field = ns.Fields[fieldKey]

    -- Condition editing: "Everyone" hides op/value entirely.
    local everyone = (fieldKey == "*")
    operationDrop:SetShown(not everyone)
    if valueLabel then valueLabel:SetShown(not everyone) end

    if everyone then
        valueBox:Hide()
        valueDrop:Hide()
    else
        local kind = field and field.kind or "text"
        local needsDropdown = (kind == "bool" or fieldKey == "profession" or fieldKey == "class")
        valueBox:SetShown(not needsDropdown)
        valueDrop:SetShown(needsDropdown)

        if needsDropdown then
            if kind == "bool" then
                valueDrop:SetOptions(BooleanOptions(), valueDrop:GetValue() or "yes")
            elseif fieldKey == "profession" then
                valueDrop:SetOptions(ProfessionOptions(), valueDrop:GetValue())
            else
                valueDrop:SetOptions(ClassOptions(), valueDrop:GetValue())
            end
        end

        -- Numeric fields only make sense with comparison operators.
        if kind == "number" then
            operationDrop:SetOptions(ns.OperationOptions(), operationDrop:GetValue() or "eq")
        else
            operationDrop:SetOptions({ ns.OperationOptions()[1], ns.OperationOptions()[2] },
                "eq")
        end
    end

    -- Schedule sub-widgets
    local interval = intervalDrop and intervalDrop:GetValue() or "daily"
    dayDrop:SetShown(interval == "at" or interval == "weekly")
    timeBox:SetShown(interval == "at")
    if interval == "at" then
        dayDrop:SetOptions(ns.DayOptions(), dayDrop:GetValue() or 3)
        if timeBox:GetText() == "" then
            timeBox:SetText("15:00")
        end
    elseif interval == "weekly" then
        dayDrop:SetOptions(ns.DayOptions(), select(2, ns.ResetConfig()))
    end
end

-------------------------------------------------------------------------------
-- Building the condition string from the widgets
-------------------------------------------------------------------------------

local function BuildCondition()
    local fieldKey = conditionDrop:GetValue()
    if fieldKey == "*" then return "*" end

    local field = ns.Fields[fieldKey]
    if not field then return "*" end

    local op = OperatorSymbol(operationDrop:GetValue() or "eq")

    local value
    if field.kind == "bool" or fieldKey == "profession" or fieldKey == "class" then
        value = valueDrop:GetValue()
    else
        value = (valueBox:GetText() or ""):match("^%s*(.-)%s*$")
    end

    if not value or value == "" then
        return nil, "Enter a value for " .. field.label .. "."
    end

    -- Quote values containing spaces so the parser keeps them together.
    if value:find("%s") and not value:find('"') then
        value = '"' .. value .. '"'
    end

    return fieldKey .. " " .. op .. " " .. value
end

-------------------------------------------------------------------------------
-- Editor actions
-------------------------------------------------------------------------------

local function CollectDraft()
    local condition, conditionErr = BuildCondition()
    if not condition then return nil, conditionErr end

    local draft = ns.editorDraft or ns.NewReminder()
    draft.message = messageBox:GetText() or ""
    draft.condition = condition
    draft.interval = intervalDrop:GetValue() or "daily"
    draft.crossChar = crossCharCheck:GetCheckedState()

    if draft.interval == "at" then
        local day = dayDrop:GetValue()
        local clock, clockErr = ns.ParseClock(timeBox:GetText())
        if not clock then return nil, clockErr end
        draft.day = day
        draft.hour = clock.hour
        draft.minute = clock.minute
    elseif draft.interval == "weekly" then
        draft.day = dayDrop:GetValue()
    end

    return draft
end

local function OnCreateClicked()
    local draft, err = CollectDraft()
    if not draft then
        ns.PrintError(err)
        return
    end

    local ok, validationErr = ns.ValidateReminder(draft, editingId)
    if not ok then
        ns.PrintError(validationErr)
        return
    end

    ns.SaveReminder(draft, editingId)
    if editingId then
        ns.Print("Updated \"|cffffd100" .. draft.message .. "|r\".")
    else
        ns.Print("Created \"|cffffd100" .. draft.message .. "|r\".")
    end

    ResetEditor()
    ns.RefreshMainWindow()
end

local function OnCancelClicked()
    ResetEditor()
    ns.RefreshMainWindow()
end

-------------------------------------------------------------------------------
-- List rows
-------------------------------------------------------------------------------

local function AcquireRow(index)
    if rowPool[index] then return rowPool[index] end

    local row = CreateFrame("Frame", nil, listContent, "BackdropTemplate")
    row:SetHeight(ROW_HEIGHT)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    row.bg = bg

    local check = ns.CreateCheckbox(row)
    check:SetPoint("LEFT", 8, 0)
    row.check = check

    local title = ns.CreateLabel(row, "", 13, THEME.text)
    title:SetPoint("TOPLEFT", 32, -8)
    title:SetPoint("TOPRIGHT", -64, -8)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    row.title = title

    local subtitle = ns.CreateLabel(row, "", 11, THEME.textDim)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    subtitle:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -3)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetWordWrap(false)
    row.subtitle = subtitle

    local schedule = ns.CreateLabel(row, "", 11, THEME.goldDim)
    schedule:SetPoint("RIGHT", -30, 0)
    schedule:SetJustifyH("RIGHT")
    row.schedule = schedule

    local delete = CreateFrame("Button", nil, row)
    delete:SetSize(18, 18)
    delete:SetPoint("RIGHT", -6, 0)
    local deleteText = ns.CreateLabel(delete, "X", 12, THEME.bad)
    deleteText:SetPoint("CENTER")
    delete:SetScript("OnEnter", function() ns.SetTextColor(deleteText, THEME.gold) end)
    delete:SetScript("OnLeave", function() ns.SetTextColor(deleteText, THEME.bad) end)
    row.delete = delete

    local hover = CreateFrame("Button", nil, row)
    hover:SetAllPoints()
    hover:SetFrameLevel(row:GetFrameLevel() + 1)
    hover:SetScript("OnEnter", function()
        bg:SetColorTexture(THEME.rowHover[1], THEME.rowHover[2], THEME.rowHover[3], THEME.rowHover[4])
    end)
    hover:SetScript("OnLeave", function()
        bg:SetColorTexture(THEME.rowAlt[1], THEME.rowAlt[2], THEME.rowAlt[3], THEME.rowAlt[4])
    end)
    hover:SetScript("OnClick", function()
        ns.LoadIntoEditor(row.reminderId)
    end)
    row.hover = hover

    rowPool[index] = row
    return row
end

local function HideAllRows()
    for _, row in ipairs(rowPool) do row:Hide() end
end

local function BuildRows()
    HideAllRows()

    local sorted = {}
    for id, reminder in pairs(RMFDB.reminders) do
        sorted[#sorted + 1] = reminder
    end
    table.sort(sorted, function(a, b)
        local aCreated, bCreated = a.createdAt or 0, b.createdAt or 0
        if aCreated == bCreated then return (a.message or "") < (b.message or "") end
        return aCreated < bCreated
    end)

    if #sorted == 0 then
        if emptyState then emptyState:Show() end
        listContent:SetHeight(1)
        return
    end
    if emptyState then emptyState:Hide() end

    local char = ns.CurrentCharacter()

    for index, reminder in ipairs(sorted) do
        local row = AcquireRow(index)
        row.reminderId = reminder.id
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", listContent, "TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)
        row:SetHeight(ROW_HEIGHT)

        local isEven = (index % 2 == 0)
        local shade = isEven and THEME.rowAlt or { 0.08, 0.07, 0.05, 0.45 }
        row.bg:SetColorTexture(shade[1], shade[2], shade[3], shade[4])

        row.check:SetCheckedState(not reminder.disabled)
        row.check.OnValueChanged = function()
            ns.ToggleReminder(reminder.id)
            ns.RefreshMainWindow()
        end

        row.title:SetText(reminder.message or "(no message)")
        if reminder.disabled then
            ns.SetTextColor(row.title, THEME.textDim)
        else
            ns.SetTextColor(row.title, THEME.text)
        end

        row.subtitle:SetText(ns.DescribeCondition(reminder.condition))

        local pendingAt = char.pending[reminder.id]
        local countdown = pendingAt and ns.DescribeCountdown(pendingAt) or ""
        local text = ns.DescribeSchedule(reminder)
        if countdown ~= "" then
            text = text .. "  |cff555555" .. countdown .. "|r"
        end
        row.schedule:SetText(text)

        row.delete:SetScript("OnClick", function()
            ns.ConfirmDelete(reminder.id)
        end)

        ns.AttachTooltip(row.hover, reminder.message or "(no message)", {
            "Condition: " .. ns.DescribeCondition(reminder.condition),
            "Schedule: " .. ns.DescribeSchedule(reminder),
            "Click to edit.",
        })

        row:Show()
    end

    listContent:SetHeight(#sorted * ROW_HEIGHT)
end

-------------------------------------------------------------------------------
-- Delete confirmation
-------------------------------------------------------------------------------

local confirmFrame

function ns.ConfirmDelete(id)
    local reminder = ns.GetReminder(id)
    if not reminder then return end

    if not confirmFrame then
        local frame = ns.CreatePanel("RemindMeForeverConfirm", "Delete reminder?", 340, 140, true)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)

        local text = ns.CreateLabel(frame.content, "", 12, THEME.text)
        text:SetPoint("TOPLEFT", 14, -12)
        text:SetPoint("TOPRIGHT", -14, -12)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(true)
        frame.messageText = text

        local yes = ns.CreateButton(frame.content, "Delete", 90, 22)
        yes:SetPoint("BOTTOMRIGHT", -12, 12)
        frame.yesButton = yes

        local no = ns.CreateButton(frame.content, "Cancel", 90, 22)
        no:SetPoint("RIGHT", yes, "LEFT", -8, 0)
        no:SetScript("OnClick", function() frame:Hide() end)

        confirmFrame = frame
    end

    confirmFrame.messageText:SetText("\"" .. (reminder.message or "") .. "\"\n\nThis also clears its schedule. There is no undo.")
    confirmFrame.yesButton:SetScript("OnClick", function()
        ns.DeleteReminder(id)
        if editingId == id then ResetEditor() end
        confirmFrame:Hide()
        ns.RefreshMainWindow()
        ns.Print("Deleted a reminder.")
    end)
    confirmFrame:Show()
end

-------------------------------------------------------------------------------
-- Window construction
-------------------------------------------------------------------------------

local function BuildEditor(parent)
    local editor = CreateFrame("Frame", nil, parent)
    editor:SetPoint("TOPLEFT", 8, -8)
    editor:SetPoint("TOPRIGHT", -8, -8)
    editor:SetHeight(92)

    -- Row 1: message
    local messageLabel = ns.CreateLabel(editor, "Reminder", 11, THEME.goldDim)
    messageLabel:SetPoint("TOPLEFT", 2, 0)

    messageBox = ns.CreateEditBox(editor, 200, 24)
    messageBox:SetPoint("TOPLEFT", 0, -14)
    messageBox:SetPoint("TOPRIGHT", -96, -14)
    messageBox:SetHeight(24)
    messageBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    messageBox:SetScript("OnTextChanged", function(self)
        if self:GetText():len() > 0 then self:SetInvalid(false) end
    end)

    -- Row 2: condition / operation / value / interval / button
    local conditionLabel = ns.CreateLabel(editor, "Condition", 11, THEME.goldDim)
    conditionLabel:SetPoint("TOPLEFT", 2, -44)

    conditionDrop = ns.CreateDropdown(editor, 120)
    conditionDrop:SetPoint("TOPLEFT", 0, -58)
    conditionDrop:SetOptions(ns.FieldChoiceOptions(), "name")
    conditionDrop.OnSelect = function()
        ns.UpdateEditorWidgets()
    end

    operationDrop = ns.CreateDropdown(editor, 108)
    operationDrop:SetPoint("LEFT", conditionDrop, "RIGHT", 6, 0)
    operationDrop:SetOptions(ns.OperationOptions(), "eq")
    operationDrop.OnSelect = function() end

    valueLabel = ns.CreateLabel(editor, "Value", 11, THEME.goldDim)
    valueLabel:SetPoint("BOTTOMLEFT", operationDrop, "TOPLEFT", 2, 3)

    valueBox = ns.CreateEditBox(editor, 120, 22)
    valueBox:SetPoint("LEFT", operationDrop, "RIGHT", 6, 0)
    valueBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    valueBox:SetScript("OnTextChanged", function(self)
        if self:GetText():len() > 0 then self:SetInvalid(false) end
    end)

    valueDrop = ns.CreateDropdown(editor, 130)
    valueDrop:SetPoint("LEFT", operationDrop, "RIGHT", 6, 0)
    valueDrop:Hide()

    intervalDrop = ns.CreateDropdown(editor, 120)
    intervalDrop:SetPoint("LEFT", valueBox, "RIGHT", 8, 0)
    intervalDrop:SetOptions(ns.IntervalOptions(), "daily")
    intervalDrop.OnSelect = function()
        ns.UpdateEditorWidgets()
    end

    createButton = ns.CreateButton(editor, "Create", 84, 22)
    createButton:SetPoint("RIGHT", 0, -14)
    createButton:SetScript("OnClick", OnCreateClicked)

    -- Extra schedule controls, revealed only when relevant
    dayDrop = ns.CreateDropdown(editor, 120)
    dayDrop:SetPoint("TOPLEFT", 0, -88)
    dayDrop:SetOptions(ns.DayOptions(), 3)
    dayDrop:Hide()

    timeBox = ns.CreateEditBox(editor, 70, 22)
    timeBox:SetPoint("LEFT", dayDrop, "RIGHT", 6, 0)
    timeBox:SetText("15:00")
    timeBox:Hide()
    timeBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    crossCharCheck = ns.CreateCheckbox(editor, "Also remind on my other characters")
    crossCharCheck:SetPoint("LEFT", 0, -88)
    crossCharCheck:SetSize(230, 20)

    cancelButton = ns.CreateButton(editor, "Cancel", 70, 22)
    cancelButton:SetPoint("RIGHT", createButton, "LEFT", -6, 0)
    cancelButton:Hide()
    cancelButton:SetScript("OnClick", OnCancelClicked)

    -- Exposed so the offline smoke test can drive the editor the way a player
    -- does; nothing in the addon reads this table back.
    ns.editorWidgets = {
        message = messageBox, condition = conditionDrop, operation = operationDrop,
        value = valueBox, valueDrop = valueDrop, interval = intervalDrop,
        day = dayDrop, time = timeBox, crossChar = crossCharCheck,
        create = createButton, cancel = cancelButton,
    }

    return editor
end

function ns.CreateMainWindow()
    if mainFrame then return mainFrame end

    local frame = ns.CreatePanel("RemindMeForeverMain", "RemindMeForever", 720, 520, true)
    RestoreWindowPosition(frame)

    local editor = BuildEditor(frame.content)

    -- Divider under the editor
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 0.5)
    divider:SetPoint("TOPLEFT", 8, -108)
    divider:SetPoint("TOPRIGHT", -8, -108)
    divider:SetHeight(1)

    -- Column headers
    local headerFrame = CreateFrame("Frame", nil, frame.content)
    headerFrame:SetPoint("TOPLEFT", 8, -116)
    headerFrame:SetPoint("TOPRIGHT", -8, -116)
    headerFrame:SetHeight(16)

    local listLabel = ns.CreateLabel(headerFrame, "YOUR REMINDERS", 10, THEME.goldDim)
    listLabel:SetPoint("LEFT", 34, 0)

    local hint = ns.CreateLabel(headerFrame, "click a row to edit", 10, THEME.textDim)
    hint:SetPoint("RIGHT", -8, 0)

    listScroll, listContent = ns.CreateScrollArea(frame.content)
    listScroll:SetPoint("TOPLEFT", 6, -136)
    listScroll:SetPoint("BOTTOMRIGHT", -6, 8)

    emptyState = ns.CreateLabel(listContent, "No reminders yet. Type a message above and hit Create.", 12, THEME.textDim)
    emptyState:SetPoint("TOP", listContent, "TOP", 0, -20)
    emptyState:SetWidth(600)
    emptyState:SetJustifyH("CENTER")
    emptyState:SetWordWrap(true)
    emptyState:Hide()

    mainFrame = frame
    return frame
end

function ns.RefreshMainWindow()
    if not mainFrame or not mainFrame:IsShown() then return end
    BuildRows()
end

function ns.ToggleMainWindow()
    local frame = ns.CreateMainWindow()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        ResetEditor()
        BuildRows()
    end
end

function ns.OpenMainWindow()
    local frame = ns.CreateMainWindow()
    frame:Show()
    ResetEditor()
    BuildRows()
end

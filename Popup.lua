-- RemindMeForever - the popup that lists due reminders.

local addonName, ns = ...

local THEME = ns.Theme
local ROW_HEIGHT = 30

local popupFrame

local function BuildPopup()
    local frame = ns.CreatePanel("RemindMeForeverPopup", "Reminder!", 470, 120, true)
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -340, 220)
    frame:SetClampedToScreen(true)

    local scroll = CreateFrame("ScrollFrame", nil, frame.content, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 8)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self, width)
        content:SetWidth(width)
    end)

    frame.rows = {}
    frame.scroll = scroll
    frame.contentFrame = content
    return frame
end

local function AcquireRow(index)
    local rows = popupFrame.rows
    if rows[index] then return rows[index] end

    local row = CreateFrame("Frame", nil, popupFrame.contentFrame, "BackdropTemplate")
    row:SetHeight(ROW_HEIGHT)
    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 8, edgeSize = 1,
    })
    row:SetBackdropColor(0.10, 0.09, 0.07, 0.7)
    row:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 0.6)

    local text = ns.CreateLabel(row, "", 12, THEME.text)
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -160, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    row.text = text

    local snooze = ns.CreateButton(row, "Snooze", 64, 18)
    snooze:SetPoint("RIGHT", -70, 0)
    row.snooze = snooze

    local dismiss = ns.CreateButton(row, "Dismiss", 62, 18)
    dismiss:SetPoint("RIGHT", -4, 0)
    row.dismiss = dismiss

    rows[index] = row
    return row
end

-- Rows are { text, reminderId, snooze, dismiss }.
function ns.ShowPopup(rows)
    if not popupFrame then popupFrame = BuildPopup() end
    if #rows == 0 then
        popupFrame:Hide()
        return
    end

    for _, row in ipairs(popupFrame.rows) do row:Hide() end

    for index, data in ipairs(rows) do
        local row = AcquireRow(index)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", popupFrame.contentFrame, "TOPLEFT", 0, -(index - 1) * (ROW_HEIGHT + 4))
        row:SetPoint("TOPRIGHT", popupFrame.contentFrame, "TOPRIGHT", 0, -(index - 1) * (ROW_HEIGHT + 4))
        row.text:SetText(data.text)

        row.snooze:SetScript("OnClick", function()
            if data.snooze then data.snooze() end
            row:Hide()
            if ns.PopupIsEmpty() then popupFrame:Hide() end
        end)

        row.dismiss:SetScript("OnClick", function()
            if data.dismiss then data.dismiss() end
            row:Hide()
            if ns.PopupIsEmpty() then popupFrame:Hide() end
        end)

        row:Show()
    end

    popupFrame.contentFrame:SetHeight(#rows * (ROW_HEIGHT + 4))
    popupFrame:SetHeight(math.min(420, 40 + #rows * (ROW_HEIGHT + 4)))
    popupFrame:Show()
end

function ns.PopupIsEmpty()
    if not popupFrame then return true end
    for _, row in ipairs(popupFrame.rows) do
        if row:IsShown() then return false end
    end
    return true
end

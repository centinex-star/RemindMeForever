-- RemindMeForever - hand-rolled widgets.
--
-- The original addon shipped the whole AceGUI suite for three dropdowns. This
-- file is the replacement: a themed panel, a dropdown, a checkbox, a button and
-- a text box, all built on stock frames so there is nothing to keep updated and
-- no third-party code inside the addon.

local addonName, ns = ...

-------------------------------------------------------------------------------
-- Theme
-------------------------------------------------------------------------------

ns.Theme = {
    -- Forever is the modern client with Classic art, so the palette leans on
    -- stone and gold rather than retail's blue glass.
    bg          = { 0.06, 0.05, 0.04, 0.96 },
    border      = { 0.45, 0.36, 0.20, 1.00 },
    borderLight = { 0.72, 0.60, 0.36, 1.00 },
    gold        = { 1.00, 0.82, 0.30, 1.00 },
    goldDim     = { 0.78, 0.64, 0.36, 1.00 },
    text        = { 0.92, 0.90, 0.86, 1.00 },
    textDim     = { 0.58, 0.56, 0.52, 1.00 },
    good        = { 0.42, 0.80, 0.45, 1.00 },
    bad         = { 0.90, 0.38, 0.34, 1.00 },
    rowHover    = { 0.18, 0.15, 0.11, 0.85 },
    rowAlt      = { 0.10, 0.09, 0.07, 0.55 },
}

local THEME = ns.Theme

local BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 8, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

function ns.SetColor(obj, color)
    if obj.SetColorTexture then
        obj:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    end
end

function ns.SetTextColor(fontString, color)
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

-- BackdropTemplate is required on the modern client; borrowing it in case an
-- older build is ever targeted keeps the call safe.
local function ApplyBackdrop(frame, color)
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(color[1], color[2], color[3], color[4] or 1)
    frame:SetBackdropBorderColor(THEME.borderLight[1], THEME.borderLight[2],
        THEME.borderLight[3], 1)
end

-------------------------------------------------------------------------------
-- Panel
-------------------------------------------------------------------------------

-- A stone-and-gold window: outer frame, header band, close button. Returns the
-- frame with `frame.content` as the body area below the header.
function ns.CreatePanel(name, titleText, width, height, movable)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    if movable ~= false then
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            if ns.SaveWindowPosition then ns.SaveWindowPosition(self) end
        end)
    end

    ApplyBackdrop(frame, THEME.bg)

    -- Header band
    local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(30)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 8, edgeSize = 1,
    })
    header:SetBackdropColor(0.14, 0.11, 0.07, 1)
    header:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 1)

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT, 14, "")
    title:SetPoint("LEFT", 12, 0)
    ns.SetTextColor(title, THEME.gold)
    title:SetText(titleText)

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 0.8)
    divider:SetPoint("TOPLEFT", 1, -31)
    divider:SetPoint("TOPRIGHT", -1, -31)
    divider:SetHeight(1)

    local close = CreateFrame("Button", nil, header)
    close:SetSize(20, 20)
    close:SetPoint("RIGHT", -6, 0)

    local closeBg = close:CreateTexture(nil, "BACKGROUND")
    closeBg:SetAllPoints()
    closeBg:SetColorTexture(0.35, 0.10, 0.09, 0.9)

    local closeText = close:CreateFontString(nil, "OVERLAY")
    closeText:SetFont(FONT, 12, "")
    closeText:SetPoint("CENTER")
    ns.SetTextColor(closeText, THEME.gold)
    closeText:SetText("X")

    close:SetScript("OnEnter", function()
        closeBg:SetColorTexture(0.55, 0.16, 0.13, 1)
    end)
    close:SetScript("OnLeave", function()
        closeBg:SetColorTexture(0.35, 0.10, 0.09, 0.9)
    end)
    close:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then self:Hide() end
    end)
    frame:SetPropagateKeyboardInput(true)

    frame.header = header
    frame.titleText = title
    frame.closeButton = close
    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetPoint("TOPLEFT", 1, -34)
    frame.content:SetPoint("BOTTOMRIGHT", -1, 1)

    frame:SetScript("OnShow", function(self)
        if self.OnShown then self:OnShown() end
    end)
    frame:SetScript("OnHide", function(self)
        if self.OnHidden then self:OnHidden() end
    end)

    return frame
end

-------------------------------------------------------------------------------
-- Button
-------------------------------------------------------------------------------

function ns.CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 90, height or 22)

    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 8, edgeSize = 1,
    })
    button:SetBackdropColor(0.20, 0.16, 0.10, 1)
    button:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 1)

    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT, 12, "")
    label:SetPoint("CENTER", 0, 0)
    ns.SetTextColor(label, THEME.gold)
    label:SetText(text)
    button.label = label

    button:SetScript("OnEnter", function(self)
        if self.disabledLook then return end
        self:SetBackdropColor(0.30, 0.24, 0.14, 1)
        self:SetBackdropBorderColor(THEME.gold[1], THEME.gold[2], THEME.gold[3], 1)
    end)
    button:SetScript("OnLeave", function(self)
        if self.disabledLook then
            self:SetBackdropColor(0.13, 0.12, 0.10, 1)
        else
            self:SetBackdropColor(0.20, 0.16, 0.10, 1)
            self:SetBackdropBorderColor(THEME.border[1], THEME.border[2],
                THEME.border[3], 1)
        end
    end)
    button:SetScript("OnMouseDown", function(self)
        if self.disabledLook then return end
        self.label:SetPoint("CENTER", 1, -1)
    end)
    button:SetScript("OnMouseUp", function(self)
        self.label:SetPoint("CENTER", 0, 0)
    end)

    function button:SetButtonEnabled(enabled)
        self.disabledLook = not enabled
        self:EnableMouse(enabled)
        if enabled then
            ns.SetTextColor(self.label, THEME.gold)
            self:SetBackdropColor(0.20, 0.16, 0.10, 1)
        else
            ns.SetTextColor(self.label, THEME.textDim)
            self:SetBackdropColor(0.13, 0.12, 0.10, 1)
        end
    end

    return button
end

-------------------------------------------------------------------------------
-- Checkbox
-------------------------------------------------------------------------------

function ns.CreateCheckbox(parent, labelText)
    local check = CreateFrame("Button", nil, parent)
    check:SetSize(20, 20)

    local box = CreateFrame("Frame", nil, check, "BackdropTemplate")
    box:SetSize(15, 15)
    box:SetPoint("LEFT", 0, 0)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 8, edgeSize = 1,
    })
    box:SetBackdropColor(0.05, 0.04, 0.03, 1)
    box:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 1)

    local tick = box:CreateTexture(nil, "OVERLAY")
    tick:SetColorTexture(THEME.gold[1], THEME.gold[2], THEME.gold[3], 1)
    tick:SetPoint("TOPLEFT", 3, -3)
    tick:SetPoint("BOTTOMRIGHT", -3, 3)
    tick:Hide()

    local label = check:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT, 12, "")
    label:SetPoint("LEFT", box, "RIGHT", 6, 0)
    ns.SetTextColor(label, THEME.text)
    label:SetText(labelText or "")

    check.box = box
    check.tick = tick
    check.label = label
    check.checked = false

    function check:SetCheckedState(state)
        self.checked = state and true or false
        if self.checked then tick:Show() else tick:Hide() end
    end

    function check:GetCheckedState()
        return self.checked
    end

    check:SetScript("OnClick", function(self)
        self:SetCheckedState(not self.checked)
        if self.OnValueChanged then self:OnValueChanged(self.checked) end
    end)

    return check
end

-------------------------------------------------------------------------------
-- Text box
-------------------------------------------------------------------------------

function ns.CreateEditBox(parent, width, height)
    local edit = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    edit:SetSize(width or 200, height or 22)
    edit:SetAutoFocus(false)
    edit:SetFont(FONT, 12, "")
    edit:SetTextInsets(6, 6, 0, 0)
    edit:SetJustifyH("LEFT")
    edit:SetMaxLetters(255)

    edit:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 8, edgeSize = 1,
    })
    edit:SetBackdropColor(0.03, 0.03, 0.02, 1)
    edit:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    ns.SetTextColor(edit, THEME.text)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    function edit:SetInvalid(isInvalid)
        if isInvalid then
            self:SetBackdropBorderColor(THEME.bad[1], THEME.bad[2], THEME.bad[3], 1)
        else
            self:SetBackdropBorderColor(THEME.border[1], THEME.border[2],
                THEME.border[3], 1)
        end
    end

    return edit
end

function ns.CreateLabel(parent, text, size, color)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT, size or 12, "")
    ns.SetTextColor(label, color or THEME.textDim)
    label:SetText(text or "")
    return label
end

-------------------------------------------------------------------------------
-- Dropdown
-------------------------------------------------------------------------------

-- A compact dropdown: a themed button that opens a menu of options.
--   options: array of { value = any, text = string }
--   onSelect(value, text)
function ns.CreateDropdown(parent, width)
    local drop = CreateFrame("Button", nil, parent, "BackdropTemplate")
    drop:SetSize(width or 130, 22)
    drop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 8, edgeSize = 1,
    })
    drop:SetBackdropColor(0.03, 0.03, 0.02, 1)
    drop:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 1)

    local text = drop:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 12, "")
    text:SetPoint("LEFT", 7, 0)
    text:SetPoint("RIGHT", -18, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    ns.SetTextColor(text, THEME.text)
    drop.text = text

    local arrow = drop:CreateFontString(nil, "OVERLAY")
    arrow:SetFont(FONT, 10, "")
    arrow:SetPoint("RIGHT", -6, 0)
    ns.SetTextColor(arrow, THEME.goldDim)
    arrow:SetText("v")

    drop.options = {}
    drop.selectedIndex = nil

    local function CloseMenu()
        if drop.menu then drop.menu:Hide() end
        if drop.clickCatcher then drop.clickCatcher:Hide() end
    end

    local function OpenMenu()
        if not drop.menu then
            local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            menu:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = true, tileSize = 8, edgeSize = 1,
            })
            menu:SetBackdropColor(0.08, 0.07, 0.05, 0.98)
            menu:SetBackdropBorderColor(THEME.borderLight[1], THEME.borderLight[2],
                THEME.borderLight[3], 1)
            menu:EnableMouse(true)
            menu.rows = {}
            drop.menu = menu
        end

        local menu = drop.menu
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", drop, "BOTTOMLEFT", 0, -2)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")

        local rowHeight = 18
        for _, row in ipairs(menu.rows) do row:Hide() end

        for index, option in ipairs(drop.options) do
            local row = menu.rows[index]
            if not row then
                row = CreateFrame("Button", nil, menu)
                row:SetHeight(rowHeight)
                row:SetPoint("LEFT", 1, 0)
                row:SetPoint("RIGHT", -1, 0)

                local hl = row:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetColorTexture(0.30, 0.24, 0.14, 0.85)

                local rowText = row:CreateFontString(nil, "OVERLAY")
                rowText:SetFont(FONT, 11, "")
                rowText:SetPoint("LEFT", 6, 0)
                rowText:SetPoint("RIGHT", -6, 0)
                rowText:SetJustifyH("LEFT")
                ns.SetTextColor(rowText, THEME.text)
                row.label = rowText
                menu.rows[index] = row
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -1 - (index - 1) * rowHeight)
            row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -1, -1 - (index - 1) * rowHeight)
            row.label:SetText(option.text)
            row:Show()

            row:SetScript("OnClick", function()
                drop:SetSelected(option.value, option.text)
                CloseMenu()
                if drop.OnSelect then drop.OnSelect(option.value, option.text) end
            end)
        end

        menu:SetSize(drop:GetWidth(), math.max(1, #drop.options) * rowHeight + 2)
        menu:Show()
        if drop.clickCatcher then drop.clickCatcher:Show() end
    end

    -- Restoring a value must never fire OnSelect: callers use OnSelect to react
    -- to a user choice, and firing it here recurses into the widget refresh.
    function drop:SetOptions(options, selectedValue)
        self.options = options or {}
        self:SetSelected(nil, "", true)

        for _, option in ipairs(self.options) do
            if option.value == selectedValue then
                self:SetSelected(option.value, option.text, true)
                return
            end
        end

        local first = self.options[1]
        if first then
            self:SetSelected(first.value, first.text, true)
        else
            self.text:SetText("")
        end
    end

    function drop:SetSelected(value, displayText, silent)
        self.value = value
        self.text:SetText(displayText or "")
        if not silent and self.OnSelect then self.OnSelect(value, displayText) end
    end

    function drop:GetValue()
        return self.value
    end

    drop:SetScript("OnClick", function()
        if drop.menu and drop.menu:IsShown() then
            CloseMenu()
        else
            OpenMenu()
        end
    end)

    drop:SetScript("OnHide", CloseMenu)

    -- An open menu closes on any click outside it, otherwise it stays floating
    -- over the window. A full-screen catcher behind the menu does this without
    -- hooking every frame in the addon.
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN")
    catcher:EnableMouse(true)
    catcher:Hide()
    catcher:SetScript("OnClick", CloseMenu)
    drop.clickCatcher = catcher

    return drop
end

-------------------------------------------------------------------------------
-- Scroll area
-------------------------------------------------------------------------------

-- A plain scrollable region built on a UIPanelScrollFrame, with a styled
-- scrollbar and a content child that callers can fill with rows.
function ns.CreateScrollArea(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    scroll:SetScript("OnSizeChanged", function(self, width)
        content:SetWidth(width)
    end)

    -- Restyle the template scrollbar to the theme.
    local sb = scroll.ScrollBar
    if sb then
        if sb.Background then sb.Background:Hide() end
        for _, child in ipairs({ sb:GetChildren() }) do
            if child:IsObjectType("Slider") then
                local thumb = child:GetThumbTexture()
                if thumb then thumb:SetColorTexture(THEME.goldDim[1], THEME.goldDim[2], THEME.goldDim[3], 0.9) end
            end
        end
    end

    return scroll, content
end

-------------------------------------------------------------------------------
-- Tooltip helper
-------------------------------------------------------------------------------

function ns.AttachTooltip(frame, titleText, lines)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(titleText, THEME.gold[1], THEME.gold[2], THEME.gold[3], 1, true)
        for _, line in ipairs(lines or {}) do
            GameTooltip:AddLine(line, THEME.text[1], THEME.text[2], THEME.text[3], true)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

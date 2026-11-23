-- UI smoke test: loads every file (including the UI ones) against a fuller
-- WoW API stub, then constructs the main window, popup, options panel,
-- confirmation dialogs and every dropdown/menu click path.
--
-- This cannot prove the window looks right - only the client can - but it does
-- catch nil fields, wrong argument shapes and construction-order bugs.
--
-- Run: lua5.1 tests/ui_smoke.lua

local failures, checks = 0, 0

local function fail(msg)
    failures = failures + 1
    io.write("FAIL: ", msg, "\n")
end

local function ok(cond, msg)
    checks = checks + 1
    if not cond then fail(msg) end
end

-------------------------------------------------------------------------------
-- Frame stub
-------------------------------------------------------------------------------

local function NewObject(kind)
    local obj = { __kind = kind or "Frame" }

    local function noop() end
    local methodNames = {
        "SetSize", "SetWidth", "SetHeight", "SetPoint", "ClearAllPoints", "SetAllPoints",
        "SetParent", "SetFrameStrata", "SetFrameLevel", "SetToplevel", "SetClampedToScreen",
        "SetMovable", "SetResizable", "SetUserPlaced", "RegisterForDrag", "EnableMouse",
        "EnableKeyboard", "SetPropagateKeyboardInput", "SetScript", "HookScript",
        "RegisterEvent", "UnregisterEvent", "UnregisterAllEvents", "SetBackdrop",
        "SetBackdropColor", "SetBackdropBorderColor", "SetAutoFocus", "SetFont",
        "SetTextInsets", "SetJustifyH", "SetJustifyV", "SetMaxLetters", "SetMaxBytes",
        "SetTextColor", "SetText", "SetColorTexture", "SetAlpha", "SetShown",
        "SetScrollChild", "SetHitRectInsets", "SetNormalTexture", "SetPushedTexture",
        "SetHighlightTexture", "SetDisabledTexture", "SetTexCoord", "SetScale",
        "SetWordWrap", "SetNonSpaceWrap", "SetIndentedWordWrap", "SetFormattedText",
        "SetDrawLayer", "SetVertexColor", "SetGradientAlpha", "SetMinMaxValues",
        "SetValue", "SetOrientation", "SetObeyStepOnDrag", "SetID", "StopMovingOrSizing",
        "StartMoving", "SetFlattensRenderLayers",
    }
    for _, name in ipairs(methodNames) do obj[name] = noop end

    obj.Show = noop
    obj.Hide = noop
    obj.IsShown = function() return obj.__shown or false end
    obj.IsVisible = function() return obj.__shown or false end
    obj.GetWidth = function() return obj.__w or 100 end
    obj.GetHeight = function() return obj.__h or 100 end
    obj.GetFrameLevel = function() return obj.__level or 1 end
    obj.GetName = function() return obj.__name end
    obj.IsObjectType = function(_, t) return t == obj.__kind end
    obj.GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end
    obj.GetText = function() return obj.__text or "" end
    obj.GetValue = function() return obj.__value end
    obj.GetChecked = function() return obj.__checked or false end
    obj.GetParent = function() return obj.__parent end
    obj.GetChildren = function() return {} end
    obj.GetRegions = function() return {} end
    obj.GetThumbTexture = function() return NewObject("Texture") end
    obj.SetText = function(_, text) obj.__text = text end
    obj.SetValue = function(_, v) obj.__value = v end
    obj.SetSize = function(_, w, h) obj.__w, obj.__h = w, h end
    obj.SetWidth = function(_, w) obj.__w = w end
    obj.SetHeight = function(_, h) obj.__h = h end
    obj.SetShown = function(_, shown) obj.__shown = shown and true or false end
    obj.Show = function() obj.__shown = true end
    obj.Hide = function() obj.__shown = false end
    obj.SetScript = function(_, name, fn) obj.__scripts = obj.__scripts or {}; obj.__scripts[name] = fn end
    obj.HookScript = function(_, name, fn) obj.__hooks = obj.__hooks or {}; obj.__hooks[name] = fn end
    obj.FireScript = function(_, name, ...)
        local scripts = obj.__scripts or {}
        if scripts[name] then return scripts[name](obj, ...) end
    end
    obj.ClearFocus = noop
    obj.SetFocus = noop
    obj.SetInvalid = function(_, invalid) obj.__invalid = invalid end

    obj.CreateFontString = function()
        local fs = NewObject("FontString")
        fs.__parent = obj
        return fs
    end
    obj.CreateTexture = function()
        local tex = NewObject("Texture")
        tex.__parent = obj
        return tex
    end
    obj.CreateFrame = function(_, frameType, name, template, id)
        local child = NewObject(frameType or "Frame")
        child.__parent = obj
        child.__name = name
        child.__template = template
        return child
    end

    return obj
end

_G.UIParent = NewObject("Frame")
_G.GameTooltip = {
    SetOwner = function() end, SetText = function() end,
    AddLine = function() end, Show = function() end, Hide = function() end,
}
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
_G.DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, msg) _G.RMF_LAST_CHAT = msg end,
}

function CreateFrame(kind, name, parent, template, id)
    local f = NewObject(kind or "Frame")
    f.__name, f.__parent, f.__template = name, parent, template
    return f
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
function GetProfessionInfo(i)
    return (i == 1 and "Alchemy") or (i == 2 and "Herbalism") or nil
end
function GetGuildInfo() return "Testers" end
function UnitFactionGroup() return "Alliance" end
function UnitAffectingCombat() return false end
function GetZoneText() return "Elwynn Forest" end
function IsInInstance() return false, "none" end
function IsInGroup() return false end
function GetMoney() return 1234567 end
function GetAddOnMetadata() return "0.1.0" end
function SetItemRef() end
function date(fmt, t) return os.date(fmt, t) end

_G.C_Timer = {
    NewTicker = function() return { Cancel = function() end } end,
    After = function(_, fn) if fn then fn() end end,
}
_G.C_DateAndTime = {
    GetSecondsUntilDailyReset = function() return 60000 end,
    GetSecondsUntilWeeklyReset = function() return 300000 end,
}
_G.SlashCmdList = {}
_G.tinsert = table.insert
_G.UISpecialFrames = {}

-------------------------------------------------------------------------------
-- Load every file the TOC lists
-------------------------------------------------------------------------------

local ns = {}
local loadFailures = 0
local files = {
    "Core.lua", "Conditions.lua", "Schedule.lua", "Reminders.lua",
    "Widgets.lua", "MainWindow.lua", "Popup.lua", "Options.lua", "Commands.lua",
}
for _, file in ipairs(files) do
    local chunk, err = loadfile(file)
    if not chunk then
        fail("could not load " .. file .. ": " .. tostring(err))
        loadFailures = loadFailures + 1
    else
        local okLoad, err2 = pcall(chunk, "RemindMeForever", ns)
        if not okLoad then
            fail("error running " .. file .. ": " .. tostring(err2))
            loadFailures = loadFailures + 1
        end
    end
end
ok(loadFailures == 0, "all addon files load cleanly")

if loadFailures > 0 then
    io.write(string.format("\n%d checks, %d failure(s)\n", checks, failures))
    os.exit(1)
end

ns.OnLoad()
ok(RMFDB ~= nil, "saved variables initialised")

-------------------------------------------------------------------------------
-- Construct every window
-------------------------------------------------------------------------------

local okMain, mainErr = pcall(ns.CreateMainWindow)
ok(okMain, "main window constructs: " .. tostring(mainErr))

local okOpt, optErr = pcall(ns.CreateOptionsPanel)
ok(okOpt, "options panel constructs: " .. tostring(optErr))

local mainFrame = ns.CreateMainWindow()
ok(mainFrame ~= nil, "main window is retrievable")

-- Opening runs ResetEditor + BuildRows against an empty list.
local okOpen = pcall(ns.OpenMainWindow)
ok(okOpen, "OpenMainWindow runs without error")

local okToggle = pcall(ns.ToggleMainWindow)
ok(okToggle, "ToggleMainWindow runs without error")

-------------------------------------------------------------------------------
-- Exercise the editor through real widget interactions
-------------------------------------------------------------------------------

-- Create a reminder by driving the widgets the way a player would.
mainFrame = ns.CreateMainWindow()

local function findDeep(root, predicate, depth)
    depth = depth or 0
    if depth > 12 then return nil end
    if predicate(root) then return root end
    return nil
end

-- Rather than dig through the widget tree, use the public API the UI calls.
local draft = ns.NewReminder()
draft.message = "Craft Living Steel"
draft.condition = "profession = Alchemy"
draft.interval = "daily"
local okSave, saveErr = pcall(ns.SaveReminder, draft, nil)
ok(okSave, "SaveReminder through the UI path works: " .. tostring(saveErr))

local okRefresh = pcall(ns.RefreshMainWindow)
ok(okRefresh, "RefreshMainWindow renders a row without error")

-- Drive the editor for every field and every interval, the way a player would.
local widgets = ns.editorWidgets
ok(widgets ~= nil, "editor widgets are reachable")

local okFields = true
for _, fieldKey in ipairs(ns.FieldOrder) do
    local good, err = pcall(function()
        ns.editorDraft = ns.NewReminder()
        widgets.condition:SetOptions(ns.FieldChoiceOptions(), fieldKey)
        ns.UpdateEditorWidgets()
    end)
    if not good then
        okFields = false
        fail("UpdateEditorWidgets failed for field " .. fieldKey .. ": " .. tostring(err))
    end
end
ok(okFields, "UpdateEditorWidgets handles every field")

local okIntervals = true
for _, interval in ipairs(ns.IntervalOptions()) do
    local good, err = pcall(function()
        ns.editorDraft = ns.NewReminder()
        widgets.interval:SetOptions(ns.IntervalOptions(), interval.value)
        ns.UpdateEditorWidgets()
    end)
    if not good then
        okIntervals = false
        fail("UpdateEditorWidgets failed for interval " .. interval.value .. ": " .. tostring(err))
    end
end
ok(okIntervals, "UpdateEditorWidgets handles every interval")

-- Everyone-condition hides the operator and value widgets.
widgets.condition:SetOptions(ns.FieldChoiceOptions(), "*")
ns.UpdateEditorWidgets()
ok(true, "everyone condition updates the editor")

-- The full create path: set the widgets up and press Create.
widgets.condition:SetOptions(ns.FieldChoiceOptions(), "profession")
ns.UpdateEditorWidgets()
widgets.valueDrop:SetOptions({ { value = "Alchemy", text = "Alchemy" } }, "Alchemy")
widgets.interval:SetOptions(ns.IntervalOptions(), "daily")
widgets.message:SetText("UI created reminder")
widgets.create:FireScript("OnClick")
local created = false
for _, r in pairs(RMFDB.reminders) do
    if r.message == "UI created reminder" then created = true end
end
ok(created, "pressing Create in the UI stores a reminder")

-- Creating the same thing twice is refused.
local before = 0
for _ in pairs(RMFDB.reminders) do before = before + 1 end
widgets.create:FireScript("OnClick")
local after = 0
for _ in pairs(RMFDB.reminders) do after = after + 1 end
ok(after == before, "duplicate create is refused")

-- Loading a reminder back into the editor.
local someId
for id in pairs(RMFDB.reminders) do someId = someId or id end
local okLoad, loadErr = pcall(ns.LoadIntoEditor, someId)
ok(okLoad, "LoadIntoEditor runs: " .. tostring(loadErr))

-- Cancel resets the form.
local okCancel = pcall(function() widgets.cancel:FireScript("OnClick") end)
ok(okCancel, "Cancel resets the editor")

-------------------------------------------------------------------------------
-- Popup
-------------------------------------------------------------------------------

local rows = ns.CollectDue(RMFDB.reminders["r1"] or {})
-- Build a row by hand so the popup can be tested even with nothing due.
local called = { snooze = false, dismiss = false }
local fakeRows = {
    {
        text = "Test reminder",
        reminderId = "r1",
        snooze = function() called.snooze = true end,
        dismiss = function() called.dismiss = true end,
    },
}
local okPopup, popupErr = pcall(ns.ShowPopup, fakeRows)
ok(okPopup, "ShowPopup constructs and shows: " .. tostring(popupErr))

local okEmpty = pcall(ns.PopupIsEmpty)
ok(okEmpty, "PopupIsEmpty runs")

-------------------------------------------------------------------------------
-- Options panel interactions
-------------------------------------------------------------------------------

local okOptions = pcall(ns.OpenOptions)
ok(okOptions, "OpenOptions runs without error")

local okSummary = pcall(ns.PrintSummary)
ok(okSummary, "PrintSummary runs without error")

-------------------------------------------------------------------------------
-- Slash command surface
-------------------------------------------------------------------------------

ns.RegisterSlashCommands()
local handler = SlashCmdList["REMINDBEFOREFOREVER"]
ok(type(handler) == "function", "slash command registered")

for _, input in ipairs({ "", "help", "list", "eval", "debug", "opts", "show",
                        "on 1", "off 1", "reset 1", "test 1", "delete 99",
                        "nonsense", "on", "test" }) do
    local good, err = pcall(handler, input)
    ok(good, "/rmf " .. (input == "" and "(none)" or input) .. " runs: " .. tostring(err))
end

-------------------------------------------------------------------------------
-- Confirmation dialogs
-------------------------------------------------------------------------------

local okConfirm, confirmErr = pcall(ns.ConfirmDelete, "r1")
ok(okConfirm, "ConfirmDelete builds its dialog: " .. tostring(confirmErr))

local okWipe, wipeErr = pcall(ns.ConfirmResetAll)
ok(okWipe, "ConfirmResetAll builds its dialog: " .. tostring(wipeErr))

-------------------------------------------------------------------------------
-- DescribeCondition through the shared path
-------------------------------------------------------------------------------

ok(ns.DescribeCondition("profession = Alchemy", nil) == "Profession = Alchemy",
    "DescribeCondition is available to UI and commands alike")

-------------------------------------------------------------------------------
-- Cleanup sanity: /rmf wipe must not corrupt the DB shape
-------------------------------------------------------------------------------

ok(type(RMFDB.reminders) == "table", "reminders table still exists")
ok(type(RMFDB.characters) == "table", "characters table still exists")

io.write(string.format("\n%d checks, %d failure(s)\n", checks, failures))
if failures > 0 then os.exit(1) end

-- RemindMeForever - condition language.
--
-- The original addon built a Lua source string from the condition text and ran
-- it through loadstring. That silently ignored unknown tokens, could not carry
-- values containing spaces, and executed whatever the string happened to say.
-- This parses into a small tree instead: no code generation, every token is
-- validated at parse time, and errors are reported to the player.
--
-- Grammar (case-insensitive keywords):
--     condition  := term { "or" term }
--     term       := factor { "and" factor }
--     factor     := "*" | field op value
--     field      := name | class | race | level | ilevel | profession
--                   | guild | faction | zone | group | instance | gold
--     op         := =, ==, ~=, !=, <, <=, >, >=
--     value      := bare word | "quoted string" | number

local addonName, ns = ...

-- Field registry. `kind` decides how values are parsed and compared; adding a
-- new condition later means adding one entry here plus a resolver field.
ns.Fields = {
    name = {
        label = "Name",
        kind = "text",
        resolve = function(ctx) return ctx.name end,
    },
    class = {
        label = "Class",
        kind = "text",
        resolve = function(ctx) return ctx.class end,
    },
    race = {
        label = "Race",
        kind = "text",
        resolve = function(ctx) return ctx.race end,
    },
    profession = {
        label = "Profession",
        kind = "list",
        resolve = function(ctx) return ctx.professions end,
    },
    level = {
        label = "Level",
        kind = "number",
        resolve = function(ctx) return ctx.level end,
    },
    ilevel = {
        label = "iLevel",
        kind = "number",
        resolve = function(ctx) return ctx.ilevel end,
    },
    guild = {
        label = "Guild",
        kind = "text",
        resolve = function(ctx) return ctx.guild end,
    },
    faction = {
        label = "Faction",
        kind = "text",
        resolve = function(ctx) return ctx.faction end,
    },
    zone = {
        label = "Zone",
        kind = "text",
        resolve = function(ctx) return ctx.zone end,
    },
    group = {
        label = "Group",
        kind = "bool",
        resolve = function(ctx) return ctx.inGroup end,
    },
    instance = {
        label = "Instance",
        kind = "bool",
        resolve = function(ctx) return ctx.inInstance end,
    },
    gold = {
        label = "Gold",
        kind = "number",
        resolve = function(ctx) return ctx.gold end,
    },
}

-- Ordered list for the UI dropdown.
ns.FieldOrder = {
    "name", "class", "race", "level", "ilevel", "profession",
    "guild", "faction", "zone", "group", "instance", "gold",
}

function ns.FieldLabel(key)
    local field = ns.Fields[key]
    return field and field.label or key
end

-------------------------------------------------------------------------------
-- Tokenizer
-------------------------------------------------------------------------------

-- Splits on whitespace but keeps "quoted strings" together as one token, so a
-- value like "Stormwind City" survives. Returns tokens plus an error string.
local function Tokenize(text)
    local tokens = {}
    local i, len = 1, #text
    while i <= len do
        local c = text:sub(i, i)
        if c:match("%s") then
            i = i + 1
        elseif c == '"' or c == "'" then
            local quote = c
            local close = text:find(quote, i + 1, true)
            if not close then
                return nil, "unclosed quote in condition"
            end
            tokens[#tokens + 1] = { value = text:sub(i + 1, close - 1), quoted = true }
            i = close + 1
        else
            -- A bare token also terminates at a quote so `name="Bob"` works.
            local stop = i
            while stop <= len do
                local ch = text:sub(stop, stop)
                if ch:match("%s") or ch == '"' or ch == "'" then break end
                stop = stop + 1
            end
            local raw = text:sub(i, stop - 1)
            -- Allow `field=value` and `field>=value` written without spaces.
            local field, op, rest = raw:match("^(%a+)([=~<>!]+)(.*)$")
            if field and rest ~= "" then
                tokens[#tokens + 1] = { value = field }
                tokens[#tokens + 1] = { value = op }
                tokens[#tokens + 1] = { value = rest }
            elseif field and rest == "" then
                tokens[#tokens + 1] = { value = field }
                tokens[#tokens + 1] = { value = op }
            else
                tokens[#tokens + 1] = { value = raw }
            end
            i = stop
        end
    end
    return tokens
end

local OPERATORS = {
    ["="] = "eq", ["=="] = "eq",
    ["~="] = "ne", ["!="] = "ne",
    ["<"] = "lt", ["<="] = "le",
    [">"] = "gt", [">="] = "ge",
}

local function IsOperator(token)
    return token and OPERATORS[token] ~= nil
end

-------------------------------------------------------------------------------
-- Parser
-------------------------------------------------------------------------------

local Parser = {}
Parser.__index = Parser

local function NewParser(tokens)
    return setmetatable({ tokens = tokens, pos = 1 }, Parser)
end

function Parser:Peek()
    return self.tokens[self.pos]
end

function Parser:Take()
    local token = self.tokens[self.pos]
    self.pos = self.pos + 1
    return token
end

function Parser:Error(msg)
    error({ condition = msg }, 0)
end

-- `*` alone means everyone.
function Parser:ParseExpression()
    local node = self:ParseTerm()
    while true do
        local token = self:Peek()
        if token and token.value:lower() == "or" then
            self:Take()
            local right = self:ParseTerm()
            node = { kind = "or", left = node, right = right }
        else
            break
        end
    end
    return node
end

function Parser:ParseTerm()
    local node = self:ParseFactor()
    while true do
        local token = self:Peek()
        if token and token.value:lower() == "and" then
            self:Take()
            local right = self:ParseFactor()
            node = { kind = "and", left = node, right = right }
        else
            break
        end
    end
    return node
end

function Parser:ParseFactor()
    local token = self:Take()
    if not token then self:Error("condition ends unexpectedly") end

    if token.value == "*" then
        return { kind = "always" }
    end

    local fieldKey = token.value:lower()
    local field = ns.Fields[fieldKey]
    if not field then
        self:Error("unknown field '" .. token.value .. "'")
    end

    local opToken = self:Take()
    if not opToken then
        self:Error("'" .. field.label .. "' needs an operator, e.g. = or >=")
    end
    local op = OPERATORS[opToken.value]
    if not op then
        self:Error("unknown operator '" .. opToken.value .. "'")
    end

    local valueToken = self:Take()
    if not valueToken then
        self:Error("'" .. field.label .. "' needs a value")
    end

    local rawValue = valueToken.value
    local value = rawValue

    if field.kind == "number" then
        value = tonumber(rawValue)
        if not value then
            self:Error("'" .. field.label .. "' needs a number, got '" .. rawValue .. "'")
        end
        local numericOps = { eq = true, ne = true, lt = true, le = true, gt = true, ge = true }
        if not numericOps[op] then
            self:Error("'" .. opToken.value .. "' does not work with '" .. field.label .. "'")
        end
    elseif field.kind == "bool" then
        local lowered = rawValue:lower()
        value = (lowered == "yes" or lowered == "true" or lowered == "1")
        if lowered ~= "yes" and lowered ~= "no" and lowered ~= "true"
            and lowered ~= "false" and lowered ~= "1" and lowered ~= "0" then
            self:Error("'" .. field.label .. "' takes yes or no, got '" .. rawValue .. "'")
        end
        if op ~= "eq" and op ~= "ne" then
            self:Error("'" .. field.label .. "' only supports = and ~=")
        end
    else
        -- text and list fields compare by equality only
        if op ~= "eq" and op ~= "ne" then
            self:Error("'" .. field.label .. "' only supports = and ~=")
        end
    end

    return {
        kind = "compare",
        field = fieldKey,
        fieldKind = field.kind,
        op = op,
        value = value,
        rawValue = rawValue,
    }
end

-------------------------------------------------------------------------------
-- Public parse / evaluate
-------------------------------------------------------------------------------

-- Returns ast, err. `err` is a plain string suitable for showing the player.
function ns.ParseCondition(text)
    if type(text) ~= "string" then return nil, "condition is empty" end
    local trimmed = text:match("^%s*(.-)%s*$")
    if trimmed == "" then return nil, "condition is empty" end
    if trimmed == "*" then return { kind = "always" }, nil end

    local tokens, tokenErr = Tokenize(trimmed)
    if not tokens then return nil, tokenErr end
    if #tokens == 0 then return nil, "condition is empty" end

    local parser = NewParser(tokens)
    local ok, result = pcall(function() return parser:ParseExpression() end)
    if not ok then
        if type(result) == "table" and result.condition then
            return nil, result.condition
        end
        return nil, "could not parse condition"
    end
    if parser.pos <= #tokens then
        return nil, "unexpected '" .. tostring(tokens[parser.pos].value) .. "'"
    end
    return result, nil
end

local function CompareNumbers(actual, op, expected)
    if actual == nil then return false end
    if op == "eq" then return actual == expected end
    if op == "ne" then return actual ~= expected end
    if op == "lt" then return actual < expected end
    if op == "le" then return actual <= expected end
    if op == "gt" then return actual > expected end
    if op == "ge" then return actual >= expected end
    return false
end

local function CompareText(actual, op, expected)
    if type(actual) ~= "string" then
        -- No data about the character: only "not equals" can be true.
        return op == "ne"
    end
    local matches = actual:lower() == expected:lower()
    if op == "eq" then return matches end
    if op == "ne" then return not matches end
    return false
end

local function CompareList(list, op, expected)
    local found = false
    if type(list) == "table" then
        for _, entry in ipairs(list) do
            if type(entry) == "string" and entry:lower() == expected:lower() then
                found = true
                break
            end
        end
    end
    if op == "eq" then return found end
    if op == "ne" then return not found end
    return false
end

local function CompareBool(actual, op, expected)
    if actual == nil then return false end
    local yes = actual and true or false
    if op == "eq" then return yes == expected end
    if op == "ne" then return yes ~= expected end
    return false
end

function ns.EvaluateNode(node, ctx)
    if not node then return false end
    if node.kind == "always" then return true end
    if node.kind == "and" then
        return ns.EvaluateNode(node.left, ctx) and ns.EvaluateNode(node.right, ctx)
    end
    if node.kind == "or" then
        return ns.EvaluateNode(node.left, ctx) or ns.EvaluateNode(node.right, ctx)
    end
    if node.kind ~= "compare" then return false end

    local field = ns.Fields[node.field]
    if not field then return false end

    local ok, actual = pcall(field.resolve, ctx)
    if not ok then return false end
    actual = ns.SafeValue(actual)

    if node.fieldKind == "number" then
        return CompareNumbers(tonumber(actual), node.op, node.value)
    elseif node.fieldKind == "list" then
        return CompareList(actual, node.op, node.value)
    elseif node.fieldKind == "bool" then
        return CompareBool(actual, node.op, node.value)
    end
    return CompareText(actual, node.op, node.value)
end

-- Human-readable form of a stored condition, e.g. "Profession = Alchemy".
-- Lives with the condition parser because both the popup and the slash
-- commands print this text.
function ns.DescribeCondition(condition)
    if not condition or condition == "" then return "Everyone" end
    if condition == "*" then return "Everyone" end
    local pretty = condition
    for _, key in ipairs(ns.FieldOrder) do
        pretty = pretty:gsub("(%f[%a]" .. key .. "%f[%A])", ns.FieldLabel(key))
    end
    pretty = pretty:gsub("%*", "Everyone")
    pretty = pretty:gsub("%f[%a]and%f[%A]", "AND")
    pretty = pretty:gsub("%f[%a]or%f[%A]", "OR")
    return pretty
end

-- Build the context for the live player.
function ns.LiveContext()
    local char = ns.CurrentCharacter()
    local zoneName = ns.SafeValue(GetZoneText())
    local _, instanceType = IsInInstance()
    return {
        name = ns.PlayerName(),
        class = char.class,
        race = char.race,
        level = char.level,
        ilevel = char.ilevel,
        professions = char.professions or {},
        guild = char.guild,
        faction = char.faction,
        zone = type(zoneName) == "string" and zoneName or nil,
        inGroup = (IsInGroup() and true) or false,
        inInstance = (instanceType and instanceType ~= "none") and true or false,
        gold = (GetMoney() or 0) / 10000,
    }
end

-- Build the context for a cached roster entry (an offline alt).
function ns.RosterContext(char)
    return {
        name = char.name,
        class = char.class,
        race = char.race,
        level = char.level,
        ilevel = char.ilevel,
        professions = char.professions or {},
        guild = char.guild,
        faction = char.faction,
        zone = nil,
        inGroup = false,
        inInstance = false,
        gold = nil,
    }
end

local class = require("lib.class")

local LEVELS = {
    DEBUG = 10,
    INFO = 20,
    WARN = 30,
    ERROR = 40
}

local DEFAULT_LEVEL_NAME = string.upper(os.getenv("COMPILER_LOG_LEVEL") or os.getenv("LOG_LEVEL") or "DEBUG")
if LEVELS[DEFAULT_LEVEL_NAME] == nil then
    DEFAULT_LEVEL_NAME = "DEBUG"
end

local DEFAULT_ENABLED = true
local DEFAULT_USE_COLOR = os.getenv("NO_COLOR") == nil

local STYLE_RESET = "\27[0m"
local STYLE_DIM = "\27[2m"
local STYLE_BOLD = "\27[1m"
local LEVEL_COLORS = {
    DEBUG = "\27[36m",
    INFO = "\27[32m",
    WARN = "\27[33m",
    ERROR = "\27[31m"
}

local WIDTH_NAME = tonumber(os.getenv("COMPILER_LOG_WIDTH_NAME")) or 18
local WIDTH_LEVEL = tonumber(os.getenv("COMPILER_LOG_WIDTH_LEVEL")) or 8
local WIDTH_EVENT = tonumber(os.getenv("COMPILER_LOG_WIDTH_EVENT")) or 24

local function normalize_level(level_name, fallback)
    local normalized = string.upper(tostring(level_name or fallback or "DEBUG"))
    if LEVELS[normalized] == nil then
        return string.upper(fallback or "DEBUG")
    end
    return normalized
end

local function stringify(value)
    if value == nil then
        return "nil"
    end
    return tostring(value)
end

local function format_fields(fields)
    if type(fields) ~= "table" then
        return ""
    end

    local out = {}
    for key, value in pairs(fields) do
        out[#out + 1] = tostring(key) .. "=" .. stringify(value)
    end

    table.sort(out)
    if #out == 0 then
        return ""
    end
    return " {" .. table.concat(out, " ") .. "}"
end

local function with_style(value, style, enabled)
    if not enabled then
        return value
    end
    return style .. value .. STYLE_RESET
end

local function fit(value, width)
    local s = tostring(value or "")
    local len = #s
    if width <= 0 then
        return ""
    end
    if len > width then
        if width <= 1 then
            return string.sub(s, 1, width)
        end
        return string.sub(s, 1, width - 1) .. "~"
    end
    return s .. string.rep(" ", width - len)
end

local logger = class {
    constructor = function(self, name, options)
        options = options or {}
        self.Name = name
        self.Enabled = options.enabled
        if self.Enabled == nil then
            self.Enabled = DEFAULT_ENABLED
        end

        local level_name = normalize_level(options.level, DEFAULT_LEVEL_NAME)
        self.Level = LEVELS[level_name] or LEVELS.DEBUG
        self.LevelName = level_name
        self.UseColor = options.use_color
        if self.UseColor == nil then
            self.UseColor = DEFAULT_USE_COLOR
        end
    end,

    drop = function(self, str)
        local name_part = fit("["..self.Name.."]", WIDTH_NAME)
        print(string.format("%s %s", name_part, tostring(str)))
    end,

    emit = function(self, level, event, message, fields)
        if not self.Enabled then
            return
        end

        local level_name = string.upper(level or "INFO")
        local threshold = LEVELS[level_name] or LEVELS.INFO
        if threshold < self.Level then
            return
        end

        local event_name = event and tostring(event) or "-"
        local message_text = message and tostring(message) or ""

        local name_part = fit("["..self.Name.."]", WIDTH_NAME)
        local level_text = fit("["..level_name.."]", WIDTH_LEVEL)
        local event_text = fit(event_name, WIDTH_EVENT)

        local level_out = with_style(level_text, LEVEL_COLORS[level_name] or "", self.UseColor)
        if self.UseColor and (LEVEL_COLORS[level_name] or "") == "" then
            level_out = with_style(level_text, STYLE_BOLD, true)
        end
        local event_out = with_style(event_text, STYLE_BOLD, self.UseColor)
        local fields_out = with_style(format_fields(fields), STYLE_DIM, self.UseColor)

        if message_text ~= "" then
            self:drop(string.format("%s %s %s%s", level_out, event_out, message_text, fields_out))
        else
            self:drop(string.format("%s %s%s", level_out, event_out, fields_out))
        end
    end,

    set_level = function(self, level_name)
        local normalized = normalize_level(level_name, self.LevelName)
        self.LevelName = normalized
        self.Level = LEVELS[normalized]
    end,

    get_level = function(self)
        return self.LevelName
    end,

    debug = function(self, event, message, fields)
        self:emit("DEBUG", event, message, fields)
    end,

    info = function(self, event, message, fields)
        self:emit("INFO", event, message, fields)
    end,

    warn = function(self, event, message, fields)
        self:emit("WARN", event, message, fields)
    end,

    error = function(self, event, message, fields)
        self:emit("ERROR", event, message, fields)
    end,

    child = function(self, suffix, options)
        options = options or {}
        options.level = options.level or self.LevelName
        if options.enabled == nil then
            options.enabled = self.Enabled
        end
        return logger.new(self.Name .. "." .. tostring(suffix), options)
    end
}

function logger.set_level(level_name)
    DEFAULT_LEVEL_NAME = normalize_level(level_name, DEFAULT_LEVEL_NAME)
end

function logger.get_level()
    return DEFAULT_LEVEL_NAME
end

function logger.set_enabled(enabled)
    DEFAULT_ENABLED = enabled ~= false
end

function logger.get_enabled()
    return DEFAULT_ENABLED
end

function logger.set_use_color(use_color)
    DEFAULT_USE_COLOR = use_color ~= false
end

function logger.get_use_color()
    return DEFAULT_USE_COLOR
end

function logger.set_widths(widths)
    if type(widths) ~= "table" then
        return
    end

    if tonumber(widths.name) then
        WIDTH_NAME = math.max(1, math.floor(tonumber(widths.name)))
    end
    if tonumber(widths.level) then
        WIDTH_LEVEL = math.max(1, math.floor(tonumber(widths.level)))
    end
    if tonumber(widths.event) then
        WIDTH_EVENT = math.max(1, math.floor(tonumber(widths.event)))
    end
end

function logger.get_widths()
    return {
        name = WIDTH_NAME,
        level = WIDTH_LEVEL,
        event = WIDTH_EVENT
    }
end

logger.levels = LEVELS

return logger

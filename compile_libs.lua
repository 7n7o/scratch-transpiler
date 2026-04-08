local json = require("lib.json")

local lib_names = {"math", "std", "string", "looks", "motion", "pen", "sound"}

local libs = {}

for _,name in ipairs(lib_names) do
    local f = io.open(".\\scratch\\lib\\"..name..".json", "w")
    f:write(json.encode(require("scratch.lib."..name)))
end

local logger = require("lib.logger")
local visitors = require("visitors")
local serpent = require("lib.serpent")


local log = logger.new("COMPILER.POSTPASS")


local postpass = {}

local function collect_calls(proc)
    local calls = {}
    local count = 0
    
    local function scan(p)
        if p[1] == "call" and not calls[p[2]] then
            calls[p[2]] = true
            count = count + 1
        end
        for _,v in ipairs(p) do
            if type(v) == "table" then
                scan(v)
            end
        end
    end
    scan(proc)

    return calls, count
end

function postpass.eliminate_dead_code(procedures)
     local isDone = false
     repeat 
        isDone = true
        local calls = collect_calls(procedures)
        for i = #procedures, 1, -1 do
            local v = procedures[i]
            if v[3][1][1] == "procDef" and calls[v[3][1][2]] ~= true then
                table.remove(procedures, i)
                isDone = false
            end
        end
    until isDone
end

return postpass
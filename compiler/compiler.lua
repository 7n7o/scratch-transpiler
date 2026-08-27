local file = require("lib.file")
local json = require("lib.json")
local serpent = require("lib.serpent")
local logger = require("lib.logger")

local codegen_class = require("compiler.codegen")
local scope = require("compiler.scope")
local prepass = require("compiler.prepass")
local postpass = require("compiler.postpass")
local program_writer = require("compiler.program_writer")

local compiler = {}
local log = logger.new("COMPILER")

local function deepcopy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do
        copy[deepcopy(k, seen)] = deepcopy(v, seen)
    end
    return copy
end

local function try_load_library(name)
    log:debug("include.load.start", "Loading include library", {name = name})
    local lua_module = "scratch.lib." .. name
    local ok, loaded = pcall(require, lua_module)
    if ok then
        log:info("include.load.lua", "Loaded include from Lua module", {module = lua_module})
        return loaded
    end

    local json_path = string.format("scratch/lib/%s.json", name)
    local handle = io.open(json_path, "rb")
    if handle ~= nil then
        handle:close()
        log:info("include.load.json", "Loaded include from JSON file", {path = json_path})
        return json.decode(file.read(json_path))
    end

    log:error("include.load.failed", "Unable to load include library", {name = name})
    error(string.format("Unable to load include library `%s` from scratch/lib (%s.lua or %s.json)\n%s", name, name, name, loaded))
end

local function collect_includes(top_tree)
    local include_names = {}
    local include_seen = {}

    if top_tree.Type ~= "StatList" then
        log:debug("include.collect.skip", "Top-level node is not StatList", {type = top_tree.Type})
        return include_names
    end

    for _, stat in ipairs(top_tree.Statements) do
        if stat.Type == "PrepStat" and stat.Base and stat.Base.Value == "include" then
            for i = 1, #(stat.Data or {}) do
                local lib = stat.Data[i]
                if type(lib) == "string" and lib ~= "" and not include_seen[lib] then
                    include_seen[lib] = true
                    include_names[#include_names + 1] = lib
                end
            end
        end
    end

    return include_names
end

local function collect_globals(codegen, top_tree)
    local globals = {
        vars = {},
        lists = {},
        info = {}
    }

    if type(top_tree.Scope) ~= "table" or type(top_tree.Scope.Vars) ~= "table" then
        log:debug("globals.collect.skip", "Top-level node does not contain vars or type is invalid", {type = type(top_tree.Vars)})
        return globals
    end
    
    for _, var in ipairs(top_tree.Scope.Vars) do
        print(serpent.block(var))
        if var.AssignToken and var.AssignToken.Value == "list" then
            globals.lists[var.Name] = true
        else
            globals.vars[var.Name] = true
        end    
    end

    local global_assigns = {}

    for _, stat in ipairs(top_tree.Statements) do
        if stat.Type == "VarStat" and stat.Init then
            for _, assign in ipairs(codegen:generate(stat, {
                globals = globals
            })) do 
                table.insert(global_assigns, assign)
             end
        end
    end

    return globals, global_assigns
end

function compiler.compile_tree(top_tree)
    log:info("compile.start", "Compiling AST", {root_type = top_tree and top_tree.Type or "nil"})
    local codegen = codegen_class.new()
    local procs = {{0, 0, {
        {"whenGreenFlag"},
        {"call", "main"}
    }}}
    local costumes, lists, vars = nil, nil, nil

    local include_names = collect_includes(top_tree)
    log:info("include.collect.done", "Collected includes", {count = #include_names})
    for _, lib_name in ipairs(include_names) do
        local library = try_load_library(lib_name)
    
        local lib_procs = library.procs or library
        local lib_costumes = library.costumes 
        local lib_lists = library.lists
        local lib_vars = library.vars

        log:debug("include.merge.proc", "Merging include procedures", {name = lib_name, count = #lib_procs})
        for _, proc in ipairs(lib_procs) do
            table.insert(procs, deepcopy(proc))
        end

        if lib_costumes ~= nil then
            costumes = costumes == nil and {} or costumes
            log:debug("include.merge.costume", "Merging include costumes", {name = lib_name, count = #lib_costumes})
            for _, costume in ipairs(lib_costumes) do
                table.insert(costumes, deepcopy(costume))
            end
        end

        if lib_lists ~= nil then
            lists = lists == nil and {} or lists
            log:debug("include.merge.list", "Merging include lists", {name = lib_name, count = #lib_lists})
            for _, list in ipairs(lib_lists) do
                table.insert(lists, deepcopy(list))
            end
        end

        if lib_vars ~= nil then
            vars = vars == nil and {} or vars
            log:debug("include.merge.var", "Merging include vars", {name = lib_name, count = #lib_vars})
            for _, var in ipairs(lib_vars) do
                table.insert(vars, deepcopy(var))
            end
        end

    end

    local globals, assigns = collect_globals(codegen, top_tree)
    print(serpent.block(vars))
    
    local init = procs[1][3]
    for _, assign in ipairs(assigns) do
        table.insert(init, 2, assign)
    end

    if top_tree.Type == "StatList" then
        log:debug("compile.prepass.start", "Running lightweight prepass for array return procedures")
        codegen.array_return_procs = prepass.collect_array_return_procs(top_tree)
        prepass.add_return_cleanup(top_tree)
        log:debug("compile.prepass.done", "Prepass complete", {tracked = tostring(next(codegen.array_return_procs) ~= nil)})

        for _, stat in ipairs(top_tree.Statements) do
            if stat.Type == "Procedure" then
                log:debug("compile.proc", "Compiling procedure", {name = stat.Name})
                local proc = codegen:generate(stat, scope.new(nil, {
                    globals = globals
                }))
                table.insert(procs, {0, 0, proc})
    
            end
        end
    end

    log:info("compile.postpass.start", "Running postpass")
    postpass.eliminate_dead_code(procs)
    log:info("compile.postpass.done", "Postpass done.")

    

    log:info("compile.done", "Compilation finished", {scripts = #procs})
    return procs, costumes, lists, vars
end

compiler.program_writer = program_writer

return compiler
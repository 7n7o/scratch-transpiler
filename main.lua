local logger = require("lib.logger")

logger.set_level("DEBUG")

local parser = require("lib.parser")
local old_compiler = require("compiler")
local new_compiler = require("compiler.compiler")
local program_writer = require("compiler.program_writer")
local serpent = require("lib.serpent")
local file = require("lib.file")
local path = require("lib.path")

local function usage()
    print("Scratch 2 Transpiler")
    print("Usage:")
    print("  luajit main.lua <source.x>")
    print("")
    print("Outputs:")
    print("  ast.lua                 AST of input script")
    print("  scratch_code.lua        The lua representation of the final sprite")
    print("  scratch/sprite/sprite/sprite.json Generated sprite JSON")
    print("  build/sprite.scratch2    Packaged Scratch 2 sprite")
end

math.randomseed(os.clock() * 100000, os.clock() * 1000)

local filepath = unpack(arg)

filepath = path.new(filepath)



local src = file.read(tostring(filepath))

if src == nil then
    usage()
    return
end

local tree = parser.parse(src)
tree = parser.varinfo(tree)
file.write("ast.lua", "return "..serpent.block(tree, {nocode = true, comment = false}))



local scratch_tree, costumes, lists = new_compiler.compile_tree(tree)



file.write("scratch_code.lua", "return "..serpent.block(scratch_tree, {nocode = true, comment = false}))

program_writer.write_sprite_program("scratch/sprite/sprite/sprite.json", {
    objName = filepath:filename() .. filepath:extension(),
    scripts = scratch_tree,
    costumes = costumes,
    lists = lists
})
os.execute("mkdir build")
os.remove("build/sprite.scratch2")

local handle = io.popen("7z a -tzip build/sprite.scratch2 .\\scratch\\sprite\\*", "r")
-- print(handle:read("*all"))

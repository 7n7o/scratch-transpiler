local logger = require("lib.logger")

logger.set_level("DEBUG")

local parser = require("lib.parser")
local old_compiler = require("compiler")
local new_compiler = require("compiler.compiler")
local program_writer = require("compiler.program_writer")
local serpent = require("lib.serpent")
local file = require("lib.file")
local path = require("lib.path")


math.randomseed(os.clock() * 100000, os.clock() * 1000)

local filepath = unpack(arg)

filepath = path.new(filepath)



local src = file.read(tostring(filepath))

local tree = parser.parse(src)
tree = parser.varinfo(tree)
file.write("ast.lua", "return "..serpent.block(tree, {nocode = true, comment = false}))



local scratch_tree, costumes, lists = new_compiler.compile_tree(tree)



file.write("scratch_code.lua", "return "..serpent.block(scratch_tree, {nocode = true, comment = false}))

program_writer.write_sprite_program("build/sprite/sprite.json", {
    objName = filepath:filename() .. filepath:extension(),
    scripts = scratch_tree,
    costumes = costumes,
    lists = lists
})

os.remove("build/sprite.scratch2")

local handle = io.popen("7z a -tzip build/sprite.scratch2 .\\build\\*", "r")
-- print(handle:read("*all"))

local file = require("lib.file")
local json = require("lib.json")
local logger = require("lib.logger")

local program_writer = {}
local log = logger.new("COMPILER.WRITER")

local function new_object()
    return setmetatable({}, {__type = "object"})
end

local function default_costumes()
    return {{
        costumeName = "costume",
        baseLayerID = 0,
        baseLayerMD5 = "d36f6603ec293d2c2198d3ea05109fe0.png",
        bitmapResolution = 2,
        rotationCenterX = 0,
        rotationCenterY = 0
    }}
end

function program_writer.build_sprite_program(options)
    options = options or {}
    log:debug("sprite.build.start", "Building sprite program", {
        objName = options.objName or "nil",
        scripts = #(options.scripts or {}),
        variables = #(options.variables or {}),
        lists = #(options.lists or {})
    })

    local program = {
        objName = options.objName,
        variables = options.variables or {},
        lists = options.lists or {},
        scripts = options.scripts or {},
        sounds = options.sounds or {},
        costumes = options.costumes or default_costumes(),
        currentCostumeIndex = options.currentCostumeIndex or 0,
        scratchX = options.scratchX or 0,
        scratchY = options.scratchY or 0,
        scale = options.scale or 1,
        direction = options.direction or 90,
        rotationStyle = options.rotationStyle or "normal",
        isDraggable = options.isDraggable == true,
        indexInLibrary = options.indexInLibrary or 100000,
        visible = options.visible == true,
        spriteInfo = options.spriteInfo or new_object()
    }
    log:info("sprite.build.done", "Sprite program built", {objName = program.objName or "nil"})
    return program
end

function program_writer.write_sprite_program(path, options)
    log:info("sprite.write.start", "Writing sprite program", {path = path})
    local program = program_writer.build_sprite_program(options)
    file.write(path, json.encode(program))
    log:info("sprite.write.done", "Sprite program written", {path = path})
    return program
end

return program_writer

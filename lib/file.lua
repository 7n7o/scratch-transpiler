local file = {}

function file.write(path, data)
    local f = io.open(path, "wb")
    f:write(data)
    f:close()
end

function file.read(path)
    local f = io.open(path, "rb")
    local data = f:read("*all")
    f:close()
    return data
end

return file
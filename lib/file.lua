local file = {}

function file.write(path, data)
    local f = io.open(path, "wb")
    if f == nil then return end
    f:write(data)
    f:close()
end

function file.read(path)
    local f = io.open(path, "rb")
    if f == nil then return end
    local data = f:read("*all")
    f:close()
    return data
end

return file
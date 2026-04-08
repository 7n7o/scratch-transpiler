table.keys = function(list)
    local keys = {}
    for k in pairs(list) do
        table.insert(keys, k)
    end
    return keys
end

table.lookupify = function(list)
    local lookup = {}
    for _, v in pairs(list) do
        lookup[v] = true
    end
    return lookup
end
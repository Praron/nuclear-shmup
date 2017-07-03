function locals()
    local variables = {}
    local idx = 1
    while idx < 10 do
        local ln, lv = debug.getlocal(2, idx)
        if ln ~= nil then
            variables[ln] = lv
        else
            idx = 1 + idx
            break
        end
        idx = 1 + idx
    end
    return variables
end

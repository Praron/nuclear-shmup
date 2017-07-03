local Utils = {}

function Utils.recursiveEnumerate(folder, file_list)
    if file_list then
        local items = love.filesystem.getDirectoryItems(folder)
        for _, item in ipairs(items) do
            local file = folder .. '/' .. item
            if love.filesystem.isFile(file) then
                table.insert(file_list, file)
            elseif love.filesystem.isDirectory(file) then
                recursiveEnumerate(file, file_list)
            end
        end
    else  -- return file names, if out argument not given. 
        local file_list = {}
        recursiveEnumerate(folder, file_list)
        return file_list
    end
end


function Utils.requireFiles(files)
    for _, file in ipairs(files) do
        local file = file:sub(1, -5)
        require(file)
    end
end

function Utils.clamp(min, n, max) return math.min(math.max(n, min), max) end

local current_id = 0
function Utils.getUniqueID()
    current_id = current_id + 1
    return current_id
end

function Utils.length(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end

function Utils.deepCopy(obj, seen)
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
  local s = seen or {}
  local res = setmetatable({}, getmetatable(obj))
  s[obj] = res
  for k, v in pairs(obj) do res[Utils.deepCopy(k, s)] = Utils.deepCopy(v, s) end
  return res
end

return Utils
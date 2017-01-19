local table_util = {}

local log = require("log")

-- https://gist.github.com/tylerneylon/81333721109155b2d244
function table_util.copy(obj, seen)
  -- Handle non-tables and previously-seen tables.
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
 
  -- New table; mark it as seen an copy recursively.
  local s = seen or {}
  local res = setmetatable({}, getmetatable(obj))
  s[obj] = res
  for k, v in pairs(obj) do res[table_util.copy(k, s)] = table_util.copy(v, s) end
  return res
end


function table_util.val_to_str ( v )
  if "string" == type( v ) then
    v = string.gsub( v, "\n", "\\n" )
    if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
      return "'" .. v .. "'"
    end
    return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
  else
    return "table" == type( v ) and table_util.tostring( v ) or
      tostring( v )
  end
end

function table_util.key_to_str ( k )
  if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
    return k
  else
    return "[" .. table_util.val_to_str( k ) .. "]"
  end
end

function table_util.tostring( tbl )
  local result, done = {}, {}
  for k, v in ipairs( tbl ) do
    table.insert( result, table_util.val_to_str( v ) )
    done[ k ] = true
  end
  for k, v in pairs( tbl ) do
    if not done[ k ] then
      table.insert( result,
        table_util.key_to_str( k ) .. "=" .. table_util.val_to_str( v ) )
    end
  end
  return "{" .. table.concat( result, "," ) .. "}"
end


function table_util.add_table_to_table(copy_from, recipient)
  if next(copy_from) == nil then return end
  for _, v in ipairs(copy_from) do
    recipient[#recipient+1] = v
  end
end

function table_util.get_table_subset(table, from, to)
  local subset={}
  for i=from, to, 1 do
    subset[#subset+1]=table[i]
  end
  return subset
end

-- gives a combination list back given this format:
-- table = {[n]={element1...elementN}, [n]={element1...elementN}, ...}
function table_util.combinations( tbl )
  local key_list, nr_keys = table_util.get_keys( tbl )
  -- log.debug("key_list")
  -- log.debug(key_list)
  local n_list = {}
  local max_n_list={}
  for i=1, nr_keys do 
    n_list[i] = 1 
    max_n_list[i]=#tbl[key_list[i]]
  end
  -- log.debug("n_list")
  -- log.debug(n_list)
  -- log.debug("max_n_list")
  -- log.debug(max_n_list)
  local result = {}
  local r = 0
  local done = false
  repeat
    r = r+1
    -- log.debug("r="..r)
    result[r]={}
    for i=1, nr_keys do result[r][key_list[i]]=tbl[key_list[i]][n_list[i]] end
    n_list[nr_keys]=n_list[nr_keys]+1
    for i=nr_keys, 1, -1 do 
      if n_list[i] > max_n_list[i] then 
        if i==1 then
          done = true
        else
          n_list[i]=1
          n_list[i-1]=n_list[i-1]+1
        end
      end
    end
    -- log.debug("result[r]=")
    -- log.debug(result[r])
  until done
  return result
end

function table_util.get_keys( tbl )
  local key_list = {}
  local n=0
  for k, _ in pairs(tbl) do
    n=n+1
    key_list[n]=k
  end
  return key_list, n
end

function table_util.contains( tbl, value )
  if tbl == nil then return false end
  for _,v in pairs(tbl) do
    if v == value then return true end
  end
  return false
end

function table_util.union( tbl1, tbl2 )
  local new_table = {}
  for k,v in pairs(tbl1) do
    new_table[k]=v
  end
  for k,v in pairs(tbl2) do
    new_table[k]=v
  end
  return new_table
end


function table_util.split(str, sep)
  local t = {}
  for word in string.gmatch(str, '([^'..sep..']+)') do
      table.insert(t, word)
  end
  return t
end

function table_util.join(str_tbl, sep)
  local t = ""
  for _,str in pairs(str_tbl) do
    t = t..sep..str
  end
  return t
end

function table_util.remove_false(tab)
  local remove_these={}
  -- log.debug("length before: "..tostring(#tab))
  for i=#tab, 1, -1 do
    if not tab[i] then remove_these[#remove_these+1]=i end
  end
  -- log.debug("false_encountered: "..tostring(#remove_these))
  for _,v in ipairs(remove_these) do
    table.remove(tab, v)
  end
  -- log.debug("length after: "..tostring(#tab))
end

function table_util.concat_table(table1, table2)
  local resulting_table = {}
  for _, v in ipairs(table1) do
    resulting_table[#resulting_table+1]=v
  end
  for _, v in ipairs(table2) do
    resulting_table[#resulting_table+1]=v
  end
  return resulting_table
end

-- propabilities = {[key]=number, [key]=number}
-- where the ratio of the number
function table_util.choose_random_key(probabilities)
  local total = 0
  for _,probability in pairs(probabilities) do total = total + probability end
  local random = math.random(total)
  local sum = 0
  for key, probability in pairs(probabilities) do
    sum = sum + probability
    if random <= sum then
      return key
    end
  end

  return nil
end

function table_util.tbl_contains_tbl( tbl1, tbl2 )
  -- for every key, value pair in tbl2
  for k,v in pairs(tbl2) do
    -- we check if we're looking for a table
    if "table" == type(v) and "table" == type(tbl1[k]) then
      -- if so we check if that table contains 
      if not table_util.tbl_contains_tbl( tbl1[k], v ) then return false end
    elseif v ~= tbl1[k] then
      return false
    end
  end
  return true
end

function table_util.equal( tbl1, tbl2 )
  for k,v in pairs(tbl1) do
    if "table" == type(v) and "table" == type(tbl2[k])  then
      if not table_util.equal( v, tbl2[k] ) then return false end
    elseif v ~= tbl1[k] then
      return false
    end
  end
  for k,v in pairs(tbl2) do
    if "table" == type(v) and "table" == type(tbl1[k]) then
      if not table_util.equal( tbl1[k], v ) then return false end
    elseif v ~= tbl1[k] then
      return false
    end
  end
  return true
end

-- http://coronalabs.com/blog/2014/09/30/tutorial-how-to-shuffle-table-items/
function table_util.shuffleTable( t )
    local rand = math.random 
    assert( t, "shuffleTable() expected a table, got nil" )
    local iterations = #t
    local j
    
    for i = iterations, 2, -1 do
        j = rand(i)
        t[i], t[j] = t[j], t[i]
    end
end

function table_util.reverse_table(t)
    local reversedTable = {}
    local itemCount = #t
    for k, v in ipairs(t) do
        reversedTable[itemCount + 1 - k] = v
    end
    return reversedTable
end

function table_util.random(tbl)
   if not tbl then return end
   return tbl[math.random(#tbl)] 
end

function table_util.get(tbl, index_tbl)
    local depth = 1
    local obj = tbl
    repeat
      obj = obj[index_tbl[depth]] or false
      if not obj then return false end
      depth = depth+1
    until depth > #index_tbl
    return obj
end

return table_util
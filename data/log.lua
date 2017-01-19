local log = {}

log.verbose = true

function log.debug_log_reset()
	local f = sol.file.open("debuglog","w")
	f:write("New Log started")
	f:flush()
	f:close()
end

function log.debug(message)
  if not log.verbose then return end
	local stringmessage = log.to_string(message)
	local f = sol.file.open("debuglog","a+")
	f:write(stringmessage .. "\n")
	f:flush()
	f:close()
end

-- used in the log representation
-- http://lua-users.org/wiki/TableSerialization
function log.table_print (tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    local sb = {}
    for key, value in pairs (tt) do
      table.insert(sb, string.rep (" ", indent)) -- indent it
      if type (value) == "table" and not done [value] then
        done [value] = true
        table.insert(sb, tostring(key)..":\n");
        table.insert(sb, string.rep (" ", indent))
        table.insert(sb, "{\n");
        table.insert(sb, log.table_print (value, indent + 2, done))
        table.insert(sb, string.rep (" ", indent)) -- indent it
        table.insert(sb, "}\n");
      elseif "number" == type(key) then
        table.insert(sb, string.format("[%s]=\"%s\"\n", tostring(key),tostring(value)))
      else
        table.insert(sb, string.format(
            "%s =\"%s\"\n", tostring (key), tostring(value)))
       end
    end
    return table.concat(sb)
  else
    return tt .. "\n"
  end
end

-- http://lua-users.org/wiki/TableSerialization
function log.to_string( tbl )
    if  "nil"       == type( tbl ) then
        return tostring(nil)
    elseif  "table" == type( tbl ) then
        return log.table_print(tbl)
    elseif  "string" == type( tbl ) then
    	return tbl
    else
        return tostring(tbl)
    end
end

-- http://www.lua.org/manual/2.4/node31.html
function log.printGlobalVariables ()
  local i, v = nextvar(nil)
  local string = "Global variables:\n"
  while i do
    string = string .. i .. "\n"
    i, v = nextvar(i)
  end
  log.debug(string)
end

function log.entities(begins_with, map)
  for entity in map:get_entities(begins_with) do
    log.debug(entity:get_name())
  end
end

return log
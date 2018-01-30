local table_util = require("table_util")

local vl = {}

vl.new_log = {
	-- personal settings
	name=game:get_player_name(),
	time_stamp=0,
	total_time = 0,
	start_time = 0,
	village_exit_time=0,
	cure_brewer=false,
	cure_witch=false,
	apples=0,
	found_bottle=false,
	filled_bottle=false,
	rupees = 0,
	village_logged=false,
	entered_village_from_save=0,
	areas_visited={ bush_area=false, woods_exit=false, plaza=false, brewer_area=false},
	NPC={
			-- witch area
			witch={talked=false, options_explored={}, options_available=1},
			-- house area
			mom={talked=false, options_explored={}, options_available=3},
			dad={talked=false, options_explored={}, options_available=2},
			brother={talked=false, options_explored={}, options_available=1},
			-- village area
			lefttwin={talked=false, options_explored={}, options_available=1}, 
			righttwin={talked=false, options_explored={}, options_available=1}, 
			glassesguy={talked=false, options_explored={}, options_available=1}, 
			oldwoman={talked=false, options_explored={}, options_available=2}, 
			oldguyleft={talked=false, options_explored={}, options_available=1}, 
			oldguyright={talked=false, options_explored={}, options_available=1}, 
			innkeeper={talked=false, options_explored={}, options_available=1}, 
			youngfellow={talked=false, options_explored={}, options_available=1}, 
			merchant={talked=false, options_explored={}, options_available=2}, 
			marketguy={talked=false, options_explored={}, options_available=1}, 
			brewer={talked=false, options_explored={}, options_available=2}, 
			littleguy={talked=false, options_explored={}, options_available=2}
		}
}

vl.log = {}

function vl.pickle_log()
	vl.log.total_time = vl.log.total_time + os.clock() - vl.log.start_time
	vl.log.start_time = os.clock()
	local f = sol.file.open("tempvillagelog"..game:get_player_name(),"w")
	f:write(pickle(vl.log));f:flush();f:close()
end

function vl.unpickle_log()
	local f = sol.file.open("tempvillagelog"..game:get_player_name(),"r")
	if (f ~= nil) then
		vl.log = unpickle(f:read("*all"))
		f:close()
	end
end

function vl.start_new_log()
	vl.log = table_util.copy(vl.new_log)
	vl.log.time_stamp = os.date()
end

function vl.to_file( game, suffix )
	local npc_order = {	"witch", 
						"mom", "dad", "brother",
						"lefttwin", "righttwin", "glassesguy", "oldwoman", "oldguyleft", "oldguyright", 
						"innkeeper", "youngfellow", "merchant", "marketguy", "brewer", "littleguy"}
	local area_order = {"bush_area", "woods_exit", "plaza", "brewer_area"}
	-- the csv will contain data in this order:
	-- name, time_stamp, npcs_talked_to, options_taken, total_options, perc_options_taken, perc_npcs_talked_to, 
	-- cure_brewer, cure_witch, apples, rupees, found_bottle, filled_bottle, visited_bush_area , visited_woods_exit, visited_plaza, visited_brewer_area
	-- time_spent_in_village, entered_village_from_save
	local data_to_write={}	
	local logbd = vl.log
	-- Player name
	table.insert(data_to_write, logbd.name)
	table.insert(data_to_write, logbd.time_stamp)
	-- # NPCs talked to
	-- NPCs options explored, options_available
	-- fraction of options explored of the talked to npcs
	-- fraction of NPCs talked to
	local npcs_talked_to = 0
	local total_options =0
	local options_taken =0
	for index,name in ipairs(npc_order) do
		local data_point = logbd.NPC[name]
		if data_point.talked then 
			npcs_talked_to = npcs_talked_to+1
			total_options = total_options + data_point.options_available
			for i=1,data_point.options_available do
				if data_point.options_explored[i] then options_taken = options_taken + 1 end
			end
		end
	end
	table.insert(data_to_write, npcs_talked_to)
	table.insert(data_to_write, options_taken)
	table.insert(data_to_write, total_options)
	table.insert(data_to_write, options_taken/total_options)
	table.insert(data_to_write, npcs_talked_to/#npc_order)
	-- cure brewer
	table.insert(data_to_write, game:get_value("strong_cure") and 1 or 0)
	-- cure witch
	table.insert(data_to_write, game:get_value("diluted_cure") and 1 or 0)
	-- apples
	table.insert(data_to_write, logbd.apples)
	-- rupees
	table.insert(data_to_write, logbd.rupees)
	-- found_bottle
	-- filled_bottle
	if game:get_value("bottle_1") then
		table.insert(data_to_write, 1)
		if logbd.filled_bottle then 
			table.insert(data_to_write, 1)
		else
			table.insert(data_to_write, 0)
		end
	else
		table.insert(data_to_write, 0)
		table.insert(data_to_write, 0)
	end
	-- areas visited
	for index,name in ipairs(area_order) do
		if logbd.areas_visited[name] then table.insert(data_to_write, 1)
	    else  table.insert(data_to_write, 0) end
	end
	-- time spent in village
	table.insert(data_to_write, logbd.village_exit_time-logbd.start_time+logbd.total_time)
	table.insert(data_to_write, logbd.entered_village_from_save)
	vl.writeTableToFile(data_to_write, "village_log_"..suffix.."_dungeon.csv")
end

function vl.writeTableToFile (dataTable, file) 
	local f = sol.file.open(file,"a+")
	for k,v in pairs(dataTable) do
		f:write(v)
		if k ~= #dataTable then f:write(",")
		else f:write("\n") end
		f:flush()
	end
	f:flush(); f:close()
end

----------------------------------------------
-- Pickle.lua
-- A table serialization utility for lua
-- Steve Dekorte, http://www.dekorte.com, Apr 2000
-- Freeware
----------------------------------------------

function pickle(t)
  return Pickle:clone():pickle_(t)
end

Pickle = {
  clone = function (t) local nt={}; for i, v in pairs(t) do nt[i]=v end return nt end 
}

function Pickle:pickle_(root)
  if type(root) ~= "table" then 
    error("can only pickle tables, not ".. type(root).."s")
  end
  self._tableToRef = {}
  self._refToTable = {}
  local savecount = 0
  self:ref_(root)
  local s = ""

  while #self._refToTable > savecount do
    savecount = savecount + 1
    local t = self._refToTable[savecount]
    s = s.."{\n"
    for i, v in pairs(t) do
        s = string.format("%s[%s]=%s,\n", s, self:value_(i), self:value_(v))
    end
    s = s.."},\n"
  end

  return string.format("{%s}", s)
end

function Pickle:value_(v)
  local vtype = type(v)
  if     vtype == "string" then return string.format("%q", v)
  elseif vtype == "number" then return v
  elseif vtype == "boolean" then return tostring(v)
  elseif vtype == "table" then return "{"..self:ref_(v).."}"
  else --error("pickle a "..type(v).." is not supported")
  end  
end

function Pickle:ref_(t)
  local ref = self._tableToRef[t]
  if not ref then 
    if t == self then error("can't pickle the pickle class") end
    table.insert(self._refToTable, t)
    ref = #self._refToTable
    self._tableToRef[t] = ref
  end
  return ref
end

----------------------------------------------
-- unpickle
----------------------------------------------

function unpickle(s)
  if type(s) ~= "string" then
    error("can't unpickle a "..type(s)..", only strings")
  end
  local gentables = loadstring("return "..s)
  local tables = gentables()
  
  for tnum = 1, #tables do
    local t = tables[tnum]
    local tcopy = {}; for i, v in pairs(t) do tcopy[i] = v end
    for i, v in pairs(tcopy) do
      local ni, nv
      if type(i) == "table" then ni = tables[i[1]] else ni = i end
      if type(v) == "table" then nv = tables[v[1]] else nv = v end
      t[i] = nil
      t[ni] = nv
    end
  end
  return tables[1]
end


return vl
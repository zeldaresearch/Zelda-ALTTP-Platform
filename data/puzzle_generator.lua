maze_gen 	= maze_gen or require("maze_generator")
pike_room 	= pike_room or require("moving_pike_room")
sokoban 	= sokoban or require("sokoban_parser")
placement 	= placement or require("object_placement")

local log 			= require("log")
local table_util 	= require("table_util")
local area_util 	= require("area_util")
local num_util 		= require("num_util")

local pg ={}
pg.static_difficulty = false
pg.puzzle_difficulty = 0

pg.pike_room_min_difficulty = game:get_value("pike_room_min_difficulty") or 1
pg.pike_room_max_difficulty = game:get_value("pike_room_max_difficulty") or 1
pg.sokoban_min_difficulty = game:get_value("sokoban_min_difficulty") or 1
pg.sokoban_max_difficulty = game:get_value("sokoban_max_difficulty") or 1
pg.maze_min_difficulty = game:get_value("maze_min_difficulty") or 1
pg.maze_max_difficulty = game:get_value("maze_max_difficulty") or 1

pg.puzzles_instantiated = {["maze"]=0, ["sokoban"]=0, ["pike_room"]=0}
pg.time_requirements = {["maze"]=30, ["sokoban"]=90, ["pike_room"]=20}
pg.areanumbers_filled = {}

function pg.get_static_difficulty(puzzle_type)
	local difficulty = pg.puzzle_difficulty

	if puzzle_type == "maze" then difficulty = difficulty-1
	elseif puzzle_type == "pike_room" then difficulty = difficulty-2 
	elseif puzzle_type == "sokoban" then difficulty = difficulty-2
	end
	if difficulty <= 0 then difficulty = 1 end
	return difficulty
end

function pg.create_puzzle( selection_type, area, areanumber, exit_areas, exclusion, area_details, params )
	local map_id = map:get_id()
	pg.areanumbers_filled[map_id] = pg.areanumbers_filled[map_id] or {}
	if not pg.areanumbers_filled[map_id][areanumber] then pg.areanumbers_filled[map_id][areanumber] = true 
	else return end
	-- determine puzzle type
	local puzzle_type
	if table_util.contains({"maze", "pike_room", "sokoban"}, selection_type) then
		puzzle_type = selection_type
	elseif selection_type == "equal_amounts" then
		local min_amount = math.huge
		local puzzle_types_available = table_util.get_keys(pg.puzzles_instantiated)
		table_util.shuffleTable( puzzle_types_available )
		for _,pt in pairs(puzzle_types_available) do
			if pg.puzzles_instantiated[pt] < min_amount then 
				puzzle_type = pt
				min_amount = pg.puzzles_instantiated[pt]
			end
		end
		pg.puzzles_instantiated[puzzle_type] = pg.puzzles_instantiated[puzzle_type] + 1
	else puzzle_type = table_util.random({"maze", "pike_room", "sokoban"}) end

	-- determine difficulty to be used
	local difficulty=0
	if pg.static_difficulty == true then
		difficulty = pg.get_static_difficulty(puzzle_type)
	else
		difficulty = pg[puzzle_type.."_min_difficulty"]
		--if game:get_life() > 16 then difficulty = pg[puzzle_type.."_max_difficulty"] end
	end
	-- determine parameters to be used
	local parameters = pg.get_parameters( puzzle_type, difficulty )
	parameters.area = area; 			parameters.areanumber = areanumber    
	parameters.exit_areas = exit_areas; parameters.exclusion = exclusion
	parameters.area_details = area_details
	-- create a puzzle for a given room using the parameters
	return pg["make_"..puzzle_type.."_puzzle"]( parameters )
end

function pg.interpret_log( completed_puzzle_log )
	local cl = completed_puzzle_log
	local time_requirement = pg.time_requirements[cl.puzzle_type]
	local hurt = cl.got_hurt + cl.falls
	if cl.puzzle_type == "pike_room" then time_requirement = pg.time_requirements[cl.puzzle_type] * ((cl.difficulty+1)/2) end

	if cl.deaths > 0 or cl.quit or hurt > 6 or cl.total_time > time_requirement*1.5  then
		if cl.difficulty_difference <= 0 then
			if cl.deaths > 0 or cl.quit or hurt > 8 then 
				pg.decrease_min_max_difficulty( cl.puzzle_type )
			end
			pg.decrease_min_max_difficulty( cl.puzzle_type )
		end
	elseif cl.difficulty_difference >= 0 then
		if cl.total_time <= time_requirement and hurt <= 4 then 
		  	pg.increase_min_max_difficulty( cl.puzzle_type )
		end
		if cl.total_time <= time_requirement*1.5 and hurt <= 2 then
			pg.increase_min_max_difficulty( cl.puzzle_type )
		end
	end
end

function pg.increase_min_max_difficulty( puzzle_type )
	if pg[puzzle_type.."_min_difficulty"] == 5 then
		return
	elseif pg[puzzle_type.."_max_difficulty"] == pg[puzzle_type.."_min_difficulty"] then
		pg[puzzle_type.."_max_difficulty"] = pg[puzzle_type.."_max_difficulty"] +1
	else
		pg[puzzle_type.."_min_difficulty"] = pg[puzzle_type.."_min_difficulty"] +1
	end
	game:set_value(puzzle_type.."_min_difficulty", pg[puzzle_type.."_min_difficulty"])
	game:set_value(puzzle_type.."_max_difficulty", pg[puzzle_type.."_max_difficulty"])
end

function pg.decrease_min_max_difficulty( puzzle_type )
	if pg[puzzle_type.."_max_difficulty"] == 1 then
		return
	elseif pg[puzzle_type.."_max_difficulty"] == pg[puzzle_type.."_min_difficulty"] then
		pg[puzzle_type.."_min_difficulty"] = pg[puzzle_type.."_min_difficulty"] -1
	else
		pg[puzzle_type.."_max_difficulty"] = pg[puzzle_type.."_max_difficulty"] -1
	end
	game:set_value(puzzle_type.."_min_difficulty", pg[puzzle_type.."_min_difficulty"])
	game:set_value(puzzle_type.."_max_difficulty", pg[puzzle_type.."_max_difficulty"])
end


function pg.get_parameters( puzzle_type, difficulty )
	return pg["get_"..puzzle_type.."_parameters"]( difficulty )
end

function pg.get_maze_parameters( difficulty )
	parameters = {darkness=true, fireball_statues=0, bubbles=0, pikes=false, pits=false}
	parameters.difficulty = difficulty
	parameters.fireball_statues = difficulty-1
	parameters.bubbles = difficulty-1
	if difficulty <= 1 then	parameters.bubbles = 0 end
	if difficulty >= 2 then parameters.pits = true end
	if difficulty >= 4 then parameters.pikes = true end
	return parameters
end

function pg.get_sokoban_parameters( difficulty )
	return {difficulty=difficulty}
end

function pg.get_pike_room_parameters( difficulty )
	local parameters = {}
	-- speed = 24, 32, 40, 48, 56
	-- width = 2 or 4
	local movement_option=table_util.random({
		{"circle", 0}, 
		{"back/forth", 0}, 
		{"side_to_side", 0}
		})
	parameters.speed = 		48
	parameters.width = 		4-(difficulty-1)*0.5
	parameters.movement = 	movement_option[1]
	parameters.difficulty = difficulty
	return parameters
end

function pg.make_sokoban_puzzle( parameters )
	sokoban.make( parameters )
end

function pg.make_pike_room_puzzle( parameters )
	pike_room.make( parameters )
end

function pg.make_maze_puzzle( parameters )
	maze_gen.make( parameters )
end

return pg
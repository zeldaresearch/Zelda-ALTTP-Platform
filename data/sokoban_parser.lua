maze_gen 		= maze_gen or require("maze_generator")
placement 		= placement or require("object_placement")

local log 				= require("log")
local table_util 		= require("table_util")
local area_util 		= require("area_util")
local num_util 			= require("num_util")

local sp = {}

--arranged by ID as to avoid using duplicates in the same game
sp.sokoban_problems = false

sp.sokoban_difficulty = false

sp.puzzles_completed = {}

sp.sokoban_files={
	"minicosmos.txt", -- Author: Aymeric du Peloux, aymeric.dupeloux@smile.fr, http://sneezingtiger.com/sokoban/levels/microcosmosText.html
}

sp.prop_types = {
	["exit_block"]={name="exit_block", layer=0, x=8, y=13, sprite="entities/block", pushable=false, pullable=false, maximum_moves=0},
	["wall_block"]={name="unmovable_block", layer=0, x=8, y=13, sprite="entities/block", pushable=false, pullable=false, maximum_moves=0},
	["move_block"]={name="movable_block_1", layer=0, x=8, y=13, sprite="entities/gray_block", pushable=true, pullable=false, maximum_moves=2},
	["block_switch"]={name="block_switch_1", layer=0, x=0, y=0, subtype="walkable", sprite="entities/gray_switch", sound="switch", needs_block=true, inactivate_when_leaving=true},
	["reset_switch"]={name="reset_switch", layer=0, x=0, y=0, subtype="walkable", sprite="entities/switch", sound="switch", needs_block=false, inactivate_when_leaving=true},
	["reset_wall"]={name="reset_wall", layer=0, x=0, y=0, width=16, height=16, stops_blocks=true},
	["reset_teleport"]={name="reset_teleport", layer=0, x=0, y=0, subtype="walkable", sprite="entities/switch", destination_map="", destination=""},
}

sp.puzzles_created = {}

function sp.parse_files ()
	log.debug("parse_files")
	sp.sokoban_problems = {}
	sp.sokoban_difficulty = {}
	for _,filename in ipairs(sp.sokoban_files) do
		local file = sol.file.open("internetsources/sokoban/"..filename)
		while true do
			local first_line = file:read()
			if first_line == nil or string.len(first_line) == 0 then break end
			local level = table_util.split(first_line, "_")
			local lvl_id = tonumber(level[2])
			local lvl_id2= tonumber(level[3])
			local difficulty_rating = tonumber(table_util.split(file:read(), "_")[2])
			local name = file:read()
			local puzzle = {}
			local line
			local max_length = 0
			while true do
				line = file:read()
				if not line then break end
				local length = string.len(line)
				if length > max_length then max_length = length end
				if length > 0 then 
					table.insert(puzzle, line)
				else break end
			end
			sp.sokoban_problems[lvl_id] = sp.sokoban_problems[lvl_id] or {}
			sp.sokoban_problems[lvl_id][lvl_id2] = {puzzle=puzzle, difficulty=difficulty_rating, dim={x=max_length, y=#puzzle}}
			sp.sokoban_difficulty[difficulty_rating] = sp.sokoban_difficulty[difficulty_rating] or {}
			table.insert(sp.sokoban_difficulty[difficulty_rating], {lvl_id, lvl_id2})
		end
	end
end

function sp.get_corrected_puzzle_table( problem, to_direction )
	log.debug("get_corrected_puzzle_table")
	local puzzle_table = sp.get_table_from_string_representation( problem )
	local from_direction = sp.get_direction_of_entrance( puzzle_table, problem.dim )
	local rotate_puzzle_table = sp.rotate_puzzle_to_direction( from_direction, to_direction, puzzle_table )
	log.debug("rotate_puzzle_table")
	return rotate_puzzle_table
end

function sp.get_random_sized_sokoban_puzzle( difficulty )
	if not sp.sokoban_problems then sp.parse_files() end
	return sp.select_puzzle( nil , difficulty ) 
end

function sp.get_sokoban_puzzle( area, difficulty )
	if not sp.sokoban_problems then sp.parse_files() end
	local max_x, max_y = math.floor((area.x2-area.x1)/16), math.floor((area.y2-area.y1)/16)
	local max_dimensions = {max=math.max(max_x, max_y), min=math.min(max_y, max_x)}
	return sp.select_puzzle( max_dimensions , difficulty )
end

function sp.select_puzzle( max_dimensions, difficulty )
	if not sp.sokoban_problems then sp.parse_files() end
	local puzzles = sp.sokoban_difficulty[difficulty]
	if not puzzles then return false end
	for i,id_pair in ipairs(puzzles) do
		if id_pair[2] == 1 or (sp.puzzles_completed[id_pair[1]] and sp.puzzles_completed[id_pair[1]][id_pair[2]-1]) then 
			local problem = sp.sokoban_problems[id_pair[1]][id_pair[2]]
			if ( max_dimensions == nil 
				or (problem.dim.x <= max_dimensions.min and problem.dim.y <= max_dimensions.max) 
				or (problem.dim.y <= max_dimensions.min and problem.dim.x <= max_dimensions.max) ) then
				table.remove(puzzles, i)
				return problem
			end
		end
	end
end

function sp.get_table_from_string_representation( problem )
	log.debug("get_table_from_string_representation")
	local string_rep = table_util.copy(problem.puzzle)
	for i=#string_rep,1, -1 do
		if #string_rep[i]==0 then table.remove(string_rep, i)
		else
			string_rep[i] = sp.string_to_table ( string_rep[i] )
			for j=#string_rep[i]+1, problem.dim.x, 1 do
				string_rep[i][j]="_"
			end
		end
	end
	return string_rep
end

function sp.string_to_table ( str )
	local t = {}
	str:gsub(".",function(c) table.insert(t,c) end)
	return t
end

-- 0:east - 3:south
function sp.get_direction_of_entrance( puzzle_table, dimensions )
	-- check left and right side
	for i=1, #puzzle_table do
		if puzzle_table[i][1] == "@" then return 2 end
		if puzzle_table[i][dimensions.x] == "@" then return 0 end
	end
	-- check top and bottom side
	for i=1, #puzzle_table[1] do
		if puzzle_table[1][i] == "@" then return 1 end
		if puzzle_table[dimensions.y][i] == "@" then return 3 end
	end
end

function sp.get_sorted_list_of_objects( puzzle_table, area ) -- objects are all 16 x 16
	log.debug("get_sorted_list_of_objects")
	local conversion_table = { ["@"]={"entrance"}, ["#"]={"wall"}, ["*"]={"block", "goal"}, ["$"]={"block"}, ["."]={"goal"}, ["_"]={"floor"}, ["E"]={"exit"}, ["R"]={"reset"} }
	local output_table = { ["wall"]={}, ["floor"]={}, ["block"]={}, ["goal"]={}, ["entrance"]={}, ["exit"]={}, ["reset"]={} }
	for i,row in ipairs(puzzle_table) do
		for j,node in ipairs(row) do
			for _,output_type in ipairs(conversion_table[node]) do
				table.insert(output_table[output_type], {x1=area.x1+(j-1)*16, x2=area.x1+j*16, y1=area.y1+(i-1)*16, y2=area.y1+i*16})
			end
		end
	end
	return output_table
end

function sp.place_sokoban_puzzle( map, area_list, puzzle_area, areanumber, difficulty )
	log.debug("place_sokoban_puzzle")
	-- place normal blocks as walls, cannot be pushed
	for _, area in ipairs(area_list.wall) do
		local wall_block = table_util.copy(sp.prop_types.wall_block)
		wall_block.x, wall_block.y = wall_block.x+area.x1, wall_block.y+area.y1
		map:create_block(wall_block)
	end
	local block_stopper = table_util.copy(sp.prop_types.reset_wall)
	block_stopper.x, block_stopper.y = block_stopper.x+area_list.entrance[1].x1, block_stopper.y+area_list.entrance[1].y1
	map:create_wall(block_stopper)
	-- place switch at entrance for resetting 
	local next_index = sp.get_next_available_index( )
	local reset_switch = table_util.copy(sp.prop_types.reset_switch)
	reset_switch.name = "reset_switch_"..next_index
	reset_switch.x, reset_switch.y = reset_switch.x+area_list.entrance[1].x1, reset_switch.y+area_list.entrance[1].y1
	reset_switch = map:create_switch(reset_switch)
	map:create_destination{name="reset_destination_"..next_index,layer=0, x=area_list.entrance[1].x1+8, y=area_list.entrance[1].y1+13, direction=0, default=false}
	for _, tp in ipairs(area_list.reset) do
		map:create_teletransporter{name="reset_teleport_"..next_index, layer=0, x=tp.x1, y=tp.y1, width=16, height=16, sprite="entities/teletransporter", sound="warp", destination_map=map:get_id(), destination="reset_destination_"..next_index}
		block_stopper.x, block_stopper.y = tp.x1, tp.y1
		map:create_wall(block_stopper)
	end
	sp.puzzles_created[next_index] = area_list
	local sensor = placement.place_sensor( puzzle_area, "sokoban_sensor_"..areanumber )
	sensor.on_activated = function () puzzle_logger.start_recording("sokoban", areanumber, difficulty) end
	sensor.on_left = function () puzzle_logger.stop_recording(); map.message = nil	end
	sensor.on_activated_repeat =
		function()
			if sol.input.is_key_pressed("q") and puzzle_logger.over_time_limit() then
				log.debug("pressed_quit")
				local index = next_index
				if puzzle_logger.pressed_quit() then sp.remove_sokoban( index, map ); map.message = nil end
			end
			if puzzle_logger.over_time_limit() then
				-- show message
				map.message = "Optional: Press Q to quit puzzle"
			end
		end
	reset_switch.on_activated = 
		function() 
			if puzzle_logger.can_reset_puzzle() then
				puzzle_logger.retry()
			end
			local index = next_index
			local map = map
			for sokoban_object in map:get_entities("sokoban_"..index) do
				sokoban_object:remove()
			end
			local area_list = sp.puzzles_created[index]
			-- place switches,
			for i, area in ipairs(area_list.goal) do
				local block_switch = table_util.copy(sp.prop_types.block_switch)
				block_switch.name = "sokoban_"..index.."_"..block_switch.name.."_"..i
				block_switch.x, block_switch.y = block_switch.x+area.x1, block_switch.y+area.y1
				local switch = map:create_switch(block_switch)
				switch.on_activated = 
					function ( )
						sp.check_switches(index, map, nr_of_switches)
					end
			end
			-- place gray blocks as movable blocks, infinite moves, can only be pushed
			for _, area in ipairs(area_list.block) do
				local move_block = table_util.copy(sp.prop_types.move_block)
				move_block.name = "sokoban_"..index.."_"..move_block.name
				move_block.x, move_block.y = move_block.x+area.x1, move_block.y+area.y1
				local block = map:create_block(move_block)
				block.on_moved = function () puzzle_logger.made_first_move() end
			end
			-- place wall for the blocks at the entrance
			for _, area in ipairs(area_list.exit) do
				local exit_block = table_util.copy(sp.prop_types.exit_block)
				exit_block.name = "sokoban_"..index.."_"..exit_block.name
				exit_block.x, exit_block.y = exit_block.x+area.x1, exit_block.y+area.y1
				map:create_block(exit_block)
			end
			-- logging retries and start time
		end
end

-- sokoban_1_wall_block_1
function sp.get_next_available_index( )
	return #sp.puzzles_created+1
end

function sp.check_switches( index, map, nr_of_switches )
	for switch in map:get_entities("sokoban_"..index.."_block_switch") do
		if not switch:is_activated() then return end
	end
	sp.remove_sokoban( index, map )
	-- log completion of sokoban puzzle 
	puzzle_logger.complete_puzzle()
end

function sp.remove_sokoban( index, map )
	for sokoban_object in map:get_entities("sokoban_"..index) do
		sokoban_object:remove()
	end
	if map:has_entity("reset_switch_"..index) then
		local reset_switch = map:get_entity("reset_switch_"..index)
		reset_switch:remove()
	end
end


function sp.rotate_puzzle_to_direction( from_direction, to_direction, puzzle_table )
	log.debug("rotate_puzzle_to_direction")
	-- example from 0 to 3 | (7-0)%4 = 3 or from 3 to 0 then (4-3)%4 = 1
	local rotated_table = puzzle_table
	local rotations = (to_direction+4-from_direction)%4
	for i=1, rotations do
	 	rotated_table = sp.rotate_table_ccw( rotated_table )
	end 
	return rotated_table
end

function sp.rotate_table_ccw( tbl )
	local max_y, max_x = #tbl, #tbl[1]
	local rotated_table = {}
	for x=1, max_x do
		for y=1, max_y do
			rotated_table[max_x-(x-1)] = rotated_table[max_x-(x-1)] or {}
			rotated_table[max_x-(x-1)][y]=tbl[y][x]
		end
	end
	return rotated_table
end

function sp.make( parameters )
	local p = parameters
	sp.create_sokoban_puzzle( p.difficulty, p.area, p.areanumber, p.area_details, p.exit_areas, p.exclusion ) 
end


function sp.create_sokoban_puzzle( difficulty, area, areanumber, area_details, exit_areas, exclusion )
	local map = area_details.map
	if not map:get_entity("sokoban_sensor_"..areanumber) then
		explore.puzzle_encountered()
		maze_gen.set_map( map )
		local cw, ww = {x=16, y=16}, {x=0, y=0}
		maze_gen.set_room( area, cw, ww, "sokoban_room"..areanumber )
		local maze, exits = maze_gen.generate_maze( area, exit_areas, exclusion)
		local area_list, puzzle_area = sp.put_in_sokoban_puzzle( area, difficulty, maze, exits[1], cw, ww, areanumber )
		sp.place_sokoban_puzzle( map, area_list, puzzle_area, areanumber, difficulty )
		if area_list then 
			exits[1] = sp.connect_to_maze( area_list, maze, exits[1] ) 
		end
		local convergence_pos = exits[1][#exits[1]]
		maze_gen.create_initial_paths( maze, exits, convergence_pos )
		if not area_details.outside then
			sp.make_room_at_exits(maze, exits)
		end
		local prop_area_list = maze_gen.maze_to_square_areas( maze, false )
		local open_area_list = maze_gen.maze_to_square_areas( maze, true )
		sp.place_props( prop_area_list, area_details.outside, puzzle_area )
	end
end

function sp.make_room_at_exits(maze, exits)
	for i=2, #exits do
		local topleft = {x=exits[i][1].x-2, y=exits[i][1].y-2}
		local bottomright = {x=exits[i][#exits[i]].x+2, y=exits[i][#exits[i]].y+2 }
		maze_gen.open_up_area( maze, topleft, bottomright )
	end
end

function sp.put_in_sokoban_puzzle( area, difficulty, maze, maze_entrance, corridor_width, wall_width, areanumber )
	local original_difficulty = difficulty
	local difficulty = difficulty
	local problem
	local tried_once_before = false
	repeat
		problem = sp.get_random_sized_sokoban_puzzle( difficulty )
		if not problem then

			if tried_once_before then difficulty = difficulty + 1
			else difficulty = difficulty - 1 end

			if difficulty == 0 and not tried_once_before then 
				difficulty = original_difficulty + 1
				tried_once_before = true
			end

		end
	until problem or difficulty == 6
	if difficulty == 6 then return {entrance={x=1, y=1}, exit={x=2, y=1}}, {x1=area.x1, y1=area.y1, x2=area.x1+2*16, y2=area.y1+16} end
	if difficulty < original_difficulty then puzzle_logger.below_difficulty_setting("sokoban", difficulty, areanumber)
	elseif difficulty > original_difficulty then puzzle_logger.above_difficulty_setting("sokoban", difficulty, areanumber)
	end


	local puzzle = sp.get_corrected_puzzle_table( problem, maze_entrance.direction )
	local ww, cw = wall_width, corridor_width
	local size_x, size_y = #puzzle[1], #puzzle
	local required_x, required_y = math.ceil(size_x * 16 / (ww.x+cw.x)), math.ceil( size_y * 16 / (cw.y+ww.y)) 
	local maze_x, maze_y = #maze, #maze[1]
	if required_x > maze_x - 2 or required_y > maze_y -2 then 
		puzzle = sp.rotate_table_ccw( puzzle )
		size_x, size_y = #puzzle[1], #puzzle 
		required_x, required_y = math.ceil(size_x * 16 / (ww.x+cw.x)), math.ceil( size_y * 16 / (cw.y+ww.y)) 
	end
	-- placed at the entrance, so we have more room for other stuff
	local topleft_pos = {x=maze_entrance[#maze_entrance].x, y=maze_entrance[#maze_entrance].y}
	if maze_entrance.direction == 0 then 		topleft_pos.x = topleft_pos.x - required_x; topleft_pos.y = topleft_pos.y - math.ceil(required_y/2)
	elseif maze_entrance.direction == 1 then 	topleft_pos.x = topleft_pos.x - math.ceil(required_x/2); topleft_pos.y = topleft_pos.y + 1
	elseif maze_entrance.direction == 2 then 	topleft_pos.x = topleft_pos.x +1; topleft_pos.y = topleft_pos.y - math.ceil(required_y/2)
	elseif maze_entrance.direction == 3 then 	topleft_pos.x = topleft_pos.x - math.ceil(required_x/2); topleft_pos.y = topleft_pos.y - required_y end
	local bottomright_pos = {x=topleft_pos.x+required_x-1, y=topleft_pos.y+required_y-1}
	maze_gen.open_up_area( maze, topleft_pos, bottomright_pos )
	-- convert into areas and place
	local puzzle_area = {x1=0, y1=0, x2=size_x*16, y2=size_y*16}
	puzzle_area = area_util.move_area(puzzle_area, area.x1, area.y1)
	puzzle_area = area_util.move_area(puzzle_area, (topleft_pos.x-1)*16, (topleft_pos.y-1)*16)
	local area_list = sp.get_sorted_list_of_objects( puzzle, maze_gen.nodes_to_area( topleft_pos, bottomright_pos, true ) )
	return area_list, puzzle_area
end

function sp.connect_to_maze( area_list, maze, maze_entrance )
	-- open up exits in the maze for the sokoban puzzle
	local sokoban_entrance_area, sokoban_exit_area = area_list.entrance[1], area_list.exit[1]
	local entrance_addition = area_util.get_side(area_list.entrance[1], maze_entrance.direction, 24, 8)
	local exit_addition = area_util.get_side(area_list.exit[1], (maze_entrance.direction+2)%4, 24, 8)

	local entrance_pos_list = maze_gen.area_to_pos (  area_util.merge_areas(sokoban_entrance_area, entrance_addition) )
	local exit_pos_list = maze_gen.area_to_pos (  area_util.merge_areas(sokoban_exit_area, exit_addition) )

	maze_gen.open_up_area( maze, entrance_pos_list[1], entrance_pos_list[#entrance_pos_list] )
	maze_gen.open_up_area( maze, exit_pos_list[1], exit_pos_list[#exit_pos_list] )

	local sb_entrance_pos_list = maze_gen.area_to_pos ( entrance_addition )
	local sb_exit_pos_list = maze_gen.area_to_pos ( exit_addition )

	-- create path from first exit to sokoban entrance
	local pos1, pos2 = maze_gen.get_closest_positions(maze_entrance, sb_entrance_pos_list)

	maze_gen.open_path( maze, maze_gen.create_direct_path( pos1, pos2, maze ) )

	return sb_exit_pos_list
end

function sp.place_props( area_list, outside, puzzle_area )
	if outside then
		puzzle_center_x = (puzzle_area.x2+puzzle_area.x1)/2
		puzzle_center_y = (puzzle_area.y2+puzzle_area.y1)/2
		local filler_ruins = {{"old_prison"}, {"stone_hedge"}, {"blue_block"}}
		local filler_large = {{"green_tree"}, {"flower1", "flower2", "halfgrass", "fullgrass"}}
		for _,area in ipairs(area_list) do
			center_x = (area.x2+area.x1)/2
			center_y = (area.y2+area.y1)/2
			if math.abs(center_x-puzzle_center_x)+math.abs(center_y-puzzle_center_y) < 150 then
				placement.spread_props(area, 0, filler_ruins, 1)
			else
				placement.spread_props(area, 16, filler_large, 1)
			end
		end
	else
		for _,area in ipairs(area_list) do
			placement.place_tile(area, 420, "sokoban_room_spikes", 0)
		end
	end
end



return sp
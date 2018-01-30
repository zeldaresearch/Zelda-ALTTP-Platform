lookup 			= lookup or require("data_lookup")
placement 		= placement or require("object_placement")
puzzle_logger 	= puzzle_logger or require("puzzle_logger")


local log = require("log")
local table_util = require("table_util")
local area_util = require("area_util")
local num_util = require("num_util")


local maze_gen = {}

------------------------------------------------------------------------------------------------------------------------------
-------------------------------------       General purpose functions       --------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------


local map
local room

-- direction (number): between 0 (East of the room) and 3 (South of the room).

function maze_gen.set_map( given_map )
	map = given_map
end

function maze_gen.set_room( area, corridor_width, wall_width, name_prefix )
	room = table_util.copy(area)
	if type(corridor_width) == "table" then room.corridor_width = corridor_width
	else room.corridor_width = {x=corridor_width, y=corridor_width} end
	if type(wall_width) == "table" then room.wall_width = wall_width
	else room.wall_width = {x=wall_width, y=wall_width} end
	room.name_prefix = name_prefix or "space"
end

------------------------------------------------------------------------------------------------------------------------------
-------------------------------------           Utility functions           --------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------

function maze_gen.get_neighbors_from_pos_list( maze, pos_list, get_not_visited )
	local neighbors = {}
	for _, pos in ipairs(pos_list) do
		table_util.add_table_to_table( maze_gen.get_neighbors(maze, pos, get_not_visited), neighbors )
	end
	return neighbors
end

function maze_gen.get_most_isolated_neighbor( maze, neighbors )
	local ranking = {}
	local highest_rank = 0
	for _,nb in ipairs(neighbors) do
		local first_degree_neighbors = maze_gen.get_neighbors(maze, nb.pos, true)
		local second_degree_neighbors = {}
		for _, nb2 in ipairs(first_degree_neighbors) do
			table_util.add_table_to_table( maze_gen.get_neighbors(maze, nb2.pos, true), second_degree_neighbors )
		end
		local nr_of_second_degree_nb = #second_degree_neighbors
		if nr_of_second_degree_nb > highest_rank then highest_rank = nr_of_second_degree_nb end
		ranking[nr_of_second_degree_nb] = ranking[nr_of_second_degree_nb] or {}
		table.insert(ranking[nr_of_second_degree_nb], nb)
	end
	local selected_nb
	log.debug("ranking:")
	log.debug(ranking)
	for i=highest_rank, 0, -1 do
		if ranking[i] and #ranking[i] > 0 then 
			selected_nb = ranking[i][1]; break
		end
	end
	return selected_nb
end

function maze_gen.close_path( maze, path )
	for i = 1, #path-1, 1 do
		local from, to
		if path[i+1].x > path[i].x then from, to = 2, 0
		elseif path[i+1].x < path[i].x then from, to = 0, 2
		elseif path[i+1].y > path[i].y then from, to = 1, 3
		elseif path[i+1].y < path[i].y then from, to = 3, 1 end
		maze[path[i].x][path[i].y][to]= true
 		maze[path[i+1].x][path[i+1].y][from]= true
        maze[path[i+1].x][path[i+1].y].visited = false
	end
end

function maze_gen.nodes_to_area( pos1, pos2, without_surrounding_walls )
	local topleft_pos, bottomright_pos
	if pos1.x <= pos2.x and pos1.y <= pos2.y then
		topleft_pos, bottomright_pos = pos1, pos2
	else
		topleft_pos, bottomright_pos = pos2, pos1
	end
	local cw = room.corridor_width
	local ww = room.wall_width
	local eww = {x=0, y=0}
	if without_surrounding_walls then eww = ww end
	return {x1=(topleft_pos.x-1)*(cw.x+ww.x)+eww.x+room.x1,
			x2=bottomright_pos.x*(cw.x+ww.x)+ww.x-eww.x+room.x1,
			y1=(topleft_pos.y-1)*(cw.y+ww.y)+eww.y+room.y1,
			y2=bottomright_pos.y*(cw.y+ww.y)+ww.y-eww.y+room.y1}
end

function maze_gen.exclude( maze, exclusion )
	for _, exclusion_area in ipairs(exclusion) do
		local pos_list = maze_gen.area_to_pos ( exclusion_area )
		local max_x, max_y= #maze, #maze[1]
		for _, pos in ipairs(pos_list) do
			if not (pos.x < 1 or pos.x > max_x or pos.y < 1 or pos.y > max_y) then
				maze[pos.x][pos.y].visited = "excluded"
			end
		end
	end
end

function maze_gen.area_to_pos ( area )
	local pos_list = {}
	local cw = room.corridor_width
	local ww = room.wall_width
	local x1 = math.floor((area.x1-room.x1)/(cw.x+ww.x))+1
	local x2 = math.ceil((area.x2-room.x1-ww.x)/(cw.x+ww.x))
	local y1 = math.floor((area.y1-room.y1)/(cw.y+ww.y))+1
	local y2 = math.ceil((area.y2-room.y1-ww.y)/(cw.y+ww.y))
	for x=x1, x2 do
		for y=y1, y2 do
			table.insert(pos_list, {x=x, y=y})
		end
	end
	return pos_list
end 

function maze_gen.initialize_maze( maze, area, wall_width, corridor_width, initial_wall_value )
	initial_wall_value = initial_wall_value or false
	wall_width = wall_width or room.wall_width
	corridor_width = corridor_width or room.corridor_width
	area = area or room
	local width = area.x2-area.x1
	local height = area.y2-area.y1
	local x_amount = math.floor((width-wall_width.x)/(wall_width.x+corridor_width.x))
	local y_amount = math.floor((height-wall_width.y)/(wall_width.y+corridor_width.y))
	for x=1,x_amount do
		maze[x]={}
		for y=1, y_amount do
			maze[x][y] = {[1]=initial_wall_value, [2]=initial_wall_value, [3]=initial_wall_value, [0]=initial_wall_value, visited = false} 
		end
	end
end

function maze_gen.place_walls_around( maze, pos_list )
	local max_x, max_y= #maze, #maze[1]
	for _, pos in ipairs(pos_list) do
		local node = maze[pos.x][pos.y]
		local neighbors = maze_gen.get_neighbors( maze, pos)
		if 		pos.x == 1 then 	node[2] = true 
		elseif 	pos.x == max_x then node[0] = true end
		if 		pos.y == 1 then 	node[1] = true 
		elseif 	pos.y == max_y then node[3] = true end
		for _, n in ipairs(neighbors) do
			node[n.wall_to] = true
			n.node[n.wall_from]=true
		end
	end
end

function maze_gen.open_unvisited( maze )
	local unvisited = maze_gen.get_not_visited( maze )
	for _, u in ipairs(unvisited) do
		local neighbors = maze_gen.get_neighbors(maze, u)
		for _, n in ipairs(neighbors) do
			maze_gen.open_path(maze, {n.from_pos, n.pos})
		end
	end
end

function maze_gen.open_exits( maze, exit_areas, extra_width, area, wall_width, corridor_width )
	local wall_width = wall_width or room.wall_width
	local corridor_width = corridor_width or room.corridor_width
	local area = area or room
	local extra_width = extra_width or 0
	local width = area.x2-area.x1
	local height = area.y2-area.y1
	local exits = {}
	for _, v in ipairs(exit_areas) do
		-- identify in which node the exit area is located
		local x1 = (v.x1-area.x1)/(wall_width.x+corridor_width.x)
		local y1 = (v.y1-area.y1)/(wall_width.y+corridor_width.y)
		local x2 = (v.x2-area.x1-wall_width.x)/(wall_width.x+corridor_width.x)
		local y2 = (v.y2-area.y1-wall_width.y)/(wall_width.y+corridor_width.y)

		local selected_x_min = num_util.clamp(math.ceil(x1)-extra_width, 1, #maze)
		local selected_x_max = num_util.clamp(math.ceil(x2)+extra_width, 1, #maze)
		local selected_y_min = num_util.clamp(math.ceil(y1)-extra_width, 1, #maze[1])
		local selected_y_max = num_util.clamp(math.ceil(y2)+extra_width, 1, #maze[1])
		
		local direction = v.direction or nil
		-- direction (number): between 0 (East of the room) and 3 (South of the room).
		if direction == 0 then selected_x_max=#maze;selected_x_min=#maze 
		elseif direction == 1 then selected_y_max=1;selected_y_min=1 
		elseif direction == 2 then selected_x_max=1;selected_x_min=1 
		elseif direction == 3 then selected_y_max=#maze[1];selected_y_min=#maze[1] 
		else 
			if v.y2 <= area.y1 and v.x1 < area.x2 and v.x2 > area.x1 then direction = 1 end
			if v.y1 >= area.y2 and v.x1 < area.x2 and v.x2 > area.x1 then direction = 3 end
			if v.x2 <= area.x1 and v.y1 < area.y2 and v.y2 > area.y1 then direction = 2 end
			if v.x1 >= area.x2 and v.y1 < area.y2 and v.y2 > area.y1 then direction = 0 end
		end

		-- create an entrance/exit area spanning from the min to the max of the exit
		local exit_nodes = {}
		log.debug("xmin:"..selected_x_min..", xmax:"..selected_x_max..", ymin:"..selected_y_min..", ymax:"..selected_y_max)
		log.debug("maze_x:"..#maze..", maze_y:"..#maze[1])
		for x=selected_x_min, selected_x_max, 1 do
			for y=selected_y_min, selected_y_max, 1 do
				maze[x][y][direction] = false
				maze[x][y].visited = true
				table.insert(exit_nodes, {x=x, y=y})
			end
		end
		maze_gen.open_path(maze, exit_nodes)
		exit_nodes.direction = direction
		table.insert(exits, exit_nodes)
	end
	return exits
end

-- direction (number): between 0 (East of the room) and 3 (South of the room).
function maze_gen.get_neighbors(maze, position, only_get_unvisited)
	local neighbors={}
	if position.x < #maze then neighbors[#neighbors+1]={pos={x=position.x+1, y=position.y}, node=maze[position.x+1][position.y], wall_to=0, wall_from=2, from_pos=position} end
	if position.x > 1 then neighbors[#neighbors+1]={pos={x=position.x-1, y=position.y}, node=maze[position.x-1][position.y], wall_to=2, wall_from=0, from_pos=position} end
	if position.y < #maze[1] then neighbors[#neighbors+1]={pos={x=position.x, y=position.y+1},node=maze[position.x][position.y+1], wall_to=3, wall_from=1, from_pos=position} end
	if position.y > 1 then neighbors[#neighbors+1]={pos={x=position.x, y=position.y-1},node=maze[position.x][position.y-1], wall_to=1, wall_from=3, from_pos=position} end
	if only_get_unvisited then
		for i=#neighbors,1,-1 do
			if neighbors[i].node.visited then table.remove(neighbors, i) end
		end
	end
	return neighbors
end

-- if width contains decimals it will grab one extra row and column on the bottomleft side
function maze_gen.get_nodes_around_pos(maze, position, width, only_get_unvisited)
	local nodes = {}
	local pos_list = {}
	for x=position.x-math.ceil(width), position.x+math.floor(width) do
		if maze[x] then
			for y=position.y-math.ceil(width), position.y+math.floor(width) do
				if maze[x][y] and ( not only_get_unvisited or not maze[x][y].visited )then
					table.insert(pos_list, {x=x, y=y})
					table.insert(nodes, maze[x][y])
				end
			end
		end
	end
	return nodes, pos_list
end

function maze_gen.pos_to_area( pos )
	local x1 = room.x1 + room.wall_width.x + (pos.x-1)*(room.wall_width.x+room.corridor_width.x)
	local y1 = room.y1 + room.wall_width.y + (pos.y-1)*(room.wall_width.y+room.corridor_width.y)
	local x2 = room.x1 + pos.x*(room.wall_width.x+room.corridor_width.x)
	local y2 = room.y1 + pos.y*(room.wall_width.y+room.corridor_width.y)
	return {x1=x1, x2=x2, y1=y1, y2=y2}
end


function maze_gen.check_straight_length( maze, branch )
	local pos_a = branch[1]
	local pos_b = branch[2]
	local direction, last_direction
	local straight_length = 0
	for i=2,#branch do
		pos_a = branch[i-1]
		pos_b = branch[i]
		if pos_a.x ~= pos_b.x then direction = "v" else direction = "h" end
		if last_direction == nil then last_direction = direction; straight_length = straight_length + 1
		elseif last_direction ~= direction or maze[pos_b.x][pos_b.y].prop then return straight_length
		else straight_length = straight_length + 1 end
	end
	return straight_length
end

function maze_gen.create_straight_branch( maze, correct_path, length, from )
	-- log.debug("creating straight branch")
	local possible_branches = {}
	-- random, but exhaustive, until one has been found
	local pos_list = table_util.copy(correct_path) 
	-- log.debug(pos_list)
	table_util.shuffleTable( pos_list )
	if from then table.insert(pos_list, 1, from) end
	for _,pos in ipairs(pos_list) do
		local path
		path=maze_gen.check_straight_path( maze, pos, {x=pos.x+length, y=pos.y} )
		if path then table.insert(possible_branches, path) end
		path=maze_gen.check_straight_path( maze, pos, {x=pos.x-length, y=pos.y} )
		if path then table.insert(possible_branches, path) end
		path=maze_gen.check_straight_path( maze, pos, {x=pos.x, y=pos.y+length} )
		if path then table.insert(possible_branches, path) end
		path=maze_gen.check_straight_path( maze, pos, {x=pos.x, y=pos.y-length} )
		if path then table.insert(possible_branches, path) end
		if next(possible_branches) ~= nil then break end
	end
	if next(possible_branches) == nil then
		-- log.debug("failed to create")
	 	return nil 
	end
	-- IF FOUND
	-- pick a branch
	local branch = possible_branches[math.random(#possible_branches)]
	-- open path
	maze_gen.open_path(maze, branch)
	-- log.debug("create straight branch success")
	return branch
end



-- check_straight_path always ignores the first node
function maze_gen.check_straight_path( maze, from, to )
	local path = {from}
	if from.x == to.x or from.y == to.y then
		local stepsize_x, stepsize_y = 1, 1
		if from.x > to.x then stepsize_x = -1 end
		if from.y > to.y then stepsize_y = -1 end
		local offset_x, offset_y = 0, 0
		if from.x == to.x then offset_y = stepsize_y end
		if from.y == to.y then offset_x = stepsize_x end
		for x=from.x+offset_x, to.x, stepsize_x do
			for y=from.y+offset_y, to.y, stepsize_y do
				if not maze[x] or not maze[x][y] or maze[x][y].visited == true then 
					return false 
				else
					table.insert(path, {x=x, y=y})
				end
			end
		end
	else
		error("check_straight_path: Expected aligned from and to")
		return false
	end
	return path
end

function maze_gen.place_wall_between( pos1, pos2, maze )
	local neighbors = maze_gen.get_neighbors(maze, pos1)
	for k,v in ipairs(neighbors) do
		if table_util.tbl_contains_tbl(v.pos, pos2) then 
			maze[v.pos.x][v.pos.y][v.wall_from] = true
			maze[pos1.x][pos1.y][v.wall_to] = true
			return true
		end
	end
	return false
end

function maze_gen.create_initial_paths( maze, exits, convergence_pos )
	log.debug("create_initial_paths")
	local starting_point
	if convergence_pos == nil then
		local possible_nodes, nr_of_nodes = maze_gen.get_not_visited(maze) 
		local viable_positions, v_pos_nr = {}, 0
		local min_dist_required = math.floor(0.4 * (0.5 * #maze + 0.5 * #maze[1]))--at least 40% of the maze size away from the exits
		for _, pos in ipairs(possible_nodes) do
			local add_node = true
			for _, exit in ipairs(exits) do
				if maze_gen.distance(pos, table_util.random(exit)) < min_dist_required then add_node = false end
			end
			if add_node then 
				v_pos_nr = v_pos_nr +1
				viable_positions[v_pos_nr] = pos
			end
		end
		starting_point = table_util.random(viable_positions)
	else
		starting_point = convergence_pos
	end

	local paths = {}
	for index, exit_list in ipairs(exits) do
		local _, exit = maze_gen.get_closest_positions( {starting_point}, exit_list )
		local found_path = maze_gen.create_direct_path( starting_point, exit , maze )
		log.debug("found_path")
		log.debug(found_path)
		if not found_path and next(paths) ~= nil then -- will fail if the starting point is in a closed off area of the maze 
			local min_dist = maze_gen.distance(starting_point, exit)
			local next_start = starting_point

			for _,path in ipairs(paths) do
				for _,pos in ipairs(path) do
					local dist = maze_gen.distance(pos, exit)
					if dist < min_dist then 
						min_dist = dist
						next_start = pos 
					end
				end
			end
			found_path = maze_gen.create_direct_path( next_start, exit , maze )
			log.debug("found_path")
			log.debug(found_path)
			-- sanity check
			-- if not found_path then log.debug("maze_gen no found path... what, why not?!")	end	
		end
		table.insert(paths, found_path)
	end
	for _,path in ipairs(paths) do
		maze_gen.open_path( maze, path )
	end
	return paths
end

function maze_gen.find_closest_node( maze, to_pos, paths )
	local result
	local min_dist = math.huge
	for _,path in ipairs(paths) do
		for _,pos in ipairs(path) do
			local dist = maze_gen.distance(pos, to_pos)
			if dist < min_dist then 
				local neighbors = maze_gen.get_neighbors( maze, pos, true)
				for _, nb in ipairs(neighbors) do
					local dist_nb = maze_gen.distance(nb.pos, to_pos)
					if dist_nb < dist then
						min_dist = dist 
						result = pos 
						break
					end
				end
			end
		end
	end
	return result
end

-- direction (number): between 0 (East of the room) and 3 (South of the room).
function maze_gen.open_path( maze, path, custom_value )
	if not path then return end
	for i = 1, #path-1, 1 do
		local from, to
		if path[i+1].x > path[i].x then from, to = 2, 0
		elseif path[i+1].x < path[i].x then from, to = 0, 2
		elseif path[i+1].y > path[i].y then from, to = 1, 3
		elseif path[i+1].y < path[i].y then from, to = 3, 1 end
		if to then maze[path[i].x][path[i].y][to]= custom_value or false end
 		if from then maze[path[i+1].x][path[i+1].y][from]=custom_value or false end
        maze[path[i+1].x][path[i+1].y].visited = true
	end
end

function maze_gen.get_not_visited( maze )
	return maze_gen.get_nodes_with_visit_status( maze, false )
end

function maze_gen.get_nodes_with_visit_status( maze, visit_status )
	local n = 0
	local result = {}
	for x=1, #maze do
		for y=1, #maze[1] do
			if maze[x][y].visited == visit_status then 
				n=n+1
				result[n] = {x=x, y=y}
			end
		end
	end
	return result, n
end
 
function maze_gen.create_direct_path( from, to, maze )
	local maze_copy = table_util.copy(maze)
	maze_copy[from.x][from.y].visited=true
	local path = {from}
	local current_pos = from
	local done = false
	if maze_gen.distance(from, to) == 0 then return path end
	repeat
		local next_nb = nil
		local neighbors = maze_gen.get_neighbors(maze_copy, current_pos, false)
		for i=1, #neighbors, 1 do
			local nb = neighbors[i]
			local dist = maze_gen.distance(nb.pos, to)
			if dist == 0 then next_nb=nb; done=true; break end
		end
		if not done then 
			local unvisited = maze_gen.get_neighbors(maze_copy, current_pos, true)
			if #unvisited == 0 then 
				repeat
					table.remove(path)
					local path_length = #path
					if path_length == 0 then return false end
					neighbors = maze_gen.get_neighbors(maze_copy, path[path_length], false)
					unvisited = maze_gen.get_neighbors(maze_copy, path[path_length], true)
				until #unvisited ~= 0
			else
				table_util.shuffleTable(neighbors)
			end 
			local min_dist = math.huge
			for i=1, #neighbors, 1 do
				local nb = neighbors[i]
				local dist = maze_gen.distance(nb.pos, to)
				if dist < min_dist and nb.node.visited == false then min_dist=dist; next_nb=nb end
			end
		end
		table.insert(path, next_nb.pos); current_pos = next_nb.pos
		maze_copy[current_pos.x][current_pos.y].visited=true
	until done

	return path
end

function maze_gen.distance( pos1, pos2 )
	return math.abs(pos1.x - pos2.x)+math.abs(pos1.y - pos2.y)
end


------------------------------------------------------------------------------------------------------------------------------
-------------------------------------      Level generation functions       --------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------


function maze_gen.generate_rooms( area_details )
	local width, height = map:get_size(); local corridor_width = room.corridor_width; local wall_width = room.wall_width
	local maze = {}
	maze_gen.initialize_maze( maze, room, wall_width, corridor_width )
	maze_gen.place_walls_around( maze, maze_gen.get_not_visited( maze ) )
	local start_pos = {x=1, y=math.floor(#maze[1]/2)}-- entrance is always west center
	maze[start_pos.x][start_pos.y].visited = true
	if not area_details.outside then
		maze[start_pos.x][start_pos.y+1].visited = true
	end	if area_details.outside then 
		maze[start_pos.x][start_pos.y][2] = "other_map" -- exit to the left because the witch hut exit is to the right
	else
		maze[start_pos.x][start_pos.y][3] = "other_map" -- exit to the bottom because of the tile for the exit
	end
	maze_gen.recursive_rooms( maze, area_details, "start", start_pos )
	return maze_gen.create_room_list( maze, corridor_width, {x=wall_width.x/2, y=wall_width.y/2} )
end

-- direction (number): between 0 (East of the room) and 3 (South of the room).
-- area size = 1, 2, or 4
function maze_gen.recursive_rooms( maze, area_details, areanumber, pos )
	-- if the area contains multiple tasks then we assign multiple nodes in random directions
	local area_size = area_details.area_size
	maze[pos.x][pos.y].areanumber = areanumber
	-- expand the area if P or F
	local room_positions={pos}
	local area_type = area_details[areanumber].area_type
	if table_util.contains({"F", "TF"}, area_type) and area_size > 1 or table_util.contains({"BOSS", "P", "TP"}, area_type) then
		if area_size >= 2 or table_util.contains({"BOSS", "P", "TP"}, area_type) then
			local neighbors = maze_gen.get_neighbors(maze, pos, true)
			local second_neighbor = maze_gen.get_most_isolated_neighbor( maze, neighbors )
			room_positions[2] = second_neighbor.pos
			second_neighbor.node.areanumber = areanumber

			maze_gen.open_path(maze, {pos, second_neighbor.pos}, "opening")
			local first_node_neighbors = maze_gen.get_neighbors(maze, pos, true)
			local second_node_neighbors = maze_gen.get_neighbors(maze, second_neighbor.pos, true)

			if area_size == 4 or area_details[areanumber].area_type == "BOSS" then

				local second_degree_neighbors_of_first_node = {}
				for _, nb in ipairs(first_node_neighbors) do
					table_util.add_table_to_table( maze_gen.get_neighbors(maze, nb.pos, true), second_degree_neighbors_of_first_node )
				end

				-- now match the second_node_neighbors with the second_degree_neighbors_of_first_node
				local found_match = false
				for _, nb1 in ipairs(second_node_neighbors) do -- use the node pos on this
					for _, nb2 in ipairs(second_degree_neighbors_of_first_node) do -- use the from pos with this one
						if nb1.pos.x == nb2.pos.x and nb1.pos.y == nb2.pos.y then
							found_match = true
							local third_node = nb1
							local fourth_node = maze[nb2.from_pos.x][nb2.from_pos.y]
							room_positions[3] = nb1.pos
							room_positions[4] = nb2.from_pos
							third_node.node.areanumber = areanumber
							fourth_node.areanumber = areanumber

							maze_gen.open_path(maze, {pos, nb2.from_pos, nb1.pos, second_neighbor.pos}, "opening")
							break
						end
					end
					if found_match then break end
				end
			end
		end
	end
	-- find new nodes for the next rooms
	if areanumber ~= "goal" and areanumber ~= "optionalgoal" then
		for _,connection in ipairs(area_details[areanumber]) do
			local neighbors = maze_gen.get_neighbors_from_pos_list( maze, room_positions, true )
			-- create the room with a given size
			local selected_nb = maze_gen.get_most_isolated_neighbor( maze, neighbors )
			local from = selected_nb.from_pos
			local to = selected_nb.pos

			maze[from.x][from.y][selected_nb.wall_to] = "exit"
			maze[to.x][to.y][selected_nb.wall_from] = "entrance"
			maze[to.x][to.y].visited = true
			maze_gen.recursive_rooms( maze, area_details, connection.areanumber, selected_nb.pos )
		end
	elseif area_details.outside then
		for _,i in ipairs({0, 1, 2, 3}) do
			if maze[pos.x][pos.y][i] == true then -- exit to the right to the mine entrance
				maze[pos.x][pos.y][i]="other_map" 
				break
			end
		end
	else
		for _,i in ipairs({3, 1}) do -- exit to the bottom because of the tile for the exit
			if maze[pos.x][pos.y][i] == true then
				maze[pos.x][pos.y][i]="other_map" -- exit to the right to the mine entrance
				break
			end
		end
	end
end

function maze_gen.create_room_list ( maze, corridor_width, wall_width )
	local result = {["walkable"]={}, ["opening"]={}, ["exit"]={}, ["nodes"]={}, ["other_map"]={}, ["entrance"]={}, ["unused"]={}}
	local w = result["walkable"]; local o = result["opening"]; local e = result["exit"]; local n = result["nodes"]; local m = result["other_map"]; local en = result["entrance"]
	for x=1, #maze do
		for y=1, #maze[1] do
			-- add corridor to walkable, walls which are false to opening and exits to exit
			if maze[x][y].areanumber ~= nil then
				local a_nr = maze[x][y].areanumber
				w[a_nr] = w[a_nr] or {}; o[a_nr] = o[a_nr] or {}; e[a_nr] = e[a_nr] or {}; n[a_nr] = n[a_nr] or {}; m[a_nr]= m[a_nr] or {}; en[a_nr] = en[a_nr] or {}
				local walkable = maze_gen.pos_to_area({x=x, y=y})
				local node = area_util.resize_area(walkable, {-wall_width.x, -wall_width.y, wall_width.x, wall_width.y})
				local p = maze_gen.maze_wall_to_areas( maze, {x=x, y=y}, corridor_width, wall_width, node)
				table.insert(w[a_nr], walkable); table.insert(n[a_nr], node);table.insert(e[a_nr], p.exit); table.insert(o[a_nr], p.opening); table.insert(m[a_nr], p.other_map); table.insert(en[a_nr], p.entrance)
			else 
				local walkable = maze_gen.pos_to_area({x=x, y=y})
				local node = area_util.resize_area(walkable, {-wall_width.x, -wall_width.y, wall_width.x, wall_width.y})
				table.insert(result.unused, node)
			end
		end
	end
	for _, a in pairs(result["walkable"]) do
		a.area = nil
		for _, area in ipairs(a) do
			if a.area == nil then a.area = table_util.copy(area)
			else a.area = area_util.merge_areas(a.area, area) end
		end
	end
	for _, a in pairs(result["nodes"]) do
		a.area = nil
		for _, area in ipairs(a) do
			if a.area == nil then a.area = table_util.copy(area)
			else a.area = area_util.merge_areas(a.area, area) end
		end
	end
	return result
end

function maze_gen.maze_wall_to_areas( maze, pos, corridor_width, wall_width, node)
	local exits = {} -- 32 wide
	local openings = {} -- 64 wide?
	local walls = {[1]={x1=node.x1+wall_width.x, x2=node.x2-wall_width.x, y1=node.y1, y2=node.y1+wall_width.y},
				   [0]={x1=node.x2-wall_width.x, x2=node.x2, y1=node.y1+wall_width.y, y2=node.y2-wall_width.y},
				   [2]={x1=node.x1, x2=node.x1+wall_width.x, y1=node.y1+wall_width.y, y2=node.y2-wall_width.y},
				   [3]={x1=node.x1+wall_width.x, x2=node.x2-wall_width.x, y1=node.y2-wall_width.y, y2=node.y2}}
	local result = {["exit"]={}, ["opening"]={}, ["other_map"]={}, ["entrance"]={}}
	if type(maze[pos.x][pos.y][0]) == "string" then
		result[maze[pos.x][pos.y][0]][0] = area_util.from_center( walls[0], wall_width.x, 32) 
		result[maze[pos.x][pos.y][0]][0].to_area = table_util.get(maze, {pos.x+1, pos.y, "areanumber"}) end
	if type(maze[pos.x][pos.y][1]) == "string" then
		result[maze[pos.x][pos.y][1]][1] = area_util.from_center( walls[1], 32, wall_width.y) 
		result[maze[pos.x][pos.y][1]][1].to_area = table_util.get(maze, {pos.x, pos.y-1, "areanumber"}) end
	if type(maze[pos.x][pos.y][2]) == "string"  then	
		result[maze[pos.x][pos.y][2]][2] = area_util.from_center( walls[2], wall_width.x, 32) 
		result[maze[pos.x][pos.y][2]][2].to_area = table_util.get(maze, {pos.x-1, pos.y, "areanumber"}) end
	if type(maze[pos.x][pos.y][3]) == "string"  then
		result[maze[pos.x][pos.y][3]][3] = area_util.from_center( walls[3], 32, wall_width.y) 
		result[maze[pos.x][pos.y][3]][3].to_area = table_util.get(maze, {pos.x, pos.y+1, "areanumber"}) end
	return result
end


------------------------------------------------------------------------------------------------------------------------------
-------------------------------------       Path generation functions       --------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------


function maze_gen.generate_path( maze, exits, path_option, path_width, intersections, exit_width )
	local intersections = intersections or {x=3, y=3}
	local path_width = path_width or 0.5
	local exit_width = exit_width or 1
	local wall_width, corridor_width = room.wall_width, room.corridor_width
	local paths = {}
	local available_points = {}
	local stepsize_x, stepsize_y = (#maze)/(intersections.x+1), (#maze[1])/(intersections.y+1)
	local max_x, max_y =  #maze, #maze[1]
	log.debug(stepsize_x);log.debug(stepsize_y);log.debug(max_x); log.debug(max_y)
	local x_counter, y_counter = 0, 0
	for i=stepsize_x, max_x-1, stepsize_x do
		x_counter = x_counter+1
		y_counter = 0
		for j=stepsize_y, max_y-1, stepsize_y do
			log.debug("i: "..i..", j: "..j)
			y_counter = y_counter+1
			local x, y = math.random(math.floor(i-stepsize_x/4), num_util.clamp(math.ceil(i+stepsize_x/4), 2, max_x)), math.random(math.floor(j-stepsize_y/4), num_util.clamp(math.ceil(j+stepsize_y/4), 2, max_y))
			table.insert(available_points, {x=x, y=y, intersect_pos={x=x_counter, y=y_counter}})
		end
	end
	if path_option == "grid" then
		local points_matrix = {}
		for _,pos in ipairs(available_points) do
			points_matrix[pos.intersect_pos.x] = points_matrix[pos.intersect_pos.x] or {}
			points_matrix[pos.intersect_pos.x][pos.intersect_pos.y] = {x=pos.x, y=pos.y}
		end
		log.debug(points_matrix)
		for _,exit in ipairs(exits) do
			local exit_point = exit[math.ceil(#exit/2)]
			local path1 = maze_gen.create_direct_path( maze_gen.find_closest_node( maze, exit_point, {available_points} ), exit_point, maze )
			if path1 then 
				table.insert(paths, path1) 
			end
		end
		local abstract_maze = {}
		maze_gen.initialize_maze(abstract_maze, {x1=0,y1=0,x2=intersections.x,y2=intersections.y}, {x=0,y=0}, {x=1,y=1})
		maze_gen.place_walls_around( abstract_maze, maze_gen.get_not_visited( abstract_maze ) )
		maze_gen.prims_algorithm( abstract_maze )
		log.debug(abstract_maze)
		for x,column in ipairs(abstract_maze) do
			for y,node in ipairs(column) do
				if not node[0] then table.insert(paths, maze_gen.create_direct_path( points_matrix[x][y], points_matrix[x+1][y], maze )) end
				if not node[3] then table.insert(paths, maze_gen.create_direct_path( points_matrix[x][y], points_matrix[x][y+1], maze )) end
			end
		end
	elseif path_options == "projections" then
		paths = maze_gen.create_initial_paths( maze, exits, nil )
		repeat
            local next_point = table.remove(available_points, math.random(#available_points))
            local path1 = maze_gen.create_direct_path( maze_gen.find_closest_node( maze, next_point, paths ), next_point, maze )
            if path1 then 
                table.insert(paths, path1) 
            end
        until #available_points == 0
    else
    	paths = maze_gen.create_initial_paths( maze, exits, nil )
	end
	-- got a path to all exits
	for _,path in ipairs(paths) do
		for _, pos in ipairs(path) do
			local nodes_to_clear = maze_gen.get_nodes_around_pos(maze, pos, path_width)
			for _,node in ipairs(nodes_to_clear) do
				if not node.visited then node.visited = true end
			end
		end
	end
	for _,exit_list in ipairs(exits) do
		for _, pos in ipairs(exit_list) do
			local nodes_to_clear = maze_gen.get_nodes_around_pos(maze, pos, exit_width)
			for _,node in ipairs(nodes_to_clear) do
				node.visited = "exit"
			end
		end
	end
	-- we have an expanded path, now to make areas from those nodes
	local closed_areas = maze_gen.maze_to_square_areas( maze, false )
	local open_areas = maze_gen.maze_to_square_areas( maze, true )
	return open_areas, closed_areas, maze
end


function maze_gen.maze_to_square_areas( maze, visit_status )
	local area_list = {}
	local max_x, max_y = #maze, #maze[1]
	for x = 1, max_x do
		for y = 1, max_y do
			local tl_node = maze[x][y]
			local tl_pos = {x=x, y=y}
			if tl_node.visited == visit_status and not tl_node.assigned then
				tl_node.assigned=true
				-- remember topleft (x, y) and the bottomright node 
				local br_pos = {x=x, y=y}
				while true do
					if br_pos.x+1 > max_x or br_pos.y+1 > max_y then table.insert(area_list, maze_gen.nodes_to_area( tl_pos, br_pos ) );break end
					-- check if the block is expandable to the right and bottom of the current block
					local right, bottom = true, true
					for x2 = x, br_pos.x+1 do
						if maze[x2][br_pos.y+1].visited ~= visit_status or maze[x2][br_pos.y+1].assigned then bottom=false end
					end
					if bottom then 
						for y2 = y, br_pos.y+1 do
							if maze[br_pos.x+1][y2].visited ~= visit_status or maze[br_pos.x+1][y2].assigned then right=false end
						end
						if right then
							br_pos = {x=br_pos.x+1, y=br_pos.y+1}
							for x2 = x, br_pos.x do
								maze[x2][br_pos.y].assigned = true
							end
							for y2 = y, br_pos.y do
								maze[br_pos.x][y2].assigned = true
							end
						else
							table.insert(area_list, maze_gen.nodes_to_area( tl_pos, br_pos ) );	break
						end
					else
						table.insert(area_list, maze_gen.nodes_to_area( tl_pos, br_pos ) );	break
					end
				end
			end
		end
	end
	return area_list
end

------------------------------------------------------------------------------------------------------------------------------
-------------------------------------        Maze creation functions        --------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------

-- http://wiki.roblox.com/index.php?title=Recursive_Backtracker
function maze_gen.standard_recursive_maze( maze, exits, alternate_probabilities)
	-- Create a table of cells, starting with just one random one
	local Cells = {table_util.random(exits[1])}
	maze[Cells[1].x][Cells[1].y].visited = true
	for i=2, #exits, 1 do
		for _,exit_pos in ipairs(exits[i]) do
			local neighbors = maze_gen.get_neighbors(maze, exit_pos, true)
			table_util.shuffleTable( neighbors )
			local nb
			for _,nb_to_test in ipairs(neighbors) do
				if #maze_gen.get_neighbors(maze, nb_to_test.pos, true) > 0 then
					nb = nb_to_test
					break
				end
			end
			maze[exit_pos.x][exit_pos.y][nb.wall_to]=false
            maze[nb.pos.x][nb.pos.y][nb.wall_from]=false
			break
		end
	end
	repeat
	     -- Select the most recent cell from the cells list (see note at bottom)
	     local CurCellIndex = #Cells
	     local CurCell = Cells[CurCellIndex]
	     -- Make sure that this cell has unvisited neighbors
	     local unvisited = maze_gen.get_neighbors(maze, CurCell, true)
	     if #unvisited > 0 then
	          -- ...and select a random one.
	          local next_node
	          if alternate_probabilities then
	          	local total_probability = 0
	          	for _,unv in ipairs(unvisited) do
	          		total_probability = total_probability + alternate_probabilities[unv.wall_to]
	          	end
	          	local sum = 0
	          	local random = math.random(total_probability)
	          	for _,unv in ipairs(unvisited) do
	          		sum = sum + alternate_probabilities[unv.wall_to]
	          		if random <= sum then
	          			next_node = unv
	          			break
	          		end
	          	end
	          else
	          	next_node = unvisited[math.random(#unvisited)]
	          end
	           
	          -- Then carve a path to it by deleting the wall between them
	          maze[CurCell.x][CurCell.y][next_node.wall_to]=false
	          maze[next_node.pos.x][next_node.pos.y][next_node.wall_from]=false
	          maze[next_node.pos.x][next_node.pos.y].visited = true
	          -- Add the neighbor to the end of the list of cells to make sure it is picked as the current one
	          table.insert(Cells, next_node.pos)
	     else
	          -- If the current cell has only visited neighbors, remove it from the list.
	          table.remove(Cells, CurCellIndex)
	     end
	until #Cells == 0
end

function maze_gen.prims_algorithm( maze, exits )
	local starting_pos
	if exits then
		starting_pos = table_util.random(exits[1])
		maze[starting_pos.x][starting_pos.y].visited = true
		for i=2, #exits, 1 do
			for _,exit_pos in ipairs(exits[i]) do
				local unvisited = maze_gen.get_neighbors(maze, exit_pos, true)
				if #unvisited > 0  then
					local nb = table_util.random(unvisited)
					maze[exit_pos.x][exit_pos.y][nb.wall_to]=false
		            maze[nb.pos.x][nb.pos.y][nb.wall_from]=false
					break
				end
			end
		end
	else
		starting_pos = {x=math.random(#maze), y=math.random(#maze[1])}
	end
	local unvisited_list=maze_gen.get_neighbors( maze, starting_pos, true )
	repeat
		local un = table.remove(unvisited_list, math.random(#unvisited_list))
		if not un.node.visited then
			maze[un.pos.x][un.pos.y][un.wall_from]=false
	        maze[un.from_pos.x][un.from_pos.y][un.wall_to]=false
	        un.node.visited = true
	        local new_unvisited_neighbors = maze_gen.get_neighbors (maze, un.pos, true)
	        table_util.add_table_to_table(new_unvisited_neighbors, unvisited_list)
		end
	until #unvisited_list == 0 
end


function maze_gen.convert_maze_to_area_list( maze, area, corridor_width, wall_width )
	-- standard 8x8 patterns
	local max_x=#maze
	local max_y=#maze[1]
	area = area or room
	wall_width = wall_width or room.wall_width
	corridor_width = corridor_width or room.corridor_width
	local area_list = {}
	-- if at least one wall is connected to the post then create it
	if maze[1][1][1] or maze[1][1][2] then
		table.insert(area_list, {area={x1=area.x1, y1=area.y1, x2=area.x1+wall_width.x, y2=area.y1+wall_width.y}, pattern="maze_post"})
	end
	-- direction (number): between 0 (East of the room) and 3 (South of the room).
	for x=1, max_x do
		for y=1, max_y do
			if x==1 then -- create left side, skipping topleft
				if maze[x][y][2] then area_list[#area_list+1] = {area={x1=area.x1, y1=area.y1+wall_width.y+(wall_width.y+corridor_width.y)*(y-1),
												 x2=area.x1+wall_width.x, y2=area.y1+(wall_width.y+corridor_width.y)*y}, pattern="maze_wall_ver"} end
			 	if maze[x][y][2] or maze[x][y][3] or ( y<max_y and maze[x][y+1][2]) then
					area_list[#area_list+1] = {area={x1=area.x1, y1=area.y1+(wall_width.y+corridor_width.y)*y, 
												  	 x2=area.x1+wall_width.x, y2=area.y1+(wall_width.y+corridor_width.y)*y+wall_width.y}, 
											   pattern="maze_post"} end
			end
			if y==1 then -- create top side, skipping topleft
				if maze[x][y][1] then area_list[#area_list+1] = {area={x1=area.x1+wall_width.x+(wall_width.x+corridor_width.x)*(x-1), y1=area.y1,
												 x2=area.x1+(wall_width.x+corridor_width.x)*x, y2=area.y1+wall_width.y}, pattern="maze_wall_hor"} end
				-- if at least one wall is connected to the post then create it
				if maze[x][y][1] or maze[x][y][0] or ( x<max_x and maze[x+1][y][1]) then
					area_list[#area_list+1] = {area={x1=area.x1+(wall_width.x+corridor_width.x)*x, y1=area.y1, 
												  	 x2=area.x1+(wall_width.x+corridor_width.x)*x+wall_width.x, y2=area.y1+wall_width.y}, 
											   pattern="maze_post"} end
			end
			-- bottom side
			if maze[x][y][3] then area_list[#area_list+1] = {area={x1=area.x1+wall_width.x+(wall_width.x+corridor_width.x)*(x-1),
															 	   y1=area.y1+(wall_width.y+corridor_width.y)*y,
															 	   x2=area.x1+(wall_width.x+corridor_width.x)*x,
															 	   y2=area.y1+wall_width.y+(wall_width.y+corridor_width.y)*y,
															 	   }, pattern="maze_wall_hor"} end
			-- right side
			if maze[x][y][0] then area_list[#area_list+1] = {area={x1=area.x1+(wall_width.x+corridor_width.x)*x,
															 	   y1=area.y1+wall_width.y+(wall_width.y+corridor_width.y)*(y-1),
															 	   x2=area.x1+wall_width.x+(wall_width.x+corridor_width.x)*x,
															 	   y2=area.y1+(wall_width.y+corridor_width.y)*y,
															 	   }, pattern="maze_wall_ver"} end
			-- maze post
			-- if at least one wall is connected to the post then create it
			if maze[x][y][0] or maze[x][y][3] or ( x<max_x and maze[x+1][y][3]) or (y<max_y and maze[x][y+1][0]) then
				area_list[#area_list+1] = {area={x1=area.x1+(wall_width.x+corridor_width.x)*x,
										 	   y1=area.y1+(wall_width.y+corridor_width.y)*y,
										 	   x2=area.x1+wall_width.x+(wall_width.x+corridor_width.x)*x,
										 	   y2=area.y1+wall_width.y+(wall_width.y+corridor_width.y)*y,
										 	   }, pattern="maze_post"} end
		end
	end
	return area_list
end


------------------------------------------------------------------------------------------------------------------------------
-------------------------------------       Puzzle creation functions       --------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------



function maze_gen.generate_maze( area, exit_areas, exclusion)
	local corridor_width = room.corridor_width
	local maze = {}
	local wall_width = room.wall_width

	maze_gen.initialize_maze( maze, area, wall_width, corridor_width )

	if exclusion ~= nil and next(exclusion) ~= nil then maze_gen.exclude( maze, exclusion ) end

	maze_gen.place_walls_around( maze, maze_gen.get_not_visited( maze ) )
	
	local exits = maze_gen.open_exits( maze, exit_areas )

	return maze, exits
end


------------------------------------------------------------------------------------------------------------------------------




function maze_gen.open_up_area( maze, topleft_pos, bottomright_pos )
	local max_x, max_y = #maze, #maze[1]
	for x=math.max(topleft_pos.x, 1), math.min(bottomright_pos.x, max_x) do
		for y=math.max(topleft_pos.y, 1), math.min(bottomright_pos.y, max_y) do
			maze[x][y].visited = true
			local directions_to_open = {[0]=true, [1]=true, [2]=true, [3]=true}
			if x == topleft_pos.x 		then directions_to_open[2] = nil end	
			if x == bottomright_pos.x 	then directions_to_open[0] = nil end
			if y == topleft_pos.y 		then directions_to_open[1] = nil end
			if y == bottomright_pos.y 	then directions_to_open[3] = nil end
			for i, _ in pairs(directions_to_open) do maze[x][y][i] = false end
		end
	end
end

function maze_gen.insert_template_into_maze( maze, template_table, topleft_pos )
	if #maze[1] < #template_table[1] + topleft_pos.x - 1 then return false end
	if #maze < #template_table + topleft_pos.y - 1 then return false end
	for x=1, #template_table[1] do
		for y=1, #template_table do
			maze[x-1+topleft_pos.x][y-1+topleft_pos.y].visited = true
			maze[x-1+topleft_pos.x][y-1+topleft_pos.y].prop = template_table[x][y]
		end
	end
end

function maze_gen.generate_branched_maze( maze, nr_of_branches, paths )
	--maze_gen.make_dark_room()
	local length_till_exit
	local distance_to_exit
	local branches = {}
	-- deform and create branches
	for i=1, 10 do
		local path_nr = math.random(#paths)
		branches[path_nr] = branches[path_nr] or {}
		table.insert(branches[path_nr], maze_gen.create_straight_branch( maze, correct_paths[path_nr], 2))
		table_util.add_table_to_table(maze_gen.deform( maze, correct_paths[path_nr] ), branches[path_nr])
	end
	return branches
end

function maze_gen.deform( maze, correct_path )
	-- log.debug("start deforming")
	--deformation of the path: placing a wall between two positions and connect via a path of nodes which have not been visited yet
	-- first select a node to travel to
	local first_node = math.random(#correct_path)
	local second_node = num_util.random_except({first_node}, 1, #correct_path)
	if second_node < first_node then first_node, second_node = second_node, first_node end
	-- that node should be part of the same correct path
	-- find a path from and to using maze_gen.create_direct_path
	local path = maze_gen.create_direct_path(correct_path[first_node], correct_path[second_node], maze)	
	-- IF FOUND
	local new_branches = {}
	if path then
		-- log.debug("found path")
		-- log.debug(path)
		-- place the wall somewhere in between the two selected nodes (random)
		local wall_node = math.random(first_node, second_node-1)
		maze_gen.place_wall_between(correct_path[wall_node], correct_path[wall_node+1], maze)
		-- add the nodes which fall in between the selected nodes to the branches

		if first_node~=wall_node then 
			table.insert(new_branches, {})
			for i=first_node+1, wall_node do table.insert(new_branches[#new_branches], correct_path[i]) end 
		end
		if second_node~=wall_node+1 then
			table.insert(new_branches, {})
			for i=second_node-1, wall_node+1, -1 do table.insert(new_branches[#new_branches], correct_path[i]) end 
		end
		-- remove nodes in between
		if second_node - first_node > 1 then
			for i=second_node-1, first_node+1, -1 do
				table.remove(correct_path, i)
			end
		end
		-- add the found path in between the selected nodes to the correct path
		for i=#path-1, 1, -1 do
			table.insert(correct_path, first_node+1, path[i])
		end
		-- open path
		maze_gen.open_path(maze, path)
	end
	-- log.debug("deform success")
	return new_branches
end

function maze_gen.create_teleport_junction( maze, correct_path, branches, nr_of_teleports)
	-- find a spot along the path that has enough branches for the nr_of_teleports
	local selected_spot
	local branches_encountered = 0
	local nodes_left = {}
	local selected_branches = {}
	for i=1, #correct_path-1, 1 do
		local pos = correct_path[i]
		for _, branch in ipairs(branches) do
			local branch_at_pos, nodes = maze_gen.branch_at_pos(maze, branch, pos)
			if branch_at_pos then 
				branches_encountered = branches_encountered + 1
				nodes_left[branches_encountered] = nodes
				selected_branches[branches_encountered] = branch
			end
			if branches_encountered == nr_of_teleports then
				selected_spot = i
				break
			end
		end
		if selected_spot ~= nil then break end
	end 
	selected_spot = selected_spot or #correct_path-1
	-- we can add a wall after that spot
	maze_gen.place_wall_between(correct_path[selected_spot], correct_path[selected_spot+1], maze)
	-- if that spot is the start of a branch then place the teleport back at the end of the branch and the way forward one spot removed
	local correct_dest, incorrect_dest
	local extra_branch_found = false
	for _, branch in ipairs(branches) do
		local branch_at_pos, nodes = maze_gen.branch_at_pos(maze, branch, correct_path[selected_spot+1])
		if branch_at_pos then 
			extra_branch_found = true
			correct_dest = maze_gen.teleport_dest( maze, branch[nodes+1] )
		end
	end
	if not extra_branch_found then correct_dest = maze_gen.teleport_dest( maze, correct_path[selected_spot+1] ) end
	incorrect_dest = maze_gen.teleport_dest( maze, correct_path[selected_spot] )
	-- add teleports to the end of the branches whereever there is space, add a destination to the beginning of the path
end


function maze_gen.teleport_dest( maze, pos )
	local area = maze_gen.pos_to_area(pos)
	local prop_name = "teletransporter_destination"
	maze[pos.x][pos.y].prop = prop_name
	local details = {name=room.name_prefix..prop_name, layer=0, x=(area.x1+area.x2)/2, y=(area.y1+area.y2)/2+5, direction=-1,  sprite="entities/"..prop_name }
	local destination = map:create_destination(details)
	return destination
end

function maze_gen.teleport_entry(maze, pos, destination)

end

function maze_gen.branch_at_pos( maze, branch, pos )
	local branch_at_pos = false
	local nodes = 0
	if table_util.tbl_contains_tbl( branch[1], pos) then
		branch_at_pos = true
		for k = 2, #branch do
			if maze[branch[k].x][branch[k].y].prop then break else nodes = nodes+1 end
		end
	end
	return branch_at_pos, nodes
end

function maze_gen.create_pike_trap( maze, branches, nr_pikes )
	-- place at the end of the branch where there is space enough and that is far away enough to function as trap
	for _,branch in ipairs(branches) do
		local branch_total = #branch
		local straight_length = maze_gen.check_straight_length( maze, branch )
		-- if length is small then we can use either a detect or auto pike
		if straight_length <= 2 then
			maze[branch[straight_length].x][branch[straight_length].y].prop = "pike_detect"
		end
		-- if length is large then a detect might have more effect
		-- if there are two branches at a single node then we can use an auto pike that is in the same direction as the correct path
	end
end

function maze_gen.get_closest_positions( pos_list1, pos_list2 )
	local max_dist, pos1, pos2 = math.huge, nil, nil
	for _,p1 in ipairs(pos_list1) do
		for _,p2 in ipairs(pos_list2) do
			local distance = maze_gen.distance( p1, p2 )
			if distance < max_dist then 
				pos1, pos2, max_dist = p1, p2, distance
			end
		end
	end
	return pos1, pos2
end

-- Creating the puzzle
function maze_gen.make( parameters )
	local p = parameters -- {darkness=true, fireball_statues=0, bubbles=0, pikes=false, pits=false}
	maze_gen.generate_maze_puzzle( p.area, p.areanumber, p.area_details, 
								   p.exit_areas, p.exclusion, parameters )
end

function maze_gen.generate_maze_puzzle( area, areanumber, area_details, exit_areas, exclusion, parameters )
	-- after opening up the exits create a normal maze afterwards
	local map = area_details.map
	if not map:get_entity("maze_sensor_"..areanumber) then
		explore.puzzle_encountered()
		-- initialize
		maze_gen.set_map( map )
		local cw, ww = {x=16, y=16}, {x=8, y=8}
		maze_gen.set_room( area, cw, ww, "maze_room"..areanumber )
		local maze, exits = maze_gen.generate_maze( area, exit_areas, exclusion)
		-- pick spots in the corners of the maze for fireball_statues
		local possible_locations = {hor={}, ver={}}
		for i=1, parameters.fireball_statues, 1 do
			table.insert(possible_locations.hor, {x=math.ceil((#maze/(parameters.fireball_statues+1))*i), y=math.ceil(#maze[1]/2)})
			table.insert(possible_locations.ver, {x=math.ceil(#maze/2), y=math.ceil((#maze[1]/(parameters.fireball_statues+1))*i)})
		end
		local use_this_list = nil
		if area.x2-area.x1 > area.y2-area.y1 then use_this_list = possible_locations.hor
		else use_this_list = possible_locations.ver end
		local fireball_statue_positions = {}
		
		for i=1, parameters.fireball_statues, 1 do
			local pos = use_this_list[i]
			log.debug(pos)
			local new_fireball_area = maze_gen.pos_to_area( pos )
			map:create_custom_entity({name="maze_enemy_"..areanumber.."_1", direction=0, 
										layer=0, x=new_fireball_area.x1+8, y=new_fireball_area.y1+13, 
										model="fireball_statue"})
			table.insert(fireball_statue_positions, {x=new_fireball_area.x1+8, y=new_fireball_area.y1+13})
			maze[pos.x][pos.y].visited = true
		end

		-- create maze
		--maze_gen.standard_recursive_maze( maze, exits )
		log.debug("setting up maze"..os.clock())
		maze_gen.prims_algorithm(maze, exits)
		maze_gen.place_walls_on_exits(exits, map)
		log.debug("collecting branches"..os.clock())
		local branches = maze_gen.collect_all_branches(maze, exits)
		log.debug("filling maze"..os.clock())
		local bubble_positions = {}
		local pike_positions = {}
		local pit_areas = {}
		-- pikes
		if parameters.pikes then pike_positions = maze_gen.place_pikes(branches, map, areanumber) end
		-- pits
		if parameters.pits then pit_areas = maze_gen.place_pits(branches, area_details, map, areanumber) end
		-- bubbles
		if parameters.bubbles >= 1 then bubble_positions = maze_gen.place_bubbles(maze, exits, map, branches, parameters.bubbles, areanumber) end


		local area_list, prop_list = maze_gen.convert_maze_to_area_list( maze, area, cw, ww )
		for _,v in ipairs(area_list) do
			placement.place_tile(v.area, lookup.tiles[v.pattern][area_details.tileset_id], "constructed_maze_"..areanumber.."_1", 0)
		end
		local furthest_sensor_area
		local distance = 0
		for i, exit in ipairs(exits) do
			local area_to_use = maze_gen.nodes_to_area(exit[1], exit[#exit])
			-- place walls that block enemies
			local exit_sensor = placement.place_sensor( area_to_use, "maze_"..areanumber.."_exit_"..i, 0 )
			local x, y = (area_to_use.x2+area_to_use.x1)/2, (area_to_use.y2+area_to_use.y1)/2
			exit_sensor.on_activated = function() 
					local x, y = x, y
					hero:save_solid_ground(x, y, 0)
				end
			if i > 1 then 
				local dist = area_util.sqr_distance(exit_areas[1], exit_areas[i])
				if dist > distance then 
					furthest_sensor_area = area_to_use
					distance = dist
				end
			end
		end
		local furthest_sensor = placement.place_sensor( furthest_sensor_area, "maze_"..areanumber.."_puzzle_complete", 0 )
		furthest_sensor.on_activated = 
			function () 
				puzzle_logger.complete_puzzle() 
			end

		local sensor
		if area_details.outside then 
			sensor = placement.place_sensor( area_util.resize_area(area, {-48, -48, 48, 48}), "maze_sensor_"..areanumber )
		else
			sensor = placement.place_sensor( area_util.resize_area(area, {-16, -16, 16, 16}), "maze_sensor_"..areanumber )
		end
		sensor.on_activated = function () 
			puzzle_logger.start_recording("maze", areanumber, parameters.difficulty) 
			
			if not map:has_entity("maze_enemy_"..areanumber.."_1") then
				maze_gen.reinstate_enemies(bubble_positions, pike_positions, fireball_statue_positions, areanumber)
				maze_gen.reinstate_maze(area_list, area_details, areanumber, pit_areas)
			end
		end
		sensor.on_left = function () 
			puzzle_logger.stop_recording()	
			map:get_hero():reset_solid_ground()
			for entity in map:get_entities("maze_enemy_"..areanumber.."_") do
				sol.timer.stop_all(entity)
				entity:remove()
			end
			for entity in map:get_entities("constructed_maze_"..areanumber.."_") do
				entity:remove()
			end
		end
		-- place darkness sensor if darkness
		if parameters.darkness then maze_gen.make_dark_room(area, area_details, areanumber) end
	end
end

function maze_gen.reinstate_enemies(bubble_positions, pike_positions, fireball_statue_positions, areanumber)
	for _,coordinate in ipairs(bubble_positions) do
		map:create_enemy{name="maze_enemy_"..areanumber.."_1",layer=0, x=coordinate.x, y=coordinate.y, direction=0, breed="bubble"}
	end
	for _,coordinate in ipairs(pike_positions) do
		map:create_enemy{name="maze_enemy_"..areanumber.."_1" ,layer=0, x=coordinate.x, y=coordinate.y, direction=coordinate.direction, breed="pike_detect"}
		-- map:create_custom_entity({name="maze_enemy_"..areanumber.."_1", direction=0, 
		-- 								layer=0, x=coordinate.x, y=coordinate.y,
		-- 								model="pike_detect"})
	end
	for _,coordinate in ipairs(fireball_statue_positions) do
		map:create_custom_entity({name="maze_enemy_"..areanumber.."_1", direction=0, 
										layer=0, x=coordinate.x, y=coordinate.y, 
										model="fireball_statue"})
	end
end

function maze_gen.reinstate_maze( area_list, area_details, areanumber, pit_areas)
	for _,v in ipairs(area_list) do
		placement.place_tile(v.area, lookup.tiles[v.pattern][area_details.tileset_id], "constructed_maze_"..areanumber.."_1", 0)
	end

	for _,area in ipairs(pit_areas) do
		if area_details.outside then 
			placement.place_tile(area, 825, "constructed_maze_"..areanumber.."_1", 0)
		else
			placement.place_tile(area, 340, "constructed_maze_"..areanumber.."_1", 0)
		end
	end
end

function maze_gen.place_bubbles(maze, exits, map, branches, amount, areanumber)
	local amount_left = amount
	local bubble_positions = {}
	-- for i=2, #exits, 1 do
	-- 	for _,exit_position in ipairs(exits[i]) do
	-- 		local connected_nodes = maze_gen.get_connected_nodes( exit_position, maze )
	-- 		for _,node in ipairs(connected_nodes) do
	-- 			if not maze_gen.list_contains_position(exits[i], node) then
	-- 				local area = maze_gen.pos_to_area(node)
	-- 				table.insert(bubble_positions, {x=area.x1+8,y=area.y1+8})
	-- 				map:create_enemy{name="maze_enemy_"..areanumber.."_1",layer=0, x=area.x1+8, y=area.y1+8, direction=0, breed="bubble"}
	-- 				amount_left = amount_left -1
	-- 				if amount_left == 0 then break end
	-- 			end
	-- 		end
	-- 		if amount_left == 0 then break end
	-- 	end
	-- end
	if amount_left >= 1 then
		for i=amount_left, 1, -1 do
			local random_branch = branches[math.random(#branches)]
			local area = maze_gen.pos_to_area(random_branch[#random_branch])
			table.insert(bubble_positions, {x=area.x1+8,y=area.y1+8})
			map:create_enemy{name="maze_enemy_"..areanumber.."_1",layer=0, x=area.x1+8, y=area.y1+8, direction=0, breed="bubble"}
		end
	end
	return bubble_positions
end

function maze_gen.place_pikes(branches, map, areanumber)
	local pike_positions = {}
	for i=#branches, 1, -1 do
		local branch = branches[i]

		if #branch > 1 then 
			local area = maze_gen.pos_to_area(branch[1])
			local direction
			if branch[2].y > branch[1].y then direction = 3 end
			if branch[2].y < branch[1].y then direction = 1 end
			if branch[2].x > branch[1].x then direction = 0 end
			if branch[2].x < branch[1].x then direction = 2 end

			table.insert(pike_positions, {x=area.x1+8,y=area.y1+13, direction=direction})
			-- map:create_custom_entity({name="maze_enemy_"..areanumber.."_1", direction=0, 
			-- 							layer=0, x=area.x1+8, y=area.y1+13, 
			-- 							model="pike_detect"})
			map:create_enemy{name="maze_enemy_"..areanumber.."_1" ,layer=0, x=area.x1+8, y=area.y1+13, direction=direction, breed="pike_detect"}
			table.remove(branches, i)
		end
	end
	return pike_positions
end

function maze_gen.place_pits(branches, area_details, map, areanumber)
	local pit_areas = {}
	for _,branch in ipairs(branches) do
		local area = maze_gen.pos_to_area(branch[1])
		if area_details.outside then 
			placement.place_tile(area, 825, "constructed_maze_"..areanumber.."_1", 0)
		else
			placement.place_tile(area, 340, "constructed_maze_"..areanumber.."_1", 0)
		end
		table.insert(pit_areas, area)
	end
	return pit_areas
end

function maze_gen.place_walls_on_exits(exits, map)
	for _,exit_list in ipairs(exits) do
		for _,exit_pos in ipairs(exit_list) do
			local exit_area = maze_gen.pos_to_area( exit_pos )
			map:create_wall{layer=0, x=exit_area.x1, y=exit_area.y1, 
							width=exit_area.x2-exit_area.x1, height=exit_area.y2-exit_area.y1,
							stops_enemies=true}
		end
	end
	
end

function maze_gen.collect_all_branches(maze, exits)
	local branches = {}
	local branch_nr = 0
	for x=1,#maze do
		for y=1,#maze[1] do
			local position = {x=x, y=y}
			if maze_gen.is_an_exit(position, exits) then
				--skip
			else
				local connected_nodes = maze_gen.get_connected_nodes( position, maze)
				if #connected_nodes == 1 then
					branch_nr = branch_nr+1
					branches[branch_nr] = {}
					table.insert(branches[branch_nr], position)
					local last_node = position
					connected_nodes = maze_gen.get_connected_nodes( connected_nodes[1], maze )

					while #connected_nodes <= 2 and #branches[branch_nr] < 3 do
						for _,node in ipairs(connected_nodes) do
							if not maze_gen.positions_are_equal(node, last_node) then
								table.insert(branches[branch_nr], node )
								last_node = node
								connected_nodes = maze_gen.get_connected_nodes( node, maze )
								break
							end
						end
					end
				end
			end
		end
	end
	return branches
end

function maze_gen.positions_are_equal(pos1, pos2)
	return pos1.x==pos2.x and pos1.y==pos2.y
end

function maze_gen.get_connected_nodes( position, maze)
	-- check every direction for open walls
	local connected_nodes = {}
	for _,direction in pairs({east=0, north=1, west=2, south=3}) do
		if not maze[position.x][position.y][direction] then 
			local new_position = maze_gen.next_position(position, direction)
			if maze_gen.valid(new_position, maze) then 
				table.insert(connected_nodes, new_position)
			end
		end
	end
	return connected_nodes
end

function maze_gen.is_an_exit(position, exits)
	for _,exit_list in ipairs(exits) do
		if maze_gen.list_contains_position(exit_list, position) then return true end
	end
	return false
end

function maze_gen.valid(position, maze)
	return position.x > 0 and position.y > 0 and position.x <= #maze and position.y <= #maze[1] 
end

function maze_gen.list_contains_position(list, position)
	for _,v in ipairs(list) do
		if v.x == position.x and v.y == position.y then return true end
	end
	return false
end

function maze_gen.next_position(position, direction)
	local new_position = {x=0, y=0}
	if direction == 0 then return {x=position.x+1, y=position.y}
	elseif direction == 1 then return {x=position.x, y=position.y-1}
	elseif direction == 2 then return {x=position.x-1, y=position.y}
	elseif direction == 3 then return {x=position.x, y=position.y+1} end
	return new_position
end

function maze_gen.make_dark_room(area, area_details, areanumber)
	local outside_sensor = map:get_entity("areasensor_outside_"..areanumber.."_type_"..area_details[areanumber].area_type)
	local width, height = outside_sensor:get_size()
	local x, y, layer = outside_sensor:get_position()
	local room_sensor = map:create_sensor({layer=layer, x=x, y=y, width=width+24, height=height+24})
	room_sensor.on_activated = 
		function() 
			map:create_darkness()
		end
	room_sensor.on_activated_repeat = 
		function()
			map:create_darkness()
		end
end


function maze_gen.get_outer_ring( maze, width, custom_value )
	local resulting_positions = {}
	for x,column in ipairs(maze) do
		for y,node in ipairs(column) do
			if (x <=width or x >= #maze-(width-1)) or (y <= width or y >= #maze[1]-(width-1)) then
				if custom_value and node.visited == custom_value or not custom_value then
					table.insert(resulting_positions, {x=x, y=y})
				end
			end
		end
	end
	return resulting_positions
end

return maze_gen
maze_gen 		= maze_gen or require("maze_gen")

local log 			= require("log")
local table_util 	= require("table_util")
local area_util 	= require("area_util")
local num_util 		= require("num_util")

local space_gen = {}

-- generating a path
-- general idea is to create a representation of every area, and connections

-- We try to do this by using a table (connections) of undefined length which contain
-- tables of undefined length to contain representations {type} of connections between nodes
-- One table (areas) explains the type of area, minimal area size, and the density of props.

-- Things that are to be taken into account:
--1- Areas need to have at least enough space between them to allow the hero to move through and have a 
---- measure of easthetics (predefine cases in which you need extra space)
--2- Connections need to be able to reach their nodes
--3- Area can be resized/scaled, but probably only beforehand (check this!)
--4- positioning of the tiles is based on topleft anchoring
--5- tiles have no size info available, only pattern number (manually add these to lookup tables -_-)

-- optimal block placement is an NP-Hard problem, do not attempt optimal~ given an area, that is not the objective!
-- instead we create and determine our map size afterwards

-- area_details = {	nr_of_areas, 
	-- 				tileset, 
	-- 				preferred_area_surface, 
	-- 				[1...nr_of_areas]={	area_type, 
	-- 									shape_modifier, 
	-- 									is_transition_area, 
	-- 									[1...connections]={ ("twoway"/"oneway_to"/"oneway_from"), areanumber}
	-- 								  }
	-- 			   }

local map

-- OLD Too complicated for the purpose
function space_gen.generate_space(area_details, given_map)
	map = given_map
	-- initialize all reused variables
	local width, height = map:get_size()

	local areas = {["walkable"]={}, ["boundary"]={[1] = {x1=0, y1=0, x2=width, y2=height}}, ["transition"]={}}

	local allowed_connectiontypes = {"separator", "adjacent", "jumper", "cave_teleport"}

	local boundary_width = 5*16

	local x = math.floor(math.random(boundary_width, width-boundary_width)/16)*16
	local y = math.floor(math.random(boundary_width, height-boundary_width)/16)*16
	local starting_origin = {256, 1024, "normal"}
	local new_walkable_area_list
	if area_details.outside then 
		new_walkable_area_list = space_gen.create_outside_walkable_areas(area_details, boundary_width, starting_origin)
	else
		new_walkable_area_list = space_gen.create_dungeon_walkable_areas(area_details, starting_origin)
	end
	log.debug("new walkable areas")
	log.debug(new_walkable_area_list)

	for areanumber=1, area_details.nr_of_areas, 1 do
		log.debug("conflict resolution for new walkable area")
		new_walkable_area = space_gen.conflict_resolution(new_walkable_area_list[areanumber], areas, boundary_width, "walkable")
		if new_walkable_area then
			areas["transition"][areanumber] = {}
			areas["walkable"][areanumber] = new_walkable_area
			space_gen.create_area_sensors(new_walkable_area, areanumber, area_details)
		else
			log.debug("conflict resolution walkable ".. areanumber .. " failed")
		end
	end 

	-- generate transitions for each area, in order
	-- direct transitions, they need to be handled first to be able to place indirect transitions without overlap
	local todo_indirect = {}
	for areanumber=1, area_details.nr_of_areas, 1 do
		local details_of_current_area = area_details[areanumber]
		for connection=1, details_of_current_area.nr_of_connections, 1 do
			log.debug("finding transition, area ".. areanumber.." connection "..connection)
			local transition_details = details_of_current_area[connection]
			-- determine which transition types are possible given the locations of the areas
			local found_path, found = space_gen.check_for_direct_path(area_details.path_width+2*area_details.wall_width, math.huge, areanumber, transition_details.areanumber, areas)
			if found then -- create direct transition
				local resulting_transitions, connected_at = space_gen.create_direct_transition(found_path, transition_details, area_details.path_width+2*area_details.wall_width, areas)
				space_gen.rectify_area_details(areas, areanumber, connected_at[1], area_details, true)
				space_gen.rectify_area_details(areas, transition_details.areanumber, connected_at[#connected_at], area_details, true)
				log.debug("creating links, area ".. areanumber.." connection "..connection)
				local links, to_transition = space_gen.expand_transition_connected_at( connected_at, area_details )
				areas["transition"][areanumber][connection]={transitions=resulting_transitions,
															 opening=to_transition[1],
															 links=links,
															 transition_type="direct", 
															 connected_at=connected_at[1]}
				areas["transition"][transition_details.areanumber]["entry_direct_area_"..areanumber.."_con_"..connection]={transitions={}, opening=to_transition[2], transition_type="direct", connected_at=connected_at[#connected_at]}
				for _, v in ipairs(resulting_transitions) do
					space_gen.conflict_resolution(v, areas, boundary_width, "transition")
				end
			else
				todo_indirect[areanumber] = todo_indirect[areanumber] or {} 
				todo_indirect[areanumber][connection]=transition_details
			end
		end
	end
	-- now that we have all the connecting areas of a certain walkable area we can properly assign a position to indirect transitions
	for areanumber, indirect_connections in pairs(todo_indirect) do
		for connection, transition_details in pairs(indirect_connections) do
			-- collect all the touching areas and create a list of open areas left for the indirect transitions
			local resulting_transitions, transition_type = space_gen.create_indirect_transition(connection, areanumber, transition_details, areas, area_details)
			space_gen.rectify_area_details(areas, areanumber, resulting_transitions[1], area_details, true)
			space_gen.rectify_area_details(areas, transition_details.areanumber, resulting_transitions[2], area_details, true)
			areas["transition"][areanumber][connection]=
				{transitions={}, opening=resulting_transitions[1], transition_type=transition_type[1]}
			areas["transition"][transition_details.areanumber]["entry_indirect_area_"..areanumber.."_con_"..connection]=
				{transitions={}, opening=resulting_transitions[2], transition_type=transition_type[2]}
		end
	end
	log.debug(transition_assignments)
	return areas
end

-- map:create_sensor(properties)
-- Creates an entity of type sensor on the map.

-- properties (table): A table that describes all properties of the entity to create. Its key-value pairs must be:
-- name (string, optional): Name identifying the entity or nil. If the name is already used by another entity, a suffix (of the form "_2", "_3", etc.) will be automatically appended to keep entity names unique.
-- layer (number): Layer on the map (0: low, 1: intermediate, 2: high).
-- x (number): X coordinate on the map.
-- y (number): Y coordinate on the map.
-- width (number): Width of the entity in pixels.
-- height (number): Height of the entity in pixels.
-- Return value (sensor): the sensor created.

-- map:create_separator(properties)
-- Creates an entity of type separator on the map.

-- properties (table): A table that describles all properties of the entity to create. Its key-value pairs must be:
-- name (string, optional): Name identifying the entity or nil. If the name is already used by another entity, a suffix (of the form "_2", "_3", etc.) will be automatically appended to keep entity names unique.
-- layer (number): Layer on the map (0: low, 1: intermediate, 2: high). The layer has no effect for separators.
-- x (number): X coordinate on the map.
-- y (number): Y coordinate on the map.
-- width (number): Width of the entity in pixels.
-- height (number): Height of the entity in pixels. One of width or height must be 16 pixels.
-- Return value (separator): The separator created.

-- direction = 0:east, 1:north, 2:west, 3:south
-- OLD Also too complicated for the purpose
function space_gen.create_area_separators_with_sensors( connected_at, path_type, from, to, connection_nr)
	log.debug("create_area_separators_with_sensors")
	log.debug(connected_at)
	local f_area = connected_at[1]
	local t_area = connected_at[#connected_at]
	local name_fwd = "sensor_pathway_"..path_type.."_fwd_f_"..from.."_t_"..to.."_con_"..connection_nr
	local name_bkw = "sensor_pathway_"..path_type.."_bkw_f_"..from.."_t_"..to.."_con_"..connection_nr
	local use_area = f_area
	log.debug(use_area)
	local dir = f_area.direction
	log.debug("dir="..dir)
	if path_type == "direct" then
		log.debug("direct case")
		local name_exit, name_entry = name_fwd.."_exitarea", name_fwd.."_intoarea"
		for i=1, 2 do
			if dir == 0 then -- east
				map:create_sensor({name=name_exit, layer=0, x=use_area.x1-24, y=use_area.y1, width=24, height=use_area.y2-use_area.y1})
				map:create_sensor({name=name_entry, layer=0, x=use_area.x1, y=use_area.y1, width=24, height=use_area.y2-use_area.y1})
				--map:create_separator({layer=0, x=use_area.x1-8, y=use_area.y1, width=16, height=use_area.y2-use_area.y1})
				--map:create_dynamic_tile({layer=2, x=use_area.x1-8, y=use_area.y1, width=16, height=use_area.y2-use_area.y1, pattern=261, enabled_at_start=true})
			elseif dir == 1 then -- north
				map:create_sensor({name=name_exit, layer=0, x=use_area.x1, y=use_area.y2, width=use_area.x2-use_area.x1, height=24})
				map:create_sensor({name=name_entry, layer=0, x=use_area.x1, y=use_area.y2-24, width=use_area.x2-use_area.x1, height=24})
				--map:create_separator({layer=0, x=use_area.x1, y=use_area.y2-8, width=use_area.x2-use_area.x1, height=16})
				--map:create_dynamic_tile({layer=2, x=use_area.x1, y=use_area.y2-8, width=use_area.x2-use_area.x1, height=16, pattern=259, enabled_at_start=true})
			elseif dir == 2 then --west
				map:create_sensor({name=name_exit, layer=0, x=use_area.x2, y=use_area.y1, width=24, height=use_area.y2-use_area.y1})
				map:create_sensor({name=name_entry, layer=0, x=use_area.x2-24, y=use_area.y1, width=24, height=use_area.y2-use_area.y1})
				--map:create_separator({layer=0, x=use_area.x2-8, y=use_area.y1, width=16, height=use_area.y2-use_area.y1})
				--map:create_dynamic_tile({layer=2, x=use_area.x2-8, y=use_area.y1, width=16, height=use_area.y2-use_area.y1, pattern=260, enabled_at_start=true})
			elseif dir == 3 then -- south
				map:create_sensor({name=name_exit, layer=0, x=use_area.x1, y=use_area.y1-24, width=use_area.x2-use_area.x1, height=24})
				map:create_sensor({name=name_entry, layer=0, x=use_area.x1, y=use_area.y1, width=use_area.x2-use_area.x1, height=24})
				--map:create_separator({layer=0, x=use_area.x1, y=use_area.y1-8, width=use_area.x2-use_area.x1, height=16})
				--map:create_dynamic_tile({layer=2, x=use_area.x1, y=use_area.y1-8, width=use_area.x2-use_area.x1, height=16, pattern=262, enabled_at_start=true})
			end
			dir = (t_area.direction+2)%4
			name_exit, name_entry = name_bkw.."_exitarea", name_bkw.."_intoarea"
			use_area = t_area
			log.debug(use_area)
		end
	else
		log.debug("indirect case")
		local name_exit, name_entry = name_fwd.."_exitarea", name_bkw.."_intoarea"
		for i=1, 2 do
			if dir == 0 then -- east
				map:create_sensor({name=name_exit, layer=0, x=use_area.x1-16, y=use_area.y1, width=24, height=use_area.y2-use_area.y1})
				map:create_sensor({name=name_entry, layer=0, x=use_area.x1-16, y=use_area.y1, width=24, height=use_area.y2-use_area.y1})
			elseif dir == 1 then -- north
				map:create_sensor({name=name_exit, layer=0, x=use_area.x1, y=use_area.y2-8, width=use_area.x2-use_area.x1, height=24})
				map:create_sensor({name=name_entry, layer=0, x=use_area.x1, y=use_area.y2-8, width=use_area.x2-use_area.x1, height=24})
			elseif dir == 2 then --west
				map:create_sensor({name=name_exit, layer=0, x=use_area.x2-8, y=use_area.y1, width=24, height=use_area.y2-use_area.y1})
				map:create_sensor({name=name_entry, layer=0, x=use_area.x2-8, y=use_area.y1, width=24, height=use_area.y2-use_area.y1})
			elseif dir == 3 then -- south
				map:create_sensor({name=name_exit, layer=0, x=use_area.x1, y=use_area.y1-16, width=use_area.x2-use_area.x1, height=24})
				map:create_sensor({name=name_entry, layer=0, x=use_area.x1, y=use_area.y1-16, width=use_area.x2-use_area.x1, height=24})
			end
			dir = t_area.direction
			name_exit, name_entry = name_bkw.."_exitarea", name_fwd.."_intoarea"
			use_area = t_area
			log.debug(use_area)
		end
	end
end


function space_gen.create_area_sensors( area, areanumber, area_details )
	local ww = area_details.wall_width
	map:create_sensor({name="areasensor_inside_"..areanumber.."_type_"..area_details[areanumber].area_type, 
		layer=0, x=area.x1+ww-8, y=area.y1+ww-8, width=area.x2-area.x1-(2*ww-16), height=area.y2-area.y1-(2*ww-16)})
	map:create_sensor({name="areasensor_outside_"..areanumber.."_type_"..area_details[areanumber].area_type, 
		layer=0, x=area.x1-24, y=area.y1-24, width=area.x2-area.x1+2*24, height=area.y2-area.y1+2*24})
end

-- OLD probably don't need this anymore
function space_gen.rectify_area_details(existing_areas, areanumber, new_area, area_details, transition_bool)
	log.debug("space_gen.rectify_area_details areanumber "..areanumber)
	log.debug("new_area")
	log.debug(new_area)
	if transition_bool == nil then transition_bool = false end
	local wall_width = area_details.wall_width
	local area_to_rectify = existing_areas["walkable"][areanumber]
	log.debug("area_to_rectify")
	log.debug(area_to_rectify)
	local use_this_area = new_area
	local check_these_areas = nil
	if transition_bool then
		-- adjust walls which intersect with the opening -- adding some extra length so we can use that with the open area
		if new_area.x1==area_to_rectify.x2 then -- east
			use_this_area = area_util.resize_area(new_area, {-wall_width, wall_width,0,-wall_width})
		elseif new_area.x2==area_to_rectify.x1 then -- west
			use_this_area = area_util.resize_area(new_area, {0, wall_width,wall_width,-wall_width})
		elseif new_area.y2==area_to_rectify.y1 then -- north
			use_this_area = area_util.resize_area(new_area, {wall_width, 0,-wall_width,wall_width})
		elseif new_area.y1==area_to_rectify.y2 then -- south
			use_this_area = area_util.resize_area(new_area, {wall_width, -wall_width,-wall_width,0}) end
		if new_area.x2==area_to_rectify.x2 then check_these_areas = area_to_rectify.walls["e"]
		elseif new_area.x1==area_to_rectify.x1 then check_these_areas = area_to_rectify.walls["w"]
		elseif new_area.y1==area_to_rectify.y1 then check_these_areas = area_to_rectify.walls["n"]
		elseif new_area.y2==area_to_rectify.y2 then check_these_areas = area_to_rectify.walls["s"] end
		if check_these_areas then 
			for k,v in ipairs(check_these_areas) do
				if area_util.areas_intersect(use_this_area, v) then
					local newly_made_areas = area_util.shrink_until_no_conflict(use_this_area, v)
					check_these_areas[k]=false
					table_util.add_table_to_table(newly_made_areas, check_these_areas)
				end
			end
			table_util.remove_false(check_these_areas)
		end
	end
	-- adjust open area
	check_these_areas = area_to_rectify.open
	for k,v in ipairs(check_these_areas) do
		if area_util.areas_intersect(use_this_area, v) then
			local newly_made_areas, conflict = area_util.shrink_until_no_conflict(use_this_area, v)
			check_these_areas[k]=false
			table_util.add_table_to_table(newly_made_areas, check_these_areas)
			table.insert(area_to_rectify.used, conflict)
		end
	end
	table_util.remove_false(check_these_areas)
	table_util.remove_false(area_to_rectify.used)
end

-- directions are 0:east, 1:north, 2:west, 3:south, which is the same in the engine
function space_gen.pick_random_wall_piece( width, existing_areas, areanumber, area_details, directions )
	local wall_width = area_details.wall_width
	local possible_directions = {}
	local possible_areas = {}
	directions = directions or {0, 1, 2, 3}
	if table_util.contains(directions, 1) then
		for k,v in pairs(existing_areas["walkable"][areanumber].walls["n"]) do
			local size = area_util.get_area_size(v)
			if size.x >= width then 
				possible_areas[1] = possible_areas[1] or {}
				table.insert(possible_areas[1], v)
				if not table_util.contains(possible_directions, 1) then table.insert(possible_directions, 1) end
			end
		end
	end
	if table_util.contains(directions, 3) then
		for k,v in pairs(existing_areas["walkable"][areanumber].walls["s"]) do
			local size = area_util.get_area_size(v)
			if size.x >= width then 
				possible_areas[3] = possible_areas[3] or {}
				table.insert(possible_areas[3], v)
				if not table_util.contains(possible_directions, 3) then table.insert(possible_directions, 3) end
			end
		end
	end
	if table_util.contains(directions, 0) then
		for k,v in pairs(existing_areas["walkable"][areanumber].walls["e"]) do
			local size = area_util.get_area_size(v)
			if size.y >= width then 
				possible_areas[0] = possible_areas[0] or {}
				table.insert(possible_areas[0], v)
				if not table_util.contains(possible_directions, 0) then table.insert(possible_directions, 0) end
			end
		end
	end
	if table_util.contains(directions, 2) then
		for k,v in pairs(existing_areas["walkable"][areanumber].walls["w"]) do
			local size = area_util.get_area_size(v)
			if size.y >= width then 
				possible_areas[2] = possible_areas[2] or {}
				table.insert(possible_areas[2], v)
				if not table_util.contains(possible_directions, 2) then table.insert(possible_directions, 2) end
			end
		end
	end
	local selected_direction = possible_directions[math.random(#possible_directions)]
	if selected_direction == nil then return false, false end
	local available_areas = possible_areas[selected_direction]
	if selected_direction == 1 or selected_direction == 3 then 
		return area_util.random_internal_area(available_areas[math.random(#available_areas)], width, wall_width), selected_direction
	else 
		return area_util.random_internal_area(available_areas[math.random(#available_areas)], wall_width, width), selected_direction
	end
end

function space_gen.pick_random_open_area( width, height, existing_areas, areanumber )
	local open_areas = existing_areas["walkable"][areanumber].open
	local possible_areas = {}
	local n = 0
	for k,v in ipairs(open_areas) do
		local size = area_util.get_area_size(v)
		if size.x >= width and size.y >= height then
			n = n+1
			possible_areas[n]=v
		end
	end
	return area_util.random_internal_area(possible_areas[math.random(#possible_areas)], width, height)
end

function space_gen.expand_transition_connected_at( connected_at, area_details )
	log.debug("connected_at")
	log.debug(connected_at)
	local width = area_details.wall_width
	local total = #connected_at
	local to_transition = {	area_util.expand_line( connected_at[1], width ), 
							area_util.expand_line( connected_at[total], width )}
	to_transition[2].direction = (to_transition[2].direction+2)%4
	local links = {}
	for i=2,total-1 do
		links[i-1]=area_util.expand_line (connected_at[i], width )
	end
	return links, to_transition
end

-- OLD takes up too much room
function space_gen.create_new_walkable_areas(area_details, boundary_width, starting_origin)
	-- area details contains the direction of the map where it should be headed
	-- for example if the from_direction == west, and the to_direction is east,
	-- then the probability of selecting a new direction for the next walkable area 
	-- should be west=0, north=0.25, east=0.5, south=0.25
	-- a from direction and to direction should not be the same, too much extra work
	local prob_dist = { ["west"]=25, 
						["east"]=25, 
						["north"]=25, 
						["south"]=25
					  }
	prob_dist[area_details.from_direction] = 0
	prob_dist[area_details.to_direction] = 50
	-- next we check what the combined area is of the areas already made, 
	-- and with the offset we can take a random between 1*offset and 2*offset
	-- with the 0 offset we can take a random between 0 and the width of the bounding area
	-- we can then place a normal origin on that point and test it if we can create a walkable area without intersections
	-- create first walkable area
	local wall_width = area_details.wall_width

	local new_area_list = {}
	local new_area = area_util.random_area(area_details, starting_origin)
	local walls, corners, open = area_util.create_walls( new_area, wall_width )
	new_area.walls=walls
	new_area.corners=corners
	new_area.open=open
	new_area.used={}
	new_area_list[#new_area_list+1] = new_area
	local bounding_area = new_area
	for i=2, area_details.nr_of_areas do
		local direction = table_util.choose_random_key(prob_dist)
		local next_origin = area_util.find_origin_along_edge(bounding_area, direction, boundary_width)
		new_area = area_util.random_area(area_details, next_origin)
		walls, corners, open = area_util.create_walls( new_area, wall_width )
		new_area.walls=walls
		new_area.corners=corners
		new_area.open=open
		new_area.used={}
		bounding_area = area_util.merge_areas(bounding_area, new_area)
		new_area_list[#new_area_list+1] = new_area
	end

	return new_area_list
end



-- path contains nodes from space_gen.check_for_direct_path
-- node={area_type, length, number, connected_to, touch_details={along_entire_length, touching_area, touching_direction}}
-- direction = 0:east, 1:north, 2:west, 3:south
function space_gen.create_direct_transition(path, transition_details, path_width, existing_areas)
	log.debug("checking for direct transition on path:")
	log.debug(path)
	local resulting_transitions={} -- in order from original area to other area
	local new_transition_areas ={}
	local entrance = area_util.random_internal_area(path[1].touch_details.touching_area, path_width, path_width)
	local connected_at = {entrance}
	log.debug("entrance before creation")
	log.debug(entrance)
	local dir1 = path[1].touch_details.touching_direction
	local exit
	local dir2
	entrance.direction = dir1 
	for p=2, #path, 1 do
		new_transition_areas = {}
		boundary_area = existing_areas[path[p-1].area_type][path[p-1].number]
		local size = area_util.get_area_size(boundary_area)
		local min_width = 2*path_width
		local cuttoff_area = area_util.area_cutoff({x=entrance.x1, y=entrance.y1}, 2*path_width, path[p].touch_details.touching_area, min_width, min_width)
		exit = area_util.random_internal_area(cuttoff_area, path_width, path_width)
		log.debug("exit")
		log.debug(exit)
		dir2 = path[p].touch_details.touching_direction
		exit.direction = dir2
		-- a transition within an area is always at most 3 areas and at least 1
		-- cases: (a) corner, (b) sidestep, (c) U-turn
		if dir1 == dir2 or dir1 == (dir2+2)%4 then -- either sidestep or U-turn
			if dir1 == 1 and dir2 == 3 then -- top U-turn
				local center_area = {x1=math.min(entrance.x1, exit.x1), 
				    				 y1=entrance.y1-path_width, 
				    				 x2=math.max(entrance.x2, exit.x2), 
				    				 y2=entrance.y2, direction=3}
			    if size.y > path_width+16 then 
			    	local extension = math.floor(num_util.clamp(size.y, 16, 2*path_width)/16)*16
			    	center_area = area_util.move_area(center_area, 0, -extension)
			    	local entrance_area = {x1=entrance.x1, x2=entrance.x2, y1=center_area.y2, y2=entrance.y1, direction=1}
			    	local exit_area = {x1=exit.x1, x2=exit.x2, y1=center_area.y2, y2=exit.y1, direction=3}
			    	new_transition_areas = {entrance_area, center_area, exit_area}
			    	table.insert(connected_at, {x1=entrance_area.x1, x2=entrance_area.x2, y1=entrance_area.y1, y2=entrance_area.y1, direction=3})
			    	table.insert(connected_at, {x1=exit_area.x1, x2=exit_area.x2, y1=exit_area.y1, y2=exit_area.y1, direction=1})
			    else new_transition_areas = {center_area} end
				log.debug("adding top vertical U-turn")
				log.debug(new_transition_areas)
			elseif dir1 == 3 and dir2 == 1 then -- bottom U-turn
				local center_area = {x1=math.min(entrance.x1, exit.x1), 
									 y1=entrance.y2, 
									 x2=math.max(entrance.x2, exit.x2), 
									 y2=entrance.y2+path_width, direction=1}
				if size.y > path_width+16 then 
			    	local extension = math.floor(num_util.clamp(size.y, 16, 2*path_width)/16)*16
			    	center_area = area_util.move_area(center_area, 0, extension)
			    	local entrance_area = {x1=entrance.x1, x2=entrance.x2, y1=entrance.y2, y2=center_area.y1, direction=3}
			    	local exit_area = {x1=exit.x1, x2=exit.x2, y1=exit.y2, y2=center_area.y1, direction=1}
			    	new_transition_areas = {entrance_area, center_area, exit_area}
			    	table.insert(connected_at, {x1=entrance_area.x1, x2=entrance_area.x2, y1=entrance_area.y2, y2=entrance_area.y2, direction=3})
			    	table.insert(connected_at, {x1=exit_area.x1, x2=exit_area.x2, y1=exit_area.y2, y2=exit_area.y2, direction=1})
			    else new_transition_areas = {center_area} end
				log.debug("adding bottom vertical U-turn")
				log.debug(new_transition_areas)
			elseif (dir1 == 1 or dir1 == 3) and dir1==dir2 then -- vertical sidestep
				local top
				local bottom
				local top_first = false
				if entrance.y1 <= exit.y1 then -- entrance needs to go south and exit north
					top = entrance
					bottom = exit
					top_first = true
				elseif entrance.y1 > exit.y1 then -- entrance needs to go north and exit south
					bottom = entrance
					top = exit
					top_first = false
				end
				local max_distance = bottom.y1 - top.y1
				local random_distance = math.floor(math.random(0, num_util.clamp(max_distance-path_width, 0, math.huge))/16)*16
				local top_area = {x1=top.x1, y1=top.y1, x2=top.x2, y2=top.y1+random_distance}
				local bottom_area = {x1=bottom.x1, y1=bottom.y1-num_util.clamp(max_distance-random_distance-path_width, 0, math.huge), x2=bottom.x2, y2=bottom.y2}
				local center_area = {x1=math.min(top_area.x1, bottom_area.x1), 
									 y1=top_area.y2, 
									 x2=math.max(top_area.x2, bottom_area.x2), 
									 y2=top_area.y2+path_width}
				if top_first then 
					if area_util.get_area_size(top_area).size > 0 then 
						table.insert(connected_at, {x1=top_area.x1, x2=top_area.x2, y1=top_area.y2, y2=top_area.y2, direction=3})
						top_area.direction=3
						table.insert(new_transition_areas, top_area) 
					end
					center_area.direction=3
					new_transition_areas[#new_transition_areas+1] = center_area
					if area_util.get_area_size(bottom_area).size > 0 then 
						table.insert(connected_at, {x1=bottom_area.x1, x2=bottom_area.x2, y1=bottom_area.y1, y2=bottom_area.y1, direction=3})
						bottom_area.direction=3
						table.insert(new_transition_areas, bottom_area)
					end
				else 
					if area_util.get_area_size(bottom_area).size > 0 then 
						table.insert(connected_at, {x1=bottom_area.x1, x2=bottom_area.x2, y1=bottom_area.y1, y2=bottom_area.y1, direction=1})
						bottom_area.direction=1
						table.insert(new_transition_areas, bottom_area)
					end
					center_area.direction=1
					new_transition_areas[#new_transition_areas+1] = center_area
					if area_util.get_area_size(top_area).size > 0 then 
						table.insert(connected_at, {x1=top_area.x1, x2=top_area.x2, y1=top_area.y2, y2=top_area.y2, direction=1})
						top_area.direction=1
						table.insert(new_transition_areas, top_area)
					end
				end
				log.debug("adding vertical Sidestep to other side")
				log.debug(new_transition_areas)
			elseif dir1 == 2 and dir2 == 0 then -- left U-turn
				local center_area = {x1=entrance.x1-path_width, 
									 y1=math.min(entrance.y1, exit.y1), 
									 x2=entrance.x2, 
									 y2=math.max(entrance.y2, exit.y2), direction=0}
				if size.x > path_width+16 then 
			    	local extension = math.floor(num_util.clamp(size.x, 16, 2*path_width)/16)*16
			    	center_area = area_util.move_area(center_area,-extension, 0)
			    	local entrance_area = {x1=entrance.x2, x2=center_area.x2, y1=entrance.y1, y2=entrance.y2, direction=2}
			    	local exit_area = {x1=exit.x2, x2=center_area.x2, y1=exit.y1, y2=exit.y2, direction=0}
			    	new_transition_areas = {entrance_area, center_area, exit_area}
			    	table.insert(connected_at, {x1=entrance_area.x1, x2=entrance_area.x1, y1=entrance_area.y1, y2=entrance_area.y2, direction=2})
					table.insert(connected_at, {x1=exit_area.x1, x2=exit_area.x1, y1=exit_area.y1, y2=exit_area.y2, direction=0})
			    else new_transition_areas = {center_area} end
				log.debug("adding left horizontal U-turn")
				log.debug(new_transition_areas) 
			elseif dir1 == 0 and dir2 == 2 then -- right U-turn
				local center_area = {x1=entrance.x1, 
									 y1=math.min(entrance.y1, exit.y1), 
									 x2=entrance.x2+path_width, 
									 y2=math.max(entrance.y2, exit.y2), direction=2}
				if size.x > path_width+16 then 
			    	local extension = math.floor(num_util.clamp(size.x, 16, 2*path_width)/16)*16
			    	center_area = area_util.move_area(center_area, extension, 0)
			    	local entrance_area = {x1=entrance.x2, x2=center_area.x1, y1=entrance.y1, y2=entrance.y2, direction=0}
			    	local exit_area = {x1=exit.x2, x2=center_area.x1, y1=exit.y1, y2=exit.y2, direction=2}
			    	new_transition_areas = {entrance_area, center_area, exit_area}
			    	table.insert(connected_at, {x1=entrance_area.x2, x2=entrance_area.x2, y1=entrance_area.y1, y2=entrance_area.y2, direction=0})
					table.insert(connected_at, {x1=exit_area.x2, x2=exit_area.x2, y1=exit_area.y1, y2=exit_area.y2, direction=2})
			    else new_transition_areas = {center_area} end
				log.debug("adding right horizontal U-turn")
				log.debug(new_transition_areas)
			elseif (dir1==0 or dir1==2) and dir1==dir2 then -- horizontal sidestep
				local left
				local right
				local left_first = false
				if entrance.x1 <= exit.x1 then -- entrance needs to go east and exit west
					left = entrance
					right = exit
					left_first = true
				elseif entrance.x1 > exit.x1 then -- entrance needs to go west and exit east
					right = entrance
					left = exit
					left_first = false
				end
				local max_distance = right.x1 - left.x1
				local random_distance = math.floor(math.random(0, num_util.clamp(max_distance-path_width, 0, math.huge))/16)*16
				local left_area = {x1=left.x1, y1=left.y1, x2=left.x2+random_distance, y2=left.y2}
				local right_area = {x1=right.x1-num_util.clamp(max_distance-random_distance-path_width, 0, math.huge), y1=right.y1, x2=right.x2, y2=right.y2}
				local center_area = {x1=left_area.x2, 
									 y1=math.min(left_area.y1, right_area.y1), 
									 x2=left_area.x2+path_width, 
									 y2=math.max(left_area.y2, right_area.y2)}
				if left_first then 
					if area_util.get_area_size(left_area).size > 0 then
						table.insert(connected_at, {x1=left_area.x2, x2=left_area.x2, y1=left_area.y1, y2=left_area.y2, direction=0}) 
						left_area.direction = 0
						table.insert(new_transition_areas, left_area)
					end
					center_area.direction = 0
					new_transition_areas[#new_transition_areas+1] = center_area
					if area_util.get_area_size(right_area).size > 0 then 
						table.insert(connected_at, {x1=right_area.x1, x2=right_area.x1, y1=right_area.y1, y2=right_area.y2, direction=0}) 
						right_area.direction = 0
						table.insert(new_transition_areas, right_area)
					end
				else 
					if area_util.get_area_size(right_area).size > 0 then 
						table.insert(connected_at, {x1=right_area.x1, x2=right_area.x1, y1=right_area.y1, y2=right_area.y2, direction=2}) 
						left_area.direction = 2
						table.insert(new_transition_areas, right_area)
					end
					center_area.direction = 2
					new_transition_areas[#new_transition_areas+1] = center_area
					if area_util.get_area_size(left_area).size > 0 then 
						table.insert(connected_at, {x1=left_area.x2, x2=left_area.x2, y1=left_area.y1, y2=left_area.y2, direction=2}) 
						right_area.direction = 2
						table.insert(new_transition_areas, left_area)
					end
				end
				log.debug("adding horizontal Sidestep to other side")
				log.debug(new_transition_areas)
			end
		else -- corner case
			log.debug("adding corner")
			local first, second
			local area1, area2
			local area1_first = false
			if dir1 == 1 or dir1 == 3 then
				area1 = entrance
				area2 = exit
				area1_first = true
			else -- entrance is horizontal
				area1 = exit
				area2 = entrance
				area1_first = false
			end
			if area1.y1 < area2.y2 then 
				first = {x1=area1.x1, y1=area1.y1, x2=area1.x2, y2=area2.y2}
				if area1_first then first.direction = 3 else first.direction = 1 end
			else 
				first = {x1=area1.x1, y1=area2.y1, x2=area1.x2, y2=area1.y2} 
				if area1_first then first.direction = 1 else first.direction = 3 end
			end
			local connected_area
			if area2.x1 < area1.x2 then 
				second = {x1=area2.x1, y1=area2.y1, x2=area1.x1, y2=area2.y2}
				if area1_first then second.direction = 2 else second.direction = 0 end
				connected_area= {x1=area1.x1, y1=area2.y1, x2=area1.x1, y2=area2.y2, direction=second.direction}
			else
				second = {x1=area1.x2, y1=area2.y1, x2=area2.x2, y2=area2.y2}
				if area1_first then second.direction = 0 else second.direction = 2 end
				connected_area= {x1=area1.x2, y1=area2.y1, x2=area1.x2, y2=area2.y2, direction=second.direction}
			end
			local first_size = area_util.get_area_size(first).size
			local second_size= area_util.get_area_size(second).size
			if first_size > 0 and second_size > 0 then table.insert(connected_at, connected_area) end
			if area1_first then 
				if first_size > 0 then new_transition_areas[#new_transition_areas+1] = first end
				if second_size > 0 then new_transition_areas[#new_transition_areas+1] = second end
			else 
				if second_size > 0 then new_transition_areas[#new_transition_areas+1] = second end
				if first_size > 0 then new_transition_areas[#new_transition_areas+1] = first end
			end
			log.debug(new_transition_areas)
		end
		table.insert(connected_at, exit)
		dir1 = dir2
		entrance = exit
		log.debug("entrance after creation")
		log.debug(entrance)
		table_util.add_table_to_table(new_transition_areas, resulting_transitions)
	end
	return resulting_transitions, connected_at
end

--[[ teletransporter
properties (table): A table that describles all properties of the entity to create. Its key-value pairs must be:
name (string, optional): Name identifying the entity or nil. If the name is already used by another entity, a suffix (of the form "_2", "_3", etc.) will be automatically appended to keep entity names unique.
layer (number): Layer on the map (0: low, 1: intermediate, 2: high).
x (number): X coordinate on the map.
y (number): Y coordinate on the map.
width (number): Width of the entity in pixels.
height (number): Height of the entity in pixels.
sprite (string, optional): Id of the animation set of a sprite to create for the teletransporter. No value means no sprite (the teletransporter will then be invisible).
sound (string, optional): Sound to play when the hero uses the teletransporter. No value means no sound.
transition (string, optional): Style of transition to play when the hero uses the teletransporter. Must be one of:
"immediate": No transition.
"fade": Fade-out and fade-in effect.
"scrolling": Scrolling between maps. The default value is "fade".
destination_map (string): Id of the map to transport to (can be id of the current map).
destination_name (string, optional): ]]

--[[ destination
properties (table): A table that describles all properties of the entity to create. Its key-value pairs must be:
name (string, optional): Name identifying the entity or nil. If the name is already used by another entity, a suffix (of the form "_2", "_3", etc.) will be automatically appended to keep entity names unique.
layer (number): Layer on the map (0: low, 1: intermediate, 2: high).
x (number): X coordinate on the map.
y (number): Y coordinate on the map.
direction (number): Direction that the hero should take when arriving on the destination, between 0 (East) and 3 (South), or -1 to keep his direction unchanged.
sprite (string, optional): Id of the animation set of a sprite to create for the destination. No value means no sprite (the destination will then be invisible).
default (boolean, optional): ]]

--[[ stairs
properties (table): A table that describes all properties of the entity to create. Its key-value pairs must be:
name (string, optional): Name identifying the entity or nil. If the name is already used by another entity, a suffix (of the form "_2", "_3", etc.) will be automatically appended to keep entity names unique.
layer (number): Layer on the map (0: low, 1: intermediate, 2: high).
x (number): X coordinate on the map.
y (number): Y coordinate on the map.
direction (number): Direction where the stairs should be turned between 0 (East of the room) and 3 (South of the room). For stairs inside a single floor, this is the direction of going upstairs.
subtype (number): Kind of stairs to create:
0: Spiral staircase going upstairs.
1: Spiral staircase going downstairs.
2: Straight staircase going upstairs.
3: Straight staircase going downstairs.
4: Small stairs inside a single floor (change the layer of the hero).
]]

function space_gen.create_indirect_transition(connection_nr, areanumber, transition_details, existing_areas, area_details)
	log.debug("creating indirect transition")
	local new_transition_areas={}
	local direction = {}
	local outside = area_details.outside
	local transition_type
	local layer
	-- create cave stairs in a random spot in both areas, with minimum distance of 3*16 from the walls
	local areanumbers = {areanumber, transition_details.areanumber}
	log.debug("areas")
	log.debug(areanumbers)
	if outside then -- cave_stairs teleports for simplicity
		layer = 0
		log.debug("creating cave stairs")
		for i=1, 2 do
			new_transition_areas[i]=space_gen.pick_random_open_area( 2*16, 3*16, existing_areas, areanumbers[i] )
		end
		transition_type = "cave_stairs"
	else 
		-- check which positions along the edge of the walkable area is available
		layer = 0
		log.debug("creating edge stairs")
		for i=1, 2 do
			new_transition_areas[i], direction[i]=space_gen.pick_random_wall_piece( 48, existing_areas, areanumbers[i], area_details, {1, 3})
			-- TODO if there is no space at top or bottom, we create space inward for a stairs piece
			-- if not direction[i] then -- we need an inward placement of a stairs piece
			-- 	space_gen.pick_random_wall_piece( 96, existing_areas, areanumbers[i], area_details, {2, 4})
			-- end
		end
		transition_type = "edge_stairs"
	end
	-- updating variables based on what is missing and which direction is needed for the destination
	-- stairs direction
	direction[1]=direction[1] or 1
	direction[2]=direction[2] or 1
	local transitions_used = {transition_type.."_"..direction[1], transition_type.."_"..direction[2]}
	local other_pos = {{x=new_transition_areas[1].x1+16, y=new_transition_areas[1].y1+16}, 
						 {x=new_transition_areas[2].x1+16, y=new_transition_areas[2].y1+16}}
	local dest_direction = {(direction[1]+2)%4, (direction[2]+2)%4}
	local dest_pos = {  {x=new_transition_areas[1].x1+24, y=new_transition_areas[1].y1+29}, 
						{x=new_transition_areas[2].x1+24, y=new_transition_areas[2].y1+29}}
	if dest_direction[1] == 1 then 
		dest_pos[1].y=new_transition_areas[1].y1+8
		other_pos[1].y=new_transition_areas[1].y1
	end
	if dest_direction[2] == 1 then 
		dest_pos[2].y=new_transition_areas[2].y1+8
		other_pos[2].y=new_transition_areas[2].y1
	end
	local connected_at = table_util.copy(new_transition_areas)
	for index,dir in ipairs(direction) do
		new_transition_areas[index].direction = dir
	end
	-- destinations are given the coordinates of where the player regains control
	-- for stair this is x+8 and y+13
	local id1 = tostring(connection_nr).."_from"..tostring(areanumbers[2]).."_to"..tostring(areanumbers[1])
	local id2 = tostring(connection_nr).."_from"..tostring(areanumbers[1]).."_to"..tostring(areanumbers[2])
	local dest1_name="destination_"..id1
	local dest2_name="destination_"..id2
	log.debug("creating destinations:\n"..dest1_name.."\n"..dest2_name)
	local dest1 = map:create_destination({name=dest1_name,layer=layer, x=dest_pos[1].x, y=dest_pos[1].y, direction=dest_direction[1]})
	local dest2 = map:create_destination({name=dest2_name,layer=layer, x=dest_pos[2].x, y=dest_pos[2].y, direction=dest_direction[2]})
	map:create_teletransporter({name="transition_"..id2, transition="immediate",layer=layer, 
								x=other_pos[1].x, y=other_pos[1].y, width=16, height=16,
								destination_map=map:get_id(), destination=dest2_name})
	map:create_teletransporter({name="transition_"..id1, transition="immediate",layer=layer, 
								x=other_pos[2].x, y=other_pos[2].y, width=16, height=16,
								destination_map=map:get_id(), destination=dest1_name})
	map:create_stairs({name="stairs_"..id2, layer=layer, x=other_pos[1].x, y=other_pos[1].y, direction=direction[1], subtype="3"})
	map:create_stairs({name="stairs_"..id1, layer=layer, x=other_pos[2].x, y=other_pos[2].y, direction=direction[2], subtype="3"})
	
	log.debug("finished creating indirect transition")
	return new_transition_areas, transitions_used
end


-- TODO Function is a bit long...
-- breadth first search with checks for earlier encountered nodes to avoid loops
function space_gen.check_for_direct_path(path_width, max_length, areanumber1, areanumber2, existing_areas)
	log.debug("checking for direct path between area "..tostring(areanumber1).." and area "..tostring(areanumber2))
	log.debug("area1:")
	log.debug(existing_areas["walkable"][areanumber1])
	log.debug("area2:")
	log.debug(existing_areas["walkable"][areanumber2])
	local depth_list = {1}
	local possible_paths_tree = {[table_util.tostring(depth_list)]={area_type="walkable", length=0, number=areanumber1}}
	local max_depth = 1
	local numbers_encountered = {["walkable"]={[areanumber1]=true}, ["boundary"]={}}
	local done = false
	local found = false
	local new_layer_has_new_entries = false
	while not done do
		local string_key = table_util.tostring(depth_list)
		log.debug("current string key: "..string_key)
		local current_area = existing_areas[possible_paths_tree[string_key].area_type][possible_paths_tree[string_key].number]
		local area_index = 1
		-- test for touching walkable areas
		for i=1, #existing_areas["walkable"] do
			if numbers_encountered["walkable"][i] == nil then
				local test_area = existing_areas["walkable"][i]
				log.debug("space_gen.check_for_direct_path testing touch walkable ")
				log.debug("current_area")
				log.debug(current_area)
				log.debug("test_area walkable "..i)
				log.debug(test_area)
				local touching, along_entire_length, touching_area, touching_direction = area_util.areas_touching(current_area, test_area)
				local touch_size = {x=0, y=0}
				if touching then touch_size = area_util.get_area_size(touching_area) end
				if touching and (touch_size.x >= path_width or touch_size.y >= path_width) then 
					numbers_encountered["walkable"][i] = true
					local length = 0 -- the total length up till the next contact point
					local length_increment = 0 
					if max_depth > 1 then length_increment = 
						area_util.overlap_distance(touching_area, possible_paths_tree[string_key].touch_details.touching_area, path_width) end
					length = possible_paths_tree[string_key].length + length_increment
					if i==areanumber2 then 
						local new_node = {area_type="walkable", length=length, number=i, 
									   touch_details={along_entire_length=along_entire_length, 
									     				touching_area=touching_area, 
									     				touching_direction=touching_direction}}
						depth_list = table_util.concat_table(depth_list, {area_index})
						local new_key = table_util.tostring(depth_list)
						possible_paths_tree[new_key] = new_node
						area_index=area_index+1
						found = true
						log.debug("found the area we were looking for!")
						done = true
						break
					end 
				end
			end
		end
		if done then break end
		-- test for touching boundary areas
		for i=1, #existing_areas["boundary"] do
			if numbers_encountered["boundary"][i] == nil then
				log.debug("testing boundary area "..tostring(i))
				local test_area = existing_areas["boundary"][i]
				local test_size = area_util.get_area_size(test_area)
				if test_size.x >= path_width and test_size.y >= path_width then -- transition might fit
					local touching, along_entire_length, touching_area, touching_direction = area_util.areas_touching(current_area, test_area)
					local touch_size = {x=0, y=0}
					if touching then touch_size = area_util.get_area_size(touching_area) end
					if touching and (touch_size.x >= path_width or touch_size.y >= path_width) then -- transition will definitely fit
						local length = 0 -- the total length up till the next contact point
						local length_increment = 0 
						if max_depth > 1 then 
							length_increment = 
								area_util.overlap_distance(touching_area, possible_paths_tree[string_key].touch_details.touching_area, path_width) 
						end
						length = possible_paths_tree[string_key].length + length_increment
						local new_node = {area_type="boundary", length=length, number=i, 
									     touch_details={along_entire_length=along_entire_length, 
									     				touching_area=touching_area, 
									     				touching_direction=touching_direction}}
						new_layer_has_new_entries= true
						local new_key = table_util.tostring(table_util.concat_table(depth_list, {area_index}))
						log.debug("added key "..new_key)
						possible_paths_tree[new_key] = new_node
						area_index=area_index+1
						numbers_encountered["boundary"][i] = true
					end
				end
			end
		end
		log.debug("found new nodes: "..tostring(new_layer_has_new_entries))
		-- breath first search of boundary areas
		local depth_counter = 1
		local got_next_node = false
		while not got_next_node do
			if depth_counter == max_depth then depth_list[depth_counter] = depth_list[depth_counter] +1 end
			local next_key = {}
			for i=1,depth_counter do
				next_key[i] = depth_list[i]
			end
			next_key = table_util.tostring(next_key)
			log.debug("next_key: "..next_key)
			if possible_paths_tree[next_key] == nil then -- last node in current branch
				if depth_counter > 1 then depth_list[depth_counter-1] = depth_list[depth_counter-1]+1 end
				if depth_counter == max_depth then depth_list[depth_counter] = 0
				else depth_list[depth_counter] = 1 end -- set to first node of the next branch
				depth_counter = depth_counter-1 -- back one step
			elseif depth_counter == max_depth then -- at the lowest depth, so we can safely say we have found the next node
				got_next_node = true
			else -- if not at max depth then we assign a new parent
				depth_counter = depth_counter+1
			end
			if depth_counter == 0 then
				if new_layer_has_new_entries then new_layer_has_new_entries = false
				else 
					done = true
					break 
				end
				depth_list[max_depth] = 1
				depth_list[max_depth+1] = 0
				depth_list[1] = 1
				max_depth = max_depth+1
				depth_counter = 1
				log.debug("going to layer "..tostring(max_depth))
			end
			log.debug("depth_counter: "..tostring(depth_counter))
			log.debug("depth_list: "..table_util.tostring(depth_list))
		end
		-- the rest of the layers are added in the while loop
	end
	local found_path = {}
	if found then -- direct transitions
		log.debug("possible_paths_tree:")
		log.debug(possible_paths_tree)
		local key = {1}
		for i=2,#depth_list do
			key[#key+1]=depth_list[i]
			local string_key = table_util.tostring(key)
			found_path[#found_path+1]=possible_paths_tree[string_key]
		end
	else --indirect transitions
		-- touching areas of the beginning and end area
		found_path={[areanumber1]={}, [areanumber2]={}}
		for _,v in ipairs({areanumber1, areanumber2}) do
			local current_area = existing_areas["walkable"][v]
			for i=1, #existing_areas["boundary"] do
				local test_area = existing_areas["boundary"][i]
				local touching, along_entire_length, touching_area, touching_direction = area_util.areas_touching(current_area, test_area)
				local touch_size = {x=0, y=0}
				if touching then touch_size = area_util.get_area_size(touching_area) end
				if touching and (touch_size.x >= 2*16 or touch_size.y >= 2*16) then -- transition will definitely fit
					local new_node = {area_type="boundary", length=length, number=i, 
								     touch_details={along_entire_length=along_entire_length, 
								     				touching_area=touching_area, 
								     				touching_direction=touching_direction}}
					found_path[v][#found_path[v]+1] = new_node
				end
			end
		end
	end
	return found_path, found
end

function space_gen.conflict_resolution(new_area, existing_areas, boundary_width, new_area_type)
	log.debug("checking for conflicts")
	log.debug(new_area_type)
	log.debug(new_area)
	-- check if the new area falls inside the map
	local width, height = map:get_size()
	if not new_area then return false end
	-- check for area intersections with the new area
	for i = 1, #existing_areas["boundary"] do
		if existing_areas["boundary"][i] then
			local conflict_area = existing_areas["boundary"][i]
			local intersection = area_util.areas_intersect(new_area, conflict_area)
			if intersection then
				-- if the conflicting area is a boundary we will use the following algorithm
				-- shrink the conflicting boundary area with the least amount of pixels
				-- create area that is equal to the part that was shrunken away (conflict area)
				-- check for intersection between the new area and conflict area,
				---- if the conflict area falls into the new area completely, discard the conflict area and end algorithm
				---- if the conflict area falls outside the new area but still intersects then repeat the algorithm
				local conflict_free = false
				log.debug("boundary conflict")
				log.debug("conflict area:")
				log.debug(conflict_area)
				existing_areas["boundary"][i], conflict_area = area_util.shrink_area(conflict_area, intersection)
				intersection = area_util.areas_intersect(new_area, conflict_area)
				log.debug("intersection:")
				log.debug(intersection)
				if area_util.areas_equal(conflict_area, intersection) then conflict_free = true end
				while not conflict_free do
					log.debug("not conflict free")
					log.debug("conflict area:")
					log.debug(conflict_area)
					existing_areas["boundary"][#existing_areas["boundary"]+1], conflict_area = area_util.shrink_area(conflict_area, intersection)
					intersection = area_util.areas_intersect(new_area, conflict_area)
					log.debug("intersection:")
					log.debug(intersection)
					if area_util.areas_equal(conflict_area, intersection) then conflict_free = true end
				end
				log.debug("conflict free again")
			end
		end
	end
	table_util.remove_false(existing_areas["boundary"])
	return new_area
end

-----------------------------------------------------------------------------------------------------------------------------------------------
-----==================================================    Overhaul starts here =========================================----------------------
-----------------------------------------------------------------------------------------------------------------------------------------------



-- Zelda 1 style
function space_gen.generate_simple_space( area_details, given_map )
	map = given_map
	local width, height = map:get_size()
	local new_area_list = {} -- contains walkable, openings and exits
	-- wall width represents either the cave wall or the treelines areas
	-- dimensions 336 x 256 ALLWAYS
	-- this includes the wall width
	-- dimensions for inside rooms: -- ground 256 x 176 -- wallwidth 32
	-- dimensions for outside rooms: -- ground 224 x 160 -- wallwidth 56 x 64
	-- if the plan contains more than one task, we place the other ones at proper distance as if we place a new area
	-- we then place openings that connect with each other
	maze_gen.set_map( map )
	if area_details.outside then maze_gen.set_room( {x1=128, y1=128, x2=width-128, y2=height-128}, {x=224, y=224}, {x=112, y=160} )
							else maze_gen.set_room( {x1=128, y1=128, x2=width-128, y2=height-128}, {x=256, y=256}, 32*2 ) end
	local areas = maze_gen.generate_rooms( area_details )
	log.debug("returned areas from maze_gen")
	log.debug(areas)
	space_gen.create_simple_area_sensors( area_details, areas )
	space_gen.create_simple_enemy_stoppers( areas )
	return areas
end

function space_gen.create_simple_enemy_stoppers( areas )
	log.debug("creating walls for enemies")
	for areanumber, a in pairs(areas["nodes"]) do
		for _, dir in ipairs({0, 1, 2, 3}) do
			local side = area_util.get_side(a.area, dir, -32, 16)
			local details = {layer=0, x=side.x1, y=side.y1, width=side.x2-side.x1, height=side.y2-side.y1, stops_enemies=true}		
			map:create_wall(details)		
		end
	end
end

function space_gen.create_simple_area_sensors( area_details, areas )
	log.debug("creating area sensors")
	for areanumber, a in pairs(areas["walkable"]) do
		local new_area = area_util.resize_area(a.area, {-16, -16, 16, 16})
		placement.show_corners(new_area)
		local details = {name="areasensor_inside_"..areanumber.."_type_"..area_details[areanumber].area_type, 
			layer=0, x=new_area.x1, y=new_area.y1, width=new_area.x2-new_area.x1, height=new_area.y2-new_area.y1}
		-- log.debug(details)
		map:create_sensor(details)
	end
	for areanumber, a in pairs(areas["nodes"]) do
		local width, height = a.area.x2-a.area.x1, a.area.y2-a.area.y1
		if area_details.outside then 
			width = width +8
			height = height +16
		end
		local details = {name="areasensor_outside_"..areanumber.."_type_"..area_details[areanumber].area_type, 
			layer=0, x=a.area.x1, y=a.area.y1, width=width, height=height}
		-- log.debug(details)
		map:create_sensor(details)
	end
end




return space_gen
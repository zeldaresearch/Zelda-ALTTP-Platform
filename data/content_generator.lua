maze_gen 			= maze_gen or require("maze_generator")
pike_room 			= pike_room or require("moving_pike_room")
puzzle_gen			= puzzle_gen or require("puzzle_generator")
placement 			= placement or require("object_placement")
lookup 				= lookup or require("data_lookup")
log 				= log or require("log")
explore 			= explore or require("exploration_log")
puzzle_logger 		= puzzle_logger or require("puzzle_logger")
fight_generator 	= fight_generator or require("fight_generator")

local mission_grammar 	= require("mission_grammar")
local space_gen 		= require("space_generator")
local lookup 			= require("data_lookup")

local table_util 		= require("table_util")
local area_util 		= require("area_util")
local num_util 			= require("num_util")
local light_manager 	= require("maps/lib/light_manager")

local content = {}


-- Main file for the generation of content

-- Main function that is called from a map
-- given_map is the map file that this is called from
-- params contains the generation parameters defined in the map lua file
-- end_destination is the teleport destination when the player reaches the end of the generated map
function content.start_test(given_map, params, end_destination)
	log.verbose = false
	local seed = tonumber(tostring(os.time()):reverse():sub(1,6)) -- good random seeds
	log.debug("random seed = " .. seed)
	math.randomseed( seed )
	-- Initialize the pseudo random number generator
	math.random(); math.random(); math.random(); math.random(); math.random(); math.random()
	-- done. :-)

	local tic = os.clock()
	
	-- set the game to static or dynamic difficulty setting
	if game:get_value("static_difficulty") == nil then
		local random_nr = math.random(1000)
		if random_nr >= 500 then 
			 game:set_value("static_difficulty", true)
		else game:set_value("static_difficulty", false) end
	end

	-- initialize the difficulty settings
	local static_difficulty = game:get_value("static_difficulty")
	fight_generator.static_difficulty = static_difficulty
	fight_generator.fight_difficulty = params.fight_difficulty
	puzzle_gen.static_difficulty = static_difficulty
	puzzle_gen.puzzle_difficulty = params.puzzle_difficulty
	
	-- initialize global variables
	map = given_map
	game = map:get_game()
	hero = map:get_hero()
	hero:freeze()

	-- Copy parameters and fill in standard parameters if not found
	local tileset_id = tonumber(map:get_tileset())
	local outside = false
	if tileset_id == 1 or tileset_id == 13 then outside = true end
	mission_grammar.update_keys_and_barriers(game)
	params = params or {}
	local standard_params = {branches=4, branch_length=0, fights=6, puzzles=4, length=6, barrier_perc=1, outside=outside, mission_type="normal", area_size=1} 
	for k,v in pairs(standard_params) do
		if params[k] == nil then params[k]=v end
	end
	
	-- Produce the graph that is used to generate the map
	mission_grammar.produce_standard_testing_graph(params)
	--mission_grammar.produce_graph(params)
	log.debug("produced graph")
	log.debug(mission_grammar.produced_graph)
	log.debug("area_details")
	content.area_details = mission_grammar.transform_to_space( {tileset_id=tileset_id, 
																outside=outside, 
																from_direction="west", 
																to_direction="east", 
																area_size=params.area_size,--1, 2, or 4
																path_width=2*16}
																)
	content.area_details.map = map
	log.debug(content.area_details)
	-- make sure hud is enabled and control is possible
	hero:set_visible(true)
	game:set_hud_enabled(true)
    game:set_pause_allowed(true)
    game:set_dialog_style("box")
    light_manager.enable_light_features(map)

	-- initialize logs
    explore.start_recording( content.area_details, params )
	puzzle_logger.init_logs()

	-- generate grid based space for rooms
    content.areas = space_gen.generate_simple_space(content.area_details, map)
    log.debug("done with generation")
	
	local exit_areas={}
    local exclusion_areas={}
    local layer
	if content.area_details.outside then -- forest
    	exit_areas, exclusion_areas = content.create_simple_forest_map(content.areas, content.area_details, end_destination)
    	layer = 0
	else -- dungeon
		exit_areas, exclusion_areas = content.create_simple_dungeon_map(content.areas, content.area_details, end_destination)
		layer = 0
	end
	
	-- adding sensors for spawning fights
	fight_generator.add_effects_to_sensors(map, content.areas, content.area_details)
	fight_generator.areastatus = {}
	fight_generator.importWeights()
	if (params.monsteroffset ~= nil) then fight_generator.set_monsterAmountDifficulty( params.monsteroffset ) end

	log.debug("filling in area types")
	log.debug("exclusion_areas")
	log.debug(exclusion_areas)
	local rewards_placed = 0

	-- fill in the space based on the graph
	maze_gen.set_map(map)
	for areanumber, a in pairs(content.areas["walkable"]) do
		log.debug("filling in area "..areanumber)
		log.debug("creating area_type " .. content.area_details[areanumber].area_type)
		if table_util.contains({"P", "TP"}, content.area_details[areanumber].area_type) then 
			local maze_types = {["MP"]="maze", ["PP"]="pike_room", ["SP"]="sokoban"}
			local outside_sensor = map:get_entity("areasensor_outside_"..areanumber.."_type_"..content.area_details[areanumber].area_type )
			outside_sensor.on_activated = 
				function() 
					puzzle_gen.create_puzzle( --"pike_room",
											params.puzzle_type or "equal_amounts", 
						a.area, areanumber, exit_areas[areanumber], exclusion_areas[areanumber], content.area_details, params )
				end
		end
		if content.area_details[areanumber].area_type == "C" then
			local split_contains = table_util.split(content.area_details[areanumber].contains_items[1], ":")
			if split_contains[1] == "EQ" then
				local equipment = split_contains[2] -- quick solution, should be checked for normal and equipment items
				local large_area = area_util.get_largest_area(a.open_areas)
				placement.place_chest(equipment, large_area)
			else
				local reward =  split_contains[2]
				if reward == "heart_container" then explore.log.heart_available = 1 end
				local large_area = area_util.get_largest_area(a.open_areas)
				placement.place_chest(reward, large_area, {["rewards_placed"]=rewards_placed})
				rewards_placed = rewards_placed +1
			end
		end
    end

    explore.log.rewards_available = rewards_placed

    for areanumber, a in pairs(content.areas["nodes"]) do
    	local area = a.area
    	local room_sensor = map:create_sensor({layer=0, x=area.x1, y=area.y1, width=area.x2-area.x1, height=area.y2-area.y1})
		room_sensor.on_activated = 
			function() 
				explore.entered_area( areanumber ) 
			end
    end
    local toc = os.clock()
    log.debug("time required for level generation = "..toc-tic.." sec")

	-- return control to the player
	hero:unfreeze()
	-- place seperators which influences camera movement
	content.place_separators(content.areas)
	-- Open all doors in case the hero died while fighting in the caves
	map:set_doors_open("door_normal_area")
	log.debug("content.areas")
	log.debug(content.areas)

	-- when the map is finished, output the logs
	map.on_finished = 
		function()
			explore.finished_level( )
			puzzle_logger.log_to_data( )
		end
end

-- used in the map itself, sets the items that should be found in the generated level
function content.set_planned_items_for_this_zone( list )
	mission_grammar.planned_items = list
end

function content.open_normal_doors_sensorwise()
	for sensor in map:get_entities("areasensor_outside_") do
		local split_table = table_util.split(sensor:get_name(), "_")
		sensor.on_activated = 
			function()
				map:open_doors("door_normal_area_"..split_table[3])
			end
		sensor.on_left = 
			function ()
				map:close_doors("door_normal_area_"..split_table[3])
			end
	end
end

-- generate a maze in a room
function content.makeSingleMaze(area, exit_areas, area_details, exclusion_area, layer) 
	log.debug("start maze generation")
	local maze = maze_gen.generate_maze( area, exit_areas, exclusion_area, map )
	for _,v in ipairs(maze) do
		placement.place_tile(v.area, lookup.tiles[v.pattern][area_details.tileset_id], "maze", layer)
	end
end

-- place the separators at the edges of the rooms
function content.place_separators( areas )
	for areanumber, a in pairs(areas["nodes"]) do
		local east = area_util.expand_line( area_util.get_side(a.area, 0), 8 )
		local north = area_util.expand_line( area_util.get_side(a.area, 1), 8 )
		local west = area_util.expand_line( area_util.get_side(a.area, 2), 8 )
		local south = area_util.expand_line( area_util.get_side(a.area, 3), 8 )
		map:create_separator{layer=0, x=east.x1, y=east.y1, width=east.x2-east.x1, height=east.y2-east.y1}
		map:create_separator{layer=0, x=north.x1, y=north.y1, width=north.x2-north.x1, height=north.y2-north.y1}
		map:create_separator{layer=0, x=west.x1, y=west.y1, width=west.x2-west.x1, height=west.y2-west.y1}
		map:create_separator{layer=0, x=south.x1, y=south.y1, width=south.x2-south.x1, height=south.y2-south.y1}
    end
end

-- fill the rooms with a forest theme
function content.create_simple_forest_map(areas, area_details, end_destination)
	-- start filling in
	local tileset = area_details.tileset_id
	local bounding_area 
	local exclusion_areas_trees={}
	local ex = 0

	local exit_areas={}
    local exclusion_areas={}

	-- initialize logging for what was generated
    for areanumber, a in pairs(areas["walkable"]) do
    	a.throwables = {["bush"]=0, ["white_rock"]=0, ["black_rock"]=0, ["pot"]=0}
    	a.contact_length = {["pitfall"]=0, ["spikes"]=0}
    	placement.place_tile(area_util.resize_area(a.area, {-16, -16, 16, 16}), 7, "room_floor_"..areanumber, 0)
    end

	-- for all room exits: add barriers, place ground tile, add areas to be excluded when the trees are placed
	for areanumber,connections in pairs(areas["exit"]) do
		exit_areas[areanumber]={}
		exclusion_areas[areanumber]={}
		for _, connection in ipairs(connections) do
			for direction, area in pairs(connection) do
				ex=ex+1
				exclusion_areas_trees[ex] = area
				local adjusted_direction = (direction+2)%4
				local adjusted_exit_area = area_util.get_side(area, adjusted_direction)
				adjusted_exit_area.direction = direction
				table.insert(exit_areas[areanumber], adjusted_exit_area)
				--placement.spread_props(area, 24, {{"flower1","flower2", "fullgrass"}}, 1) 
				placement.place_tile(area, 7, "transition", 0)
				local added_throwables = content.create_simple_barriers( area_details, area_util.from_center(area, 32, 32), direction, areanumber, area.to_area )
				if added_throwables then 
					areas["walkable"][areanumber].throwables.bush = areas["walkable"][areanumber].throwables.bush + added_throwables.bush
					areas["walkable"][areanumber].throwables.white_rock = areas["walkable"][areanumber].throwables.white_rock + added_throwables.white_rock
				end
			end
		end
	end

	-- for all room entrances: place ground tile, add areas to be excluded when the trees are placed
	for areanumber,connections in pairs(areas["entrance"]) do
		for _, connection in pairs(connections) do
			for direction, area in pairs(connection) do
				ex=ex+1
				exclusion_areas_trees[ex] = area
				placement.place_tile(area, 7, "transition", 0)
				local adjusted_direction = (direction+2)%4
				local adjusted_exit_area = area_util.get_side(area, adjusted_direction)
				adjusted_exit_area.direction = direction
				table.insert(exit_areas[areanumber], 1, adjusted_exit_area)
			end
		end
	end
	log.debug("exit_areas")
	log.debug(exit_areas)

	-- Add ground tiles for level entrance and exits and set up teleporters
	for areanumber,connections in pairs(areas["other_map"]) do
		for _, connection in ipairs(connections) do
			for direction, area in pairs(connection) do
				if areanumber == "start" and direction == 2 then 
					map:create_wall{layer=0, x=area.x1, y=area.y1, width=8, height=32, stops_hero=true}
					map:create_destination{name="start_here",layer=0, x=area.x1+16, y=area.y1+16, direction=0, default=true}
					hero:teleport(map:get_id(), "start_here")
				end
				if areanumber == "goal" or areanumber == "optionalgoal" then
					local side = area_util.get_side(area, direction, -16, 16)
					map:create_teletransporter{layer=0, x=side.x1, y=side.y1, width=side.x2-side.x1, height=side.y2-side.y1,  destination_map=end_destination.map_id, destination=end_destination.destination_name}-- "5", "dungeon_entrance_left"
				end
				-- displaying transition areas
				if areanumber == "start" or areanumber == "goal" then
					local adjusted_area = area_util.get_side(area, (direction+2)%4, -64, 0)
					placement.place_tile(adjusted_area, 49, "walkable", 0)
					content.place_edge_tiles(adjusted_area, 8, "floor")
				end
				ex=ex+1
				exclusion_areas_trees[ex] = area
				local adjusted_direction = (direction+2)%4
				local adjusted_exit_area = area_util.get_side(area, adjusted_direction)
				adjusted_exit_area.direction = direction
				table.insert(exit_areas[areanumber], adjusted_exit_area)
			end
		end
	end

	-- Generate the walkable path through the rooms
	local walkable_areas = {}
	for areanumber, a in pairs(areas["walkable"]) do
		local exclusions = {}
		if table_util.contains({"P", "TP", "BOSS"}, area_details[areanumber].area_type) then
			ex=ex+1
			exclusion_areas_trees[ex] = a.area
			table.insert(exclusions, a.area)
			a.open_areas = {a.area}
		else
			maze_gen.set_room( a.area, 16, 0, nil )
			local maze = {}
			maze_gen.initialize_maze( maze )
			local exits = maze_gen.open_exits( maze, exit_areas[areanumber] )
			if table_util.contains({"E", "TF"}, area_details[areanumber].area_type) then 
				open, closed = maze_gen.generate_path( maze, exits, true )
			else
				open, closed = maze_gen.generate_path( maze, exits, false )
			end
			exclusion_areas[areanumber] = closed
			a.open_areas = open
			for _,o in ipairs(open) do
				ex=ex+1
				exclusion_areas_trees[ex] = o
				table.insert(exclusions, o)
			end
			
		end

		if bounding_area == nil then bounding_area = a.area
		else bounding_area = area_util.merge_areas(bounding_area, a.area)
		end
    end

	-- We now have all the walkable areas, in the areas that are left we place the treelines
    bounding_area = area_util.resize_area(bounding_area, {-152, -128, 256, 256}) 
	local treelines = content.plant_trees(bounding_area, areas["walkable"], exclusion_areas_trees)

	-- We determine the left over spaces from planting the trees
	local closed_leftovers = {}
	for areanumber, list in ipairs(exclusion_areas) do
		closed_leftovers[areanumber] = {}
		for _, exclusion in ipairs(list) do
			local adjusted_exclusions = {exclusion}
			for _, tl in ipairs(treelines) do
				local counter=1
				repeat
					local excl = adjusted_exclusions[counter]
					if excl and area_util.areas_intersect(excl, tl) then 
						local new_areas = area_util.shrink_until_no_conflict(tl, excl)
						adjusted_exclusions[counter] = false
						table_util.add_table_to_table(new_areas, adjusted_exclusions)
					else 
						counter = counter +1
					end
				until counter > #adjusted_exclusions
			end
			table_util.remove_false(adjusted_exclusions)
			table_util.add_table_to_table(adjusted_exclusions, closed_leftovers[areanumber])
		end
	end
	
	-- Prop priority from large to small
	local choices = { -- themes
					 { -- a single theme, lists of props ordered from largest to smallest
					  {"green_tree"}, {"old_prison"}, {"stone_hedge"}
					 },
					 {
					  {"green_tree"}, {"small_green_tree"}, --{"tiny_yellow_tree"}
					 },
					 {
					  {"green_tree"}, {"big_statue"}, --{"blue_block"}
					 }
					}

	local destructible = "bush"

	local types_of_filler = {["pitfall"]=20, ["filler"]=60, ["destructible"]=20}
	if tileset == 13 then types_of_filler = {["water"]=40, ["filler"]=40, ["destructible"]=20} end
	
	-- Fill the left over areas
	for areanumber, list in ipairs(closed_leftovers) do 
		local choice_for_that_area = table_util.random(choices)
		for _, c in ipairs(list) do
			local filler_type = table_util.choose_random_key(types_of_filler)				
			if filler_type == "water" then
				placement.place_tile(c, 275, "water", 0)
			elseif filler_type == "pitfall" then
				placement.place_tile(c, 825, "pitfall", 0)
			elseif filler_type == "filler" then
				placement.spread_props(c, 0, choice_for_that_area, 1)
			elseif filler_type == "destructible" then
				placement.tile_destructible( lookup.destructible[destructible], c, "destructible", {} )
			end
		end
	end 		

	-- generate signs for the main path
	for areanumber,connections in pairs(areas["exit"]) do
		for _, connection in ipairs(connections) do
			for direction, area in pairs(connection) do
				for _,con in ipairs(area_details[areanumber]) do
					if con.main and con.areanumber == area.to_area then
						local new_area
						if direction == 0 or direction == 2 then 
							new_area = area_util.merge_areas(area, area_util.get_side(area, direction, 56, 0))
						else
							new_area = area_util.merge_areas(area, area_util.get_side(area, direction, 80, 0))
						end
						content.display_main_path( area_details.outside, new_area, direction )
					end 
				end
			end
		end
	end

	return exit_areas, exclusion_areas
end

-- Dungeons have edge tiles along the walkable areas' edges
function content.place_edge_tiles(area, width, type, layer, custom_name)
	local tileset = tonumber(map:get_tileset())
	local layer = layer or 0; local name = custom_name or "edge"
	local edges, corners = area_util.create_walls(area, width)
	for _, dir in ipairs({0, 1, 2, 3}) do
		placement.place_tile(edges[dir], lookup.wall_tiling[type.."tile"][dir][tileset], name.."tile", 0)
		placement.place_tile(corners[dir], lookup.wall_tiling[type.."corner"][dir][tileset], name.."corner", 0)
	end

end

-- fill the rooms with dungeon theme
function content.create_simple_dungeon_map(areas, area_details, end_destination)
	local tileset = area_details.tileset_id

	-- initialize generation log and place floor and edge tiles
	for areanumber, a in pairs(areas["walkable"]) do
    	a.throwables = {["bush"]=0, ["white_rock"]=0}
    	log.debug("placing floor")
		placement.place_tile(area_util.resize_area(a.area, {-16, -16, 16, 16}), lookup.tiles["dungeon_floor"][tileset], "room_floor_"..areanumber, 0)
		content.place_edge_tiles(a.area, 8, "floor")
    end

    -- walls
    for areanumber, a in pairs(areas["nodes"]) do
		content.place_edge_tiles(area_util.resize_area(a.area, {8, 8, -8, -8}), 24, "wall")
		for _, dir in ipairs({0, 1, 2, 3}) do
			local side = area_util.get_side(a.area, dir, -8, 0)				
			placement.place_tile(side, lookup.tiles["dungeon_spacer"][tileset], "spacer", 1)
		end
    end

    -- transitions
	local exit_areas={}
    local exclusion_areas={}
	for areanumber,connections in pairs(areas["exit"]) do
		exit_areas[areanumber]={}
		exclusion_areas[areanumber]={}
		for _, connection in ipairs(connections) do
			for direction, area in pairs(connection) do
				if direction == 3 or direction == 0 then
					placement.place_prop("edge_doors_"..direction, area, 0, tileset, lookup.transitions)
				end
				-- check if main path
				for _,con in ipairs(area_details[areanumber]) do
					if con.main and con.areanumber == area.to_area then
						local new_area = area_util.merge_areas(area, area_util.get_side(area, direction, 32, 0))
						content.display_main_path( area_details.outside, new_area, direction )
					end 
				end
				local adjusted_direction = (direction+2)%4
				local adjusted_exit_area = area_util.get_side(area, adjusted_direction)
				adjusted_exit_area.direction = direction
				table.insert(exit_areas[areanumber], adjusted_exit_area)
				
				local added_throwables = content.create_simple_barriers( area_details, area_util.get_side(area, (direction+2)%4, 32, 0), direction, areanumber, area.to_area )
				if added_throwables then 
					areas["walkable"][areanumber].throwables.bush = areas["walkable"][areanumber].throwables.bush + added_throwables.bush
					areas["walkable"][areanumber].throwables.white_rock = areas["walkable"][areanumber].throwables.white_rock + added_throwables.white_rock
				end
			end
		end
	end

	-- place doors at the room entrances
	for areanumber,connections in pairs(areas["entrance"]) do
		for _, connection in pairs(connections) do
			for direction, area in pairs(connection) do
				if direction == 3 or direction == 0 then
					placement.place_prop("edge_doors_"..direction, area, 0, tileset, lookup.transitions)
				end
				local adjusted_direction = (direction+2)%4
				local adjusted_exit_area = area_util.get_side(area, adjusted_direction)
				adjusted_exit_area.direction = direction
				table.insert(exit_areas[areanumber], 1, adjusted_exit_area)
				content.create_simple_door( area, areanumber, direction )
			end
		end
	end
	
	-- place doors at the room exits
	for areanumber,connections in pairs(areas["exit"]) do
		for _, connection in ipairs(connections) do
			for direction, area in pairs(connection) do
				content.create_simple_door( area, areanumber, direction )
			end
		end
	end
	
	-- place teleporters and entrance and exit props
	for areanumber,connections in pairs(areas["other_map"]) do
		for _, connection in ipairs(connections) do
			for direction, area in pairs(connection) do
				if areanumber == "start" and direction == 3 then 
					map:create_destination{name="start_here",layer=0, x=area.x1+16, y=area.y1+8, direction=1, default=true}
					hero:teleport(map:get_id(), "start_here")
					placement.place_prop("cave_entrance", area, 0, tileset, lookup.transitions)
				elseif areanumber == "goal" or areanumber == "optionalgoal" then 
					map:create_teletransporter{layer=0, x=area.x1+8, y=area.y1, width=16, height=32, destination_map=end_destination.map_id, destination=end_destination.destination_name} -- "5", "dungeon_exit"
					if direction == 3 then
						placement.place_prop("cave_entrance", area, 0, tileset, lookup.transitions)
					elseif direction == 1 then
						local adjusted_area = area_util.resize_area(area,{0, 8, 0, 0})
						placement.place_prop("cave_stairs_up", adjusted_area, 0, tileset, lookup.transitions)
						map:create_stairs{layer=0, x=adjusted_area.x1+8, y=adjusted_area.y1+8, direction=1, subtype=0}
					end
				end
				local adjusted_direction = (direction+2)%4
				local adjusted_exit_area = area_util.get_side(area, adjusted_direction)
				adjusted_exit_area.direction = direction
				table.insert(exit_areas[areanumber], adjusted_exit_area)
			end
		end
	end

	-- start filling in the rooms
	for areanumber, a in pairs(areas["walkable"]) do
		local choices = {["pitfall"]=2, ["spikes"]=2, ["wall"]=6}
		local filler_choices = {{{"bright_rock_64x64"}, {"bright_rock_48x48"}, {"bright_rock_32x32"}},
					 	--{{"dark_rock_64x64"}, {"dark_rock_48x48"}, {"dark_rock_32x32"}},
					 	--{{"pipe_64x32_h"}, {"pipe_32x32_v"}, {"pipe_16x32_v", "pipe_32x16_h"}}
					 } 
		local filler = {"pipe_16x16_h", "pipe_16x16_v"}

		a.contact_length = {["pitfall"]=0, ["spikes"]=0}

		if not table_util.contains({"P", "TP", "BOSS"}, area_details[areanumber].area_type) then
			maze_gen.set_room( a.area, 16, 0, nil )
			local maze = {}
			maze_gen.initialize_maze( maze )
			local exits = maze_gen.open_exits( maze, exit_areas[areanumber] )
			local open, closed
			if table_util.contains({"E", "TF"}, area_details[areanumber].area_type) then 
				open, closed = maze_gen.generate_path( maze, exits, true )
			else
				open, closed = maze_gen.generate_path( maze, exits, false )
			end
			exclusion_areas[areanumber] = closed
			a.open_areas = open
			local area_assignment = {["pitfall"]={}, ["spikes"]={}, ["wall"]={} }
			
			for _,c in ipairs(closed) do			
				local choice_for_that_area = table_util.choose_random_key(choices)				
				if choice_for_that_area == "pitfall" then
					placement.place_tile(c, 340, "pitfall", 0)
					table.insert(area_assignment.pitfall, c)
				elseif choice_for_that_area == "spikes" then
					placement.place_tile(c, 420, "spikes" , 0)
					table.insert(area_assignment.spikes, c)
				else
					local leftovers = placement.spread_props(c, 0, table_util.random(filler_choices), 1)
					for _,l in ipairs(leftovers) do
						placement.tile_destructible( lookup.destructible.black_rock, l, "destructible", {} )
					end
					table.insert(area_assignment.wall, c)
				end
			end
			
			for _, t in ipairs({"pitfall", "spikes"}) do
				for _, area in ipairs(area_assignment[t]) do
					for _, o in ipairs(open) do
						-- if touching, check the length of the touching area
						local _, _, _, _, touching_length = area_util.areas_touching(area, o)
						a.contact_length[t] = a.contact_length[t] + touching_length/8
						-- add that length/8 to a.contact_length[t]
					end
				end
			end
		else
			a.open_areas = {a.area}
		end
    end


	return exit_areas, exclusion_areas
end

-- Create door at a certain location with a certain direction
function content.create_simple_door( area, areanumber, direction )
	local object_details = lookup.doors["door_normal"]
	local name = "door_normal_area_"..areanumber.."_"..direction
	local position
	local temp_area
	if direction == 1 or direction == 3 then 		
		temp_area = area_util.from_center(area, 16, area.y2-area.y1)
	elseif direction == 0 or direction == 2 then 	
		temp_area = area_util.from_center(area, area.x2-area.x1, 16)
	end
	if direction == 3 or direction == 0 then 		
		position = {x1=temp_area.x1, x2=temp_area.x1+16, y1=temp_area.y1, y2=temp_area.y1+16 }
	elseif direction == 2 or direction == 1 then 	
		position = {x1=temp_area.x2-16, x2=temp_area.x2, y1=temp_area.y2-16, y2=temp_area.y2 }
	end
	local optional = {name=name}
	placement.place_door(object_details, direction, position, optional)
end


-- barrier type is already concluded when the mission grammar is formed
-- so we need to create a table of destructables and doors to place at specific spots along the area
function content.create_simple_barriers( area_details, opening, direction, areanumber, to_area )
	if not to_area then return false end
	
	-- check if area details has anything on barriers to the to_area
	local connection = false
	for k, v in ipairs(area_details[areanumber]) do	if v.areanumber == to_area then connection = k end end
	if not connection then return false
	else
		-- log.debug("found connection "..connection)
		local barriers =area_details[areanumber][connection].barriers
		-- log.debug()
		if barriers == nil then	return false end
		local added_throwables = {["bush"]=0, ["white_rock"]=0, ["black_rock"]=0, ["pot"]=0}
		for _,barrier in pairs(barriers) do
			local split = table_util.split(barrier, ":")
			local barrier_type
			local object_details
			if lookup.destructible[split[2]] then 
				barrier_type = "destructible" 
				object_details = lookup.destructible[split[2]]
				added_throwables[split[2]] = added_throwables[split[2]] + 4
			else
				barrier_type = "door" 
				object_details = lookup.doors[split[2]]
			end
			local obj_size = object_details.required_size
			if split[1] == "L" then
				local dir = direction
				local position
				local temp_area
				if dir == 1 or dir == 3 then 		
					temp_area = area_util.from_center(opening, 16, opening.y2-opening.y1)
	    		elseif dir == 0 or dir == 2 then 	
	    			temp_area = area_util.from_center(opening, opening.x2-opening.x1, 16)
	    		end
	    		if dir == 3 or dir == 0 then 		
					position = {x1=temp_area.x1, x2=temp_area.x1+16, y1=temp_area.y1, y2=temp_area.y1+16 }
	    		elseif dir == 2 or dir == 1 then 	
	    			position = {x1=temp_area.x2-16, x2=temp_area.x2, y1=temp_area.y2-16, y2=temp_area.y2 }
	    		end
	    		local optional = {opening_condition="small_key_map"..map:get_id()}
	    		placement.place_lock( object_details, dir, position, optional )
				-- create lock (placed upon the entry of the transition)
				-- determine direction
				-- place door in beginning of transition at connected_at
			else
				
				-- create destructible and doors (weak_blocks)
				-- determine direction and the area
				-- place destructibles in front of the transition or inside the transition
				if not area_details.outside and area_details[areanumber].area_type == "P" then
					local adjusted_area
					if direction == 1 or direction == 3 then 
						adjusted_area = area_util.resize_area(opening, {0, 8, 0, -8})
					else
						adjusted_area = area_util.resize_area(opening, {8, 0, -8, 0})
					end
					placement.tile_destructible( object_details, adjusted_area , barrier_type, {} )
				else
					placement.tile_destructible( object_details, opening , barrier_type, {} )
				end
			end
		end

		return added_throwables

	end
end


-- create the tree lines for the forest map based on the total area and the exclusion areas
function content.plant_trees(area, areas_to_plant, exclude_these)
	-- create tree lines which will follow a certain pattern uniformly across the map
	local tree_size = {x=64, y=80}
	local x, y, width, height = area.x1, area.y1, area.x2-area.x1, area.y2-area.y1
	local unused_areas = {table_util.copy(area)}
	for _, a in pairs(areas_to_plant) do
		local area_to_plant = area_util.resize_area(a.area, {-152, -128, 64, 128})
		local counter=1
		repeat
			local area_part = unused_areas[counter]
			if area_part and area_util.areas_intersect(area_part, area_to_plant) then 
				local new_areas = area_util.shrink_until_no_conflict(area_to_plant, area_part, "vertical")
				unused_areas[counter] = false
				table_util.add_table_to_table(new_areas, unused_areas)
			else 
				counter = counter +1
			end
		until counter > #unused_areas
	end
 	table_util.remove_false(unused_areas)
	
	-- create each horizontal layer of trees
	local treelines = math.floor((height-32) -- 32 is the height that overlaps with the previous row
										/ 48) -- the height of the tree that is not overlapping at the bottom row
	log.debug("treelines")
	local blocking_size = {x=48, y=64}
	local current_treeline = {}
	local previous_treeline = {}
	local treeline_area_list = {}
	local left_overs = {}
	for i=1, treelines do
		local x_offset = 0
		if i % 2 == 0 then x_offset=24 end
		local top_line = 16+(i-1)*48
		local new_treeline = {x1=x+x_offset+8, y1=y+top_line, 
							  x2=x+width, y2=y+top_line+64}
		local chopped_treeline = {new_treeline}
		
		-- checking for overlap with transitions
		for _, area in ipairs(unused_areas) do
			local counter=1
			repeat
				local tl = chopped_treeline[counter]
				if tl and area_util.areas_intersect(tl, area) then 
					local new_areas = area_util.shrink_until_no_conflict(area, tl, "horizontal")
					chopped_treeline[counter] = false
					table_util.add_table_to_table(new_areas, chopped_treeline)
				else 
					counter = counter +1
				end
			until counter > #chopped_treeline
		end
		table_util.remove_false(chopped_treeline)
		
		-- make sure the treelines fall inside the map
		for j, ctl in ipairs(chopped_treeline) do
			chopped_treeline[j] = area_util.resize_area(ctl, {-128, 0, 128, 0})
		end
		
		-- exclude the walkables from the treelines
		for _, area in ipairs(exclude_these) do
			local counter=1
			repeat
				local tl = chopped_treeline[counter]
				if tl and area_util.areas_intersect(tl, area) then 
					local new_areas = area_util.shrink_until_no_conflict(area, tl, "horizontal")
					chopped_treeline[counter] = false
					table_util.add_table_to_table(new_areas, chopped_treeline)
				else 
					counter = counter +1
				end
			until counter > #chopped_treeline
		end
		
		table_util.remove_false(chopped_treeline)
		
		-- final determination whether a space is large enough to fit a tree, and shrink the areas to fully fit the trees
		current_treeline = {}
		for _, tl in ipairs(chopped_treeline) do
			local area_size = area_util.get_area_size(tl)
			local x_available = (tl.x2 - (tl.x2-x_offset-x) % blocking_size.x) - (tl.x1 + (blocking_size.x - (tl.x1-x_offset-x) % blocking_size.x))
			if area_size.y < blocking_size.y or x_available < blocking_size.x then 
				if i > 1 then
					local intersection_found = false
					for _, prev_tl in ipairs(previous_treeline) do
						if area_util.areas_intersect(tl, prev_tl) then
							intersection_found = true
							local new_areas = area_util.shrink_until_no_conflict(prev_tl, tl, "horizontal")
							table_util.add_table_to_table(new_areas, left_overs)
						end					
					end
					if not intersection_found then 
						table.insert(left_overs, tl)
					end
				end
			else 
				-- chop left side
				tl.y1 = tl.y1+16
				--left
				local till_next_part = (tl.x1-x_offset-x)%blocking_size.x 
				if till_next_part <= 0 then till_next_part = blocking_size.x  
				else till_next_part = blocking_size.x - till_next_part end
				local left_area = {x1=tl.x1,y1=tl.y1,x2=tl.x1+(till_next_part-8),y2=tl.y2}
				tl.x1 = tl.x1+(till_next_part)
				if left_area.x2-left_area.x1 > 8 then
					table.insert(left_overs, left_area)
				end
				-- chop right side
				till_next_part = (tl.x2-x_offset-x)%blocking_size.x 
				if till_next_part <= 0 then till_next_part = blocking_size.x end
				local right_area = {x1=tl.x2-(till_next_part)+8,y1=tl.y1,x2=tl.x2,y2=tl.y2}
				tl.x2 = tl.x2-(till_next_part)
				if right_area.x2-right_area.x1 > 8 then
					table.insert(left_overs, right_area)
				end
				if tl.x2-tl.x1 ~= 0 then 
					table.insert(current_treeline, tl)
				end 
			end
		end
		table_util.add_table_to_table(current_treeline, treeline_area_list)
		previous_treeline = current_treeline
	end
	-- plant the trees
	for _, tl in ipairs(treeline_area_list) do
		--left side
		placement.place_tile({x1=tl.x1-8, y1=tl.y1-3*8, x2=tl.x1, y2=tl.y1+2*8}, 513, "forest", 2) -- left canopy
		placement.place_tile({x1=tl.x2, y1=tl.y1-3*8, x2=tl.x2+8, y2=tl.y1+2*8}, 514, "forest", 2) -- right canopy
		--right side
		placement.place_tile({x1=tl.x1-8, y1=tl.y1+2*8, x2=tl.x1, y2=tl.y1+4*8}, 503, "forest", 0) -- left trunk
		placement.place_tile({x1=tl.x2, y1=tl.y1+2*8, x2=tl.x2+8, y2=tl.y1+4*8}, 504, "forest", 0) -- right trunk
		-- fill the middle
		placement.place_tile({x1=tl.x1, y1=tl.y1-1*8, x2=tl.x2, y2=tl.y1+4*8}, 502, "forest", 0) -- wall
		placement.place_tile({x1=tl.x1, y1=tl.y1+3*8, x2=tl.x2, y2=tl.y1+5*8}, 505, "forest", 0) -- middle trunk
		
		placement.place_tile({x1=tl.x1, y1=tl.y1-2*8, x2=tl.x2, y2=tl.y1+3*8}, 511, "forest", 2) -- middle canopy
		placement.place_tile({x1=tl.x1, y1=tl.y1-4*8, x2=tl.x2, y2=tl.y1-2*8}, 512, "forest", 2) -- top canopy
		-- tricky part, the bottom trunk
		local x = tl.x1+8
		repeat
			placement.place_tile({x1=x, y1=tl.y1+5*8, x2=x+32, y2=tl.y1+6*8}, 523, "forest", 0) -- bottom trunk
			x = x+48
		until x > tl.x2
	end
	for index, tl in ipairs(treeline_area_list) do
		treeline_area_list[index]= area_util.resize_area(tl, {-8, -16, 8, 0})
	end
	return treeline_area_list
end


-- Actual placement of the signs which display the main path
function content.display_main_path( outside, area, direction )
	if outside then
		-- place signs beside the exit saying either, towards mines, towards village
		local sign_to, sign_from
		if direction == 0 then
			sign_to = map:create_npc{layer=0, x=area.x1+24, y=area.y1-3, direction=3, subtype=0, sprite="entities/normal_sign"}
			sign_from = map:create_npc{layer=0, x=area.x2-24, y=area.y1-3, direction=3, subtype=0, sprite="entities/normal_sign"}
		elseif direction == 1 then
			sign_to = map:create_npc{layer=0, x=area.x2+8, y=area.y2-19, direction=3, subtype=0, sprite="entities/normal_sign"}
			sign_from = map:create_npc{layer=0, x=area.x1-8, y=area.y1+29, direction=3, subtype=0, sprite="entities/normal_sign"}
		elseif direction == 2 then
			sign_from = map:create_npc{layer=0, x=area.x1+24, y=area.y1-3, direction=3, subtype=0, sprite="entities/normal_sign"}
			sign_to = map:create_npc{layer=0, x=area.x2-24, y=area.y1-3, direction=3, subtype=0, sprite="entities/normal_sign"}
		elseif direction == 3 then
			sign_from = map:create_npc{layer=0, x=area.x2+8, y=area.y2-19, direction=3, subtype=0, sprite="entities/normal_sign"}
			sign_to = map:create_npc{layer=0, x=area.x1-8, y=area.y1+29, direction=3, subtype=0, sprite="entities/normal_sign"}
		end
		function sign_to:on_interaction() game:start_dialog("test.variable", lookup["sign_to_"..direction]) end
		function sign_from:on_interaction() game:start_dialog("test.variable", lookup["sign_from_"..((direction+2)%4)]) end
	else
		-- place signs beside the exit saying either, towards exit, towards entrance
		local sign_to, sign_from
		if direction == 0 then
			sign_to = map:create_npc{layer=0, x=area.x1+8, y=area.y1-3, direction=2, subtype=0, sprite="entities/hint_stone"}
			sign_from = map:create_npc{layer=0, x=area.x2-8, y=area.y1-3, direction=0, subtype=0, sprite="entities/hint_stone"}
		elseif direction == 1 then
			sign_to = map:create_npc{layer=0, x=area.x2+8, y=area.y2-3, direction=3, subtype=0, sprite="entities/hint_stone"}
			sign_from = map:create_npc{layer=0, x=area.x1-8, y=area.y1+13, direction=1, subtype=0, sprite="entities/hint_stone"}
		elseif direction == 2 then
			sign_from = map:create_npc{layer=0, x=area.x1+8, y=area.y1-3, direction=2, subtype=0, sprite="entities/hint_stone"}
			sign_to = map:create_npc{layer=0, x=area.x2-8, y=area.y1-3, direction=0, subtype=0, sprite="entities/hint_stone"}
		elseif direction == 3 then
			sign_from = map:create_npc{layer=0, x=area.x2+8, y=area.y2-3, direction=3, subtype=0, sprite="entities/hint_stone"}
			sign_to = map:create_npc{layer=0, x=area.x1-8, y=area.y1+13, direction=1, subtype=0, sprite="entities/hint_stone"}
		end
		function sign_to:on_interaction() game:start_dialog("test.variable", lookup["hint_stone_to_"..direction]) end
		function sign_from:on_interaction() game:start_dialog("test.variable", lookup["hint_stone_from_"..((direction+2)%4)] ) end
	end

end




return content
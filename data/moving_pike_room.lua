maze_gen 		= maze_gen or require("maze_generator")
placement 		= placement or require("object_placement")
puzzle_logger 	= puzzle_logger or require("puzzle_logger")

local log 			= require("log")
local table_util 	= require("table_util")
local area_util 	= require("area_util")
local num_util 		= require("num_util")

local pr = {}


function pr.make( parameters )
	local p = parameters
	pr.create_pike_room( p.areanumber, p.area_details, p.area, p.exit_areas, p.speed, p.width, p.movement, p.difficulty )
end

function pr.create_pike_room( areanumber, area_details, area, exit_areas, speed, width, movement, difficulty )
	local map = area_details.map
	if not map:get_entity("pikeroom_sensor_"..areanumber) then 
		explore.puzzle_encountered()
		maze_gen.set_map( map )
		local breed = "pike_fixed"
		if area_details.outside then
			breed = "cactus"
		end
		local original_area = table_util.copy(area)
		-- set the room to appropriate width 16 as wall width
		-- for outside : either {x=560(35*16), y=224(14*16)} or {x=224(14*16), y=608(38*16)}
		-- for inside : either {x=576(36*16), y=256(16*16)} or {x=256(16*16), y=576(36*16)}

		-- 2 (5 rows)  3 (3 rows) or 4 (3 rows) wide 4 3.5 3 2.5 2
		-- length is going to be total RoundDown((length - 16) / ((width+1)*16))*((width+1)*16)+16
		-- breadth is going to be RoundDown((breadth - 16) / ((width+1)*16))*((width+1)*16)+16
		-- dimensions are reduced to 256x592

		local area = table_util.copy(area)
		if area_details.outside then
			if area.x2-area.x1 > area.y2-area.y1 then 
				 area = area_util.resize_area(area, {-16, -16, 16, 16})
			else area = area_util.resize_area(area, {-16, 8, 16, -8}) end
		else 
			if area.x2-area.x1 > area.y2-area.y1 then 
				 area = area_util.resize_area(area, {-8, 0, 8, 0})
			else area = area_util.resize_area(area, {0, -8, 0, 8}) end
		end
		local y_dist = area.y2-area.y1
		local x_dist = area.x2-area.x1
		local length_adjustment = y_dist - ( math.floor( (y_dist - 16) / ((width+1)*16)) * ((width+1)*16)+16 )
		local breadth_adjustment = x_dist - ( math.floor( (x_dist - 16) / ((width+1)*16)) * ((width+1)*16)+16 )
		local left_adjustment = math.floor((breadth_adjustment/8)/2)*8
		local right_adjustment = math.ceil((breadth_adjustment/8)/2)*8
		local top_adjustment = math.floor((length_adjustment/8)/2)*8
		local bottom_adjustment = math.ceil((length_adjustment/8)/2)*8

		if left_adjustment >= 16 or right_adjustment >= 16 or top_adjustment >= 16 or bottom_adjustment >= 16 then
			local corners = { {x1=area.x1, y1=area.y1, x2=area.x1+left_adjustment+8, y2=area.y1+top_adjustment+8},
			{x1=area.x1, y1=area.y2-bottom_adjustment-8, x2=area.x1+left_adjustment+8, y2=area.y2},
			{x1=area.x2-right_adjustment-8, y1=area.y2-bottom_adjustment-8, x2=area.x2, y2=area.y2},
			{x1=area.x2-right_adjustment-8, y1=area.y1, x2=area.x2, y2=area.y1+top_adjustment+8} }

			for _,corner_area in ipairs(corners) do
				map:create_wall{layer=0, x=corner_area.x1, y=corner_area.y1, width=corner_area.x2-corner_area.x1, height=corner_area.y2-corner_area.y1, stops_hero=true}
			end
		end

		area = area_util.resize_area(area, {left_adjustment, top_adjustment, -right_adjustment, -bottom_adjustment })

		maze_gen.set_room( area, width*16, 16, "pikeroom_"..areanumber )

		-- initialize maze

		local maze = {}
		maze_gen.initialize_maze( maze, nil, nil, nil, true  )
		local exits = maze_gen.open_exits( maze, exit_areas )
		local floor

		-- if outside remove old floor, create new one with tile 311

		if area_details.outside then
			local old_floor = map:get_entity("room_floor_"..areanumber)
			local floor_x, floor_y, layer = old_floor:get_position()
			local floor_w, floor_h = old_floor:get_size()
			old_floor:remove()
			floor = map:create_dynamic_tile{name="room_floor_"..areanumber, layer=0, 
											x=area.x1, y=area.y1, width=area.x2-area.x1-16, height=area.y2-area.y1-16, 
											pattern=311, enabled_at_start=true}
			floor.initial_pos={x=area.x1, y=area.y1}
			floor:bring_to_back()
			local walls, corners = area_util.create_walls( area, 16 )
			for _, wall_area in pairs(walls) do
				map:create_dynamic_tile{name="room_floor_wall_"..areanumber, layer=0, 
											x=wall_area.x1, y=wall_area.y1, width=wall_area.x2-wall_area.x1, height=wall_area.y2-wall_area.y1, 
											pattern=310, enabled_at_start=true}
			end
			for _, corner_area in pairs(corners) do
				map:create_dynamic_tile{name="room_floor_corner_"..areanumber, layer=0, 
											x=corner_area.x1, y=corner_area.y1, width=corner_area.x2-corner_area.x1, height=corner_area.y2-corner_area.y1, 
											pattern=310, enabled_at_start=true}
			end
		else
			floor = map:get_entity("room_floor_"..areanumber)
			floor.initial_pos={x=original_area.x1-8, y=original_area.y1-8}
		end

		local room_sensor 
		-- if area_details.outside then
		-- 	room_sensor = placement.place_sensor( area_util.resize_area(area, {8,8,-8,-8}), "pikeroom_sensor_"..areanumber, 0 )
		-- else
		-- 	room_sensor = placement.place_sensor( area, "pikeroom_sensor_"..areanumber, 0 )
		-- end
		local alternate_probabilities = {[0]=20, [1]=20, [2]=20, [3]=20}
		-- determine direction of the maze
		if #maze < #maze[1] then -- vertical
			room_sensor = placement.place_sensor( area_util.resize_area(area, {0,8,0,-8}), "pikeroom_sensor_"..areanumber, 0 )
			if exits[1][1].y < #maze[1]/2 then -- downward
				alternate_probabilities[3]=10
			else -- upward
				alternate_probabilities[1]=10
			end
		else -- horizontal
			room_sensor = placement.place_sensor( area_util.resize_area(area, {8,0,-8,0}), "pikeroom_sensor_"..areanumber, 0 )
			if exits[1][1].x < #maze/2 then -- rightward
				alternate_probabilities[0]=10
			else -- leftward
				alternate_probabilities[2]=10
			end
		end

		-- create a maze with less probability forward, using standard_recursive_maze
		maze_gen.standard_recursive_maze( maze, exits, alternate_probabilities)
		maze_gen.open_unvisited( maze )
		-- convert maze to area list, maze_post and maze_wall_hor and maze_wall_ver to pikes/cactus
		local area_list = maze_gen.convert_maze_to_area_list( maze )

		for _,node in ipairs(area_list) do
			local details = {name="pike_area_"..areanumber.."_nr_1", layer=0, x=0, y=0, direction=3, breed=breed, required_size={x=16, y=16}, offset={x=8, y=13}}
			placement.tile_enemies( details, node.area)
			if node.area.x1 == area.x1 then 
				map:create_wall{layer=0, x=node.area.x1, y=node.area.y1, width=8, height=node.area.y2-node.area.y1, stops_hero=true} 
			end
			if node.area.x2 == area.x2 then 
				map:create_wall{layer=0, x=node.area.x2-8, y=node.area.y1, width=8, height=node.area.y2-node.area.y1, stops_hero=true} 
			end
			if node.area.y1 == area.y1 then 
				map:create_wall{layer=0, x=node.area.x1, y=node.area.y1, width=node.area.x2-node.area.x1, height=8, stops_hero=true} 
			end
			if node.area.y2 == area.y2 then 
				map:create_wall{layer=0, x=node.area.x1, y=node.area.y2-8, width=node.area.x2-node.area.x1, height=8, stops_hero=true} 
			end

		end
		-- check for straight parts of length 3
		-- create a row or column with a node's width of moving pikes
		-- do not overlap with other moving pikes

		local direction
		if movement == "back/forth" then
			if area.x2-area.x1 > area.y2-area.y1 then  
				 direction = 0
			else direction = 2 end
		elseif movement == "side_to_side" then
			if area.x2-area.x1 > area.y2-area.y1 then 
				 direction = 2
			else direction = 0 end
		else direction =  math.random(0, 3)*2
		end
		--local x, y, layer = floor:get_position()
		local pos = floor.initial_pos
		local stream = map:create_stream{name="stream_area_"..areanumber, 
					  layer=0, x=area.x1, y=area.y1, 
					  direction=direction, speed=speed}

		floor:set_optimization_distance(600)
		floor.position, floor.direction, floor.speed, floor.times_till_change, floor.stream = {x=pos.x, y=pos.y}, direction, speed, 4, stream
		local x_offset, y_offset = 0, 0
		if 		floor.direction == 0 then x_offset = 0; y_offset =  0 
		elseif 	floor.direction == 2 then x_offset = 0; y_offset =  16
		elseif 	floor.direction == 4 then x_offset =  16; y_offset = 0
		elseif 	floor.direction == 6 then x_offset =  0; y_offset = 0 end
		floor:set_position(floor.position.x+x_offset, floor.position.y+y_offset, 0)
		pr.move_recurrent( floor, movement )

		

		room_sensor.on_activated = 
			function() 
				if hero:get_animation() == "hurt" and stream:is_enabled() then stream:set_enabled(false) 
				elseif not stream:is_enabled() then stream:set_enabled() end
				local hero_x, hero_y, layer = map:get_hero():get_position()	
				stream:set_position(num_util.clamp(hero_x, area.x1+8, area.x2-8), num_util.clamp(hero_y, area.y1+13, area.y2-3), layer)
				puzzle_logger.start_recording( "pike_room", areanumber, difficulty )
			end
		room_sensor.on_activated_repeat = 
			function() 
				if hero:get_animation() == "hurt" and stream:is_enabled() then stream:set_enabled(false) 
				elseif not stream:is_enabled() then stream:set_enabled() end	
				local hero_x, hero_y, layer = hero:get_position()
				stream:set_position(num_util.clamp(hero_x, area.x1+8, area.x2-8), num_util.clamp(hero_y, area.y1+13, area.y2-3), layer)
			end
		room_sensor.on_left =
			function()
				puzzle_logger.stop_recording()
			end
		local furthest_sensor
		local distance = 0
		for i, exit in ipairs(exits) do
			local area_to_use = maze_gen.nodes_to_area(exit[1], exit[#exit])
			local exit_sensor = placement.place_sensor( area_to_use, "pikeroom_"..areanumber.."_exit_"..i, 0 )
			if i > 1 then 
				local dist = area_util.sqr_distance(exit_areas[1], exit_areas[i])
				if dist > distance then 
					furthest_sensor = exit_sensor
					distance = dist
				end
			end
		end
		furthest_sensor.on_activated = 
				function () 
					puzzle_logger.complete_puzzle() 
				end
	else
		local hero_x, hero_y, layer = map:get_hero():get_position()
		map:get_entity("stream_area_"..areanumber):set_position(hero_x, hero_y, layer)
	end
end

function pr.move_recurrent( obj, movement_type )
	local m = sol.movement.create("path")
	if obj.times_till_change == 0 then
		m:set_speed(16)
		obj.stream:set_speed(16)
	else
		m:set_speed(obj.speed)
		obj.stream:set_speed(obj.speed)
	end
	m:set_path{obj.direction, obj.direction}
	m:set_ignore_obstacles()
	m.on_finished = 
		function ()
			if obj.times_till_change == 0 then
				if movement_type == "side_to_side" then
					obj.direction = (obj.direction +4) %8
				elseif movement_type == "circle" then
					obj.direction = (obj.direction +2) %8
				elseif movement_type == "back/forth" then
					obj.direction = (obj.direction +4) %8
				elseif movement_type == "straight" then
					-- pass
				end
				obj.stream:set_direction(obj.direction)
				obj.times_till_change = 4
			else
				obj.times_till_change = obj.times_till_change -1
			end

			local x_offset, y_offset = 0, 0
			if 		obj.direction == 0 then x_offset = 0; y_offset =  0 
			elseif 	obj.direction == 2 then x_offset = 0; y_offset =  16
			elseif 	obj.direction == 4 then x_offset =  16; y_offset = 0
			elseif 	obj.direction == 6 then x_offset =  0; y_offset = 0 end
			obj:set_position(obj.initial_pos.x+x_offset, obj.initial_pos.y+y_offset, 0)
			pr.move_recurrent( obj, movement_type  )
		end
	m:start(obj)
end

return pr
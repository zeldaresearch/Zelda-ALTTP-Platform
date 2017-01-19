local log 				= require("log")
local table_util 		= require("table_util")
local area_util 		= require("area_util")
local num_util 			= require("num_util")

local lookup 			= require("data_lookup")

local op = {}

function op.spread_props(area, density_offset, prop_names, prop_index)
	-- place randomly in the areas that are left
	local left_over_areas = {}
	local areas_left = {table_util.copy(area)}
	repeat
		-- log.debug("areas_left")
		-- log.debug(areas_left)
		local selected_prop 
		if "table" == type(prop_names[prop_index]) then
			selected_prop = prop_names[prop_index][math.random(#prop_names[prop_index])]
		else
			selected_prop = prop_names[prop_index]
		end
		local min_required_size = {x=lookup.props[selected_prop].required_size.x, y=lookup.props[selected_prop].required_size.y}
		-- if the last area in areas left is not large enough, we discard
		local current_area = table.remove(areas_left)
		local area_size = area_util.get_area_size(current_area)
		if area_size.x < min_required_size.x or area_size.y < min_required_size.y then
			-- pop off last, and try to put in the next prop
			if prop_index < #prop_names then
				local left_overs = op.spread_props(current_area, density_offset, prop_names, prop_index+1)
				table_util.add_table_to_table(left_overs, left_over_areas)
			else
				table.insert(left_over_areas, current_area)
			end
		else
			-- take a random area within the last area
			local random_area = area_util.random_internal_area(current_area, min_required_size.x, min_required_size.y)
			-- if it is large enough then place tree prop, and reduce area by middle canopy size with 8 from the top and bottom
			op.place_prop(selected_prop, random_area, 0)
			local new_areas = area_util.shrink_until_no_conflict( area_util.resize_area(random_area, 
																	{-density_offset, 
																	 -density_offset, 
																	  density_offset, 
																	  density_offset}),
														current_area)

			table_util.add_table_to_table(new_areas, areas_left)
			-- do this until no areas are left
		end
	until next(areas_left) == nil
	return left_over_areas
end

function op.place_walls(area, wall_width)
	local walls, corners = area_util.create_walls(area, wall_width)
	for dir,area_list in pairs(walls) do
		for _,a in ipairs(area_list) do
			content.place_tile(a, lookup.wall_tiling["dungeon"]["wall"][dir], "wall", 0)
		end
	end
	for dir,a in pairs(corners) do
		content.place_tile(a, lookup.wall_tiling["dungeon"]["wall_inward_corner"][dir], "wall_corner", 0)
	end
end

function op.place_door( details, direction, area, optional )
	local layer = optional.layer or 0
	local details = table_util.copy(details)
	details.layer = details.layer+layer
	for k,v in pairs(optional) do
		details[k] = v
	end
	details.direction = direction
	details.x, details.y = area.x1, area.y1
	-- log.debug(details)
	local door = map:create_door(details)
	door:bring_to_front()
end

function op.tile_destructible( details, area, barrier_type, optional )
	optional = optional or {}
	local layer = optional.layer or 0
	local details = details
	details.layer = details.layer+layer
	for k,v in pairs(optional) do
		details[k] = v
	end
	for x=area.x1, area.x2-details.offset.x-1, details.required_size.x do
		for y=area.y1, area.y2-details.offset.y-1, details.required_size.y do
			details.x, details.y = x+details.offset.x, y+details.offset.y
			if barrier_type == "door" then
				-- log.debug("creating door")
				-- log.debug(details)
				map:create_door(details)
			else
				-- log.debug("creating destructible")
				-- log.debug(details)
				map:create_destructible(details)
			end
		end
	end
end

function op.tile_enemies( details, area, optional )
	optional = optional or {}
	local layer = optional.layer or 0
	local details = details
	details.layer = details.layer+layer
	for k,v in pairs(optional) do
		details[k] = v
	end
	for x=area.x1, area.x2-details.offset.x-1, details.required_size.x do
		for y=area.y1, area.y2-details.offset.y-1, details.required_size.y do
			details.x, details.y = x+details.offset.x, y+details.offset.y
			map:create_enemy(details)
		end
	end
end

function op.place_lock( details, direction, area, optional )
	local layer = optional.layer or 0
	local details = table_util.copy(details)
	details.layer = details.layer+layer
	for k,v in pairs(optional) do
		details[k] = v
	end
	details.direction = direction
	details.x, details.y = area.x1, area.y1
	-- log.debug("creating lock")
	-- log.debug(details)
	map:create_door(details)
end

function op.place_chest( object_name, pos, optional )
	local chest_details = { layer=0, x=pos.x1+8, y=pos.y1+13, sprite="entities/chest" }
	if lookup.equipment[object_name] ~= nil then
		for k,v in pairs(lookup.equipment[object_name]) do
			chest_details[k] = v
		end
	elseif lookup.rewards[object_name] ~= nil then
		for k,v in pairs(lookup.rewards[object_name]) do
			chest_details[k] = v
		end
	end
	if optional then
		for k,v in pairs(optional) do
			if k ~= "rewards_placed" then
				chest_details[k] = v
			end
		end
	end
	if chest_details.treasure_name == "rupee" then 
		local save_variable = "reward_"..map:get_id().."_"..(optional.rewards_placed+1)
		if not game:get_value(save_variable) then
			chest_details.treasure_savegame_variable = save_variable
			game:set_value(save_variable, false)
		else
			chest_details.treasure_savegame_variable = save_variable
		end
	end
	if  chest_details.treasure_name == "heart_container" then
		local save_variable = "heart_"..map:get_id()
		if not game:get_value(save_variable) then
			chest_details.treasure_savegame_variable = save_variable
			game:set_value(save_variable, false)
		else
			chest_details.treasure_savegame_variable = save_variable
		end
	end
	log.debug("creating chest with details:")
	log.debug(chest_details)
	map:create_chest(chest_details)
end

function op.place_prop(name, area, layer, tileset_id, use_this_lookup, custom_name)
	local temp_name = custom_name or "prop"..name
	local lookup_table = use_this_lookup or lookup.props
	local nr_of_steps = #lookup_table[name]
	local priority_list = {}
	if nr_of_steps > 0 then
		for i=1, nr_of_steps do
			priority_list[i] = lookup_table[name][i]
		end
	else
		priority_list = {lookup_table[name]}
	end
	for _, lookup in ipairs(priority_list) do
		for positioning, tile in pairs(lookup) do
			if "table" == type( positioning ) then
				local temp_pos={x1=area.x1+positioning.x1,
							    y1=area.y1+positioning.y1,
							    x2=area.x1+positioning.x2,
							    y2=area.y1+positioning.y2}
				local temp_layer = layer or 0
				if positioning.layer ~= nil then temp_layer = temp_layer+positioning.layer end
				local temp_tile = tile
				if "table" == type( tile ) then temp_tile = tile[tileset_id] end
				op.place_tile(temp_pos, temp_tile, temp_name, temp_layer)
			end
	    end
	end
end

function op.show_corners(area, tile_id)
	local layer = 0
	local tileset = tonumber(map:get_tileset())
	local tile_id = tile_id or lookup.tiles["debug_corner"][tileset]
	op.place_tile({x1=area.x1, y1=area.y1, x2=area.x1+8, y2=area.y1+8}, tile_id, "corner", layer)--topleft
	op.place_tile({x1=area.x2-8, y1=area.y1, x2=area.x2, y2=area.y1+8}, tile_id, "corner", layer)--topright
	op.place_tile({x1=area.x2-8, y1=area.y2-8, x2=area.x2, y2=area.y2}, tile_id, "corner", layer)--bottomright
	op.place_tile({x1=area.x1, y1=area.y2-8, x2=area.x1+8, y2=area.y2}, tile_id, "corner", layer)--bottomleft
end

-- area = {x1, y1, x2, y2}
function op.place_tile(area, pattern_id, par_name, layer)
	map:create_dynamic_tile({name=par_name, 
							layer=layer, 
							x=area.x1, y=area.y1, 
							width=math.floor((area.x2-area.x1)/8)*8, height=math.floor((area.y2-area.y1)/8)*8, 
							pattern=pattern_id, enabled_at_start=true})
end

function op.place_sensor( area, name, layer )
	return map:create_sensor({name=name,layer=layer or 0, x=area.x1, y=area.y1, width=area.x2-area.x1, height=area.y2-area.y1})
end

return op
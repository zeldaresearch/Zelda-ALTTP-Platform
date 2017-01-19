local map = ...
local game = map:get_game()

function map:on_started(destination)
	hero:set_visible(true)
	game:set_hud_enabled(true)
    game:set_pause_allowed(true)
    game:set_dialog_style("box")
    local path = generate_path_bottomup(3, "","", 5*5)
    for i=1, #path.areas, 1 do
    	fill_area(path.areas[i].walkable, "1", "walkable", 0)
    end
end


-- generating a path
-- general idea is to create a representation of every area, and connections

-- We try to do this by using a table (connections) of undefined length which contain
-- tables of undefined length to contain representations {type} of connections between nodes
-- One table (areas) explains the type of area, minimal area size, and the density of props.
-- 

-- Things that are to be taken into account:
--1- Areas need to have at least enough space between them to allow the hero to move through and have a 
---- measure of easthetics (predefine cases in which you need extra space)
--2- Connections need to be able to reach their nodes
--3- Area can be resized/scaled, but probably only beforehand (check this!)
--4- positioning of the tiles is based on topleft anchoring
--5- tiles have no size info available, only pattern number (manually add these to lookup tables -_-)

-- nr_of_nodes (number) gives the exact number of nodes used on the map
-- connectivity is a table with the following items:
---- {start_node=number, end_node=number, allowed_types={}, ... }
function generate_path_topdown(nr_of_nodes, connectivity)
	-- this is for a solver, we don't want that...
	local generated_path = {areas={},connections={}}
	for i=1, nr_of_nodes, 1 do
		generated_path.areas[i] = {area_type="empty", min_area_size=25*16, prop_density=0}
	end
	for i=1, nr_of_nodes, 1 do
		-- first try some random connections
		for j=1, math.random(1, 3), 1 do
			generated_path.connections[i][j] = {to=math.random(1, nr_of_nodes), connection_type="direct"}
		end
	end
	return generated_path
end

-- preferred area size is in #tiles (blocks of 16x16)
-- optimal block placement is an NP-Hard problem, do not attempt optimal~!
function generate_path_bottomup(nr_of_nodes, entrytype, tileset, preferred_area_size)
	-- initialize
	local generated_path = {areas={},connections={}}
	-- generate the first area, determine its size and it's walkable area {topleft_x, topleft_y, bottomright_x, bottomright_y}
	local new_origin = {304, 0}
	for i=1, nr_of_nodes, 1 do
		-- create walkable area
		---- area size is determined by parameters
		---- upon creation of an area the generated walkable area will be tested if it overlaps with any other area or connection
		--** randomized dimensions, later dimensions should be based on type of area
		local dimx = math.random(1, math.floor(preferred_area_size/3))
		local dimy = math.floor(preferred_area_size/(dimx))
		generated_path.areas[i] = 	{	walkable={	x1=new_origin[1], 
													y1=new_origin[2],
													x2=new_origin[1]+dimx*16,
													y2=new_origin[2]+dimy*16
												}
									}
		if i > 1 then
			local expanded_area = resize_area(generated_path.areas[i].walkable, {-3*16,-3*16,3*16,3*16});
			local intersecting_areas = {}
			local done = false
			while not done do
				intersecting_areas = {}
				for j=i-1, 1, -1 do
					local intersection = areas_intersect(expanded_area, generated_path.areas[j].walkable)
					if intersection ~= nil then
						intersecting_areas[#intersecting_areas+1]=intersection
						-- shrink/move walkable area until areas no longer intersect
					end
			    end
			    -- how much room am I missing in each direction to comply with the initial map size
			    local width, height = map:get_size()
			    local room_needed = {top=0+expanded_area.y1,
			    					right=width-expanded_area.x2,
			    					left=0+expanded_area.x1,
			    					bottom=height-expanded_area.y2}
			   	local shrink_using_this = {0,0,0,0}
			   	-- shrink it to proper size
			    if room_needed.top < 0 then shrink_using_this[2] = -room_needed.top end
			    if room_needed.right < 0 then shrink_using_this[3] = room_needed.right end
			    if room_needed.left < 0 then shrink_using_this[1] = -room_needed.left end
			    if room_needed.bottom < 0 then shrink_using_this[4] = room_needed.bottom end
			    expanded_area = resize_area(expanded_area, shrink_using_this)
			    local min_direction = {math.max(width, height),0}
			    -- make sure that the expanded area doesn't intersect anymore with any other areas
			    for k=1, #intersecting_areas, 1 do
			    	shrink_using_this = {0,0,0,0}
			    	shrink_using_this[2] = intersecting_areas.y2-expanded_area.y1
			    	shrink_using_this[4] = intersecting_areas.y1-expanded_area.y2
			    	shrink_using_this[3] = intersecting_areas.x1-expanded_area.x2
			    	shrink_using_this[1] = intersecting_areas.x2-expanded_area.x1
			    	min_direction[1] = math.abs(shrink_using_this[1])
			    	min_direction[2] = 1
			    	-- greedy actions first, lowest amount of shrinkage on each intersection
			    	-- not optimal
			    	for s=2, #shrink_using_this,1 do
			    		if math.abs(shrink_using_this[s]) < min_direction[1] then
							shrink_using_this[min_direction[2]] = 0
							min_direction[1] = math.abs(shrink_using_this[s])
							min_direction[2] = s
			    		else
			    			shrink_using_this[s] = 0
			    		end
			    	end
			    	expanded_area = resize_area(expanded_area, shrink_using_this)
			    	generated_path.areas[i].walkable = resize_area(generated_path.areas[i].walkable, shrink_using_this)
			    end
			    -- check if the area is large enough to actually count as an area
			    if get_area_size(generated_path.areas[i].walkable).size > 10 then
			    	done = true
			    	new_origin[1] = generated_path.areas[i].walkable.x2
			    	new_origin[2] = generated_path.areas[i].walkable.y1
			    else
			    	local dimx = math.random(1, math.floor(preferred_area_size/3))
					local dimy = math.floor(preferred_area_size/(dimx))
					generated_path.areas[i] = 	{	walkable={	x1=new_origin[1], 
																y1=new_origin[2],
																x2=new_origin[1]+dimx*16,
																y2=new_origin[2]+dimy*16
															}
												}
			    end
			end
			-- determine type of connection
			---- we'll just use direct connections just to simplify
			-- if it is the starting node, then add connection based on entry from the last area
			-- else
			---- determine starting position of connection 
			--[[
			local connection_type = "border"
			if connection_type == "border" then
				-- direction determined by closeness and whether there is something in between

			end
			--]]
			---- determine shape of connection
			
			---- at the end of connection add new starting point
		end
	end
end

-- area 1 and 2 are both represented
-- the overlap horizontally and vertically
--[[
function get_areas_in_between(area1, area2)
			{x2=math.max(area1.x1, area2.x1), 
			x1=math.min(area1.x2, area2.x2), 
			y1=math.max(area1.y1, area2.y1),
			y2=math.min(area1.y2, area2.y2)}
			{x1=math.max(area1.x1, area2.x1), 
			x2=math.min(area1.x2, area2.x2), 
			y2=math.max(area1.y1, area2.y1),
			y1=math.min(area1.y2, area2.y2)}
end
--]]

function get_area_size(area)
	return {size=((area.x2-area.x1)*(area.y2-area.y1))/16, x=(area.x2-area.x1)/16, y=(area.y2-area.y1)/16}
end

function resize_area(area, resize_table)
	return {x1=area.x1+resize_table[1], y1=area.y1+resize_table[2], x2=area.x2+resize_table[3], y2=area.y2+resize_table[4]}
end

function move_area(area, move_x, move_y)
	return {x1=area.x1+move_x, y1=area.y1+move_y, x2=area.x2+move_x, y2=area.y2+move_y}
end

-- area = {x1, y1, x2, y2}
function fill_area(area, pattern_id, par_name, layer)
	map:create_dynamic_tile({name=par_name, 
							layer=layer, 
							x=area.x1, y=area.y1, 
							width=area.x2-area.x1, height=area.y2-area.y1, 
							pattern=pattern_id, enabled_at_start=true})
end

-- area = {x1, y1, x2, y2}
function areas_intersect(area1, area2)
	if (area1.x1 < area2.x2 and area1.x2 > area2.x1 and
    area1.y1 < area2.y2 and area1.y2 > area2.y1) then
		return {x1=math.max(area1.x1, area2.x1), 
				y1=math.max(area1.y1, area2.y1), 
				x2=math.min(area1.x2, area2.x2), 
				y2=math.min(area1.y2, area2.y2)}
    else
    	return nil
    end
end


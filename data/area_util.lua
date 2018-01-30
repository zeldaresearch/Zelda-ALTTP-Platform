local log = require("log")
local table_util = require("table_util")
local num_util = require("num_util")
local lookup = require("data_lookup")
local area_util = {}

-- This file contains util functions that manipulate areas of the form {x1=num, x2=num, y1=num, y2=num}


-- Used as part of conflict resolution in the space generation
-- Shrinks and splits the new_area into one or more areas such that they do not overlap with the old_area
function area_util.shrink_until_no_conflict(new_area, old_area, preference)
	local conflict_free = false
	local newly_made_areas = {}
	intersection = area_util.areas_intersect(new_area, old_area)
	if not intersection then return {new_area}, false end
	local conflict_area
	newly_made_areas[#newly_made_areas+1], conflict_area = area_util.shrink_area(old_area, intersection, preference)
	intersection = area_util.areas_intersect(new_area, conflict_area)

	if area_util.areas_equal(conflict_area, intersection) then conflict_free = true end
	while not conflict_free do
		newly_made_areas[#newly_made_areas+1], conflict_area = area_util.shrink_area(conflict_area, intersection, preference)
		intersection = area_util.areas_intersect(new_area, conflict_area)
		if area_util.areas_equal(conflict_area, intersection) then conflict_free = true end
	end
	
	table_util.remove_false(newly_made_areas)
	return newly_made_areas, conflict_area
end

-- Used to assist the space generation of rooms
-- Using the area as outer boundary, wall areas are returned with a certain width
function area_util.create_walls( area, wall_width )
	local walls = {[1]={x1=area.x1+wall_width, x2=area.x2-wall_width, y1=area.y1, y2=area.y1+wall_width}, -- north
				   [0]={x1=area.x2-wall_width, x2=area.x2, y1=area.y1+wall_width, y2=area.y2-wall_width}, -- east
				   [2]={x1=area.x1, x2=area.x1+wall_width, y1=area.y1+wall_width, y2=area.y2-wall_width}, -- west
				   [3]={x1=area.x1+wall_width, x2=area.x2-wall_width, y1=area.y2-wall_width, y2=area.y2}} -- south
	local corners = {[1]={x1=area.x2-wall_width, x2=area.x2, y1=area.y1, y2=area.y1+wall_width}, -- northeast
					 [2]={x1=area.x1, x2=area.x1+wall_width, y1=area.y1, y2=area.y1+wall_width}, -- northwest
					 [0]={x1=area.x2-wall_width, x2=area.x2, y1=area.y2-wall_width, y2=area.y2}, -- southeast
					 [3]={x1=area.x1, x2=area.x1+wall_width, y1=area.y2-wall_width, y2=area.y2}} -- southwest
	return walls, corners
end

-- Util function to get the amount of pixels in the area, and the length of x and y
function area_util.get_area_size(area)
	return {size=((area.x2-area.x1)*(area.y2-area.y1)), x=(area.x2-area.x1), y=(area.y2-area.y1)}
end

-- Util function to offset the boundaries of an area
-- resize_table={x1, y1, x2, y2}
function area_util.resize_area(area, resize_table)
	local result = table_util.copy(area)
	result.x1 = result.x1+resize_table[1]
	result.y1 = result.y1+resize_table[2]
	result.x2 = result.x2+resize_table[3]
	result.y2 = result.y2+resize_table[4]
	return result
end

-- Util function to move the area a certain amount of pixels
function area_util.move_area(area, move_x, move_y)
	local result = table_util.copy(area)
	result.x1 = result.x1+move_x
	result.y1 = result.y1+move_y
	result.x2 = result.x2+move_x
	result.y2 = result.y2+move_y
	return result
end

-- Util function to test whether area1 intersects with area2 and returns the intersecting area if it does
-- area = {x1, y1, x2, y2}
function area_util.areas_intersect(area1, area2)
	if (area1.x1 < area2.x2 and area1.x2 > area2.x1 and
    area1.y1 < area2.y2 and area1.y2 > area2.y1) then
		return {x1=math.max(area1.x1, area2.x1), 
				y1=math.max(area1.y1, area2.y1), 
				x2=math.min(area1.x2, area2.x2), 
				y2=math.min(area1.y2, area2.y2)}
    else
    	return false
    end
end

-- Util function to test if areas are equal
function area_util.areas_equal(area1, area2)
	if 	area1.x1 == area2.x1 and
		area1.x2 == area2.x2 and
		area1.y1 == area2.y1 and
		area1.y2 == area2.y2 then
	 	return true
	else
		return false
	end
end


-- Util function to cut off any part of the given area such that limit_this_area falls inside to_this_area
function area_util.limit_area_to_area(limit_this_area, to_this_area)
	local result = table_util.copy(limit_this_area)
	local limited_area = {
			x1=math.min(math.max(limit_this_area.x1, to_this_area.x1), to_this_area.x2),
			x2=math.max(math.min(limit_this_area.x2, to_this_area.x2), to_this_area.x1),
			y1=math.min(math.max(limit_this_area.y1, to_this_area.y1), to_this_area.y2),
			y2=math.max(math.min(limit_this_area.y2, to_this_area.y2), to_this_area.y1),
			}
	result.x1, result.x2, result.y1, result.y2 = limited_area.x1, limited_area.x2, limited_area.y1, limited_area.y2
	if area_util.get_area_size(limited_area).size == 0 then return false end
	return result
end

-- Util test to test if area1 and area2 are adjescent and touching and in which direction and the touching length
-- touching direction is from 1 to 2
-- 0:east, 1:north, 2:west, 3:south
function area_util.areas_touching(area1, area2)
	local touching = true
	local along_entire_length = {false, false}
	local touching_area = {}
	local touching_direction = false
	local touching_length = 0
	if area1.x1 == area2.x2 and area2.y1 < area1.y2 and area2.y2 > area1.y1 then -- area1 west is touching
		touching_direction = 2
		touching_area = {x1=area1.x1, y1=math.max(area1.y1, area2.y1), x2=area1.x1, y2=math.min(area1.y2, area2.y2)}
		touching_length = touching_area.y2-touching_area.y1
	elseif area1.x2 == area2.x1 and area2.y1 < area1.y2 and area2.y2 > area1.y1 then -- area1 east is touching
		touching_direction = 0
		touching_area = {x1=area1.x2, y1=math.max(area1.y1, area2.y1), x2=area1.x2, y2=math.min(area1.y2, area2.y2)}
		touching_length = touching_area.y2-touching_area.y1
	elseif area1.y1 == area2.y2 and area2.x1 < area1.x2 and area2.x2 > area1.x1 then -- area1 north is touching
		touching_direction = 1
		touching_area = {x1=math.max(area1.x1, area2.x1), y1=area1.y1, x2=math.min(area1.x2, area2.x2), y2=area1.y1}
		touching_length = touching_area.x2-touching_area.x1
	elseif area1.y2 == area2.y1 and area2.x1 < area1.x2 and area2.x2 > area1.x1 then -- area1 south is touching
		touching_direction = 3
		touching_area = {x1=math.max(area1.x1, area2.x1), y1=area1.y2, x2=math.min(area1.x2, area2.x2), y2=area1.y2}
		touching_length = touching_area.x2-touching_area.x1
	else touching = false end
	if (area1.y1 >= area2.y1 and area1.y2 <= area2.y2) or (area1.x1 >= area2.x1 and area1.x2 <= area2.x2) then along_entire_length[1] = true end
	if (area1.y1 <= area2.y1 and area1.y2 >= area2.y2) or (area1.x1 <= area2.x1 and area1.x2 >= area2.x2) then along_entire_length[2] = true end
	return touching, along_entire_length, touching_area, touching_direction, touching_length
end


-- Util function to generate a random sized area with a certain origin point where normal is the top left anchor
-- area_details = {preferred_area_surface=number, wall_width=number}
-- origin = {x, y, origindirection}
function area_util.random_area(area_details, origin)
	local preferred_area_surface = area_details.preferred_area_surface
	local wall_width = area_details.wall_width
	local dimxy_sqrt = math.floor(math.sqrt(preferred_area_surface))
	local dimx = dimxy_sqrt+math.random(-math.floor(dimxy_sqrt/5), math.floor(dimxy_sqrt/5))
	local dimy = math.floor(preferred_area_surface/(dimx))
	if origin[3] == "normal" then
		return {	x1=origin[1], 
					y1=origin[2],
					x2=origin[1]+dimx*16+2*wall_width,
					y2=origin[2]+dimy*16+2*wall_width
				}
	elseif origin[3] == "north" then
		return {x1 = origin[1]-math.floor(dimx/2)*16-wall_width,
				y1 = origin[2]-dimy*16-2*wall_width,
				x2 = origin[1]+math.ceil(dimx/2)*16+wall_width,
				y2 = origin[2]}
	elseif origin[3] == "south" then
		return {x1 = origin[1]-math.floor(dimx/2)*16-wall_width,
				y1 = origin[2],
				x2 = origin[1]+math.ceil(dimx/2)*16+wall_width,
				y2 = origin[2]+dimy*16+2*wall_width}
	elseif origin[3] == "east" then
		return {x1 = origin[1],
				y1 = origin[2]-math.floor(dimy/2)*16-wall_width,
				x2 = origin[1]+dimx*16+2*wall_width,
				y2 = origin[2]+math.ceil(dimy/2)*16+wall_width}
	elseif origin[3] == "west" then
		return {x1 = origin[1]-dimx*16-2*wall_width,
				y1 = origin[2]-math.floor(dimy/2)*16-wall_width,
				x2 = origin[1],
				y2 = origin[2]+math.ceil(dimy/2)*16+wall_width}
	else 
		return false
	end

end

-- Used in the space generation of mazes and rooms
-- Util function to expand an area with a width or length of 0 to a rectangular area
function area_util.expand_line( area, width )
	local expanded_area
	if area.y1 == area.y2 then -- needs to be expanded vertically
		expanded_area = area_util.resize_area(area, {0, -width, 0, width})
	else -- needs to be expanded horizontally
		expanded_area = area_util.resize_area(area, {-width, 0, width, 0})
	end
	return expanded_area
end

-- Util function that helps shape an area based on the point of another area
-- helper function for creating transitions that will be close together
function area_util.area_cutoff(closest_point, max_distance, area, min_width, min_height)
	local new_area = table_util.copy(area)
	local width = area.x2-area.x1
	local height = area.y2-area.y1
	-- horizontal
	if closest_point.x < area.x2 then  -- if closest_point is left of the area then we need to cut from the right side
		local distance = area.x2-closest_point.x 
		if distance > max_distance and width > min_width then
			new_area.x2 = num_util.clamp(new_area.x2-(distance-max_distance), new_area.x1+min_width, math.huge)
		end
	end
	if closest_point.x > area.x1 then  -- if closest_point is right of the area then we need to cut from the right side
		local distance = closest_point.x-area.x1
		if distance > max_distance and width > min_width then
			new_area.x1 = num_util.clamp(new_area.x1+(distance-max_distance), 0, new_area.x2-min_width)
		end
	end
	--vertical
	if closest_point.y < area.y2 then  -- if closest_point is above the area then we need to cut from the bottom side
		local distance = area.y2-closest_point.y 
		if distance > max_distance and height > min_height then
			new_area.y2 = num_util.clamp(new_area.y2-(distance-max_distance), new_area.y1+min_height, math.huge)
		end
	end
	if closest_point.y > area.y1 then  -- if closest_point is below the area then we need to cut from the top side
		local distance = closest_point.y-area.y1
		if distance > max_distance and height > min_height then
			new_area.y1 = num_util.clamp(new_area.y1+(distance-max_distance), 0, new_area.y2-min_width)
		end
	end
	return new_area
end

-- Util function to get a random piece of an area with a certain width and height 
-- if the width and height parameters are larger than the area, then the entire area is returned
function area_util.random_internal_area(area, width, height)
	local new_area = {}
	if  area.x2 - area.x1 > width then 
		new_area.x1 = math.floor(math.random(area.x1, area.x2-width)/16)*16
		new_area.x2 = new_area.x1+width
	else 
		new_area.x1 = area.x1
		new_area.x2 = area.x2
	end
	if  area.y2 - area.y1 > height then 
		new_area.y1 = math.floor(math.random(area.y1, area.y2-height)/16)*16
		new_area.y2 = new_area.y1+height
	else 
		new_area.y1 = area.y1
		new_area.y2 = area.y2
	end
	return new_area
end

-- Util function to merge 2 areas
-- only merge areas that are touching along entire length
-- or when trying to find the area span of 2 areas
function area_util.merge_areas(area1, area2)
	return {x1=math.min(area1.x1, area2.x1), 
			y1=math.min(area1.y1, area2.y1), 
			x2=math.max(area1.x2, area2.x2), 
			y2=math.max(area1.y2, area2.y2)}
end

-- Not used
-- Util function to find the area in between two areas
function area_util.get_areas_in_between(area1, area2)
	return  {x2=math.max(area1.x1, area2.x1), 
			x1=math.min(area1.x2, area2.x2), 
			y1=math.max(area1.y1, area2.y1),
			y2=math.min(area1.y2, area2.y2)}, 
			{x1=math.max(area1.x1, area2.x1), 
			x2=math.min(area1.x2, area2.x2), 
			y2=math.max(area1.y1, area2.y1),
			y1=math.min(area1.y2, area2.y2)}
end

-- Util function to get the largest area
function area_util.get_largest_area( areas )
	local largest_area
	local max_size = 0
	for _,area in ipairs(areas) do
		local size = area_util.get_area_size(area).size
		if largest_area == nil or size > max_size then
			largest_area = area; max_size = size
		end
	end
	return largest_area
end

-- Get sqrt squared distance between two areas
function area_util.sqr_distance(area1, area2)
	local center1 = {x=(area1.x1+area1.x2)/2, y=(area1.y1+area1.y2)/2}
	local center2 = {x=(area2.x1+area2.x2)/2, y=(area2.y1+area2.y2)/2}
	local zeroed = {x=center1.x-center2.x, y=center1.y-center2.y}
	return math.sqrt(zeroed.x^2+zeroed.y^2)
end

-- Util function to get the distance between two areas with an optional overlap that should be required
function area_util.overlap_distance(area1, area2, overlap_required)
	local x_distance = 0
	if area2.x2 < area1.x1 then x_distance = area1.x1 - area2.x2 + overlap_required -- area2 is left of area1
	elseif area2.x1 > area1.x2 then x_distance = area2.x1 - area1.x2 + overlap_required -- area 2 is right of area1
	elseif area2.x1 < area1.x1 and area2.x2 > area1.x1 then -- there is horizontal overlap on the left side
		local overlap = area2.x2 - area1.x1
		if overlap < overlap_required then x_distance = overlap_required - overlap end
	elseif area2.x1 < area1.x2 and area2.x2 > area1.x2 then -- there is horizontal overlap on the right side
		local overlap = area1.x2 - area2.x1
		if overlap < overlap_required then x_distance = overlap_required - overlap end
	end
	local y_distance = 0
	if area2.y2 < area1.y1 then y_distance = area1.y1 - area2.y2 + overlap_required -- area2 is left of area1
	elseif area2.y1 > area1.y2 then y_distance = area2.y1 - area1.y2 + overlap_required -- area 2 is right of area1
	elseif area2.y1 < area1.y1 and area2.y2 > area1.y1 then -- there is vertical overlap on the top side
		local overlap = area2.y2 - area1.y1
		if overlap < overlap_required then y_distance = overlap_required - overlap end
	elseif area2.y1 < area1.y2 and area2.y2 > area1.y2 then -- there is vertical overlap on the bottom side
		local overlap = area1.y2 - area2.y1
		if overlap < overlap_required then y_distance = overlap_required - overlap end
	end
	return math.sqrt(x_distance^2 + y_distance^2), x_distance, y_distance
end

-- function used within shrink_until_no_conflict
-- Util function to shrink an area once based on the intersection such that the area doesn't overlap with the intersection
function area_util.shrink_area(area_to_be_shrunk, intersection, preference)
	local area_width = area_to_be_shrunk.x2-area_to_be_shrunk.x1
	local area_height = area_to_be_shrunk.y2-area_to_be_shrunk.y1
	local min_direction = {math.max(area_width, area_height),0, 1}
	-- make sure that the expanded area doesn't intersect anymore with any other areas
	local shrink_using_this = {0,0,0,0}
	local ratios = {0,0,0,0}
	-- 2:southward, 4:northward, 3:eastward, 1:westward
	shrink_using_this[2] = intersection.y2-area_to_be_shrunk.y1
	shrink_using_this[4] = intersection.y1-area_to_be_shrunk.y2
	shrink_using_this[3] = intersection.x1-area_to_be_shrunk.x2
	shrink_using_this[1] = intersection.x2-area_to_be_shrunk.x1
	if area_width == 0 then
		ratios[1] = 1
		ratios[3] = 1
	else
		ratios[1] = math.abs(shrink_using_this[1])/area_width
		ratios[3] = math.abs(shrink_using_this[3])/area_width
	end
	if area_height == 0 then
		ratios[2] = 1
		ratios[4] = 1
	else
		ratios[2] = math.abs(shrink_using_this[2])/area_height
		ratios[4] = math.abs(shrink_using_this[4])/area_height
	end
	min_direction[1] = math.abs(shrink_using_this[1])
	min_direction[2] = 1
	min_direction[3] = ratios[1]	
	if preference == "horizontal" and (ratios[1] < 1 or ratios[3] < 1) then
		if ratios[1] < ratios[3] then
			shrink_using_this[2], shrink_using_this[3], shrink_using_this[4] = 0, 0, 0
			min_direction = {math.abs(shrink_using_this[1]), 1, ratios[1]}
		else
			shrink_using_this[1], shrink_using_this[2], shrink_using_this[4] = 0, 0, 0
			min_direction = {math.abs(shrink_using_this[3]), 3, ratios[3]}
		end
	elseif preference == "vertical" and (ratios[2] < 1 or ratios[4] < 1) then
		if ratios[2] < ratios[4] then
			shrink_using_this[1], shrink_using_this[3], shrink_using_this[4] = 0, 0, 0
			min_direction = {math.abs(shrink_using_this[2]), 2, ratios[2]}
		else
			shrink_using_this[1], shrink_using_this[2], shrink_using_this[3] = 0, 0, 0
			min_direction = {math.abs(shrink_using_this[4]), 4, ratios[4]}
		end
	else
		-- greedy actions first, lowest amount of shrinkage on each intersection
		for s=2, #shrink_using_this do
			if ratios[s] < min_direction[3] then
				shrink_using_this[min_direction[2]] = 0
				min_direction[1] = math.abs(shrink_using_this[s])
				min_direction[2] = s
				min_direction[3] = ratios[s]
			else
				shrink_using_this[s] = 0
			end
		end
	end

	local newly_made_area
	if min_direction[3] == 1 then newly_made_area = false
	else newly_made_area = area_util.resize_area(area_to_be_shrunk, shrink_using_this) end

	-- now the other way around
	if 		min_direction[2] == 1 then -- shrunk left side
				shrink_using_this[min_direction[2]] = min_direction[1] - area_width
	elseif 	min_direction[2] == 2 then -- shrunk top side
				shrink_using_this[min_direction[2]] = min_direction[1] - area_height
	elseif 	min_direction[2] == 3 then -- shrunk right side
				shrink_using_this[min_direction[2]] = area_width - min_direction[1] 
	elseif 	min_direction[2] == 4 then -- shrunk bottom side
				shrink_using_this[min_direction[2]] = area_height - min_direction[1] 
	end
	shrink_using_this[1], shrink_using_this[2], shrink_using_this[3], shrink_using_this[4] = 
		shrink_using_this[3], shrink_using_this[4], shrink_using_this[1], shrink_using_this[2]
	local conflict_area = area_util.resize_area(area_to_be_shrunk, shrink_using_this)
	return newly_made_area, conflict_area
end

-- Not used
-- Util function to find a randomized origin point
-- Was used for randomized generation of areas
-- directions = {"north","south", "east", "west"}
-- origin_point= {x, y, expansiondirection}
function area_util.find_origin_along_edge(area, direction, offset)
	local x, y
	x = math.floor(math.random(area.x1, area.x2)/16)*16
	y = math.floor(math.random(area.y1, area.y2)/16)*16
	local randomized_offset = math.floor((offset * math.random() + offset)/16)*16
	if direction == "north" then
		return {x, area.y1-randomized_offset, direction}
	elseif direction == "south" then
		return {x, area.y2+randomized_offset, direction}	
	elseif direction == "east" then
		return {area.x2+randomized_offset, y, direction}
	elseif direction == "west" then
		return {area.x1-randomized_offset, y, direction} -- originpoint
	else 
		return false
	end
end

-- Used in space generation
-- Util function to return a line or new area that is located on the edge in a certain direction from the given area
-- 0:east, 1:north, 2:west, 3:south
function area_util.get_side(area, direction, pluslength, pluswidth)
	local pluslength = pluslength or 0
	local pluswidth = pluswidth or 0
	if direction == 0 then return area_util.correct({x1=area.x2, x2=area.x2+pluslength, y1=area.y1-pluswidth, y2=area.y2+pluswidth}) end
	if direction == 1 then return area_util.correct({x1=area.x1-pluswidth, x2=area.x2+pluswidth, y1=area.y1-pluslength, y2=area.y1}) end
	if direction == 2 then return area_util.correct({x1=area.x1-pluslength, x2=area.x1, y1=area.y1-pluswidth, y2=area.y2+pluswidth}) end
	if direction == 3 then return area_util.correct({x1=area.x1-pluswidth, x2=area.x2+pluswidth, y1=area.y2, y2=area.y2+pluslength}) end
	return false
end

-- Used in space generation
-- Util function to get an area of a given {x, y} size from the center of a given area
function area_util.from_center( area, x, y, round_to_8)
	local center_x
	local center_y
	if not round_to_8 then 
		center_x = (area.x2+area.x1)/2
		center_y = (area.y2+area.y1)/2
	else
		center_x = math.floor(((area.x2+area.x1)/2)/8)*8
		center_y = math.floor(((area.y2+area.y1)/2)/8)*8
	end
	return {x1=center_x-x/2, x2=center_x+x/2, y1=center_y-y/2, y2=center_y+y/2}
end

-- makes sure there are no negative width or height in the area
function area_util.correct(area)
	return {x1=math.min(area.x1, area.x2), x2=math.max(area.x1, area.x2), y1=math.min(area.y1, area.y2), y2=math.max(area.y1, area.y2)}
end

return area_util
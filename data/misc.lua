-- Copyright (c) 2014, lordnaugty
-- All rights reserved.

-- Redistribution and use in source and binary forms, with or without 
-- modification, are permitted provided that the following conditions are met:

-- 1. Redistributions of source code must retain the above copyright notice, 
-- this list of conditions and the following disclaimer.

-- 2. Redistributions in binary form must reproduce the above copyright 
-- notice, this list of conditions and the following disclaimer in the 
-- documentation and/or other materials provided with the distribution.

-- 3. Neither the name of the copyright holder nor the names of its
-- contributors may be used to endorse or promote products derived from this 
-- software without specific prior written permission.

-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE 
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
-- SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
-- CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
-- OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
-- OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


function assertf( cond, ... )
	if not cond then
		error(string.format(...), 2)
	end
end


function math.round( value )
	return math.floor(0.5 + value)
end

function table.keys( tbl )
	local result = {}

	for k, _ in pairs(tbl) do
		result[#result+1] = k
	end

	return result
end

function table.copy( tbl )
	local result = {}

	for k, v in pairs(tbl) do
		result[k] = v
	end

	return result
end

function table.count( tbl )
	local result = 0

	for _ in pairs(tbl) do
		result = result + 1
	end

	return result
end

function table.random( tbl )
	local count = table.count(tbl)

	local index = math.random(1, count)
	local k = nil

	for i = 1, index do
		k = next(tbl, k)
	end

	return k, tbl[k]
end

function table.shuffle( tbl )
	for i = 1, #tbl-1 do
		local index = math.random(i, #tbl)
		tbl[i], tbl[index] = tbl[index], tbl[i]
	end
end

function table.collect( tbl, func )
	local result = {}

	for k, v in pairs(tbl) do
		result[k] = func(v)
	end

	return result
end


function printf( ... )
	print(string.format(...))
end

function table.print( tbl, indent )
	indent = indent or 0
	for k, v in pairs(tbl) do
		printf('%s%s = %s', string.rep(' ', indent), tostring(k), tostring(v))

		if type(v) == 'table' then
			table.print(v, indent + 2)
		end
	end
end

-------------------------------------------------------------------------------

local epsilon = 1 / 2^7

function lerpf( value, in0, in1, out0, out1 )
    -- This isn't just to avoid a divide by zero but also a catstrophic loss of precision.
	assertf(math.abs(in1 - in0) > epsilon, "lerp() - in bounds [%f..%f] are too close together", in0, in1)
	local normed = (value - in0) / (in1 - in0)
	local result = out0 + (normed * (out1 - out0))
	return result
end

-------------------------------------------------------------------------------

-- TODO: This is less efficient than an array of arrays so change it.
function newgrid( width, height, value )
	local data = {}

	for x = 1, width do
		local column = {}
		for y = 1, height do
			column[y] = value
		end
		data[x] = column
	end

	return {
		width = width,
		height = height,
		set = 
			function ( x, y, value )
				data[x][y] = value
			end,
		get =
			function ( x, y )
				return data[x][y]
			end,
		print =
			function ()
				for y = 1, height do
					local line = {}
					for x = 1, width do
						line[x] = (data[x][y]) and 'x' or '.'
					end
					print(table.concat(line))
				end
			end,
	}
end

-------------------------------------------------------------------------------

Dampener = {}
Dampener.__index = Dampener

function Dampener.newf( value, target, bias )
	local result = {
		value = value,
		target = target,
		bias = bias,
	}

	setmetatable(result, Dampener)

	return result
end

function Dampener.newv( value, target, bias )
	local result = {
		value = { value[1], value[2] },
		target = { target[1], target[2] },
		bias = bias,
	}

	setmetatable(result, Dampener)

	return result
end

function Dampener:updatef( target )
	target = target or self.target

	self.value = self.value + self.bias * (target - self.value)

	return self.value
end

function Dampener:updatev( target )
	target = target or self.target

	local vtot = Vector.to(self.value, target)
	Vector.scale(vtot, self.bias)

	self.value[1] = self.value[1] + vtot[1]
	self.value[2] = self.value[2] + vtot[2]

	return self.value
end

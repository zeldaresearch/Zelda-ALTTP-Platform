local num_util = {}

function num_util.clamp(number, between_this, and_this)
	if number < between_this then return between_this end
	if number > and_this then return and_this end
	return number
end


function num_util.random_except(for_these_numbers, from, to)
	assert(type(for_these_numbers)=="table", "num_util.random_except: Expected table as #1 argument")
	local checking_table = {}
	for i = 1, #for_these_numbers do
		checking_table[for_these_numbers[i]] = true
	end
	local random_number = math.random(from, to-#for_these_numbers)
	local got_right_number = false
	while not got_right_number do
		if checking_table[random_number] ~= nil then
			random_number = random_number + 1
		else
			got_right_number = true
		end
	end
	return random_number
end

return num_util
local map = ...
game = map:get_game()

local content = require("content_generator")

function map:on_started(destination)
	game:save()
	content.set_planned_items_for_this_zone({"glove-1"})
	content.start_test(map, {fight_difficulty=3, puzzle_difficulty=3, 
		branch_length=1, main_length=3, 
		optional_length=2, add_heart=false}, 
		{map_id="1b", destination_name=nil})
end

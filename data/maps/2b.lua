local map = ...
game = map:get_game()

local content = require("content_generator")

function map:on_started(destination)
	game:save()
	content.start_test(map, {fight_difficulty=4, puzzle_difficulty=4,
		branch_length=4, main_length=3, optional_length=2, add_heart=true}, {map_id="13", destination_name=nil})
end

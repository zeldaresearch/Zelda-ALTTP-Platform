local map = ...
game = map:get_game()

local content = require("content_generator")

function map:on_started(destination)
	game:save()
	content.start_test(map, {fight_difficulty=5, puzzle_difficulty=5, branch_length=6, main_length=3, optional_length=2, add_heart=true}, {map_id="14", destination_name=nil})
end

local map = ...
game = map:get_game()

local content = require("content_generator")

function map:on_started(destination)
	game:save()
	content.start_test(map, {fight_difficulty=2, puzzle_difficulty=2, mission_type="tutorial", branches=0, branch_length=0, 
			fights=4, puzzles=3, length=7, area_size=1}, {map_id="11", destination_name=nil})
end

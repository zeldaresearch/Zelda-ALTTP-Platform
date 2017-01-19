local map = ...
game = map:get_game()

local content = require("content_generator")

function map:on_started(destination)
	game:save()
	content.start_test(map, {mission_type="boss"}, {map_id="5", destination_name="dungeon_exit"})
end
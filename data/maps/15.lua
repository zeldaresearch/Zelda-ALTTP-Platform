local map = ...

content = require("content_generator")

function map:on_started(destination)
	map = map
	game = map:get_game()
	hero = game:get_hero()
end

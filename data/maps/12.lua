local map = ...

local q = require("ingamequestionnaire")

function map:on_started(destination)
	map = map
	game = map:get_game()
	hero = game:get_hero()
	game:save()
	q.init(map)
	q.map_number = 1
end
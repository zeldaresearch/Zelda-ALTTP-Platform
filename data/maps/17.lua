local map = ...
game = map:get_game()

local sign_a_message=[[

      To Caves

]]
-----------------------

function sign_a:on_interaction()
	game:start_dialog("test.variable", sign_a_message)
end

local sign_b_message=[[

      To Forest
      
]]
-----------------------

function sign_b:on_interaction()
	game:start_dialog("test.variable", sign_b_message)
end
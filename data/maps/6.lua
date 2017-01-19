local map = ...
game = map:get_game()
village_logger = village_logger or require("village_logger")

-- Hero's house
-- HOUSE
-----------------------
--Sick kid/lil bro: 
local brother_talk =[[
You see your brother 
sweating profusely, 
wide awake but in a 
state of delerium.

What to do...
]]

local brother_talk_2 =[[
You see your brother 
sweating profusely, 
wide awake but in a 
state of delerium.
]]

local feed_cure=[[
You feed him the
Medicine!
]]

local finale1 = [[
Your brother instantly
regains full 
consciousness!
]]

local finale2a=[[
But he still looks 
weak, he needs 
to rest...$0
You have saved the day!
]]

local finale2b=[[
He looks quite well,
the poison seems to
gone completely!$0
You have saved the day!
]]

-----------------------
--Dad/blacksmith: 
local dad_talk_q1 = game:get_player_name().."!\n"..[[
Your brother is really 
ill, we can't wait for 
the doctor to arrive
from out of town!

We have to save him!
Tell me what to do!
How'd this happen?
]]

--<answer 1> 
local dad_talk_q1_ans1 = [[
Get my sword and shield 
from the shed, here is
the key!
And here, some rupees to 
pay the witch with...
]]
--<hand over wooden key>
--<answer 2> 
local dad_talk_q1_ans2 = [[
He drank something from
the old brewer's stash.
Something poisonous no
doubt. 
]]
--<followed by answer 1>
local dad_talk_after = [[
Go to the witch in the 
woods to the east, ask
her for some Medicine!
Now go! Good luck!
]]
-----------------------
--Mom:
--<question 1>
local mom_talk_q1 = [[
Your brother's still
sick. I'm so worried!
Ohw my dear boy...
have you spoken to your
father?

I think he has a plan.
I will!
Father's plan?
]]
--<q1 answer 1>
local mom_talk_q1_ans1 =[[
Hurry back, I don't
know how long your 
brother can hold out...
]]

--<q1 answer 2> <q2>
local mom_talk_q2 =[[
Your father seems to
want to ask the witch
for help and try to
get Medicine from her.
The witch?
Why not the brewer?
]]

--<q2 answer 1>
local mom_talk_q2_ans1 =[[
The witch lives in the 
woods to the east, 
there have been rumors 
going around, I don't
know the details though
and neither does your 
father...
]]

--<q2 answer 2>
local mom_talk_q2_ans2 =[[
He seems to hold a 
grudge against the old
brewer now that your 
brother got poisoned.
But your brother's
condition would've 
been much worse if
not for the brewer.
]]

local function step_in_front_of_door(mom)
	local m = sol.movement.create("path")
	m:set_path{0, 0}
	m:set_speed(32)
	m.on_finished = function ( )
		mom:get_sprite():set_direction(1)
	end
	m:start(mom)
end

local function step_away_from_door(mom)
	local m = sol.movement.create("path")
	m:set_speed(32)
	m:set_path{4, 4}
	m.on_finished = function ( )
  	  	mom:get_sprite():set_direction(1)
  	end
	m:start(mom)
end

function map:on_started(destination)
	game:save()
	if next(village_logger.log) == nil then
		village_logger.start_new_log()
		village_logger.log.start_time = os.clock()
		if game:get_value("shed_key") then
			village_logger.unpickle_log()
			village_logger.log.entered_village_from_save=1
		end
	end
	if destination == start_position then
		sol.audio.play_music("beginning")
		if not game:get_value("shed_key") then
			step_in_front_of_door(mom)
		end
	end

end

function dad:on_interaction( ... )
	village_logger.log.NPC.dad.talked = true
	if not game:get_value("shed_key") then
		game:start_dialog("test.question", dad_talk_q1, function(answer) 
			if answer == 1 then
				village_logger.log.NPC.dad.options_explored[1] = true
				game:start_dialog("test.variable", dad_talk_q1_ans1, function()
					game:add_money(50) 
					hero:start_treasure("wooden_key", 1, "shed_key", function()
		            	game:start_dialog("test.variable", dad_talk_after, function()
		            		step_away_from_door(mom)
		            	end)
		          	end)
				end)
			else
				village_logger.log.NPC.dad.options_explored[2] = true
				game:start_dialog("test.variable", dad_talk_q1_ans2, function() 
					game:start_dialog("test.variable", dad_talk_q1_ans1, function() 
						game:add_money(50)
						hero:start_treasure("wooden_key", 1, "shed_key", function()
			            	game:start_dialog("test.variable", dad_talk_after, function ( )
			            		step_away_from_door(mom)
			            	end)
			          	end)
					end)
				end)
			end
		end)
	else
		game:start_dialog("test.variable", dad_talk_after)
	end
end

function mom:on_interaction( ... )
	village_logger.log.NPC.mom.talked = true
	game:start_dialog("test.question", mom_talk_q1, function(answer) 
		if answer == 1 then
			village_logger.log.NPC.mom.options_explored[1] = true
			game:start_dialog("test.variable", mom_talk_q1_ans1)
		else
			game:start_dialog("test.question", mom_talk_q2, function(answer) 
				if answer == 1 then
					village_logger.log.NPC.mom.options_explored[2] = true
					game:start_dialog("test.variable", mom_talk_q2_ans1)
				else
					village_logger.log.NPC.mom.options_explored[3] = true
					game:start_dialog("test.variable", mom_talk_q2_ans2)
				end
			end)
		end
 	end)
end

function brother:on_interaction( ... )
	village_logger.log.NPC.brother.talked = true
	village_logger.log.NPC.brother.options_explored[1] = true
	if game:get_value("diluted_cure") or game:get_value("strong_cure") then
		game:start_dialog("test.variable", brother_talk_2, function() 
			local hero_x, hero_y = hero:get_position()
			local c_entity = map:create_npc{ direction=0, x=hero_x, y=hero_y-24, layer=2, subtype=0, sprite="entities/items" }
			hero:freeze()
			hero:set_animation("brandish")
			c_entity:get_sprite():set_animation("cure")
			game:start_dialog("test.variable", feed_cure, function()
				local m = sol.movement.create("target")
				m:set_ignore_obstacles(true)
				local brother_x, brother_y = brother:get_position()
				m:set_target(brother_x, brother_y)
				m:start(c_entity)
				m.on_finished = function() 
					game:start_dialog("test.variable", finale1, function() 
						hero:set_animation("victory")
						if game:get_value("diluted_cure") then 
							game:start_dialog("test.variable", finale2a, function() 
								game_over()
							end)
						elseif game:get_value("strong_cure") then
							sheets:get_sprite():set_animation("empty_open")
							game:start_dialog("test.variable", finale2b, function() 
								game_over()
							end)
						end
					end)
				end
			end)
		end)
	else
		game:start_dialog("test.variable", brother_talk)
	end
end

local credits = [[
Programming:
Norbert Heijne
Arjen Swellengrebel$0$0
Thanks For Playing!
Don't forget to send us
the log files! :)$0
And visit the website
again to finish the 
last part!$0
]]

local credits2 = [[
The logs are under
C:\Users\<username>\
.solarus\dynamicZelda$0
Please mail every file
in that folder to
dynamicZelda@gmail.com$0
And visit the website
again to finish the 
last part!$0
Repeat the info?
Yes
No
]]


function game_over()
	village_logger.to_file( game, "after" )
	sol.audio.play_music("fanfare")
	game:start_dialog("test.variable", credits, function() 
		game:start_dialog("test.question_repeat_on_1", credits2, function(answer)
			if answer == 1 then
				-- skip
			else
			    game:set_hud_enabled(false)
			    game:set_pause_allowed(false)
			    sol.timer.start(5000, function()
			      hero:set_visible(false)
			      sol.main.reset()
			    end)
			end
	    end)
	end)
end
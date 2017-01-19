local game = ...

-- Include the various game features.
sol.main.load_file("dungeons")(game)
sol.main.load_file("equipment")(game)
sol.main.load_file("menus/pause")(game)
sol.main.load_file("menus/dialog_box")(game)
sol.main.load_file("menus/game_over")(game)
sol.main.load_file("hud/hud")(game)

-- Key presses to keep track of.
local leftPressed = false
local rightPressed = false
local upPressed = false
local downPressed = false

-- Useful functions for this specific quest.

function game:on_started()

  -- Set up the dialog box and the HUD.
  self:initialize_dialog_box()
  self:initialize_hud()
end

function game:on_finished()

  -- Clean what was created by on_started().
  self:quit_hud()
  self:quit_dialog_box()
end

-- This event is called when a new map has just become active.
function game:on_map_changed(map)

  -- Notify the hud.
  self:hud_on_map_changed(map)
end

function game:on_paused()
  self:hud_on_paused()
  self:start_pause_menu()
end

function game:on_unpaused()
  self:stop_pause_menu()
  self:hud_on_unpaused()
end

function game:get_player_name()
  return self:get_value("player_name")
end

function game:set_player_name(player_name)
  self:set_value("player_name", player_name)
end

-- Returns whether the current map is in the inside world.
function game:is_in_inside_world()
  return self:get_map():get_world() == "inside_world"
end

-- Returns whether the current map is in the outside world.
function game:is_in_outside_world()
  return self:get_map():get_world() == "outside_world"
end

-- Returns whether the current map is in a dungeon.
function game:is_in_dungeon()
  return self:get_dungeon() ~= nil
end

function game:on_key_pressed(key, modifiers)
	local f = sol.file.open("userExperience.txt","a+"); f:write(key .. "-keypress\n"); f:flush(); f:close()
	if key == "left" then leftPressed = true end
	if key == "right" then rightPressed = true end
	if key == "up" then upPressed = true end
	if key == "down" then downPressed = true end
	-- returning false gives it back to the engine to handle
	return false
end

function game:on_key_released(key, modifiers)
	if key == "left" then leftPressed = false end
	if key == "right" then rightPressed = false end
	if key == "up" then upPressed = false end
	if key == "down" then downPressed = false end
	-- returning false gives it back to the engine to handle
	return false
end

-- Checks the initial position and fixes it if necessary.
local function fix_starting_location(game)

  -- Check if the savegame was broken by the bug of the teletransportation
  -- in Billy's cave. If yes, fix it.
  local initial_map_id = game:get_starting_location()
  if initial_map_id == "121"  -- Billy's cave North.
      or initial_map_id == "53" then  -- Dungeon 8 hidden room.

    -- It is supposed to be impossible to start a game here before dungeon 8.
    if not game:get_value("b703") then  -- Locked door in dungeon 8 1F.
      -- The locked door is not open yet: the savegame has the bug.
      -- Fix the starting location and close Billy's door again.
      game:set_starting_location("5", "from_billy_cave")
      game:set_value("b928", false)  -- Close the door.
    end

  end
end

local f = sol.file.open("userExperience.txt","w+"); f:write("A NEW GAME IS STARTING NOW\n"); f:flush(); f:close()
sol.timer.start(200, function ()
	local f = sol.file.open("userExperience.txt","a+")
  if leftPressed or rightPressed or upPressed or downPressed then
	  f:write("moving around\n"); f:flush()
	else
		f:write("standing still\n"); f:flush()
	end
	local totalGoingEnemies = 0
	-- for enemy in game:get_map():get_entities("generatedEnemy") do
	-- 	totalGoingEnemies = totalGoingEnemies + (enemy:get_going_hero() and 1 or 0)
	-- end
	f:write(totalGoingEnemies .. "-goingHero\n"); f:flush(); f:close()
	return true
end)
-- Run the game.
sol.main.game = game
fix_starting_location(game)
game:start()


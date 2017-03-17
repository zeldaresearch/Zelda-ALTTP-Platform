local log = require("log")
local q = {}

-- This file contains the code to create the in game questionnaire at the shopkeeper's areas


q.questionnaire_done = false
-----------------------
q.questions_start=[[
Please answer some
questions about the
last segment...
i.e. the areas between
the last shop spot or
village and here.
Note that your answers 
do not affect gameplay
whatsoever...
]]

q.questions_repeat=[[
Thanks for filling
in these questions...
Would you like to
revise your answers?
No thanks.
Yes please.
]]

q.merchant_start=[[
Hello traveler...
Don't forget to search
for treasure if you
want some of these 
fine pieces of 
equipment...
]]


q.questionnaire = {}
q.map_number = 0
q.map = nil

local hero
local game
local map

function q.init(map)
  q.npc_name = "bouncer"
  q.map = map
  hero = map:get_hero()
  game = map:get_game()
  local npc = map:get_entity(q.npc_name)
  function npc:on_interaction()
    if not q.questionnaire_done then
      game:start_dialog("test.variable", q.questions_start, function()
          hero:freeze()
          sol.menu.start(map, q.questionnaire)
        end)
    else
      game:start_dialog("test.question", q.questions_repeat, function(answer) 
        if answer == 2 then
          hero:freeze()
          sol.menu.start(map, q.questionnaire)
        end
      end)
    end
  end

  local merchant = map:get_entity("salesman")
  function merchant:on_interaction()
    game:start_dialog("test.variable", q.merchant_start)
  end

  function map:on_finished()
    -- name, map_nr, exploration, puzzles, puzzlepreference, fights, overalexperience
    q.questionnaire_done = false
    local f = sol.file.open("levelquestionnaire.csv","a+")
    f:write(tostring(game:get_player_name())..",")
    f:write(tostring(q.map_number)..",")
    f:write(tostring(game:get_value("exploration"))..",")
    f:write(tostring(game:get_value("puzzles"))..",")
    f:write(tostring(game:get_value("puzzlepreference"))..",")
    f:write(tostring(game:get_value("fights"))..",")
    f:write(tostring(game:get_value("overalexperience")).."\n")
    f:flush(); f:close()
  end

end



function q.questionnaire:on_finished()
  log.debug("questionnaire_done"..tostring(q.questionnaire_done))
	if not q.questionnaire_done then
    local npc = q.map:get_entity(q.npc_name)
		local dir = npc:get_sprite():get_direction()
		local m = sol.movement.create("path")
		m:set_speed(32)
		if dir == 1 then
			m:set_path{4, 4}
			m.on_finished = function ( )
		  	  	npc:get_sprite():set_direction(0)
		  	end
		else
			m:set_path{2, 2}
			m.on_finished = function ( )
		  	  	npc:get_sprite():set_direction(3)
		  	end
		end
		m:start(npc)
		q.questionnaire_done = true
	end
	hero:unfreeze()
end			

function q.questionnaire:on_started()

  -- Create all graphic objects.
  self.surface = sol.surface.create(320, 240)
  self.background_color = { 104, 144, 240 }
  self.background_img = sol.surface.create("menus/selection_menu_background.png")
  self.save_container_img = sol.surface.create("menus/selection_menu_save_container.png")
  self.option_container_img = sol.surface.create("menus/selection_menu_option_container.png")
  self.option1_text = sol.text_surface.create()
  self.option2_text = sol.text_surface.create()
  self.title_text = sol.text_surface.create{
    horizontal_alignment = "center",
    font = sol.language.get_menu_font(),
  }
  self.cursor_position = 1
  self.cursor_sprite = sol.sprite.create("menus/selection_menu_cursor")
  self.allow_cursor_move = true
  self.finished = false
  self.phase = nil

  self:init_phase()
  -- Show an opening transition.
  self.surface:fade_in()
end

function q.questionnaire:set_bottom_buttons(key1, key2, customtext)

  if not customtext and key1 ~= nil then
    self.option1_text:set_text_key(key1)
  elseif customtext then
    self.option1_text:set_text(key1)
  else
    self.option1_text:set_text("")
  end

  if not customtext and key2 ~= nil then
    self.option2_text:set_text_key(key2)
  elseif customtext then
    self.option2_text:set_text(key2)
  else
    self.option2_text:set_text("")
  end
end

function q.questionnaire:init_phase()

  self.title_text:set_text("In the last level I liked...")
  self.modifying_profile = false
  self.profile_cursor_position = 1

  -- Option texts and values.
  self.profile = {
    {
      name = "exploration",
      values = {"Strongly disagree", "Disagree", "Neutral", "Agree", "Strongly agree"},
      initial_value = "Strongly disagree",
      current_index = nil,
      label_text = sol.text_surface.create{
        font = sol.language.get_menu_font(),
        text = "...the amount of exploration available"
      },
      value_text = sol.text_surface.create{
        font = sol.language.get_menu_font(),
        horizontal_alignment = "right"
      },
    },
    {
      name = "puzzles",
      values = {"Strongly disagree", "Disagree", "Neutral", "Agree", "Strongly agree"},
      initial_value = "Strongly disagree",
      current_index = nil,
      label_text = sol.text_surface.create{
        font = sol.language.get_menu_font(),
        text = "...the challenge that the puzzles gave me"
      },
      value_text = sol.text_surface.create{
        font = sol.language.get_menu_font(),
        horizontal_alignment = "right"
      },
 
    },
    {
      name = "puzzlepreference",
      values = {"None", "Block-pushing", "Maze", "Moving-floor"},
      initial_value = "None",
      current_index = nil,
      label_text = sol.text_surface.create{
        font = sol.language.get_menu_font(),
        text = "...this type of puzzle the best"
      },
      value_text = sol.text_surface.create{
        font = sol.language.get_menu_font(),
        horizontal_alignment = "right"
      },
 
    },
    {
      name = "fights",
      values = {"Strongly disagree", "Disagree", "Neutral", "Agree", "Strongly agree"},
      initial_value = "Strongly disagree",
      current_index = nil,
      label_text = sol.text_surface.create{
        font = sol.language.get_menu_font(),
        text = "...the challenge that the fights gave me"
      },
      value_text = sol.text_surface.create{
        font = sol.language.get_menu_font(),
        horizontal_alignment = "right"
      },
 
    },
    {
      name = "overalexperience",
      values = {"Strongly disagree", "Disagree", "Neutral", "Agree", "Strongly agree"},
      initial_value = "Strongly disagree",
      current_index = nil,
      label_text = sol.text_surface.create{
        font = sol.language.get_menu_font(),
        text = "...the composition and the general feel"
      },
      value_text = sol.text_surface.create{
        font = sol.language.get_menu_font(),
        horizontal_alignment = "right"
      },
 
    },
    
  }

  for _, option in ipairs(self.profile) do
    -- Initial value.
    for i, value in ipairs(option.values) do
      if value == option.initial_value then
  self:set_value(option, i)
      end
    end
  end

  -- Sprites.
  self.left_arrow_sprite = sol.sprite.create("menus/arrow")
  self.left_arrow_sprite:set_animation("blink")
  self.left_arrow_sprite:set_direction(2)

  self.right_arrow_sprite = sol.sprite.create("menus/arrow")
  self.right_arrow_sprite:set_animation("blink")
  self.right_arrow_sprite:set_direction(0)

  self:set_bottom_buttons("Done", nil, true)
  self:set_cursor_position(1)
end

function q.questionnaire:on_key_pressed(key)
  local handled = false
  if key == "escape" then
    -- Stop the program.
    handled = true
    sol.menu.stop(self)
  elseif key == "right" then
    handled = self:direction_pressed(0)
  elseif key == "up" then
    handled = self:direction_pressed(2)
  elseif key == "left" then
    handled = self:direction_pressed(4)
  elseif key == "down" then
    handled = self:direction_pressed(6)
  end

  local handled = true
  if key == "space" or key == "return" then
    if self.profile_cursor_position > #self.profile then
      -- Back.
      sol.audio.play_sound("ok")
      sol.menu.stop(self)
    else
      -- Set an option.
      local option = self.profile[self.profile_cursor_position]
      if not self.modifying_profile then
  sol.audio.play_sound("ok")
  self.left_arrow_sprite:set_frame(0)
  self.right_arrow_sprite:set_frame(0)
  option.label_text:set_color{255, 255, 255}
  option.value_text:set_color{255, 255, 0}
  self.modifying_profile = true
      else
  sol.audio.play_sound("danger")
  option.label_text:set_color{255, 255, 0}
  option.value_text:set_color{255, 255, 255}
  self.left_arrow_sprite:set_frame(0)
  self.right_arrow_sprite:set_frame(0)
  self.modifying_profile = false
      end
    end
  else
    handled = false
  end
  return handled
end

function q.questionnaire:on_joypad_button_pressed(button)
  return self:on_key_pressed("space")
end

function q.questionnaire:on_joypad_axis_moved(axis, state)

  if axis % 2 == 0 then  -- Horizontal axis.
    if state > 0 then
      self:direction_pressed(0)
    elseif state < 0 then
      self:direction_pressed(4)
    end
  else  -- Vertical axis.
    if state > 0 then
      self:direction_pressed(6)
    elseif state < 0 then
      self:direction_pressed(2)
    end
  end
end

function q.questionnaire:on_joypad_hat_moved(hat, direction8)

  if direction8 ~= -1 then
    self:direction_pressed(direction8)
  end
end

function q.questionnaire:direction_pressed(direction8)

  local handled = false
  if not self.modifying_profile then
    -- Just moving the profile cursor (not modifying any option).

    if direction8 == 2 then  -- Up.
      sol.audio.play_sound("cursor")
      self.left_arrow_sprite:set_frame(0)
      local position = self.profile_cursor_position - 1
      if position == 0 then
        position = #self.profile + 1
      end
      self:set_cursor_position(position)
      handled = true

    elseif direction8 == 6 then  -- Down.
      sol.audio.play_sound("cursor")
      self.left_arrow_sprite:set_frame(0)
      local position = self.profile_cursor_position + 1
      if position > #self.profile + 1 then
        position = 1
      end
      self:set_cursor_position(position)
      handled = true
    end

  else
    -- An option is currently being modified.

    if direction8 == 0 then  -- Right.
      local option = self.profile[self.profile_cursor_position]
      local index = (option.current_index % #option.values) + 1
      self:set_value(option, index)
      sol.audio.play_sound("cursor")
      self.left_arrow_sprite:set_frame(0)
      self.right_arrow_sprite:set_frame(0)
      handled = true

    elseif direction8 == 4 then  -- Left.
      local option = self.profile[self.profile_cursor_position]
      local index = (option.current_index + #option.values - 2) % #option.values + 1
      self:set_value(option, index)
      sol.audio.play_sound("cursor")
      self.left_arrow_sprite:set_frame(0)
      self.right_arrow_sprite:set_frame(0)
      handled = true

    end
  end
  return handled
end

function q.questionnaire:on_draw(dst_surface)

  -- Background color.
  --self.surface:fill_color(self.background_color)
  -- Savegames container.
  self.background_img:draw(self.surface, 37, 38)
  self.title_text:draw(self.surface, 160, 54)

  -- Phase-specific draw method.
  q.questionnaire:draw_phase()

  -- The menu makes 320*240 pixels, but dst_surface may be larger.
  local width, height = dst_surface:get_size()
  self.surface:draw(dst_surface, width / 2 - 160, height / 2 - 120)
end

function q.questionnaire:draw_bottom_buttons()

  local x
  local y = 158
  if self.option1_text:get_text():len() > 0 then
    x = 57
    self.option_container_img:draw(self.surface, x, y)
    self.option1_text:draw(self.surface, 90, 172)
  end
  if self.option2_text:get_text():len() > 0 then
    x = 165
    self.option_container_img:draw(self.surface, x, y)
    self.option2_text:draw(self.surface, 198, 172)
  end
end


function q.questionnaire:draw_phase()

  -- All profile.
  for i, option in ipairs(self.profile) do
    local y = 57 + i * 19
    option.label_text:draw(self.surface, 64, y)
    option.value_text:draw(self.surface, 266, y+9)
  end

  -- Bottom buttons.
  self:draw_bottom_buttons()

  -- Cursor.
  if self.profile_cursor_position > #self.profile then
    -- The cursor is on the bottom button.
    --self:draw_savegame_cursor()
    self.cursor_sprite:draw(self.surface, 58, 159)
  else
    -- The cursor is on an option line.
    local y = 51 + self.profile_cursor_position * 19
    if self.modifying_profile then
      local option = self.profile[self.profile_cursor_position]
      local width, _ = option.value_text:get_size()
      self.left_arrow_sprite:draw(self.surface, 256 - width, y)
      self.right_arrow_sprite:draw(self.surface, 268, y)
    else
      self.right_arrow_sprite:draw(self.surface, 54, y)
    end
  end
end

function q.questionnaire:set_cursor_position(position)

  if self.profile_cursor_position <= #self.profile then
    -- An option line was previously selected.
    local option = self.profile[self.profile_cursor_position]
    option.label_text:set_color{255, 255, 255}
  end

  self.profile_cursor_position = position

  if position <= #self.profile then
    -- An option line is now selected.
    local option = self.profile[self.profile_cursor_position]
    option.label_text:set_color{255, 255, 0}
  end
end

-- Sets the value of an option.
function q.questionnaire:set_value(option, index)

  if option.current_index ~= index then
    option.current_index = index
    local value = option.values[index]
    option.value_text:set_text(value)
    game:set_value(option.name, index)
  end
end

return q
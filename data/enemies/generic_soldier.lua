local enemy = ...

-- Generic script for an enemy with a sword
-- that goes towards the hero if he sees him
-- and walks randomly otherwise.

-- Example of use from an enemy script:

-- sol.main.load_file("enemies/generic_soldier")(enemy)
-- enemy:set_properties({
--   main_sprite = "enemies/green_knight_soldier",
--   sword_sprite = "enemies/green_knight_soldier_sword",
--   life = 4,
--   damage = 2,
--   play_hero_seen_sound = false,
--   normal_speed = 32,
--   faster_speed = 64,
--   hurt_style = "normal"
-- })

-- The parameter of set_properties() is a table.
-- Its values are all optional except main_sprite
-- and sword_sprite.

local properties = {}
local going_hero = false
local being_pushed = false
local main_sprite = nil
local sword_sprite = nil
local time_since_disengagement = 0
local time_at_disengagement = 0
local hero

function enemy:get_going_hero()
	return going_hero
end

function enemy:set_properties(prop)

  properties = prop
  -- Set default values.
  if properties.life == nil then
    properties.life = 2
  end
  if properties.damage == nil then
    properties.damage = 2
  end
  if properties.play_hero_seen_sound == nil then
    properties.play_hero_seen_sound = false
  end
  if properties.normal_speed == nil then
    properties.normal_speed = 32
  end
  if properties.faster_speed == nil then
    properties.faster_speed = 64
  end
  if properties.hurt_style == nil then
    properties.hurt_style = "normal"
  end
end

function enemy:on_created()
  hero = self:get_map():get_entity("hero")
  self:set_life(properties.life)
  self:set_damage(properties.damage)
  self:set_hurt_style(properties.hurt_style)
  sword_sprite = self:create_sprite(properties.sword_sprite)
  main_sprite = self:create_sprite(properties.main_sprite)
  self:set_size(16, 16)
  self:set_origin(8, 13)

  self:set_invincible_sprite(sword_sprite)
  self:set_attack_consequence_sprite(sword_sprite, "sword", "custom")
  self:set_attack_consequence("arrow", 3)
end

function enemy:on_restarted()

  if not being_pushed then
    if going_hero then
      self:go_hero()
    else
      self:go_random()
      self:check_hero()
    end
  end
end

function enemy:check_hero()

 
  --local self_x, self_y, layer = self:get_position()
  --local hero_x, hero_y, hero_layer = hero:get_position()
  --local dx, dy = hero_x-self_x, hero_y-self_y
  local near_hero = 
    --layer == hero_layer and 
    self:get_distance(hero) < 100
   -- and self:line_of_sight(dx, dy)
    --and self:is_in_same_region(hero)

  if near_hero and not going_hero then
    if properties.play_hero_seen_sound then
      sol.audio.play_sound("hero_seen")
    end
    enemy:engage()
  elseif not near_hero and going_hero then
    enemy:start_disengaging()
  end
  sol.timer.stop_all(self)
  sol.timer.start(self, 1000, function() self:check_hero() end)
end

function enemy:on_movement_changed(movement)

  if not being_pushed then
    local direction4 = movement:get_direction4()
    main_sprite:set_direction(direction4)
    sword_sprite:set_direction(direction4)
  end
end

function enemy:on_movement_finished(movement)

  if being_pushed then
    self:go_hero()
  end
end

function enemy:on_obstacle_reached(movement)

  if being_pushed then
    self:go_hero()
  end
end

function enemy:on_custom_attack_received(attack, sprite)

  if attack == "sword" and sprite == sword_sprite then
    local f = sol.file.open("userExperience.txt","a+"); f:write("swords-clang\n"); f:flush(); f:close()
    sol.audio.play_sound("sword_tapping")
    being_pushed = true
    local x, y = self:get_position()
    local angle = self:get_angle(self:get_map():get_entity("hero")) + math.pi
    local movement = sol.movement.create("straight")
    movement:set_speed(128)
    movement:set_angle(angle)
    movement:set_max_distance(26)
    movement:set_smooth(true)
    movement:start(self)
  end
end

function enemy:go_random()
  local movement = sol.movement.create("random_path")
  movement:set_speed(properties.normal_speed)
  movement:start(self)
  being_pushed = false
  going_hero = false
end

function enemy:go_hero()
  local movement = sol.movement.create("target")
  movement:set_speed(properties.faster_speed)
  movement:start(self)
  being_pushed = false
  going_hero = true
end

function enemy:go_pathfind_hero()
  local movement = sol.movement.create("path_finding")
  movement:set_speed(properties.faster_speed)
  movement:start(self)
  being_pushed = false
  going_hero = true
end

function enemy:line_of_sight(dx, dy)
  local abs, floor, ceil = math.abs, math.floor, math.ceil
  local sign_x, sign_y = self:sign(dx), self:sign(dy)
  local repeats, change_x, change_y = 0, 0, 0
  if abs(dx) > abs(dy) then
    repeats = floor(abs(dx)/8)
    change_x, change_y = 8, ceil(abs(dy)/repeats)
  else
    repeats = floor(abs(dy)/8)
    change_x, change_y = ceil(abs(dx)/repeats), 8
  end
  for i= 0, repeats do
    if self:test_obstacles(change_x*sign_x*i, change_y*sign_y*i) then return false end
  end
  return true
end

function enemy:sign(x)
  return x>0 and 1 or x<0 and -1 or 0
end

function enemy:start_disengaging()
  if time_at_disengagement == 0 then time_at_disengagement = os.clock() end
  time_since_disengagement = os.clock() - time_at_disengagement
  if time_since_disengagement > 1.9 then self:go_random() 
  else self:go_hero() end
end

function enemy:engage()
  time_since_disengagement = 0
  time_at_disengagement = 0
  self:go_hero()
end

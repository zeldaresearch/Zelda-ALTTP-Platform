local enemy = ...

-- A bouncing triple fireball, usually shot by another enemy.

local speed = 192
local sprite2 = nil
local sprite3 = nil
local m = nil

local map, hero

function enemy:on_created()
  map = self:get_map()
  hero = map:get_entity("hero")
  
  self:set_life(1)
  self:set_damage(2)
  self:set_size(8, 8)
  self:set_origin(4, 4)
  self:create_sprite("enemies/red_projectile")
  self:set_obstacle_behavior("flying")
  self:set_layer_independent_collisions(true)
  self:set_minimum_shield_needed(1)
  self:set_pushed_back_when_hurt(false)

  -- Two smaller fireballs just for the displaying.
  sprite2 = sol.sprite.create("enemies/red_projectile")
  sprite2:set_animation("small")
  sprite3 = sol.sprite.create("enemies/red_projectile")
  sprite3:set_animation("tiny")
end

function enemy:go()

  local hero_x, hero_y = self:get_map():get_entity("hero"):get_position()
  local angle = self:get_angle(hero_x, hero_y - 5)
  m = sol.movement.create("straight")
  m:set_speed(speed)
  m:set_angle(angle)
  m:set_smooth(false)
  m:set_ignore_obstacles(true)
  m:set_max_distance(200)
  m.on_finished = function() self:remove() end
  m:start(self)
end

function enemy:on_pre_draw()
  if m ~= nil then
	  local angle = m:get_angle()
	  local x, y = self:get_position()
	
	  local x2 = x - math.cos(angle) * 8
	  local y2 = y + math.sin(angle) * 8
	
	  local x3 = x - math.cos(angle) * 12
	  local y3 = y + math.sin(angle) * 12
	
	  self:get_map():draw_sprite(sprite2, x2, y2)
	  self:get_map():draw_sprite(sprite3, x3, y3)
  end
end


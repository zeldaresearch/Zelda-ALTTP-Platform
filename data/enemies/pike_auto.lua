local enemy = ...

-- Pike that always moves, horizontally or vertically
-- depending on its direction.

local recent_obstacle = 0
local move

function enemy:on_created()

  self:set_life(1)
  self:set_damage(4)
  self:create_sprite("enemies/pike_auto")
  self:set_size(16, 16)
  self:set_origin(8, 13)
  self:set_can_hurt_hero_running(true)
  self:set_invincible()
  self:set_attack_consequence("sword", "protected")
  self:set_attack_consequence("thrown_item", "protected")
  self:set_attack_consequence("arrow", "protected")
  self:set_attack_consequence("hookshot", "protected")
  self:set_attack_consequence("boomerang", "protected")
  self:restart()
end

function enemy:on_restarted()
  self:update_move() 
  move:start(self)
end

function enemy:update_move()
  local sprite = self:get_sprite()
  local direction4 = sprite:get_direction()
  move = sol.movement.create("path")
  move:set_path{direction4 * 2}
  move:set_speed(64)
  move:set_loop(true)
end

function enemy:on_obstacle_reached()

  local sprite = self:get_sprite()
  local direction4 = sprite:get_direction()
  sprite:set_direction((direction4 + 2) % 4)

  local x, y = self:get_position()
  local hero_x, hero_y = self:get_map():get_entity("hero"):get_position()
  if recent_obstacle == 0
      and math.abs(x - hero_x) < 184
      and math.abs(y - hero_y) < 144 then
    sol.audio.play_sound("sword_tapping")
  end

  recent_obstacle = 8
  move:stop()
  sol.timer.start(self, 500, function() 
    self:update_move() 
    move:start(self)
  end)

end

function enemy:on_position_changed()

  if recent_obstacle > 0 then
    recent_obstacle = recent_obstacle - 1
  end
end


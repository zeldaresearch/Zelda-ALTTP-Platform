local custom_entity = ...

-- Pike that moves when the hero is close.
local cactus = false
local current_timer = nil
local map, hero
local state = "stopped"  -- "stopped", "moving", "going_back" or "paused".
local initial_xy = {}
local activation_distance = 64

-- function custom_entity:on_restarted()
--   if current_timer == nil then
--     self:check()
--   end
-- end

-- function custom_entity:on_enabled()
--   if current_timer == nil then
--     self:check()
--   end
-- end

-- function custom_entity:on_removed()
--   sol.timer.stop_all(self)
-- end

function custom_entity:check()
  local distance = self:get_distance(hero)
  if state == "stopped" and distance <= 64 then self:attack() end
  -- if not cactus then self:create_sprite("enemies/cactus"); cactus = true
  -- else self:create_sprite("enemies/pike_detect"); cactus = false end
end

function custom_entity:attack()

    local x, y = self:get_position()
    local hero_x, hero_y = hero:get_position()
    local dx, dy = hero_x - x, hero_y - y

    if math.abs(dx) <= activation_distance and math.abs(dy) < 16 then
      if dx > 0 then
	       self:go(0)
      else
	       self:go(2)
      end
    elseif math.abs(dy) <= activation_distance and math.abs(dx) < 16 then
      if dy > 0 then
	       self:go(3)
      else
	       self:go(1)
      end
    end
end

function custom_entity:go(direction4)

  local dxy = {
    { x =  8, y =  0},
    { x =  0, y = -8},
    { x = -8, y =  0},
    { x =  0, y =  8}
  }

  -- Check that we can make the move.
  local index = direction4 + 1
  --if not self:test_obstacles(dxy[index].x * 2, dxy[index].y * 2) then

    state = "moving"

    local x, y = self:get_position()
    local angle = direction4 * math.pi / 2
    local m = sol.movement.create("straight")
    m:set_speed(80)
    m:set_angle(angle)
    m:set_max_distance(64)
    m:set_smooth(false)
    m.on_obstacle_reached = function () self:go_back() end
    m.on_finished = function () self:go_back() end
    m:start(self)

  --end
end

-- function custom_entity:on_obstacle_reached()

--   self:go_back()
-- end

-- function custom_entity:on_movement_finished()

--   self:go_back()
-- end

-- function custom_entity:on_collision_custom_entity(other_custom_entity, other_sprite, my_sprite)

--   if string.find(other_custom_entity:get_breed(),"pike") and state == "moving" then
--     self:go_back()
--   end
-- end

function custom_entity:go_back()

  if state == "moving" then

    state = "going_back"

    local m = sol.movement.create("target")
    m:set_speed(32)
    m:set_target(initial_xy.x, initial_xy.y)
    m:set_smooth(false)
    m.on_obstacle_reached = function () self:go_back() end
    m.on_finished = function () self:go_back() end
    m:start(self)
    sol.audio.play_sound("sword_tapping")

  elseif state == "going_back" then

    state = "paused"
    sol.timer.start(self, 500, function() self:unpause() end)
  end
end

function custom_entity:unpause()
  state = "stopped"
end

function custom_entity:on_created()
  self:create_sprite("enemies/pike_detect")
  self:set_size(16, 16)
  self:set_origin(8, 13)
  map = self:get_map()
  hero = map:get_entity("hero")
  custom_entity:set_can_traverse_ground( "traversable", true)
  custom_entity:add_collision_test("overlapping", 
    function(pike_entity, other_entity)
      if not hero:is_invincible() and other_entity:get_name() == "hero" then
        other_entity:start_hurt(self, 2)
        hero:set_invincible(true, 1000)
      end
    end)
  --self:set_optimization_distance(100)
 
  initial_xy.x, initial_xy.y = self:get_position()
  current_timer = sol.timer.start(self, 500, function()
                        self:check()
                        return true
                      end)
end
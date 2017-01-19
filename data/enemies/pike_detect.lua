local enemy = ...

-- Pike that moves when the hero is close.

-- local current_timer = nil
--local cactus = false
local time_till_unpause = 0.5
local last_clock = 0
local map, hero
local state = "stopped"  -- "stopped", "moving", "going_back" or "paused".
local initial_xy = {}
local activation_distance = 64

-- function enemy:on_removed()
--   sol.timer.stop_all(self)
-- end

function enemy:on_update()
  if time_till_unpause > 0 then 
    local time = os.clock()
    time_till_unpause = time_till_unpause- (time - last_clock)
    last_clock=time
  end
  local distance = self:get_distance(hero)
  if distance <= 64 and time_till_unpause <= 0 and state == "stopped" then self:attack()  end
  -- if current_timer == nil then
  --   current_timer = sol.timer.start(self, 500, function()
  --                         self:check()
  --                         if self:get_distance(hero) > 100
  --                         return true
  --                       end)
  -- end
end

function enemy:check()
  local distance = self:get_distance(hero)
  if state == "stopped" and distance <= 64 then self:attack() end
  -- if not cactus then self:create_sprite("enemies/cactus"); cactus = true
  -- else self:create_sprite("enemies/pike_detect"); cactus = false end
end

function enemy:attack()

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

function enemy:go(direction4)

  local dxy = {
    { x =  8, y =  0},
    { x =  0, y = -8},
    { x = -8, y =  0},
    { x =  0, y =  8}
  }

  -- Check that we can make the move.
  --local index = direction4 + 1
  --if not self:test_obstacles(dxy[index].x * 2, dxy[index].y * 2) then
    local dir8 = direction4*2 
    local opp_dir = (dir8 + 4) % 8
    state = "moving"
    self:stop_movement()
    local m = sol.movement.create("path")
    m:set_speed(80)
    m:set_path{dir8, dir8, dir8, dir8, dir8, dir8, dir8, dir8}
    m.on_finished = function() self:go_back(opp_dir) end
    m.on_obstacle_reached = function() self:go_back(opp_dir) end
    m:start(self)
  --end
end

-- function enemy:on_obstacle_reached()

--   self:go_back()
-- end

-- function enemy:on_movement_finished()

--   self:go_back()
-- end

-- function enemy:on_collision_enemy(other_enemy, other_sprite, my_sprite)

--   if string.find(other_enemy:get_breed(),"pike") and state == "moving" then
--     self:go_back()
--   end
-- end

function enemy:go_back(dir8)

  if state == "moving" then

    state = "going_back"
    self:stop_movement()
    local m = sol.movement.create("path")
    m:set_speed(24)
    local current_xy = {}
    current_xy.x, current_xy.y = self:get_position()
    local distance = math.abs(current_xy.x - initial_xy.x) + math.abs(current_xy.y - initial_xy.y)
    local path = {}
    for i=1,math.ceil(distance/8) do
      table.insert(path, dir8)
    end
    m:set_path(path)
    m.on_finished = function() self:unpause() end
    m.on_obstacle_reached = function() self:unpause() end
    m:start(self)
    sol.audio.play_sound("sword_tapping")
  end
end

function enemy:unpause()
  time_till_unpause = 0.5
  state = "stopped"
end


function enemy:on_created()

  self:set_life(1)
  self:set_damage(2)
  self:create_sprite("enemies/pike_detect")
  self:set_size(16, 16)
  self:set_origin(8, 13)
  self:set_can_hurt_hero_running(true)
  self:set_invincible()
  self:set_attack_consequence("sword", "protected")
  self:set_attack_consequence("thrown_item", "protected")
  self:set_attack_consequence("arrow", "protected")
  self:set_attack_consequence("hookshot", "protected")
  self:set_attack_consequence("boomerang", "protected")
  --self:set_optimization_distance(100)
  map = self:get_map()
  hero = map:get_entity("hero")
  initial_xy.x, initial_xy.y = self:get_position()
end
custom_entity = ...

local last_clock
local map, hero
local x, y
local interval = 4
local son

function custom_entity:on_update()
  local time = os.clock()
  if interval > 0 then interval = interval - (time - last_clock) end
  last_clock = time
  if interval <= 0 then
    distance = self:get_distance(hero)
    if distance < 200 then self:attack();interval=4 end
  end
  if son and interval <= 3.5 then 
    sol.audio.play_sound("boss_fireball")
    son:go(angle)
    son = nil
  end
end

function custom_entity:attack()
  local son_name = self:get_name() .. "_son_1"
  son = map:create_enemy{
      name = son_name,
      breed = "red_projectile",
      x = x,
      y = y,
      layer = 2,
      direction=0
    }
end

-- function custom_entity:start()
--   if not attack_on then
-- 	  attack_on = true
-- 	  sol.timer.start(self, math.random(1000, 3000), function()
-- 	  	self:check()
-- 	  end)
--   end
-- end

-- function custom_entity:stop()
--   attack_on = false
-- end

-- function custom_entity:check()
--   local distance = self:get_distance(hero)
--   if distance < 200 and self:is_in_same_region(hero) then self:attack() end
-- end

-- function custom_entity:set_interval(milliseconds)
-- 	interval = milliseconds
-- end

function custom_entity:on_created()
	map = self:get_map()
	hero = map:get_entity("hero")
	x, y = self:get_position()
	self:set_traversable_by(false)
	self:create_sprite("entities/fireball_statue")
  last_clock = os.clock()
  interval = math.random(1, 3)
end

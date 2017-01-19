local enemy = ...

-- Pike that does not move.

function enemy:on_created()

  self:set_life(1)
  self:set_damage(2)
  self:create_sprite("enemies/pike_fixed")
  self:set_size(16, 16)
  self:set_origin(8, 13)
  self:set_can_hurt_hero_running(true)
  self:set_invincible()
end

function enemy:on_attacking_hero(hero, enemy_sprite)
	if not hero:is_invincible() then
		hero:start_hurt(self, self:get_damage())
		hero:set_invincible(true, 700)
		local m = sol.movement.create("path")
		local direction = get_direction_between_pike_and_hero(self, hero)
		if direction then 
			m:set_speed(12)
			m:set_path{direction} 
		end
		m:set_ignore_obstacles(false)
		hero:freeze()
		hero:set_animation("hurt")
		m:start(hero)
		m.on_obstacle_reached = function () m:stop();hero:unfreeze();hero:set_invincible(false) end
		m.on_finished = function () hero:unfreeze() end
	end
	
end

function get_direction_between_pike_and_hero(pike, hero) -- from 1 to 2
	local pike_x, pike_y = pike:get_position()
	local hero_x, hero_y = hero:get_position()
	local x_diff, y_diff = hero_x-pike_x, (hero_y)-(pike_y)
	local dir8
	if x_diff < -10 then dir8 = 4 
	elseif x_diff > 10 then dir8 = 0 
	else
		if y_diff < -10 then 	dir8 = 2
		elseif y_diff > 10 then 	dir8 = 6
		else dir8 = pike:get_direction8_to(hero) end
	end
	return dir8
end
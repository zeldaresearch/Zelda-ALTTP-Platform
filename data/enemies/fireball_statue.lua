enemy = ...

local attack_on = false

function enemy:attack()
  local son_name = self:get_name() .. "_son_1"
    local son = self:create_enemy{
      name = son_name,
      breed = "red_projectile",
      x = 0,
      y = 0,
      layer = 2,
    }
  sol.timer.start(self, 500, function()
    sol.audio.play_sound("boss_fireball")
    son:go(angle)
  end)
end

function enemy:start()
  attack_on = true
  self:check()
end

function enemy:stop()
  attack_on = false
end

function enemy:check()
  if attack_on then
    self:attack()
    sol.timer.start(self, math.random(1000, 3000), function()
      self:check()
    end)
  end
end

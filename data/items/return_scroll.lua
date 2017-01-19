local item = ...

local used_last_time = 0

function item:on_created()

  self:set_savegame_variable("i1108")
  self:set_assignable(true)
end

function item:on_using()
	if os.clock() -used_last_time > 3 then
		if self:get_map():has_entity("start_here") then
			sol.audio.play_sound("warp")
			self:get_map():get_entity("hero"):teleport(map:get_id(), "start_here")
			self:get_map():open_doors("door_normal_area_")
		else sol.audio.play_sound("wrong")
		end
		used_last_time = os.clock()
	end
	self:set_finished()
end

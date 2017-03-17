local game = ...

-- Define the existing dungeons and their floors for the minimap menu.
game.dungeons = { -- Placeholder
  [0] = {
    floor_width = 8000,
    floor_height = 8000,
    lowest_floor = 0,
    highest_floor = 0,
    maps = {},
    boss = {
      floor = 0,
      x = 480,
      y = 480,
      savegame_variable = "b0",
      },
  },
}

-- Returns the index of the current dungeon if any, or nil.
function game:get_dungeon_index()

  --local world = self:get_map():get_world()
  --local index = tonumber(world:match("^dungeon_([0-9]+)$"))
  return 0
end

-- Returns the current dungeon if any, or nil.
function game:get_dungeon()

  local index = self:get_dungeon_index()
  return self.dungeons[index]
end

function game:is_dungeon_finished(dungeon_index)
  return self:get_value("dungeon_" .. dungeon_index .. "_finished")
end

function game:set_dungeon_finished(dungeon_index, finished)
  if finished == nil then
    finished = true
  end
  self:set_value("dungeon_" .. dungeon_index .. "_finished", finished)
end

function game:has_dungeon_map(dungeon_index)

  dungeon_index = dungeon_index or self:get_dungeon_index()
  return self:get_value("dungeon_" .. dungeon_index .. "_map")
end

function game:has_dungeon_compass(dungeon_index)

  dungeon_index = dungeon_index or self:get_dungeon_index()
  return self:get_value("dungeon_" .. dungeon_index .. "_compass")
end

function game:has_dungeon_big_key(dungeon_index)

  dungeon_index = dungeon_index or self:get_dungeon_index()
  return self:get_value("dungeon_" .. dungeon_index .. "_big_key")
end

function game:has_dungeon_boss_key(dungeon_index)

  dungeon_index = dungeon_index or self:get_dungeon_index()
  return self:get_value("dungeon_" .. dungeon_index .. "_boss_key")
end


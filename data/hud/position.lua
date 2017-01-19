-- The magic bar shown in the game screen.

local hud_position = {}

local last_clock = os.clock()
local current_fps = 0
local max_frames = 30
local at_frame = 0
local frames_time = {}

function hud_position:new(game)

  local object = {}
  setmetatable(object, self)
  self.__index = self

  object:initialize(game)

  return object
end

function hud_position:initialize(game)

  self.game = game

  self.hero = game:get_hero()
  self.surface = sol.surface.create(256, 120)
  self.digits_text = sol.text_surface.create{
    font = "alttp2",
    horizontal_alignment = "left",
  }
  self.map = self.game:get_map()
  --self.x, self.y, self.layer = self.hero:get_position()
  --self.digits_text:set_text("")
end

function hud_position:update()
  -- local time = os.clock()
  -- local measurement = time - last_clock
  -- last_clock = time
  -- at_frame = (at_frame%max_frames)+1
  -- if frames_time[at_frame] ~= nil then current_fps = current_fps - (1/frames_time[at_frame]) * (1/max_frames) end
  -- frames_time[at_frame] = measurement
  -- current_fps = current_fps + (1/frames_time[at_frame]) * (1/max_frames)

  self.surface:clear()

  -- Max magic.
  --self.digits_text:set_text(self.x.." "..self.y.." "..self.layer)
  -- self.digits_text:set_text(current_fps)
  local message
  if self.map == nil or self.map:get_id() ~= game:get_map():get_id() then
    self.map = self.game:get_map()
  else
    message = self.map.message
    if message == nil then message = "" end
  end
  -- if puzzle_logger then
  --   message = puzzle_logger.get_current_time_spent()
  -- end
  self.digits_text:set_text(message)
  self.digits_text:draw(self.surface, 48, 16)
end

function hud_position:set_dst_position(x, y)
  self.dst_x = x
  self.dst_y = y
end

function hud_position:on_draw(dst_surface)

  local x, y = self.dst_x, self.dst_y
  local width, height = dst_surface:get_size()
  if x < 0 then
    x = width + x
  end
  if y < 0 then
    y = height + y
  end

  self.surface:draw(dst_surface, x, y)
  self:update()
end

return hud_position

